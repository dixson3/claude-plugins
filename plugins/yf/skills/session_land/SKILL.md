---
name: yf:session_land
description: Orchestrate session close-out — commit, push, and hand off context
user_invocable: true
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


# Session Landing Skill

Orchestrates the full session close-out sequence. Ensures context is preserved, work is tracked, and code is committed before ending a session.

## Behavior

Execute these steps in order. Each step is conditional — skip when not applicable.

### Step 1: Check Dirty Tree

```bash
git status --porcelain
```

Report changed files to the operator. If clean, note it and continue.

### Step 2: File Remaining Work

```bash
bd list --status=in_progress --json 2>/dev/null
```

If in-progress beads exist, present each to the operator via AskUserQuestion:
- "Close (work is done)"
- "Leave open (still in progress)"
- "Create followup bead"

Close or update beads based on operator response.

### Step 3: Capture Context (conditional)

If significant work was done since the last chronicle capture, invoke `/yf:chronicle_capture topic:session-close`.

Skip if no meaningful context would be lost (routine completions, minor changes).

### Step 4: Generate Diary (conditional)

Check for open chronicles:

```bash
bd list --label=ys:chronicle --status=open --json 2>/dev/null
```

If open chronicles exist, invoke `/yf:chronicle_diary`.

### Step 5: Quality Gates (conditional)

If code was changed during this session, run project quality checks:

```bash
bash tests/run-tests.sh --unit-only 2>&1
```

Report results. Do not block on test failures — report and let operator decide.

### Step 6: Memory Reconciliation (conditional)

Check if specifications exist:

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
test -d "${ARTIFACT_DIR}/specifications" && echo "specs exist"
```

If specs exist, invoke `/yf:memory_reconcile mode:check`.

### Step 7: Update Issue Status

Close any beads that were completed during this session but not yet closed:

```bash
bd list --status=in_progress --json 2>/dev/null
```

For each remaining in-progress bead, confirm with operator before closing.

### Step 8: Session Prune

```bash
bash plugins/yf/scripts/session-prune.sh all 2>/dev/null || true
```

### Step 9: Commit

Stage all changes and present a diff summary:

```bash
git status --porcelain
git diff --stat
```

Present the summary to the operator, then commit with a conventional message.

### Step 10: Push with Operator Confirmation

Use AskUserQuestion to ask: "Push to remote?"

Options:
- "Yes, push now"
- "No, skip push"

If yes: `git push`. If no: note that unpushed changes remain for next session.

### Step 11: Hand Off

Summarize:
- What was done this session
- What remains (open beads, unpushed commits)
- Key context for the next session
