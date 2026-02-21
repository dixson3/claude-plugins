---
name: yf:issue_process
description: Evaluate, consolidate, and submit staged issue beads to the project tracker
arguments:
  - name: plan_idx
    description: Only process issue beads tagged with this plan index
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


# Issue Processing

Evaluate, consolidate, and submit staged `ys:issue` beads to the project tracker. Uses the `yf_issue_triage` agent for judgment on duplicates, consolidation, and cross-referencing.

## Behavior

### Step 1: Query Open Issue Beads

```bash
bd list --label=ys:issue --status=open --json
```

If `plan_idx` is specified, filter further:
```bash
bd list --label=ys:issue --label=plan:<idx> --status=open --json
```

If no open issue beads: report "No staged issues found. Nothing to process." and stop.

### Step 2: Detect Tracker

```bash
TRACKER_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-detect.sh")
TRACKER=$(echo "$TRACKER_JSON" | jq -r '.tracker')
```

### Step 3: Fetch Existing Remote Issues

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-api.sh" list --state open --limit 50
```

### Step 4: Cross-Route Guard

```bash
PLUGIN_REPO=$(. "${CLAUDE_PLUGIN_ROOT}/scripts/yf-config.sh" && yf_plugin_repo)
PROJECT_SLUG=$(echo "$TRACKER_JSON" | jq -r '.project')
```

Verify `PLUGIN_REPO` differs from `PROJECT_SLUG`. If they match, error:

> Plugin repo and project tracker point to the same repository. Cannot safely process issues.

### Step 5: Launch Triage Agent

Use the `yf_issue_triage` agent to evaluate all open beads against existing remote issues:

```
/yf:issue_triage
```

Pass the agent:
- All open `ys:issue` beads (IDs, titles, descriptions)
- List of existing remote issues (numbers, titles, states)
- Tracker type (github/gitlab/file)

The agent returns a triage plan with actions: `create`, `comment`, `skip`, `redirect`.

### Step 6: Present Triage Plan

Present the triage plan to the operator via AskUserQuestion:

```
Issue Triage Plan
=================
1. CREATE: "Add input validation for API endpoints"
   Source beads: abc, def (consolidated)

2. COMMENT on #33: "Additional context from testing"
   Source bead: ghi

3. SKIP: Duplicate of action #1
   Source bead: jkl

4. REDIRECT: This is a plugin issue, not a project issue
   Source bead: mno → Use /yf:plugin_issue

Approve this plan?
```

Options:
- "Execute all actions" (Recommended)
- "Review individually"
- "Cancel"

### Step 7: Execute Approved Actions

For each approved action:

**create:**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-api.sh" create \
  --title "<title>" --body "<body>" --labels "<labels>"
```

**comment:**
```bash
gh issue comment <num> --repo "$PROJECT_SLUG" --body "<body>"
```

**skip:** No action needed.

**redirect:** Report to operator for manual `/yf:plugin_issue`.

### Step 8: Close Processed Beads

```bash
bd close <bead-id> -r "Submitted as <tracker-type> issue"
```

### Step 9: Report

```
Issue Processing Complete
=========================
Created: 2 issues
  - #45: Add input validation for API endpoints
  - TODO-003: Refactor error handling
Commented: 1 issue
  - #33: Additional context
Skipped: 1 (duplicate)
Redirected: 1 (plugin issue)
Beads closed: 4
```
