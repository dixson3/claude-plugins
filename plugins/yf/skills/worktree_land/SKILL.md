---
name: yf:worktree_land
description: Land an epic worktree back into the base branch
arguments:
  - name: worktree
    description: "Path to the worktree (default: auto-detect from current directory)"
    required: false
  - name: base
    description: "Base branch to merge into (default: extracted from branch naming convention)"
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


# Land Epic Worktree

Validate, rebase, and merge an epic worktree back into the base branch. Uses a validate-rebase-revalidate-land sequence to ensure clean integration.

## When to Invoke

- `/yf:worktree_land` — Auto-detect worktree and base branch
- `/yf:worktree_land worktree:/path/to/wt base:main` — Explicit paths

## Behavior

### Step 1: Detect Worktree and Base Branch

If `worktree` not provided, auto-detect:
```bash
# Check if currently in a worktree
WT_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
```

If `base` not provided, extract from branch naming convention:
```bash
# Branch format: <base>/<epic-name>
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE="${BRANCH%%/*}"
```

### Step 2: Validate (Pre-Rebase)

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-ops.sh" validate "$WT_PATH")
STATUS=$(echo "$RESULT" | jq -r '.status')
```

If validation fails:
- Uncommitted changes → Report and stop: "Commit or stash changes before landing."
- Tests fail → Report and stop: "Fix failing tests before landing."

### Step 3: Rebase onto Base

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-ops.sh" rebase "$WT_PATH" "$BASE")
STATUS=$(echo "$RESULT" | jq -r '.status')
```

If conflicts:
- Report conflict files from the JSON output
- Stop for manual intervention: "Resolve conflicts and re-run /yf:worktree_land"

### Step 4: Re-Validate (Post-Rebase)

Run validation again after rebase to ensure nothing broke:

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-ops.sh" validate "$WT_PATH")
```

If validation fails after rebase, report and stop.

### Step 5: Land

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-ops.sh" land "$WT_PATH" "$BASE")
STATUS=$(echo "$RESULT" | jq -r '.status')
```

If not fast-forwardable (should not happen after rebase), report error.

### Step 6: Report

```
Epic Worktree Landed
====================
Branch: <merged-branch> → <base>
Worktree: removed
Branch: deleted

All changes from <epic-name> are now on <base>.
```

## Error Handling

- Not in a worktree and no `worktree` argument → Report error with usage
- Conflicts at any stage → Report conflict files, stop for manual intervention
- Validation failure → Report issues, stop
- Not fast-forwardable → Report error (should not happen after successful rebase)
