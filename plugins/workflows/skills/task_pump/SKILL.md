---
name: workflows:task_pump
description: Pull ready beads into parallel agent dispatch via Task tool
arguments:
  - name: plan_idx
    description: "Plan index (e.g., 07). Defaults to most recent active plan."
    required: false
---

# Task Pump Skill

Reads beads that are ready for work, groups them by assigned agent, and dispatches them as parallel Task tool calls. This is the mechanism that converts the persistent beads DAG into live agent execution.

## When to Invoke

- Called by `/workflows:execute_plan` in the pump loop
- Can be invoked directly: `/workflows:task_pump [plan_idx]`

## Architecture

```
Beads (bd ready) → group by agent:<name> → parallel Task tool calls
                                            └→ subagent_type = agent name
```

**Beads** = persistent store of work (git-backed, labeled, with dependencies)
**Task tool** = execution engine (launches specialized agent subprocesses)

The pump is the bridge: it reads from beads and dispatches to agents.

## Behavior

### Step 1: Identify Plan

If `plan_idx` not specified, find the most recent active plan:
```bash
bd list -l ys:plan --type=epic --status=open --sort=created --reverse --limit=1
```

Extract the `plan:<idx>` label and root epic ID.

### Step 2: Get Ready Beads

```bash
plugins/workflows/scripts/plan-exec.sh next <root-epic-id>
```

This returns ready tasks for the plan (empty if not in Executing state).

### Step 3: Filter Already-Dispatched

For each ready bead, check the pump state:
```bash
plugins/workflows/scripts/pump-state.sh is-dispatched <bead-id>
```

Skip beads that have already been dispatched (prevents double-dispatch on re-pump).

### Step 4: Group by Agent

Read each bead's labels to find the `agent:<name>` assignment:
```bash
bd label list <bead-id> --json | jq -r '.[] | select(startswith("agent:")) | sub("agent:"; "")'
```

Group beads by agent name:
- Beads with `agent:<name>` → grouped under that agent
- Beads without agent label → grouped under `general-purpose`

### Step 5: Dispatch in Parallel

For each agent group, launch Task tool calls **in parallel** (multiple calls in one message):

```
Task(
  subagent_type = "<agent-name>",
  prompt = "Work on bead <bead-id>

Context from bd show:
<full task context>

Instructions:
1. Claim the task: bd update <bead-id> --status=in_progress
2. Review scope — if non-trivial, invoke /workflows:breakdown_task first
3. Do the work described in the task
4. Close when done: bd close <bead-id>
5. If you create sub-tasks, use bd create with --parent=<bead-id>
   and invoke /workflows:select_agent on each"
)
```

Independent beads (no dependency between them) are dispatched concurrently.

### Step 6: Mark Dispatched

After launching each Task call:
```bash
plugins/workflows/scripts/pump-state.sh mark-dispatched <bead-id>
```

### Step 7: Report

Output summary:
```
Task Pump: plan-07
==================
Ready beads: 4
Already dispatched: 1
Dispatching: 3
  agent:chronicler_diary → 1 task
  general-purpose → 2 tasks
Parallel Task calls launched: 3
```

## Completion Tracking

When subagents return (Task tool calls complete), the caller (execute_plan) should:
1. Check if the bead was closed by the subagent
2. Mark done in pump state: `pump-state.sh mark-done <bead-id>`
3. Re-pump to pick up newly unblocked beads

## Error Handling

- If `plan-exec.sh next` returns empty → no work to dispatch (not an error)
- If a bead has no agent label → dispatch as `general-purpose`
- If pump-state.sh fails → skip tracking (dispatch anyway, risk double-dispatch vs missing dispatch)
- If bd commands fail → report error, skip that bead, continue with others
