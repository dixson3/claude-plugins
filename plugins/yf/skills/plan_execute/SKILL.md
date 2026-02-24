---
name: yf:plan_execute
description: Orchestrate plan execution by dispatching tasks to agents respecting dependencies and execution state
arguments:
  - name: plan_file
    description: "Path to plan file"
    required: false
  - name: plan_idx
    description: "Plan index (e.g., 0003-a3x7m)"
    required: false
---

## Activation Guard

Before proceeding, check that yf is active:

```bash
ACTIVATION=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-activation-check.sh")
IS_ACTIVE=$(echo "$ACTIVATION" | jq -r '.active')
```

If `IS_ACTIVE` is not `true`, read the `reason` and `action` fields from `$ACTIVATION` and tell the user:

> Yoshiko Flow is not active: {reason}. {action}

Then stop. Do not execute the remaining steps.

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

# Execute Plan Skill

Orchestrates plan execution using the task pump. The pump reads ready tasks from the plan DAG, classifies each into a **formula track** (dispatched via `/yf:swarm_run`) or an **agent track** (dispatched via bare Task tool calls), and launches them in parallel. The execution loop continues until all work is complete.

## Prerequisites

- Plan must be in Executing state (gate resolved, tasks undeferred)
- `plan-exec.sh start <root-epic>` must have been called first

## Behavior

### Step 1: Identify Plan

If `plan_idx` not specified, find the most recent active plan:
```bash
bash "$YFT" list -l ys:plan --type=epic --status=open --sort=created --reverse --limit=1
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

Call `/yf:plan_pump` with the plan index. The pump:

1. Calls `plan-exec.sh next <root-epic-id>` to get ready tasks
2. Filters out already-dispatched tasks via `dispatch-state.sh pump is-dispatched`
3. Classifies each task into **formula track** (has `formula:<name>` label → dispatch via `/yf:swarm_run`) or **agent track** (has `agent:<name>` label only → dispatch via bare Task tool)
4. Returns two groups: formula tasks (for swarm dispatch) and agent tasks (for bare Task dispatch)

#### 3b. Check Empty Result

If the pump returns no tasks to dispatch:
- Check `plan-exec.sh status <root-epic-id>`:
  - **completed** -> proceed to Step 4 (completion)
  - **paused** -> report "Plan is paused. Say 'resume the plan' to continue." and stop
  - **executing** with in-progress tasks -> wait for subagents to return, then re-pump

> **CRITICAL: Dispatch Routing**
> Tasks with a `formula:<name>` label MUST be dispatched via `/yf:swarm_run`, NOT via bare Task tool calls. Bare dispatch of formula-labeled tasks is a bug — it bypasses multi-agent workflows (research → implement → review), structured task comments (FINDINGS/CHANGES/REVIEW/TESTS), reactive bugfix spawning, and chronicle capture.

#### 3c. Dispatch in Parallel

For each group from the pump, launch dispatch calls **in parallel** (multiple calls in one message). The pump classifies tasks into two tracks:

**Formula dispatch** (tasks with `formula:<name>` label):
Invoke the swarm system for full multi-agent workflow:
```
/yf:swarm_run formula:<formula-name> feature:"<task title>" parent_task:<task-id>
```

The swarm handles the complete lifecycle: wisp instantiation, step dispatch through specialized agents, squash on completion, and chronicle capture. The parent task is closed by swarm_run on success.

**Agent dispatch** (tasks with `agent:<name>` label, no formula):
```
Task(
  subagent_type = "<agent-name>",
  prompt = "Work on task <task-id>

Context from bash "$YFT" show:
<full task context>

Instructions:
1. Claim the task: bash "$YFT" update <task-id> --status=in_progress
2. Review scope — if non-trivial, invoke /yf:plan_breakdown first
3. Do the work described in the task
4. Close when done: bash "$YFT" close <task-id>
5. If you create sub-tasks, use bash "$YFT" create with --parent=<task-id>
   and invoke /yf:plan_select_agent on each"
)
```

**Direct execution** (tasks without agent or formula label): Claim with `bash "$YFT" update <task-id> --status=in_progress` and work directly.

Mark each dispatched task:
```bash
plugins/yf/scripts/dispatch-state.sh pump mark-dispatched <task-id>
```

#### 3d. Wait and Loop

After dispatching a batch:
1. Wait for all dispatched Task tool calls to return
2. Mark completed tasks: `dispatch-state.sh pump mark-done <task-id>`
3. Loop back to Step 3a — newly unblocked tasks become ready

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
   bash "$YFT" list -l "ys:chronicle:auto,plan:<idx>" --status=open --json 2>/dev/null \
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
CLOSED=$(bash "$YFT" count -l "$PLAN_LABEL" --status=closed --type=task 2>/dev/null || echo "0")
TOTAL=$(bash "$YFT" list -l "$PLAN_LABEL" --type=task --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Chronicle counts
ALL_CHRON=$(bash "$YFT" list -l ys:chronicle,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN_CHRON=$(bash "$YFT" list -l ys:chronicle,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Archive counts
ALL_ARCH=$(bash "$YFT" list -l ys:archive,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN_ARCH=$(bash "$YFT" list -l ys:archive,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
```

7. **Report structured completion**: Include tasks completed count, chronicles captured/processed, diary entries generated, archives captured/processed. Omit sections with zero items. Always include the Tasks line.

## Error Handling

- Subagent failure: task stays in_progress, pump continues with other ready tasks
- Guard error from `plan-exec.sh next`: report state and stop
- Dispatch state prevents double-dispatch of in-flight tasks
