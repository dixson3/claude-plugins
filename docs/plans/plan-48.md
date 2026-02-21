# Plan: Remove `bd prime` hooks in yf preflight

## Context

The beads-cli tool (`bd`) has its own Claude Code integration (`bd setup claude`) that installs `SessionStart` and `PreCompact` hooks calling `bd prime` into `.claude/settings.local.json`. The yf plugin already supersedes this with its own plugin-level hooks (`session-recall.sh`, `pre-compact.sh`) declared in `plugin.json`. When both are present, `bd prime` injects ~3k chars of redundant static documentation every session, wasting prompt cache tokens and duplicating context.

The preflight should detect and remove these hooks proactively, since any user who runs `bd setup claude` or `bd init` (which may auto-configure) would end up with duplicate context injection.

## Changes

### 1. Add `bd prime` hook cleanup to `plugin-preflight.sh`

**File**: `plugins/yf/scripts/plugin-preflight.sh`

**Location**: After the "Enabled guard" section (after confirming yf is enabled and bd is available, ~line 132), before the fast-path check. This ensures the cleanup runs early and on every preflight invocation.

**Logic**:
```
SETTINGS_LOCAL="$PROJECT_DIR/.claude/settings.local.json"
if settings.local.json exists AND contains "bd prime" in hooks:
  run: bd setup claude --remove --project
  set FAST_PATH=false (force full resync)
  output warning: "preflight: removed bd prime hooks from .claude/settings.local.json — reset context (/clear) for changes to take effect"
```

**Why `bd setup claude --remove --project`**: Use bd's own removal command rather than manual jq surgery. It's idempotent, handles the exact JSON structure bd writes, and future-proofs against format changes.

**Why before fast-path**: The fast-path checks version + symlink integrity. If `bd prime` hooks are present, we need to clean them regardless of whether rules are up to date.

### 2. Add `bd prime` hook prevention to `beads-setup.sh`

**File**: `plugins/yf/scripts/beads-setup.sh`

**Location**: After Step 5 (uninstall git hooks), add Step 5b.

**Logic**:
```
# Step 5b: Remove beads Claude hooks (yf plugin provides its own)
if bd setup claude --check --project exits with hooks found:
  bd setup claude --remove --project
  CHANGES++
  echo "beads-setup: removed beads Claude hooks (yf supersedes)"
```

This catches the case where `bd init` auto-installs Claude hooks during Phase 1 initialization.

## Files Modified

1. `plugins/yf/scripts/plugin-preflight.sh` — add hook cleanup step (~15 lines)
2. `plugins/yf/scripts/beads-setup.sh` — add Step 5b after git hook uninstall (~10 lines)

## Verification

1. Install bd prime hooks: `bd setup claude --project`
2. Run preflight: `CLAUDE_PROJECT_DIR=. bash plugins/yf/scripts/plugin-preflight.sh`
3. Confirm output includes the removal warning
4. Confirm `.claude/settings.local.json` hooks are clean (no `bd prime`)
5. Run preflight again — should not warn (idempotent)
6. Run `bd setup claude --check --project` — should report no hooks installed
