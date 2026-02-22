---
name: yf:worktree_create
description: Create an epic worktree for isolated development
arguments:
  - name: epic_name
    description: "Name for the epic branch and worktree (e.g., hash-ids, swarm-isolation)"
    required: true
  - name: base
    description: "Base branch to branch from (default: current branch)"
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


# Create Epic Worktree

Create an isolated git worktree for epic-scoped development. The worktree gets its own branch and working directory while sharing the main repo's beads database.

## When to Invoke

- `/yf:worktree_create epic_name:feature-x` — Create worktree branching from current branch
- `/yf:worktree_create epic_name:feature-x base:main` — Create worktree branching from main

## Behavior

### Step 1: Determine Base Branch

```bash
BASE="${base:-$(git rev-parse --abbrev-ref HEAD)}"
```

If no `base` argument provided, use the current branch.

### Step 2: Create Worktree

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-ops.sh" create "$BASE" "$EPIC_NAME")
STATUS=$(echo "$RESULT" | jq -r '.status')
```

If `status` is `error`, report the message and stop.

### Step 3: Verify Beads Redirect

Check that `.beads/redirect` was created in the worktree:

```bash
WT_PATH=$(echo "$RESULT" | jq -r '.worktree')
BEADS_OK=$(echo "$RESULT" | jq -r '.beads_redirect')
```

If `beads_redirect` is `false`, warn: "Beads redirect not created — beads operations may not work in the worktree."

### Step 4: Report

```
Epic Worktree Created
=====================
Branch: <branch>
Path: <worktree-path>
Beads: <redirect status>

To work in this worktree, set CLAUDE_PROJECT_DIR to the worktree path,
or use `cd <worktree-path>`.

When done, run /yf:worktree_land to merge changes back.
```

## Error Handling

- Worktree already exists → Report and suggest using existing worktree or removing it
- Branch already exists → Report and suggest a different epic name
- Not a git repo → Report error
