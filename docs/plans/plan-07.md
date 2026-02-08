# Plan 07: Beads-Driven Task Orchestration with Agent Teams

**Status:** Completed

## Context

The workflows plugin decomposes plans into a DAG of beads and assigns agents, but the execution loop (`execute_plan`) uses sequential subagent dispatch via the Task tool. Claude Code now has Agent Teams — true parallel Claude instances with shared task lists, inter-agent messaging, and lifecycle hooks (TeammateIdle, TaskCompleted).

The vision: **beads orchestrates the task orchestration.** Beads is the persistent DAG of work. The Claude Task system is the live execution engine that pulls from beads, launches agents in parallel, and syncs completions back. Rules and hooks ensure beads exist before work starts. The chronicler overlays execution, capturing chronicle beads that are gated to end-of-plan so the diary agent sees the full arc.

## Key Concepts: Claude Code Execution Mechanisms

Three distinct mechanisms exist — they do different things:

| Mechanism | What it does | Agent-specific? | Parallel? |
|-----------|-------------|-----------------|-----------|
| **Task tool** (`subagent_type`) | Launches a specialized agent subprocess | Yes — maps to agent definitions | Yes — multiple Task calls in one message |
| **TaskCreate/TaskList** | Shared to-do list (coordination metadata) | No — just data | N/A — doesn't execute anything |
| **Agent Teams** | Multiple independent Claude sessions | No — all generic | Yes — separate sessions |

**Task tool** is the execution engine for "launch the right agent for this bead." The `subagent_type` parameter maps to agent definitions (e.g., `chronicler_diary`, a hypothetical `rust_writer`). This is what the current `execute_plan` uses.

**TaskCreate** is a shared Kanban board. It doesn't launch agents. Agent Teams teammates can see and self-claim items from it, but teammates are generic — there's no way to say "this teammate is a Rust specialist."

**Agent Teams** is for persistent multi-session coordination. Useful when you want sessions that stay alive across task batches, or human + AI collaboration. NOT the same as launching specialized agents.

**Implication:** The task pump uses the **Task tool with `subagent_type`** to launch the agent identified in each bead's `agent:<name>` label. Independent beads are dispatched in parallel (multiple Task calls in one message). Agent Teams is an optional overlay for persistent multi-session coordination, not the primary dispatch mechanism.

## Architecture

```
                    ┌──────────────────────┐
                    │   Plan Document      │
                    │   docs/plans/...     │
                    └──────────┬───────────┘
                               │ plan_to_beads
                               ▼
                    ┌──────────────────────┐
                    │   Beads DAG          │  ← Persistent store (git-backed)
                    │   epics → tasks      │     Labels, deps, agent assignments
                    │   chronicle gate     │     Survives sessions
                    │                      │     Syncs via beads-sync branch
                    └──────────┬───────────┘
                               │ task pump reads bd ready
                               │ groups by agent:<name>
                               ▼
                    ┌──────────────────────┐
                    │   Task Tool Dispatch │  ← Parallel agent launch
                    │   subagent_type from │     Multiple Task calls per batch
                    │   bead agent label   │     Each agent has own context
                    └──────────┬───────────┘
                               │ agents claim bead, work, close bead
                               │ pump loops: newly unblocked → next batch
                               ▼
                    ┌──────────────────────┐
                    │   Chronicler Overlay │
                    │   Chronicle beads    │  ← Captured during execution
                    │   tagged plan:<idx>  │     Gated to plan completion
                    │   diary at end       │     Full-arc diary generation
                    └──────────────────────┘

    Optional: Agent Teams layer for persistent multi-session coordination
    (lead monitors progress, teammates stay alive across batches)
```

## What Already Exists

- `plan_to_beads` — decomposes plan into beads DAG with deps, labels, gates
- `select_agent` — assigns `agent:<name>` labels to tasks
- `execute_plan` — dispatch loop (currently subagent-only)
- `plan-exec.sh` — state machine (start/pause/status/next/guard)
- Hooks — code-gate, plan-exec-guard, exit-plan-gate
- Chronicler — capture/recall/diary skills, pre-push hook
- Beads git-flow — already configured as team mode with `beads-sync` branch, daemon auto-sync

## What Needs to Change

### Solo/Team/Contributor Are Beads Git-Flow Modes (NOT plugin modes)

Beads already supports these via `bd init`:
- **Solo** — main branch unprotected, direct push
- **Team** (`bd init --team`) — dedicated sync branch (`beads-sync`), shared repo
- **Contributor** (`bd init --contributor`) — fork-based, separate planning repo, PRs

The workflows plugin doesn't need to implement these. It should **respect whatever mode beads is configured with** and document the differences. The `bd sync` and daemon handle git-flow automatically.

---

## Phase 0: Housekeeping

Add ephemeral pump state to `.gitignore`:
```
# Workflows plugin - ephemeral session state
.claude/.task-pump.json
.claude/.plan-gate
```

**File:** `.gitignore`

---

## Phase 1: Task Pump — Beads to Parallel Agent Dispatch

**Goal:** Create the mechanism that reads `bd ready`, groups by agent, and dispatches via Task tool in parallel batches.

### 1.1 New skill: `/workflows:task_pump`

**File:** `plugins/workflows/skills/task_pump/SKILL.md`

The pump reads beads that are ready, groups them by assigned agent, and dispatches parallel Task tool calls:

1. Query: `bd list -l plan:<idx> --ready --type=task --json`
2. Group beads by `agent:<name>` label
3. For each group, launch Task tool calls **in parallel** (multiple calls in one message):
   - `subagent_type` = agent name from bead label (e.g., `chronicler_diary`, `rust_writer`)
   - Prompt includes: full `bd show` context + instructions (claim bead, assess scope, implement, close bead)
   - Beads without `agent:<name>` label → dispatched as `general-purpose` subagent type
4. Track dispatched beads in `.claude/.task-pump.json` to prevent double-dispatch
5. Return: count dispatched, agent breakdown, bead IDs

**The pump is called repeatedly** — each time dependencies resolve and new beads become ready, the pump dispatches the next parallel batch.

**Key improvement over current `execute_plan`:** Today the dispatch is inline in execute_plan. Extracting it to a skill makes it reusable and testable. Grouping by agent and launching multiple Task calls in one message maximizes parallelism.

### 1.2 New script: `plugins/workflows/scripts/pump-state.sh`

Tracks which beads have been dispatched (prevents double-dispatch on re-pump):
- `pump-state.sh is-dispatched <bead-id>` — check if already sent
- `pump-state.sh mark-dispatched <bead-id>` — record dispatch
- `pump-state.sh mark-done <bead-id>` — record completion
- `pump-state.sh pending` — list dispatched but not yet done
- `pump-state.sh clear` — reset all state

State file: `.claude/.task-pump.json`

### 1.3 Tests

**File:** `tests/scenarios/unit-pump-state.yaml`
- Mark/check dispatch operations
- Missing file returns "not dispatched"
- Duplicate mark is idempotent
- Clear resets all

---

## Phase 2: Execution Loop Evolution

**Goal:** Evolve `execute_plan` to use the task pump for cleaner batch dispatch and completion tracking.

### 2.1 Modify: `/workflows:execute_plan`

**File:** `plugins/workflows/skills/execute_plan/SKILL.md`

Refactor the execution loop to use the pump:

**New execution flow:**
1. Identify plan (unchanged)
2. **Pump loop:**
   a. Call `plan-exec.sh next <root-epic>` to get ready beads
   b. If empty → check status:
      - All closed → auto-complete plan
      - Paused → report and stop
      - Some in-progress → wait for subagents to return, then re-check
   c. Call `/workflows:task_pump` — dispatches ready beads as parallel Task tool calls, grouped by agent type
   d. Subagents run in parallel, each:
      - Claims its bead: `bd update <id> --status=in_progress`
      - Assesses scope (breakdown if non-trivial)
      - Implements the work
      - Closes bead: `bd close <id>`
   e. Subagents return results to lead
   f. Lead updates pump state (mark done)
   g. Loop back to (a) — newly unblocked beads become ready
3. Completion (unchanged — update plan file, close root epic)

**Key differences from today:**
- Dispatch logic extracted to `task_pump` skill (reusable, testable)
- Beads grouped by `agent:<name>` before dispatch (right agent for each bead)
- Multiple Task tool calls per batch (parallel, not sequential)
- Pump state prevents double-dispatch across loop iterations

**Backwards compatible:** Same mechanism (Task tool), just better organized and more parallel.

### 2.2 Optional: Agent Teams hooks (future enhancement)

If Agent Teams is active (persistent teammate sessions), these hooks add value:

**`plugins/workflows/hooks/teammate-idle.sh`** (TeammateIdle)
- Check `bd ready` for active plan
- If work available: exit 2 (keep teammate working)
- If no work: exit 0 (idle)

**`plugins/workflows/hooks/task-completed.sh`** (TaskCompleted)
- If a teammate completes a native task that maps to a bead, sync the closure

These are additive — the core pump works without them. They're for when Agent Teams is the coordination layer on top of the pump.

### 2.3 Tests

**File:** `tests/scenarios/unit-pump-dispatch.yaml`
- Verify pump-state tracking across dispatch cycles
- Verify no double-dispatch when pump called twice with same ready set

---

## Phase 4: Chronicler Gating to Plan Execution

**Goal:** Chronicle beads captured during plan execution are gated to end-of-plan so the diary agent sees the full arc.

### 4.1 Modify: `/workflows:plan_to_beads`

**File:** `plugins/workflows/skills/plan_to_beads/SKILL.md`

After creating all plan tasks and wiring dependencies, add a final step:

**New Step: Create Chronicle Gate**
```bash
bd create --type=gate \
  --title="Generate diary from plan-<idx> chronicles" \
  --parent=<root-epic> \
  -l ys:chronicle-gate,plan:<idx> \
  --silent
```

This gate bead is part of the plan hierarchy. It stays open until plan execution completes.

### 4.2 Modify: `plugins/workflows/scripts/plan-exec.sh`

**In the `status` command:** When detecting "completed" status (all tasks closed), also check for chronicle gates:
```bash
# After determining all plan tasks are closed:
CHRONICLE_GATES=$(bd list -l "ys:chronicle-gate,$PLAN_LABEL" --status=open --type=gate --json 2>/dev/null)
if [[ -n "$CHRONICLE_GATES" ]]; then
    # Close chronicle gates — diary can now generate
    echo "$CHRONICLE_GATES" | jq -r '.[].id' | while read gate_id; do
        bd close "$gate_id" --reason="Plan execution completed, diary ready"
    done
fi
```

### 4.3 Modify: `/chronicler:capture`

**File:** `plugins/chronicler/skills/capture/SKILL.md`

Add plan-context auto-detection:
- Check if a plan is currently executing (look for `exec:executing` label on any open epic)
- If yes, auto-tag the chronicle bead with `plan:<idx>` label
- This links the chronicle to the specific plan execution

### 4.4 Modify: `/chronicler:diary`

**File:** `plugins/chronicler/skills/diary/SKILL.md`

Add optional plan filtering:
- New argument: `plan_idx` (optional)
- If provided: only process chronicles with `plan:<idx>` label
- Check for open chronicle gates: if gate still open for this plan, warn "Plan still executing — diary will capture partial arc. Proceed anyway?"
- If no plan_idx: process all open chronicles (current behavior)

### 4.5 Tests

**File:** `tests/scenarios/unit-chronicle-gate.yaml`
- plan_to_beads creates chronicle gate bead
- Gate has correct labels: `ys:chronicle-gate,plan:<idx>`
- Gate is child of root epic
- plan-exec.sh closes gate when plan completes

---

## Phase 5: Documentation & Metadata

### 5.1 New rule: `plugins/workflows/rules/beads-drive-tasks.md`

Behavioral rule: "Beads are the source of truth. Native tasks are projections. Never create native tasks for plan work without corresponding beads."

### 5.2 Modified files

- `plugins/workflows/.claude-plugin/plugin.json` — version bump to 1.3.0, new hooks
- `plugins/workflows/README.md` — document architecture, pump, chronicler gating
- `.claude-plugin/marketplace.json` — update workflows version
- `CHANGELOG.md` — v1.3.0 entry
- `CLAUDE.md` — update workflows architecture description
- Memory files — add plan-07 reference

---

## Dependency Graph

```
Phase 1 (Task Pump) ──→ Phase 2 (Execution Loop)
                                    │
Phase 3 (Chronicler Gating) ───────┘  (can start in parallel with Phase 2)
                                    │
                                    ▼
                           Phase 4 (Docs)
```

## File Summary

| Phase | Action | File |
|-------|--------|------|
| 1 | Create | `plugins/workflows/skills/task_pump/SKILL.md` |
| 1 | Create | `plugins/workflows/scripts/pump-state.sh` |
| 1 | Create | `tests/scenarios/unit-pump-state.yaml` |
| 2 | Modify | `plugins/workflows/skills/execute_plan/SKILL.md` |
| 2 | Create | `tests/scenarios/unit-pump-dispatch.yaml` |
| 2 | Create | `plugins/workflows/hooks/teammate-idle.sh` (optional, Agent Teams) |
| 2 | Create | `plugins/workflows/hooks/task-completed.sh` (optional, Agent Teams) |
| 3 | Modify | `plugins/workflows/skills/plan_to_beads/SKILL.md` |
| 3 | Modify | `plugins/workflows/scripts/plan-exec.sh` |
| 3 | Modify | `plugins/chronicler/skills/capture/SKILL.md` |
| 3 | Modify | `plugins/chronicler/skills/diary/SKILL.md` |
| 3 | Create | `tests/scenarios/unit-chronicle-gate.yaml` |
| 4 | Create | `plugins/workflows/rules/beads-drive-tasks.md` |
| 4 | Modify | `plugins/workflows/.claude-plugin/plugin.json` |
| 4 | Modify | `plugins/workflows/README.md` |
| 4 | Modify | `.claude-plugin/marketplace.json` |
| 4 | Modify | `CHANGELOG.md` |

**Totals:** 9 new files (2 optional), 7 modified files

## Scope Boundaries

- Does **not** implement beads git-flow modes (solo/team/contributor) — beads handles this natively via `bd init --team` / `bd init --contributor`
- Beads is the persistent store; Task tool subagents are the execution mechanism
- Does **not** change the plan lifecycle state machine (Draft/Ready/Executing/Paused/Completed)
- Does **not** modify existing hooks (code-gate, exit-plan-gate, plan-exec-guard)
- Agent Teams hooks (TeammateIdle, TaskCompleted) are optional enhancements, not core

## Verification

After each phase: `bash tests/run-tests.sh --unit-only`

End-to-end test procedure:
1. Create a plan with 4-5 tasks (2 parallel, 2 sequential, 1 final)
2. `plan_to_beads` — verify DAG + chronicle gate created
3. `execute_plan` — verify pump groups by agent, dispatches parallel Task calls
4. Verify subagents claim beads, implement work, close beads
5. Verify newly unblocked beads get pumped in next batch
6. Capture 2-3 chronicles during execution — verify `plan:<idx>` auto-tagging
7. On plan completion — verify chronicle gate closed, diary sees full arc
