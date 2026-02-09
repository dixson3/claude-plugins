# Plan 15: Split yf.json into Committable Config + Local Overrides

**Status:** Completed
**Date:** 2026-02-08

## Overview

Split the single gitignored `.claude/yf.json` into two files: a committable shared config (`yf.json` v2) and a gitignored local overrides file (`yf.local.json`). This allows team-shareable configuration while keeping machine-local state (preflight checksums, timestamps) out of git.

## Implementation Sequence

### 1. NEW: `yf-config.sh` — Shared config library
Sourceable shell library (bash 3.2 compatible) providing merged config access:
- `yf_merged_config` — prints merged JSON (yf.json * yf.local.json)
- `yf_is_enabled` / `yf_is_chronicler_on` — boolean checks on merged config
- `yf_read_field EXPR` — jq on merged config
- `yf_config_exists` — true if either file exists

### 2. MODIFY: 4 hooks — Replace inline guards
Replace 4-line inline jq guards with 3-line library sourcing in code-gate.sh, exit-plan-gate.sh, plan-exec-guard.sh, pre-push-diary.sh.

### 3. MODIFY: `plugin-preflight.sh` — Major changes
- Source config library
- Add v1→v2 migration (split preflight into yf.local.json)
- Setup signal checks either file
- Read/write two-file model (config → yf.json, lock → yf.local.json)

### 4. MODIFY: `SKILL.md` (setup wizard)
- Read merged config from both files
- Add Question 4: commit to git (shared) vs local-only

### 5. MODIFY: `.gitignore`
Remove `.claude/yf.json` from ignore list (now committable).

### 6. MODIFY: `plugin.json`
Bump version 2.1.0 → 2.2.0.

### 7. Test Scenarios
- NEW: `unit-yf-config-merge.yaml` (8 cases)
- NEW: `unit-yf-v2-migration.yaml` (7 cases)
- UPDATED: 6 existing preflight scenarios for two-file model

### 8. MODIFY: `CLAUDE.md`
Document two-file model in Preflight System section.

## Completion Criteria

- [x] `yf-config.sh` library created with all 5 functions
- [x] All 4 hooks use library instead of inline guards
- [x] `plugin-preflight.sh` reads/writes two-file model
- [x] v1→v2 migration works (including chain from plugin-lock.json v0)
- [x] Setup wizard has Question 4 for commit vs local
- [x] `.gitignore` updated (yf.json committable, yf.local.json ignored)
- [x] Plugin version bumped to 2.2.0
- [x] All 221 unit tests pass
- [x] CHANGELOG updated
