---
name: execute_plan
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

Orchestrates plan execution. Dispatches ready tasks to appropriate agents, respects dependency ordering, and manages the execution loop until all work is complete.

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

### Step 2: Execution Loop

Repeat until no more tasks:

#### 2a. Get Ready Tasks

```bash
plugins/workflows/scripts/plan-exec.sh next <root-epic-id>
```

This calls `bd ready` filtered by plan label, but only if the plan is in Executing state. Returns empty if paused.

If empty → check if plan is complete or paused:
- All tasks closed → auto-complete the plan
- Plan paused → report "Plan is paused. Say 'resume the plan' to continue."
- Some tasks in_progress → wait for them to finish, then re-check

#### 2b. Group by Agent

Separate ready tasks by their `agent:*` label:
- Tasks with `agent:<name>` → dispatch to that agent as subagent
- Tasks without agent label → handle directly (primary agent)

#### 2c. Dispatch in Parallel

For independent tasks (no dependency between them), dispatch concurrently:

**Subagent dispatch** (for tasks with agent labels):
Use the Task tool to launch a specialized agent:

```
Task: Work on bead <task-id>

Context from bd show:
<full task context>

Instructions:
1. Claim the task: bd update <task-id> --status=in_progress
2. Review scope — if non-trivial, invoke /workflows:breakdown_task first
3. Do the work described in the task
4. Close when done: bd close <task-id>
5. If you create sub-tasks, use bd create with --parent=<task-id>
   and invoke /workflows:select_agent on each
```

**Direct execution** (for tasks without agent labels):
Claim and work on the task directly:
```bash
bd update <task-id> --status=in_progress
```

Then follow the same workflow: assess scope, break down if needed, implement, close.

#### 2d. Wait and Loop

After dispatching a batch:
1. Wait for all dispatched tasks to complete
2. Loop back to Step 2a to get the next batch of ready tasks
3. Newly unblocked tasks will appear in `bd ready`

### Step 3: Completion Check

When `plan-exec.sh next` returns empty and no tasks are in_progress:

```bash
plugins/workflows/scripts/plan-exec.sh status <root-epic-id>
```

If status is `completed`:
1. Update plan file status to "Completed"
2. Close root epic if not already closed
3. Report completion summary

```
Plan Execution Complete
=======================
Plan: plan-03 — <Title>
Tasks completed: 12/12
Duration: <time from first claim to last close>
```

## Parallel Dispatch Rules

- Tasks at the same dependency level with no inter-dependencies → dispatch in parallel
- Tasks with `bd dep` relationships → respect ordering (blocked tasks won't appear in `bd ready`)
- Multiple subagents can run concurrently for different agent types
- The beads dependency system naturally enforces correct ordering

## Error Handling

- If a task fails, it stays in_progress — the execution loop continues with other ready tasks
- Failed tasks should be reported for manual intervention
- If `plan-exec.sh next` returns a guard error, report the state and stop the loop
