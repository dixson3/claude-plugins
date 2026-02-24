# Plan: Add Stale State Cleanup to session_land and plan_intake

## Context

After completing a plan, `.yoshiko-flow/` accumulates stale artifacts:
- Closed chronicle JSON files (already processed into diary entries)
- Closed task/epic JSON files for completed plans
- Orphaned gates (chronicle-gate, qualification-gate) left open after all work tasks are closed
- Dedup markers (`.chronicle-*`) from prior sessions

The existing `session-prune.sh` handles sentinels and date-stamped markers but **not** closed chronicles or completed plan epics. This was discovered manually during the Plan 0059 session where 6 closed chronicles and 2 completed plan epics had to be cleaned by hand.

This plan adds a cleanup step to both `session_land` and `plan_intake` so stale state is cleaned automatically.

## Change 1: Add `completed-plans` command to `session-prune.sh`

**File**: `plugins/yf/scripts/session-prune.sh`

Add a new `do_completed_plans()` function that:

1. **Closes orphaned gates** — For each open gate (`ys:chronicle-gate` or `ys:qualification-gate`) whose sibling work tasks are all closed, close the gate automatically
2. **Closes completed plan epics** — For each open epic with a `plan:*` label, check if all child tasks are closed. If so, close the epic with reason `"session-prune: all tasks completed"`
3. **Removes closed chronicle files** — Delete `.yoshiko-flow/chronicler/*.json` files where status is `"closed"`

Add `completed-plans` as a new subcommand and include it in the `all` sequence (after `drafts`).

Supports `--dry-run` like existing commands.

## Change 2: Add Step 8.5 to `session_land`

**File**: `plugins/yf/skills/session_land/SKILL.md`

Insert a new step between Step 8 (Session Prune) and Step 9 (Commit):

```
### Step 8b: Clean Completed Plans

Close orphaned gates and completed plan epics, remove closed chronicle files:

\`\`\`bash
bash plugins/yf/scripts/session-prune.sh completed-plans 2>/dev/null || true
\`\`\`

This runs after the standard session prune (Step 8) to catch plan lifecycle
artifacts that the ephemeral/tasks/drafts passes don't cover.
```

No renumbering needed — use `Step 8b` to keep it adjacent to Step 8.

## Change 3: Add Step 0.5 to `plan_intake`

**File**: `plugins/yf/skills/plan_intake/SKILL.md`

Insert a new step between Step 0 (Foreshadowing) and Step 1 (Ensure Plan File):

```
### Step 0.5: Clean Prior Plan State

Before starting a new plan lifecycle, clean up residual state from
completed prior plans:

\`\`\`bash
bash plugins/yf/scripts/session-prune.sh completed-plans 2>/dev/null || true
\`\`\`

This prevents accumulation of closed chronicles, orphaned gates, and
completed plan epics across plans within a single session. Fail-open —
cleanup failures do not block intake.
```

## Files to Modify

- `plugins/yf/scripts/session-prune.sh` — add `do_completed_plans()` function + `completed-plans` subcommand
- `plugins/yf/skills/session_land/SKILL.md` — add Step 8b
- `plugins/yf/skills/plan_intake/SKILL.md` — add Step 0.5

## Key Implementation Details

The `do_completed_plans()` function logic:

```bash
do_completed_plans() {
  local cleaned=0

  # 1. Close orphaned gates for completed plans
  #    Find open gates with ys:chronicle-gate or ys:qualification-gate labels
  #    For each, check if all sibling tasks (same parent) are closed
  #    If so, close the gate

  # 2. Close completed plan epics
  #    Find open epics with plan:* labels
  #    For each, check if all child tasks are closed
  #    If so, close the epic

  # 3. Remove closed chronicle files
  #    Find *.json in .yoshiko-flow/chronicler/ where .status == "closed"
  #    Remove them

  echo "session-prune completed-plans: $cleaned artifacts cleaned"
}
```

Gate/epic detection uses `yft_list` with label filters. Child status checks use `find` + `jq` on the epic directory. Chronicle cleanup uses direct file inspection.

## Verification

```bash
# After changes, run existing tests to ensure no regressions:
bash tests/run-tests.sh --unit-only

# Manual verification:
# 1. Create a task, close it, run session-prune.sh completed-plans — epic should close
# 2. Create a chronicle, close it, run completed-plans — file should be removed
# 3. Run session_land — Step 8b should execute without error
# 4. Run plan_intake — Step 0.5 should execute without error
```
