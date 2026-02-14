# Plan 33: Simplify yf Setup — Always-On Chronicler & Archivist

**Status:** Completed
**Date:** 2026-02-14

## Overview

The `/yf:setup` wizard currently asks 4 interactive questions (enable yf, artifact dir, chronicler, archivist). In practice, chronicler and archivist are always enabled and should not be toggleable. The setup should be zero-question: just enable everything silently with `docs/` as default artifact dir. The only way to disable yf should be `/yf:setup disable`, and artifact dir can be overridden via `/yf:setup artifact_dir:<name>`.

### Config Format Change

**Before:** `{"enabled":true,"config":{"artifact_dir":"docs","chronicler_enabled":true,"archivist_enabled":true}}`
**After:** `{"enabled":true,"config":{"artifact_dir":"docs"}}`

Old configs with `chronicler_enabled`/`archivist_enabled` are actively pruned during preflight/setup — deprecated fields are stripped from `config.json` on first run.

## Implementation Sequence

### 1. Config Library — Remove Toggle Functions
**File:** `plugins/yf/scripts/yf-config.sh`
- Delete `yf_is_chronicler_on()` and `yf_is_archivist_on()`
- Keep `_yf_check_flag()`, `yf_is_enabled()`, `yf_is_prune_on_complete()`, `yf_is_prune_on_push()`

### 2. Hooks — Remove Feature Guards
Remove `yf_is_chronicler_on || exit 0` and `yf_is_archivist_on` conditionals from hooks.

### 3. Scripts — Remove Feature Guards
Remove `yf_is_chronicler_on || exit 0` and `yf_is_archivist_on` guards from scripts.

### 4. Preflight — Remove Feature-Toggle Logic + Add Config Pruning
Remove CHRONICLER_ENABLED/ARCHIVIST_ENABLED logic and add config pruning.

### 5. Setup Skill — Rewrite
Rewrite to zero-question setup with disable and artifact_dir params.

### 6. Tests — Delete, Update & Add Pruning Test
Delete obsolete test files, remove guard test cases, add config pruning test.

### 7. Documentation — Update Config Sections
Remove chronicler/archivist toggle references from docs.

### 8. Version & Changelog
Bump to v2.16.0 and add changelog entry.

## Completion Criteria

- [ ] All `yf_is_chronicler_on` / `yf_is_archivist_on` references removed
- [ ] Config pruning strips deprecated fields on first run
- [ ] Setup is zero-question by default
- [ ] All tests pass (`bash tests/run-tests.sh --unit-only`)
- [ ] Documentation updated
- [ ] Version bumped to 2.16.0
