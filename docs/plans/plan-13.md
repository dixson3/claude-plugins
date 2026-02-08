# Plan 13: Consolidate Plugins — Yoshiko Flow (`yf`)

**Status:** Completed
**Date:** 2026-02-08

## Overview

Consolidate the `workflows` and `chronicler` plugins into a single `yf` (Yoshiko Flow) plugin. Rename `.claude/plugin-lock.json` to `.claude/yf.json` with `preflight` key nesting.

## Implementation Sequence

### Phase 1: Create `plugins/yf/` with merged content
- Merged manifests (plugin.json, preflight.json)
- 11 skills namespaced `yf:*`
- 2 agents prefixed `yf_*`
- 9 rules prefixed `yf-*`
- 5 hooks (merged from both plugins)
- 2 scripts (copied from workflows)
- Consolidated README

### Phase 2: Update preflight for `yf.json`
- Lock file path: `.claude/plugin-lock.json` → `.claude/yf.json`
- JSON structure: nested under `preflight` key
- Migration logic for old lock file

### Phase 3: Update marketplace-level files
- marketplace.json: 2 plugins → 1
- .gitignore: updated lock file entry
- CLAUDE.md: all namespace refs updated
- README.md: updated plugin table
- CHANGELOG.md: [2.0.0] entry

### Phase 4: Update tests
- All 14 scenario files updated for new paths/names/structure
- New test: unit-yf-migration.yaml

### Phase 5: Delete old plugins
- `plugins/workflows/` removed
- `plugins/chronicler/` removed
- Old un-prefixed rules removed from `.claude/rules/`

### Phase 6: Documentation & memory
- MEMORY.md updated
- Plan file created

## Completion Criteria

- [ ] `plugins/yf/` contains all 11 skills, 2 agents, 9 rules, 5 hooks, 2 scripts
- [ ] Plugin description is "Yoshiko Flow — ..."
- [ ] All skill names use `yf:*` namespace
- [ ] All agent names use `yf_*` prefix
- [ ] All rule filenames use `yf-*` prefix, installed to `.claude/rules/yf-*.md`
- [ ] `plugins/workflows/` and `plugins/chronicler/` deleted
- [ ] `.claude/yf.json` replaces `.claude/plugin-lock.json` with `preflight` nesting
- [ ] Migration from old lock file works
- [ ] `marketplace.json` lists only `yf`
- [ ] All unit tests pass (`bash tests/run-tests.sh --unit-only`)
