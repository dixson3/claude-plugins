# Yoshiko Flow — Agent Rules

Rules are ordered by priority. Hard enforcement rules are checked first; advisory monitoring runs at lowest priority.

## 1. HARD ENFORCEMENT

### 1.0 Activation Gate

yf is INACTIVE when ANY of:
- `.yoshiko-flow/config.json` does not exist
- `.yoshiko-flow/config.json` has `enabled: false`
- The beads plugin (`steveyegge/beads`) is not installed

When inactive: all skills except `/yf:setup` refuse to execute, all hooks exit silently.
To activate: install beads (`/install steveyegge/beads`), then run `/yf:setup`.

### 1.1 Beads Are the Source of Truth

During plan execution, beads own all task state. The Claude Task system (TaskCreate/TaskList) is NOT used for plan work.

- **Never** create native Tasks (TaskCreate) for plan work. All work items come from beads via `bd ready`.
- The task pump dispatches beads to agents via the Task tool with appropriate `subagent_type`.
- Agents claim beads (`bd update <id> --status=in_progress`) and close them (`bd close <id>`).
- Dependencies live in beads (`bd dep add`).
- Before writing code for a plan, verify beads exist: `bd list -l plan:<idx>`. If none exist, invoke `/yf:plan_create_beads` first.

### 1.2 Plan Intake: No Implementation Without Lifecycle

**CRITICAL — Hard Enforcement.** Backed by `code-gate.sh` which BLOCKS Edit/Write when a plan file exists without beads.

Before writing ANY implementation code, self-check:
1. Does the conversation contain plan-like content? (headings, phases, steps)
2. Did the user say "implement" + "plan"?
3. Has `/yf:plan_intake` already run in this session?

If (1) AND (2) AND NOT (3): invoke `/yf:plan_intake` BEFORE any edits.

**Detection:** Fires when ALL of these are true:
- The user says "implement the/this plan" or provides plan content to execute
- Plan-like content exists (headings like "## Implementation", structured task lists)
- The auto-chain has NOT fired (no "Auto-chaining plan lifecycle..." message)

If the auto-chain HAS fired, this rule does NOT apply.

**Action:** Invoke `/yf:plan_intake` which handles: save plan file, create beads, start execution, capture context, dispatch.

**No exceptions.** This rule has NO override for agent judgment. Even if plan content appears to conflict with the beads system, the lifecycle still applies.

### 1.3 Formula-Labeled Beads Route Through Swarm

During plan execution, when the task pump reads a bead with a `formula:<name>` label:

```bash
bd label list <bead-id> --json | jq -r '.[] | select(startswith("formula:"))'
```

If found, dispatch via `/yf:swarm_run formula:<name> feature:"<title>" parent_bead:<bead-id>`. Do NOT use bare Task tool dispatch — that bypasses multi-agent workflows, structured comments, reactive bugfix, and chronicle capture.

**Validation before dispatching any bead:**
1. Check for formula label
2. If formula label: dispatch via `/yf:swarm_run`
3. If no formula label: dispatch via bare Task tool with `subagent_type` from `agent:<name>` label

### 1.4 Specifications Are Anchor Documents

When `<artifact_dir>/specifications/` exists, specifications define the contract. All plans, tests, and implementations conform to the spec — not the reverse.

- **No contraction**: No plan may remove, weaken, or contradict existing REQ, DD, NFR, or UC entries without explicit operator approval.
- **New capability requires spec coverage**: Functionality not traced to existing spec entries must have spec additions (new REQs, new UCs, new DDs) written as part of the implementing plan — not after.
- **Tests align to specs first**: Test cases reference specification items (REQ-xxx, UC-xxx, DD-xxx) as their primary basis. Implementation-only tests are insufficient.
- **Spec changes require approval**: All additions, modifications, and deprecations to spec files require explicit operator approval via AskUserQuestion before writing.
- **When in doubt, read the spec. When the spec is silent, extend it.**

Skills: `/yf:engineer_reconcile`, `/yf:engineer_update`, `/yf:engineer_suggest_updates`

Enforcement: The plan intake checklist (Step 1.5 in `plan_intake/SKILL.md`) and plan completion checklist (Steps 3.25–3.75 in `plan_execute/SKILL.md`) operationalize these principles at lifecycle boundaries. The structural consistency script (`spec-sanity-check.sh`) provides mechanical backstop checks.

---

## 2. PLAN LIFECYCLE

### 2.1 Auto-Chain After ExitPlanMode

When ExitPlanMode completes and you see "Auto-chaining plan lifecycle..." in hook output, execute automatically without waiting for user input:

1. **Format plan file** — standard structure (# Plan, Status, Date, Overview, Implementation Sequence, Completion Criteria). Plan files in `docs/plans/` are exempt from the plan gate.
1.5. **Specification integrity gate** — If `<artifact_dir>/specifications/` exists, run the intake checklist (Rule 1.4): contradiction check, new capability check, test-spec alignment, test deprecation, chronicle spec/functionality changes, structural consistency (`bash plugins/yf/scripts/spec-sanity-check.sh all`). All spec changes require explicit operator approval. Then proceed with reconciliation.
2. **Reconcile with specifications** — If `<artifact_dir>/specifications/` exists, invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`. If conflicts detected, present to operator. If no specs, skip.
3. **Update MEMORY.md** — Add plan reference under "Current Plans".
4. **Create beads** — Invoke `/yf:plan_create_beads` with the plan file.
5. **Start execution** — `bash plugins/yf/scripts/plan-exec.sh start "$ROOT_EPIC"`.
6. **Begin dispatch** — Invoke `/yf:plan_execute`.

A plan-save chronicle stub is already created by `exit-plan-gate.sh`. If the planning discussion had significant design rationale beyond the plan file, optionally invoke `/yf:chronicle_capture topic:planning` for enrichment.

If the planning discussion involved web searches or design decisions with alternatives, invoke `/yf:archive_capture type:research` or `/yf:archive_capture type:decision` between plan save and beads creation.

If any step fails, stop and report. The user can retry or run `/yf:plan_dismiss_gate`.

### 2.2 Plan Lifecycle Phrase Triggers

When the user says lifecycle phrases, invoke `/yf:plan_engage`:
- "the plan is ready" / "activate the plan" → Ready
- "execute the plan" / "start the plan" / "run the plan" → Executing
- "pause the plan" / "stop the plan" → Paused
- "resume the plan" → Resume
- "mark plan complete" → Complete

Note: The Draft transition is handled by ExitPlanMode auto-chain.

### 2.3 Breakdown Before Building

Before writing code on a claimed task, review its scope:
1. Read the task: `bd show <task-id>`
2. If non-trivial (multiple files, multiple concerns, distinct phases): invoke `/yf:plan_breakdown <task-id>`
3. If atomic (single file, single concern): proceed directly

This applies to ALL agents including subagents.

### 2.4 Plan Completion Report

When `plan-exec.sh status` returns "completed", the report MUST include:

1. **Task Summary** — closed/total counts
2. **Chronicle Summary** — total captured, processed into diary, still open
3. **Diary Entries** — list files from `docs/diary/`
4. **Archive Summary** — total, processed, open; list files from `docs/research/`, `docs/decisions/`
5. **Qualification Summary** — REVIEW verdict, config mode, issues
6. **Specification Status** — PRD/EDD/IG/TODO existence, sanity check result (pass/N issues), self-reconciliation verdict, any spec changes made during this plan
7. **Open Items Warning** — warn if chronicles or archives remain open
8. **Deprecated Artifacts** — list any tests, functionality, or spec entries marked for deprecation at intake and whether removal was completed

Spec check (shared by all spec-aware sections):
```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

If specs exist after plan completion, invoke `/yf:engineer_suggest_updates plan_idx:<idx>` for advisory update suggestions.

---

## 3. SWARM EXECUTION

### 3.1 Comment Protocol

Agents within a swarm communicate through structured comments on the parent bead. Prefix format is mandatory:

| Prefix | Posted by | Must include |
|--------|-----------|-------------|
| `FINDINGS:` | Research/analysis steps | Purpose, Sources, Summary, Recommendations |
| `CHANGES:` | Implementation steps | Files Modified, Files Created, Summary |
| `REVIEW:PASS` or `REVIEW:BLOCK` | Review steps | Verdict line, Summary, Issues, Files Reviewed |
| `TESTS:` | Test steps | PASS/FAIL counts, Test Files, Coverage |

Post: `bd comment <parent-bead-id> "<PREFIX>: ..."`. Read upstream: `bd show <parent-bead-id> --comments`.

### 3.2 Nesting Depth Limit

Maximum nesting depth: **2**. At depth 2, `compose` fields are ignored — steps dispatch as bare Tasks. Sub-swarms post comments on the outermost parent bead.

### 3.3 Reactive Bugfix

After a swarm step posts `REVIEW:BLOCK` or `TESTS:` with failures, the dispatch loop invokes `/yf:swarm_react`.

Eligible when: depth < 2, no prior `ys:bugfix-attempt` label, config `reactive_bugfix` not false, bug (not design concern).

Design BLOCKs ("wrong approach", "needs redesign", "architectural concern") are excluded — they require human judgment.

Budget: 1 retry per step (configurable via `max_retries`). After bugfix, the failed step is retried via `dispatch-state.sh swarm mark-retrying`.

---

## 4. SESSION PROTOCOL

### 4.1 Beads Quick Reference

Agent operations use beads skills (DD-016):

```
/beads:ready              # Find available work
/beads:show <id>          # View issue details
/beads:update <id> --status in_progress  # Claim work
/beads:close <id>         # Complete work
/beads:sync               # Sync beads state with git
```

Also available via `bd` CLI for direct access: `bd ready`, `bd show`, `bd update`, `bd close`, `bd sync`.

### 4.2 Landing the Plane

When ending a work session:
1. File issues for remaining work
2. Capture context (if significant): `/yf:chronicle_capture topic:session-close`
3. Generate diary (if open chronicles): `/yf:chronicle_diary`
4. Run quality gates (if code changed)
4.5. Memory reconciliation (if specs exist): `/yf:memory_reconcile`
5. Update issue status — close finished work
6. Session prune (automatic via SessionEnd hook; manual: `bash plugins/yf/scripts/session-prune.sh all`)
7. Sync beads: `bd sync`
8. Commit code changes
9. Push only when user explicitly requests
10. Hand off context for next session

---

## 5. ADVISORY MONITORING

### 5.1 Swarm Completion Bridges

After a swarm completes (wisp squashed):

- If FINDINGS contain URLs/external sources or multi-source synthesis: suggest `/yf:archive_capture type:research`
- If REVIEW:BLOCK raised architectural concerns: suggest `/yf:archive_capture type:decision`
- If reactive bugfix triggered: auto-capture a chronicle bead (NOT advisory — fires automatically via `swarm_react` Step 4.5)
- If formula was feature-build/build-test/code-implement with REVIEW:PASS and specs exist: suggest `/yf:engineer_suggest_updates`

At most once per swarm completion. Skip trivial swarms.

### 5.2 Research Spike During Planning

During plan mode, if 3+ web searches performed, or comparing alternatives, or reading multiple API docs: suggest `/yf:swarm_run formula:research-spike feature:"<topic>"`. Check for existing archive beads first. At most once per planning session.

### 5.3 Chronicle Worthiness

An event is chronicle-worthy when it produces **context that would be lost** and **would be needed to understand future work**.

**Tier 1 — Auto-capture (deterministic, no suggestion needed):**

These fire within skills. The agent does NOT need to watch for them.

| Event | Skill | Captures |
|-------|-------|----------|
| Reconciliation conflict | `engineer_reconcile` Step 7.5 | Verdict, conflicts, operator decision |
| Spec mutation | `engineer_update` Step 3.5 | Action, entry ID, rationale |
| Qualification verdict | `swarm_qualify` Step 6.5 | PASS/BLOCK, scope, issues |
| Scope change (3+ children) | `plan_breakdown` Step 5.5 | Parent task, child count, decomposition rationale |
| Intake reconciliation | `plan_intake` Step 1.5g | Reconciliation verdict, spec changes approved |
| Swarm step completion | `swarm_dispatch` Step 6c | Step comment content (when formula `"chronicle": true`) |

**Tier 2 — Agent-initiated (behavioral, write-capable agents):**

Write-capable swarm agents (`yf_code_writer`, `yf_code_tester`, `yf_swarm_tester`) create chronicle beads when they encounter:

- **Plan deviation**: implementation diverges from task description or upstream FINDINGS
- **Unexpected discovery**: constraint, dependency, or behavior not anticipated
- **Test failure with non-obvious cause**: failure whose root cause is not the code under test

Using: `bd create --type task --title "Chronicle: <summary>" -l ys:chronicle,ys:topic:swarm --description "<what, why, impact>"`

**Tier 3 — Advisory (main agent watches):**

The main orchestrating agent suggests `/yf:chronicle_capture` for:

- Context switches between plan tasks (at most once per switch)
- Significant blockers requiring human input
- Session boundaries (already in Rule 4.2 step 2)

Cadence: at most once every 15 minutes. Tiers 1 and 2 are NOT advisory — they fire automatically.

**NOT chronicle-worthy**: routine task completion matching the plan, config tweaks, formatting, typo fixes, intermediate pipeline steps (the terminal step captures the outcome).

### 5.4 Archive Worthiness

Flag archive-worthy research (web searches, external docs, tool evaluations) and decisions (architecture choices, tool selections, scope changes with alternatives).

Suggest `/yf:archive_capture type:research` or `type:decision`. Do NOT auto-capture. At most once every 15-20 minutes.

### 5.5 Specification Drift

If specs exist under `<artifact_dir>/specifications/`, watch for:
- PRD drift: new functionality not traced to REQ-xxx, requirement contradictions
- EDD drift: technology conflicts with DD-xxx, NFR violations
- IG drift: feature changes affecting documented use cases

Suggest appropriate `/yf:engineer_update type:<type>` command. Do NOT auto-update. At most once every 15-20 minutes. Skip if no spec files exist.
