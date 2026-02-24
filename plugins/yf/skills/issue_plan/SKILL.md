---
name: yf:issue_plan
description: Pull a remote issue into a yf planning session and transition it to in-progress
arguments:
  - name: issue
    description: Issue number or ID to pull into planning
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

# Issue to Plan

Pull a remote issue into a yf planning session. Fetches the issue, transitions it to in-progress, and sets up context for plan creation.

## Behavior

### Step 1: Detect Tracker

```bash
TRACKER_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-detect.sh")
TRACKER=$(echo "$TRACKER_JSON" | jq -r '.tracker')
```

### Step 2: Fetch Issue

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-api.sh" view --issue "<issue>"
```

If the issue is not found, report the error and stop.

### Step 3: Transition to In-Progress

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-api.sh" transition \
  --issue "<issue>" --state in_progress
```

For GitHub/GitLab: the issue remains open (these trackers don't have a native in-progress state). For file backend: moves to an "In Progress" section if available.

### Step 4: Write Plan-Issue Link

Create a marker so `plan_create_tasks` can apply the issue label:

```bash
echo "<issue>" > "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-issue-link"
```

### Step 5: Present Issue Summary

Present the issue details to the operator:

```
Issue #<num>: <title>
==========================================
<body summary>

Labels: <labels>
State: in-progress

Ready to plan. Enter plan mode to create an implementation plan for this issue.
The plan's root epic will be tagged with issue:<num>.
```

### Step 6: Instruct

Tell the operator to enter plan mode. The auto-chain will pick up the `plan-issue-link` marker and tag the root epic accordingly.

## Plan-Issue Link

When `plan_create_tasks` runs and `.yoshiko-flow/plan-issue-link` exists:
1. Read the issue number from the file
2. Add `issue:<num>` label to the root epic
3. Delete the marker file

This ensures the plan is traceable back to the originating issue.
