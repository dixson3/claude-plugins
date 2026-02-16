---
name: yf:plan_execute
description: Orchestrate plan execution by dispatching tasks to agents respecting dependencies and execution state
arguments:
  - name: plan_file
    description: "Path to plan file"
    required: false
  - name: plan_idx
    description: "Plan index (e.g., 03)"
    required: false
---

# Execute Plan Skill

Orchestrates plan execution using the task pump. The pump reads ready beads from the plan DAG, classifies each into a **formula track** (dispatched via `/yf:swarm_run`) or an **agent track** (dispatched via bare Task tool calls), and launches them in parallel. The execution loop continues until all work is complete.

## Architecture

```
Beads DAG (persistent) → task pump → Task tool (parallel agent dispatch) → loop
```

**Beads** is the source of truth for what work exists, what's blocked, and what's ready.
**Task tool** with `subagent_type` is the execution engine — it launches the right agent for each bead.
**The pump** bridges these: reads beads, dispatches agents, tracks state.

## When to Invoke

- Called by `/yf:engage_plan` during the Ready -> Executing transition
- Can be invoked directly: `/yf:execute_plan`

## Prerequisites

- Plan must be in Executing state (gate resolved, tasks undeferred)
- `plan-exec.sh start <root-epic>` must have been called first

## Behavior

### Step 1: Identify Plan

If `plan_idx` not specified, find the most recent active plan:
```bash
bd list -l ys:plan --type=epic --status=open --sort=created --reverse --limit=1
```

Extract the `plan:<idx>` label and root epic ID.

### Step 2: Initialize Pump State

Clear any stale pump state from a previous execution:
```bash
plugins/yf/scripts/dispatch-state.sh pump clear
```

### Step 3: Pump Loop

Repeat until no more tasks:

#### 3a. Invoke Task Pump

Call `/yf:task_pump` with the plan index. The pump:

1. Calls `plan-exec.sh next <root-epic-id>` to get ready beads
2. Filters out already-dispatched beads via `dispatch-state.sh pump is-dispatched`
3. Classifies each bead into **formula track** (has `formula:<name>` label → dispatch via `/yf:swarm_run`) or **agent track** (has `agent:<name>` label only → dispatch via bare Task tool)
4. Returns two groups: formula beads (for swarm dispatch) and agent beads (for bare Task dispatch)

#### 3b. Check Empty Result

If the pump returns no beads to dispatch:
- Check `plan-exec.sh status <root-epic-id>`:
  - **completed** -> proceed to Step 4 (completion)
  - **paused** -> report "Plan is paused. Say 'resume the plan' to continue." and stop
  - **executing** with in-progress tasks -> wait for subagents to return, then re-pump

> **CRITICAL: Dispatch Routing**
> Beads with a `formula:<name>` label MUST be dispatched via `/yf:swarm_run`, NOT via bare Task tool calls. Bare dispatch of formula-labeled beads is a bug — it bypasses multi-agent workflows (research → implement → review), structured bead comments (FINDINGS/CHANGES/REVIEW/TESTS), reactive bugfix spawning, and chronicle capture.

#### 3c. Dispatch in Parallel

For each group from the pump, launch dispatch calls **in parallel** (multiple calls in one message). The pump classifies beads into two tracks:

**Formula dispatch** (tasks with `formula:<name>` label):
Invoke the swarm system for full multi-agent workflow:
```
/yf:swarm_run formula:<formula-name> feature:"<bead title>" parent_bead:<task-id>
```

The swarm handles the complete lifecycle: wisp instantiation, step dispatch through specialized agents, squash on completion, and chronicle capture. The parent bead is closed by swarm_run on success.

**Agent dispatch** (tasks with `agent:<name>` label, no formula):
```
Task(
  subagent_type = "<agent-name>",
  prompt = "Work on bead <task-id>

Context from bd show:
<full task context>

Instructions:
1. Claim the task: bd update <task-id> --status=in_progress
2. Review scope — if non-trivial, invoke /yf:breakdown_task first
3. Do the work described in the task
4. Close when done: bd close <task-id>
5. If you create sub-tasks, use bd create with --parent=<task-id>
   and invoke /yf:select_agent on each"
)
```

**Direct execution** (tasks without agent or formula label — `general-purpose`):
Claim and work on the task directly:
```bash
bd update <task-id> --status=in_progress
```
Then follow the same workflow: assess scope, break down if needed, implement, close.

Mark each dispatched bead:
```bash
plugins/yf/scripts/dispatch-state.sh pump mark-dispatched <bead-id>
```

#### 3d. Wait and Loop

After dispatching a batch:
1. Wait for all dispatched Task tool calls to return
2. Mark completed beads: `dispatch-state.sh pump mark-done <bead-id>`
3. Loop back to Step 3a — newly unblocked beads become ready

### Step 3e: Qualification Gate

When `plan-exec.sh status` returns `completed` (which also closes any chronicle gates), but **before** running the completion sequence:

1. Invoke `/yf:swarm_qualify plan_idx:<idx>` to run the code-review qualification gate
2. If the qualification returns **PASS** (or config is `advisory`/`disabled`), proceed to Step 4
3. If the qualification returns **BLOCK** (and config is `blocking`):
   - Report the block to the user
   - Do NOT proceed to Step 4
   - The user must fix the issues and re-run `/yf:plan_execute`

### Step 4: Completion

After qualification passes (or is advisory/disabled):

1. **Verify completion chronicle**: A completion chronicle stub was already created by `plan-exec.sh` when it detected completion. Verify it exists:

   ```bash
   bd list -l "ys:chronicle:auto,plan:<idx>" --status=open --json 2>/dev/null \
     | jq '[.[] | select(.title | ascii_downcase | contains("complete"))] | length'
   ```

   - If count > 0: stub exists. Optionally invoke `/yf:chronicle_capture topic:completion` to create an enriched chronicle with execution details.
   - If count = 0: invoke `/yf:chronicle_capture topic:completion` as a fallback to preserve the execution summary.
2. **Generate diary**: Invoke `/yf:chronicle_diary plan:<idx>` to process
   all open chronicles into diary entries. This must run before any
   pruning so chronicle content is preserved.

3. **Process archives**: Invoke `/yf:archive_process plan:<idx>`.

3.25. **Structural staleness check**: Run the mechanical consistency
   checks to catch any drift introduced during plan execution:
   ```bash
   bash plugins/yf/scripts/spec-sanity-check.sh all
   ```
   Include results in the completion report. If issues found, list them
   as warnings with recommended fixes.

3.5. **Spec self-reconciliation**: Reconcile specifications with
   themselves — verify:
   - PRD requirements trace to EDD design decisions
   - EDD decisions trace to IG use cases
   - test-coverage.md reflects all current spec items (REQ, DD, NFR, UC)
   - No orphaned entries (IDs in coverage but not in source spec)
   - No stale entries (removed capabilities still listed)

   Use `/yf:engineer_suggest_updates plan_idx:<idx>` for advisory
   suggestions, then output the sanity check report alongside.

3.75. **Prune deprecated artifacts**: If the plan or its spec changes
   deprecated any tests, functionality, or spec entries (identified
   at intake step 1.5d), verify those removals were completed. If not,
   flag as open items in the completion report.
4. **Update plan file** status to "Completed"
5. **Close root epic** if not already closed
6. **Collect summary data** for the completion report:

```bash
PLAN_LABEL="plan:<idx>"
# Task counts
CLOSED=$(bd count -l "$PLAN_LABEL" --status=closed --type=task 2>/dev/null || echo "0")
TOTAL=$(bd list -l "$PLAN_LABEL" --type=task --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Chronicle counts
ALL_CHRON=$(bd list -l ys:chronicle,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN_CHRON=$(bd list -l ys:chronicle,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Archive counts
ALL_ARCH=$(bd list -l ys:archive,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN_ARCH=$(bd list -l ys:archive,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
```

7. **Report structured completion** (see `yf-plan-completion-report` rule):

```
Plan Execution Complete
=======================
Plan: plan-07 — <Title>
Tasks: 12/12 completed

Chronicles: 5 captured, 4 processed into diary, 1 still open
Diary entries:
  - docs/diary/26-02-13.14-30.authentication.md
  - docs/diary/26-02-13.16-00.api-layer.md

Archives: 2 captured, 2 processed
  - docs/research/oauth-providers/SUMMARY.md
  - docs/decisions/DEC-003-session-storage/SUMMARY.md

⚠ 1 chronicle bead still open — run /yf:chronicle_diary to process
```

Omit sections with zero items (e.g., if no archives were captured, omit the Archives section entirely). Always include the Tasks line.

## Parallel Dispatch Rules

- Tasks at the same dependency level with no inter-dependencies -> dispatch in parallel
- Tasks with `bd dep` relationships -> respect ordering (blocked tasks won't appear in `bd ready`)
- Multiple subagents can run concurrently for different agent types
- The beads dependency system naturally enforces correct ordering
- The pump groups by agent for efficient batch dispatch

## Error Handling

- If a subagent fails, its bead stays in_progress — the pump loop continues with other ready beads
- Failed tasks should be reported for manual intervention
- If `plan-exec.sh next` returns a guard error, report the state and stop the loop
- Pump state prevents double-dispatch: if a bead was dispatched but the subagent hasn't returned, it won't be re-dispatched
