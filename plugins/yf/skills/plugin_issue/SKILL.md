---
name: yf:plugin_issue
description: Report or comment on issues against the yf plugin repository
arguments:
  - name: issue
    description: Existing issue number to comment on (omit for new issue)
    required: false
  - name: type
    description: "Issue type: bug, enhancement, question (default: bug)"
    required: false
  - name: title
    description: Issue title (for new issues)
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


# Plugin Issue Reporting

Report bugs, enhancements, or questions against the yf plugin repository.

## Behavior

### Step 1: Check gh Availability

```bash
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not available. Install GitHub CLI to report plugin issues."
  exit 1
fi
gh auth status 2>&1
```

If not authenticated, instruct the user to run `gh auth login`.

### Step 2: Disambiguation Guard

Verify the issue is about yf, beads, or plugin internals — not the user's project.

Check the title, body, and conversation context for references to:
- yf plugin skills, agents, rules, hooks, scripts
- beads-cli (bd commands)
- Plugin configuration (.yoshiko-flow/, plugin.json, preflight.json)
- This plugin repository

If the issue references project-specific code (not plugin internals), warn:

> This looks like a project issue, not a plugin issue. Use `/yf:issue_capture` instead.

Then stop.

### Step 3: Cross-Route Guard

```bash
PLUGIN_REPO=$(CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-config.sh" 2>/dev/null; yf_plugin_repo)
TRACKER_JSON=$(CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-detect.sh")
PROJECT_SLUG=$(echo "$TRACKER_JSON" | jq -r '.project')
```

Actually, source the config library and use it:

```bash
. "${CLAUDE_PLUGIN_ROOT}/scripts/yf-config.sh"
PLUGIN_REPO=$(yf_plugin_repo)
TRACKER_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tracker-detect.sh")
PROJECT_SLUG=$(echo "$TRACKER_JSON" | jq -r '.project')
```

If `PLUGIN_REPO` equals `PROJECT_SLUG`, error:

> The plugin repo and project tracker point to the same repository. This would create issues on your own project instead of the plugin repo.

Then stop.

### Step 4: Resolve Target Repository

Use `PLUGIN_REPO` as the target (default: `dixson3/d3-claude-plugins`).

### Step 5: List Recent Issues

```bash
gh issue list --repo "$PLUGIN_REPO" --limit 10 --json number,title,state
```

Present the list to the operator so they can check for duplicates or choose to comment on an existing issue.

### Step 6a: Comment on Existing Issue

If `issue` argument is provided:

```bash
gh issue comment <issue> --repo "$PLUGIN_REPO" --body "<comment body>"
```

Synthesize the comment body from the current conversation context.

### Step 6b: Create New Issue

If creating a new issue:

1. Synthesize title and body from conversation context
2. Auto-include metadata footer:
   ```
   ---
   **yf version:** <version from plugin.json>
   **OS:** <uname -s>
   **beads-cli:** <bd --version>
   ```
3. Present to operator via AskUserQuestion for confirmation
4. Create:
   ```bash
   gh issue create --repo "$PLUGIN_REPO" --title "<title>" --body "<body>" --label "<type>"
   ```

### Step 7: Report

Output the issue URL and confirmation.

## Important

- This skill is **manually initiated only**. Never suggest it proactively (Rule 5.6 only suggests `/yf:issue_capture`).
- Always confirm with the operator before creating or commenting on issues.
