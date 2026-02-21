---
name: yf:issue_disable
description: Close all open issue beads without submitting to any tracker
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


# Issue Disable

Close all open `ys:issue` beads without submitting them to any tracker. Mirrors `/yf:chronicle_disable`.

## Behavior

### Step 1: Query Open Issue Beads

```bash
bd list --label=ys:issue --status=open --json
```

If no open issue beads: report "No open issue beads found." and stop.

### Step 2: Confirm

Present the list to the operator:

```
Open issue beads:
  - abc: Issue: Add input validation
  - def: Issue: Refactor error handling

Close all without submitting?
```

Options:
- "Yes, close all" (Recommended)
- "No, keep them"

### Step 3: Close Beads

For each open issue bead:

```bash
bd close <bead-id> -r "Closed without submission (issue_disable)"
```

### Step 4: Report

```
Closed 2 issue bead(s) without submission.
```
