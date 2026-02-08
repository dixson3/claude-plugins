---
name: workflows:execute_plan
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

Orchestrates plan execution using the task pump. The pump reads ready beads from the plan DAG, groups them by assigned agent, and dispatches them as parallel Task tool calls. The execution loop continues until all work is complete.

## Architecture

```
Beads DAG (persistent) → task pump → Task tool (parallel agent dispatch) → loop
```

**Beads** is the source of truth for what work exists, what's blocked, and what's ready.
**Task tool** with `subagent_type` is the execution engine — it launches the right agent for each bead.
**The pump** bridges these: reads beads, dispatches agents, tracks state.

## When to Invoke

- Called by `/workflows:engage_plan` during the Ready → Executing transition
- Can be invoked directly: `/workflows:execute_plan`

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
plugins/workflows/scripts/pump-state.sh clear
```

### Step 3: Pump Loop

Repeat until no more tasks:

#### 3a. Invoke Task Pump

Call `/workflows:task_pump` with the plan index. The pump:

1. Calls `plan-exec.sh next <root-epic-id>` to get ready beads
2. Filters out already-dispatched beads via `pump-state.sh is-dispatched`
3. Groups remaining beads by `agent:<name>` label
4. Returns the grouped beads for dispatch

#### 3b. Check Empty Result

If the pump returns no beads to dispatch:
- Check `plan-exec.sh status <root-epic-id>`:
  - **completed** → proceed to Step 4 (completion)
  - **paused** → report "Plan is paused. Say 'resume the plan' to continue." and stop
  - **executing** with in-progress tasks → wait for subagents to return, then re-pump

#### 3c. Dispatch in Parallel

For each agent group from the pump, launch Task tool calls **in parallel** (multiple calls in one message):

**Subagent dispatch** (tasks with `agent:<name>` label):
```
Task(
  subagent_type = "<agent-name>",
  prompt = "Work on bead <task-id>

Context from bd show:
<full task context>

Instructions:
1. Claim the task: bd update <task-id> --status=in_progress
2. Review scope — if non-trivial, invoke /workflows:breakdown_task first
3. Do the work described in the task
4. Close when done: bd close <task-id>
5. If you create sub-tasks, use bd create with --parent=<task-id>
   and invoke /workflows:select_agent on each"
)
```

**Direct execution** (tasks without agent label — `general-purpose`):
Claim and work on the task directly:
```bash
bd update <task-id> --status=in_progress
```
Then follow the same workflow: assess scope, break down if needed, implement, close.

Mark each dispatched bead:
```bash
plugins/workflows/scripts/pump-state.sh mark-dispatched <bead-id>
```

#### 3d. Wait and Loop

After dispatching a batch:
1. Wait for all dispatched Task tool calls to return
2. Mark completed beads: `pump-state.sh mark-done <bead-id>`
3. Loop back to Step 3a — newly unblocked beads become ready

### Step 4: Completion

When `plan-exec.sh status` returns `completed` (which also closes any chronicle gates):

1. Capture completion context: Invoke `/chronicler:capture topic:completion` to preserve the execution summary as a chronicle bead before closing everything out.
2. Generate diary: Invoke `/chronicler:diary plan:<idx>` to process all plan chronicles into diary entries. This is scoped to the plan so it only processes chronicles tagged with that plan label.
3. Update plan file status to "Completed"
4. Close root epic if not already closed
5. Report completion summary (include diary file paths in the report)

```
Plan Execution Complete
=======================
Plan: plan-07 — <Title>
Tasks completed: 12/12
Duration: <time from first claim to last close>

Diary entries generated for plan:07.
```

## Parallel Dispatch Rules

- Tasks at the same dependency level with no inter-dependencies → dispatch in parallel
- Tasks with `bd dep` relationships → respect ordering (blocked tasks won't appear in `bd ready`)
- Multiple subagents can run concurrently for different agent types
- The beads dependency system naturally enforces correct ordering
- The pump groups by agent for efficient batch dispatch

## Error Handling

- If a subagent fails, its bead stays in_progress — the pump loop continues with other ready beads
- Failed tasks should be reported for manual intervention
- If `plan-exec.sh next` returns a guard error, report the state and stop the loop
- Pump state prevents double-dispatch: if a bead was dispatched but the subagent hasn't returned, it won't be re-dispatched
