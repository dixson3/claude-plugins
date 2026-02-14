# Plan 26: Rename `yf.json` to `config.json` + Stale-File Migration

**Status:** Completed
**Date:** 2026-02-13

## Context

The yf plugin config file is `.yoshiko-flow/yf.json`. The name `config.json` is more descriptive and avoids redundancy with the `yf` directory naming. The rename also requires a migration path so existing users' config is preserved, and any stale `yf.json` files are cleaned up.

## Overview

1. Rename `.yoshiko-flow/yf.json` → `.yoshiko-flow/config.json` across all source, docs, and tests
2. Add migration logic: auto-rename existing `yf.json` → `config.json` on first preflight run
3. Add stale-file removal: if both `yf.json` and `config.json` exist, remove the stale `yf.json`
4. Update `.yoshiko-flow/.gitignore` to whitelist `config.json` (with auto-update for existing installs)
5. Do NOT touch historical docs (CHANGELOG.md, diary entries, plan files)

## Implementation Sequence

### Phase 1: Core Config Library
**File:** `plugins/yf/scripts/yf-config.sh`
- Line 5: Comment `Config: .yoshiko-flow/yf.json` → `config.json`
- Line 15: `_YF_JSON` path `yf.json` → `config.json` (variable name stays `_YF_JSON`)

### Phase 2: Migration Logic
**File:** `plugins/yf/scripts/plugin-preflight.sh`

Update `CONFIG_FILE` (line 33) and restructure lines 51-63:

1. **New step — rename within `.yoshiko-flow/`**: Before the `.claude/` migration block, add:
   ```bash
   OLD_YF_JSON="$YF_DIR/yf.json"
   if [ -f "$OLD_YF_JSON" ] && [ ! -f "$CONFIG_FILE" ]; then
     mv "$OLD_YF_JSON" "$CONFIG_FILE"
     echo "preflight: renamed .yoshiko-flow/yf.json → config.json"
   elif [ -f "$OLD_YF_JSON" ] && [ -f "$CONFIG_FILE" ]; then
     rm -f "$OLD_YF_JSON"
     echo "preflight: removed stale .yoshiko-flow/yf.json"
   fi
   ```

2. **Update `.claude/yf.json` migration** — destination is now `config.json` (already handled by `$CONFIG_FILE` variable change)

3. **Update `.gitignore` block** — change from "create if missing" to "ensure correct content":
   ```bash
   EXPECTED_GI_MARKER='!config.json'
   if [ ! -f "$YF_DIR/.gitignore" ] || ! grep -qF "$EXPECTED_GI_MARKER" "$YF_DIR/.gitignore"; then
     cat > "$YF_DIR/.gitignore" <<'GITIGNORE_EOF'
   # Ignore everything except config.json
   *
   !.gitignore
   !config.json
   GITIGNORE_EOF
   fi
   ```

4. **Update comment** on line 8 and log messages as needed

### Phase 3: Setup Skill
**File:** `plugins/yf/skills/setup/SKILL.md`
- 6 occurrences of `yf.json` → `config.json` (lines 15, 18, 58, 61, 113, 123)

### Phase 4: In-Repo Gitignore + File Rename
- `git mv .yoshiko-flow/yf.json .yoshiko-flow/config.json`
- Edit `.yoshiko-flow/.gitignore`: `!yf.json` → `!config.json`, comment update

### Phase 5: Active Documentation
- `README.md` line 86 — config path reference
- `plugins/yf/README.md` line 147 — config path reference
- `plugins/yf/DEVELOPERS.md` lines 188, 191, 194 — config path references

### Phase 6: Test Scenarios (21 files)
Mechanical `yf.json` → `config.json` replacement across all test YAML files that use it as an active config path. Includes both inline references and teardown lines.

### Phase 7: New Migration Test Cases
**File:** `tests/scenarios/unit-migration.yaml`

Add 3 new test cases:
1. `yf_json_renamed_to_config_json` — verifies rename, stale removal, content preservation
2. `stale_yf_json_removed_when_config_exists` — both files exist, old is removed, new is untouched
3. `gitignore_updated_from_yf_json_to_config_json` — old `.gitignore` content refreshed

Update existing migration test assertions to check for `config.json` instead of `yf.json`.

## Files Modified

| File | Change |
|------|--------|
| `plugins/yf/scripts/yf-config.sh` | Config path `yf.json` → `config.json` |
| `plugins/yf/scripts/plugin-preflight.sh` | Migration logic + CONFIG_FILE + .gitignore block |
| `plugins/yf/skills/setup/SKILL.md` | 6 path references |
| `.yoshiko-flow/.gitignore` | Whitelist `config.json` |
| `.yoshiko-flow/yf.json` | `git mv` → `config.json` |
| `README.md` | 1 reference |
| `plugins/yf/README.md` | 1 reference |
| `plugins/yf/DEVELOPERS.md` | 3 references |
| 21 test YAML files | Mechanical `yf.json` → `config.json` |
| `tests/scenarios/unit-migration.yaml` | Update existing + 3 new test cases |

## Not Modified

- `CHANGELOG.md` — historical (add new entry for this version)
- `docs/diary/*.md` — historical
- `docs/plans/*.md` — historical

## Completion Criteria

- [ ] `yf-config.sh` points to `config.json`
- [ ] `plugin-preflight.sh` migrates `yf.json` → `config.json` and removes stale copies
- [ ] `.yoshiko-flow/.gitignore` whitelists `config.json` (auto-updated for existing installs)
- [ ] `.yoshiko-flow/config.json` exists in repo (renamed from `yf.json`)
- [ ] All 3 new migration test cases pass
- [ ] `bash tests/run-tests.sh --unit-only` passes (all existing tests updated)
- [ ] No references to `yf.json` remain in active source/docs (only in CHANGELOG/diary/plans)
