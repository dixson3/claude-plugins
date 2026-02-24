---
name: yf:issue_disable
description: Close all open issue tasks without submitting to any tracker
arguments: []
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

# Issue Disable

Close all open `ys:issue` tasks without submitting them to any tracker. Mirrors `/yf:chronicle_disable`.

## Behavior

### Step 1: Query Open Issue Tasks

```bash
bash "$YFT" list --label=ys:issue --status=open --json
```

If no open issue tasks: report "No open issue tasks found." and stop.

### Step 2: Confirm

Present the list to the operator:

```
Open issue tasks:
  - abc: Issue: Add input validation
  - def: Issue: Refactor error handling

Close all without submitting?
```

Options:
- "Yes, close all" (Recommended)
- "No, keep them"

### Step 3: Close Tasks

For each open issue task:

```bash
bash "$YFT" close <task-id> -r "Closed without submission (issue_disable)"
```

### Step 4: Report

Report the count of closed tasks.
