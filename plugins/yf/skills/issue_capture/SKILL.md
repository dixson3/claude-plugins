---
name: yf:issue_capture
description: Stage a project issue as a ys:issue bead for deferred submission
arguments:
  - name: type
    description: "Issue type: bug, enhancement, task, debt (default: task)"
    required: false
  - name: priority
    description: "Priority: high, medium, low (default: medium)"
    required: false
  - name: title
    description: Brief issue summary
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


# Issue Capture

Stage a project issue as a `ys:issue` bead for deferred submission to the project tracker. Mirrors the chronicle capture pattern — issues are staged first, then batch-processed via `/yf:issue_process`.

## Behavior

### Step 1: Disambiguation Guard

Verify the issue is about the user's project, not the yf plugin.

If the title or context references yf, beads-cli, plugin internals, or `.yoshiko-flow/` configuration:

> This looks like a plugin issue, not a project issue. Use `/yf:plugin_issue` instead.

Then stop.

### Step 2: Analyze Context

Review the current conversation for issue details:
- What was discovered or observed
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Related files or code
- Priority and severity

### Step 3: Determine Labels

Build label list:
- Always: `ys:issue`
- Type: `ys:issue:<type>` (bug, enhancement, task, debt)
- Priority: `ys:priority:<priority>` if specified

Auto-detect executing plan for `plan:<idx>` label:
```bash
PLAN_EPIC=$(bd list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null)
PLAN_LABEL=$(echo "$PLAN_EPIC" | jq -r '.[0].labels[]? | select(startswith("plan:"))' 2>/dev/null | head -1)
```

### Step 4: Create Bead

```bash
LABELS="ys:issue,ys:issue:<type>"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

bd create --type task \
  --title "Issue: <summary>" \
  -l "$LABELS" \
  --description "<issue details template>" \
  --silent
```

Issue description template:
```
## Summary
<brief description>

## Type
<bug|enhancement|task|debt>

## Priority
<high|medium|low>

## Details
<full context, steps to reproduce, expected behavior>

## Related
<file paths, code references, related issues>
```

### Step 5: Report

```
Issue captured as bead: <bead-id>
Type: <type> | Priority: <priority>
Labels: <labels>

The issue is staged for deferred submission.
Run /yf:issue_process to submit staged issues to the project tracker.
```

## When to Capture

Capture issues when:
- Testing reveals a non-critical bug outside the current plan's scope
- Design work surfaces an enhancement opportunity
- Code review identifies technical debt
- Plan implementation defers improvements for later

## NOT Issue-Worthy

- Work that is part of the current plan's scope (already tracked as beads)
- Routine completions, formatting, config tweaks
- Issues already captured in this session
