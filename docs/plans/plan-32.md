# Plan 32: Automatic Bead Pruning

**Status:** Draft
**Date:** 2026-02-14

## Context

Plan 30 manually pruned 278 closed beads that had accumulated across all historical plans. The pruning was safe — all content had already been captured in diary entries, plan docs, and CHANGELOG. But it was entirely manual, and nothing prevents the same accumulation from happening again.

The process Plan 30 used should be systematized with two scopes:
1. **Plan-scoped** (automatic): When a plan completes, prune its closed beads
2. **Global** (automatic on push): After `git push`, prune all stale closed beads across the database

## Overview

Add a prune script (`plan-prune.sh`) that handles both scopes. Hook it into two existing trigger points:
- **Plan completion** → plan-scoped prune, called from `plan-exec.sh` status completion path
- **Post-push** → global prune via PostToolUse hook on `Bash(git push*)`, followed by `bd sync` to push pruned state to beads-sync

The sequence for a push is: code pushes upstream (safe) → prune runs → `bd sync` pushes pruned beads state to beads-sync. This ensures code is safely remote before any cleanup, and the beads-sync branch reflects the pruned database.

Both are advisory/non-blocking (exit 0 always) and configurable via `.yoshiko-flow/config.json`.

## Implementation Sequence

### 1. Create `plan-prune.sh` script

**File:** `plugins/yf/scripts/plan-prune.sh` (new)

A script with two subcommands:

```bash
plan-prune.sh plan <plan-label>    # Prune closed beads for a specific plan
plan-prune.sh global               # Prune all stale closed beads
```

**Plan-scoped prune** (`plan <plan-label>`):
1. Query `bd list -l <plan-label> --status=closed --type=task --limit=0 --json` to find closed tasks
2. Also query closed epics and gates for the plan
3. Exclude beads that have open dependents (safety)
4. Run `bd delete <ids> --reason="plan completion auto-prune"` with soft delete (tombstones)
5. Output summary: `Pruned N beads for <plan-label>`

**Global prune** (`global`):
1. Read `older_than_days` from config (default: 7)
2. Run `bd admin cleanup --older-than <days> --force` to soft-delete all closed beads older than threshold
3. Also run `bd admin cleanup --ephemeral --force` to clean up closed wisps (transient molecules) regardless of age
4. Output summary: `Global prune: N beads cleaned, M tombstones expired`

**Config guard**: Both subcommands check `.yoshiko-flow/config.json` before acting:
```json
{
  "config": {
    "auto_prune": {
      "on_plan_complete": true,
      "on_push": true,
      "older_than_days": 7
    }
  }
}
```
Default (no config): both enabled, 7-day threshold. Set `on_plan_complete: false` or `on_push: false` to disable.

**Safety**:
- Always soft-delete (tombstones, 30-day recovery window)
- `--dry-run` flag for preview mode
- Fail-open: errors in prune never block the parent operation
- Never prunes open or in-progress beads (bd handles this)

### 2. Add config helpers to `yf-config.sh`

**File:** `plugins/yf/scripts/yf-config.sh` (modify)

Add two helpers:
```bash
yf_is_prune_on_complete() { _yf_check_flag '.config.auto_prune.on_plan_complete'; }
yf_is_prune_on_push() { _yf_check_flag '.config.auto_prune.on_push'; }
```

### 3. Hook into plan completion

**File:** `plugins/yf/scripts/plan-exec.sh` (modify)

In the `status` command's completion path (after `close_chronicle_gates` at line 264, before `echo "completed"` at line 265), add:

```bash
# Auto-prune closed plan beads (fail-open)
(
  set +e
  yf_is_prune_on_complete 2>/dev/null || exit 0
  bash "$SCRIPT_DIR/plan-prune.sh" plan "$PLAN_LABEL" 2>/dev/null
) || true
```

This runs plan-scoped pruning as a fail-open subshell — if anything fails, the completion still proceeds.

### 4. Create PostToolUse hook for global prune on push

**File:** `plugins/yf/hooks/post-push-prune.sh` (new)

A PostToolUse hook on `Bash(git push*)` that runs global pruning after the code push completes, then syncs the pruned state to beads-sync.

### 5. Register the PostToolUse hook in plugin.json

**File:** `plugins/yf/.claude-plugin/plugin.json` (modify)

Add a new `PostToolUse` section.

### 6. Add tests

**File:** `tests/scenarios/unit-plan-prune.yaml` (new)

### 7. Add config tests

**File:** `tests/scenarios/unit-yf-config.yaml` (modify)

### 8. Version bump to 2.15.0

**Files:** `plugins/yf/.claude-plugin/plugin.json`, `CHANGELOG.md`, `CLAUDE.md`

## Completion Criteria

- [ ] Plan-scoped prune runs automatically when `plan-exec.sh status` returns `completed`
- [ ] Global prune runs automatically after `git push` via PostToolUse hook
- [ ] Both prune operations are configurable via `auto_prune` config
- [ ] Both prune operations are fail-open (never block parent operations)
- [ ] Soft delete only (tombstones, 30-day recovery)
- [ ] All existing + new tests pass
- [ ] Version bumped to 2.15.0

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass
2. Manual: complete a plan, verify closed beads are pruned
3. Manual: `git push`, verify global cleanup runs
4. Config: set `on_plan_complete: false`, verify prune is skipped
