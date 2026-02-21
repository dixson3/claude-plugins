---
name: yf:issue_list
description: List remote issues and staged issue beads in a combined view
arguments:
  - name: state
    description: "Filter by state: open, closed, all (default: open)"
    required: false
  - name: limit
    description: Maximum number of remote issues to show (default: 20)
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


# Issue List

Show a combined view of remote tracker issues and locally staged `ys:issue` beads.

## Behavior

### Step 1: Detect Tracker

```bash
TRACKER_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-detect.sh")
TRACKER=$(echo "$TRACKER_JSON" | jq -r '.tracker')
PROJECT=$(echo "$TRACKER_JSON" | jq -r '.project')
```

### Step 2: Fetch Remote Issues

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-api.sh" list \
  --state "${state:-open}" --limit "${limit:-20}"
```

### Step 3: Query Staged Beads

```bash
bd list --label=ys:issue --status=open --json 2>/dev/null
```

### Step 4: Present Combined View

```
Project Issues — <tracker> (<project>)
========================================

Remote Issues (open):
  #45  Add input validation for API endpoints
  #33  Fix race condition in worker pool
  #28  Update documentation for v2

Staged (not yet submitted):
  abc  Issue: Refactor error handling [ys:issue:debt]
  def  Issue: Add retry logic [ys:issue:enhancement]

Summary: 3 remote open, 2 staged
```

If no remote issues and no staged beads:

```
No open issues found (remote or staged).
```
