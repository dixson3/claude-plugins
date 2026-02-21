# Plan: Ensure `.beads/config.yaml` Is Committed via Allowlist Gitignore

## Context

The `.beads/config.yaml` file (containing `dolt.database` and `no-git-ops` settings) must be committed to git so it's shared across clones. Currently this works by accident — the `.beads/.gitignore` uses a 57-line blocklist that doesn't mention `config.yaml`, so it's implicitly tracked. This is fragile: new runtime files (like `.pending-diary`, `.dirty-tree`) can slip through, and there's no explicit signal that `config.yaml` should be tracked.

The fix: switch `.beads/.gitignore` to an allowlist pattern (matching the `.yoshiko-flow/.gitignore` convention already in the project), and have `beads-setup.sh` enforce it on every run.

## Changes

### 1. Replace Step 7 in `beads-setup.sh` — allowlist repair

**File**: `plugins/yf/scripts/beads-setup.sh` (lines 119-125)

Replace the advisory `dolt/` check with an enforcing allowlist repair:

```bash
# Step 7: Ensure .beads/.gitignore uses allowlist (only config.yaml + .gitignore tracked)
BEADS_GI="$PROJECT_DIR/.beads/.gitignore"
EXPECTED_GI_MARKER='!config.yaml'
if [ ! -f "$BEADS_GI" ] || ! grep -qF "$EXPECTED_GI_MARKER" "$BEADS_GI"; then
  cat > "$BEADS_GI" <<'GITIGNORE_EOF'
# Ignore everything except config.yaml and this file
*
!.gitignore
!config.yaml
GITIGNORE_EOF
  CHANGES=$((CHANGES + 1))
  echo "beads-setup: updated .beads/.gitignore to allowlist"
fi
```

Same pattern as `plugin-preflight.sh:55-64` for `.yoshiko-flow/.gitignore`.

### 2. Add Step 8 in `beads-setup.sh` — remove `.beads/` from project gitignore

**File**: `plugins/yf/scripts/beads-setup.sh` (insert after new Step 7, before Phase 3)

```bash
# Step 8: Ensure .beads/ is NOT in project .gitignore
PROJECT_GI="$PROJECT_DIR/.gitignore"
if [ -f "$PROJECT_GI" ] && grep -q '^\.beads/' "$PROJECT_GI" 2>/dev/null; then
  sed '/^\.beads\//d' "$PROJECT_GI" > "$PROJECT_GI.tmp" && mv "$PROJECT_GI.tmp" "$PROJECT_GI"
  CHANGES=$((CHANGES + 1))
  echo "beads-setup: removed .beads/ from project .gitignore"
fi
```

Uses POSIX `sed` with temp file (no `-i` flag) for macOS compatibility.

### 3. Update repo's `.beads/.gitignore`

**File**: `.beads/.gitignore`

Replace entire 57-line blocklist with:

```
# Ignore everything except config.yaml and this file
*
!.gitignore
!config.yaml
```

Already-tracked files are not affected by gitignore changes.

### 4. Extend preflight check to verify gitignore marker

**File**: `plugins/yf/.claude-plugin/preflight.json`

Extend the setup check from:
```
test -d .beads && bd config get no-git-ops 2>/dev/null | grep -q true
```
to:
```
test -d .beads && bd config get no-git-ops 2>/dev/null | grep -q true && grep -qF '!config.yaml' .beads/.gitignore
```

Ensures existing installs with old blocklist gitignore trigger a repair on next preflight.

### 5. Update IG spec

**File**: `docs/specifications/IG/beads-integration.md` (line 20)

Change UC-025 step 5 from:
> 5. Beads manages its own `.beads/.gitignore`

To:
> 5. `.beads/.gitignore` uses allowlist pattern (`*`, `!.gitignore`, `!config.yaml`). `beads-setup.sh` enforces this on every run, overwriting any blocklist from `bd init`.

### 6. Add test cases

**File**: `tests/scenarios/unit-beads-git.yaml` — add case verifying repo `.beads/.gitignore` uses allowlist markers (`!config.yaml`, `!.gitignore`, `*`).

**File**: `tests/scenarios/unit-beads-setup.yaml` — add structural test verifying `beads-setup.sh` contains the allowlist repair logic.

## Verification

1. Run `bash tests/run-tests.sh --unit-only` — all tests pass
2. Confirm `git diff .beads/.gitignore` shows blocklist→allowlist migration
3. Confirm `git status .beads/` still shows only `config.yaml` and `.gitignore` tracked (no runtime files leaked)
