---
name: yf:plan_breakdown
description: Decompose a non-trivial task into child beads with proper dependencies and agent assignments
arguments:
  - name: task_id
    description: "Bead ID to decompose"
    required: true
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


# Breakdown Task Skill

Decomposes a non-trivial task into child beads. Called when the breakdown-the-work rule fires before starting work on a task.

## When to Invoke

- Triggered by the `breakdown-the-work` rule when claiming a task
- Can be invoked directly: `/yf:breakdown_task <task_id>`

## Behavior

### Step 1: Read Task Context

```bash
bd show <task_id>
```

Extract full context: title, description, design, acceptance criteria, notes, labels, parent.

### Step 2: Assess Scope

Evaluate whether the task is atomic or needs decomposition:

**Atomic (do NOT decompose) if:**
- Single file change
- One logical concern
- Estimated under 30 minutes of focused work
- No distinct sub-phases

**Non-trivial (DO decompose) if:**
- Multiple files involved
- Multiple concerns (e.g., implementation + tests + docs)
- Clear sequential phases
- Multiple independent pieces that could parallelize

If genuinely atomic -> report "Task is atomic, proceeding directly" and stop.

### Step 3: Create Child Beads

For logical groups, create child epics:
```bash
bd create --title="<Group description>" \
  --type=epic \
  --parent=<task_id> \
  --description="<What this group covers>" \
  -l <inherit-plan-labels> \
  --silent
```

For atomic work items, create child tasks:
```bash
bd create --title="<Specific work item>" \
  --type=task \
  --parent=<task_id> \
  --description="<Detailed instructions>" \
  --notes="<File refs, patterns to follow>" \
  --priority=2 \
  -l <inherit-plan-labels> \
  --silent
```

### Step 4: Wire Dependencies

For ordered steps within the breakdown:
```bash
bd dep add <step-2> <step-1>  # step-2 depends on step-1
```

### Step 5: Agent Selection

For each new child:
```
/yf:select_agent <child-id>
```

### Step 5.5: Chronicle Non-Trivial Decomposition

If 3 or more child beads were created in Step 3, create a chronicle bead capturing the scope change. Trivial 1-2 child splits are routine and not worth chronicling.

```bash
CHILD_COUNT=<number of children created>
if [ "$CHILD_COUNT" -ge 3 ]; then
  PLAN_LABEL=$(bd label list <task_id> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
  LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:planning"
  [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

  bd create --type task \
    --title "Chronicle: plan_breakdown — $CHILD_COUNT children from <task title>" \
    -l "$LABELS" \
    --description "Scope change: task decomposed into $CHILD_COUNT children
Parent: <task_id> — <task title>
Children: <list of child titles>
Decomposition rationale: <why this split was needed>
Dependencies: <summary of dependency graph>" \
    --silent
fi
```

### Step 6: Continue Work

After decomposition, use `bd ready` filtered by the parent to pick up the first unblocked child and start working.

## Recursive Property

Children may themselves be non-trivial. The `breakdown-the-work` rule applies to them too — when a subagent claims a child task, it will assess scope and decompose further if needed. This continues until all work is atomic.

## Label Inheritance

Child beads inherit plan labels from the parent:
- `ys:plan` — marks as plan-originated
- `plan:<idx>` — links to specific plan
- `plan-part:<idx>-<N>` — links to specific part (if applicable)

## Report

```
Breakdown: <task_id> — "<task title>"
  Assessment: Non-trivial (multiple files, sequential phases)
  Created: 4 child tasks
  Dependencies: 3 sequential deps wired
  Agent assignments: 1 task assigned to yf_chronicle_diary

  Children:
    1. <child-1> — "<title>" [ready]
    2. <child-2> — "<title>" [blocked by child-1]
    3. <child-3> — "<title>" [blocked by child-2]
    4. <child-4> — "<title>" [ready, agent:yf_chronicle_diary]
```
