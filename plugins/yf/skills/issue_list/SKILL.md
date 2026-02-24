---
name: yf:issue_list
description: List remote issues and staged issue entries in a combined view
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

Show a combined view of remote tracker issues and locally staged `ys:issue` entries.

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

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

### Step 3: Query Staged Entries

```bash
bash "$YFT" list -l ys:issue --status=open --json 2>/dev/null
```

### Step 4: Present Combined View

Report includes: tracker name and project, remote issues (number + title), staged entries (ID + title + labels), and summary counts. If none found, reports no open issues.
