---
name: yf:plan_breakdown
description: Decompose a non-trivial task into child tasks with proper dependencies and agent assignments
arguments:
  - name: task_id
    description: "Task ID to decompose"
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

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

# Breakdown Task Skill

Decomposes a non-trivial task into child tasks. Called when the breakdown-the-work rule fires before starting work on a task.

## Behavior

### Step 1: Read Task Context

```bash
bash "$YFT" show <task_id>
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

### Step 3: Create Child Tasks

For logical groups, create child epics:
```bash
bash "$YFT" create --title="<Group description>" \
  --type=epic \
  --parent=<task_id> \
  --description="<What this group covers>" \
  -l <inherit-plan-labels> \
  --silent
```

For atomic work items, create child tasks:
```bash
bash "$YFT" create --title="<Specific work item>" \
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
bash "$YFT" dep add <step-2> <step-1>  # step-2 depends on step-1
```

### Step 5: Agent Selection

For each new child:
```
/yf:plan_select_agent <child-id>
```

### Step 5.5: Chronicle Non-Trivial Decomposition

If 3 or more child tasks were created in Step 3, create a chronicle task capturing the scope change. Trivial 1-2 child splits are routine and not worth chronicling.

```bash
CHILD_COUNT=<number of children created>
if [ "$CHILD_COUNT" -ge 3 ]; then
  PLAN_LABEL=$(bash "$YFT" label list <task_id> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
  LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:planning"
  [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

  bash "$YFT" create --type task \
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

After decomposition, use `bash "$YFT" list --ready` filtered by the parent to pick up the first unblocked child and start working.

## Recursive Property

Children may themselves be non-trivial. The `breakdown-the-work` rule applies to them too — when a subagent claims a child task, it will assess scope and decompose further if needed. This continues until all work is atomic.

## Label Inheritance

Child tasks inherit plan labels from the parent:
- `ys:plan` — marks as plan-originated
- `plan:<idx>` — links to specific plan
- `plan-part:<idx>-<N>` — links to specific part (if applicable)

## Report

Report includes: task ID, assessment (atomic vs non-trivial), child count, dependency count, agent assignments, and child list with status (ready/blocked).
