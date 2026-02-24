---
name: yf:plan_pump
description: Pull ready tasks into parallel agent dispatch via Task tool
arguments:
  - name: plan_idx
    description: "Plan index (e.g., 0007-b4m2k). Defaults to most recent active plan."
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

# Task Pump Skill

Reads tasks that are ready for work, classifies each into a **formula track** (dispatched via `/yf:swarm_run` for multi-agent workflows) or an **agent track** (dispatched via bare Task tool calls), and launches them in parallel. This is the mechanism that converts the persistent task DAG into live agent execution.

## Architecture

```
Tasks (bash "$YFT" list --ready) → classify dispatch track → group by track
                                    ├→ formula:<name>  → swarm dispatch (via /yf:swarm_run)
                                    └→ agent:<name>    → bare agent dispatch (via Task tool)
```

**Tasks** = persistent store of work (git-backed, labeled, with dependencies)
**Task tool** = execution engine (launches specialized agent subprocesses)
**Swarm** = multi-agent formula execution (research → implement → review)

The pump is the bridge: it reads from tasks, classifies dispatch tracks, and groups for execution.

## Behavior

### Step 1: Identify Plan

If `plan_idx` not specified, find the most recent active plan:
```bash
bash "$YFT" list -l ys:plan --type=epic --status=open --sort=created --reverse --limit=1
```

Extract the `plan:<idx>` label and root epic ID.

### Step 2: Get Ready Tasks

```bash
plugins/yf/scripts/plan-exec.sh next <root-epic-id>
```

This returns ready tasks for the plan (empty if not in Executing state).

### Step 3: Filter Already-Dispatched

For each ready task, check the pump state:
```bash
plugins/yf/scripts/dispatch-state.sh pump is-dispatched <task-id>
```

Skip tasks that have already been dispatched (prevents double-dispatch on re-pump).

### Step 4: Classify Dispatch Track and Group (CRITICAL — formula labels take priority)

For each ready task, read labels to determine the dispatch track:

```bash
# Check for formula label first (takes priority)
FORMULA=$(bash "$YFT" label list <task-id> --json | jq -r '.[] | select(startswith("formula:")) | sub("formula:"; "")' | head -1)

# Check for agent label
AGENT=$(bash "$YFT" label list <task-id> --json | jq -r '.[] | select(startswith("agent:")) | sub("agent:"; "")' | head -1)
```

**Dispatch track classification:**
- Tasks with `formula:<name>` label → **formula track** (grouped by formula name)
- Tasks with `agent:<name>` label only → **agent track** (grouped by agent name)
- Tasks with neither → **agent track** under `general-purpose`

If a task has both `formula:<name>` and `agent:<name>` labels, the formula label takes priority — the swarm formula handles agent selection internally.

Group tasks into two output sections:
1. **Formula dispatch** — keyed by formula name, each entry includes task ID and title
2. **Agent dispatch** — keyed by agent name (unchanged from previous behavior)

### Step 5: Dispatch in Parallel

For each group, launch dispatch calls **in parallel** (multiple calls in one message):

**Formula track** — dispatch via swarm_run:
```
/yf:swarm_run formula:<formula-name> feature:"<task title>" parent_task:<task-id>
```

The swarm handles the full lifecycle: wisp instantiation, multi-agent dispatch, squash, and chronicle.

**Agent track** — dispatch via Task tool (unchanged):
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

Independent tasks (no dependency between them) are dispatched concurrently. Formula and agent track tasks can also dispatch concurrently.

### Step 6: Mark Dispatched

After launching each Task call:
```bash
plugins/yf/scripts/dispatch-state.sh pump mark-dispatched <task-id>
```

### Step 7: Report

Report includes: plan reference, ready task count, already-dispatched count, dispatching count broken down by track (formula vs agent) with task counts, and total parallel dispatch calls launched.

## Completion Tracking

When subagents return (Task tool calls complete), the caller (execute_plan) should:
1. Check if the task was closed by the subagent
2. Mark done in pump state: `dispatch-state.sh pump mark-done <task-id>`
3. Re-pump to pick up newly unblocked tasks

## Error Handling

- If `plan-exec.sh next` returns empty -> no work to dispatch (not an error)
- If a task has no agent label -> dispatch as `general-purpose`
- If dispatch-state.sh fails -> skip tracking (dispatch anyway, risk double-dispatch vs missing dispatch)
- If yf-task-cli commands fail -> report error, skip that task, continue with others
