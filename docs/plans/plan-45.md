# Plan 45: Remove Legacy Beads-Sync and Hooks Configuration

**Status:** Completed
**Date:** 2026-02-17

## Overview

beads v0.52.0 uses an embedded dolt backend where writes persist immediately. Three mechanisms are now dead:

1. **`bd sync`** — explicitly a no-op ("Dolt persists writes immediately")
2. **`beads-sync` branch** — hasn't been updated since Feb 16 despite many commits; JSONL export pipeline is non-functional
3. **`bd hooks install`** — sets `core.hooksPath = .beads/hooks` where all 5 hooks are silent no-ops in dolt mode. `issues.jsonl` doesn't even exist. The "JSONL export for git sharing" story is dead.

The yf plugin still configures all three in preflight, references them in rules/specs/docs. All dead code.

**Key findings:**
- `bd sync` = no-op
- All 5 git hooks (`pre-commit`, `post-merge`, `pre-push`, `post-checkout`, `prepare-commit-msg`) exit 0 silently in dolt mode
- `issues.jsonl` doesn't exist — no JSONL export happening
- `bd vc commit/status/merge` = beads-native dolt version control
- `bd worktree` redirects worktrees to shared dolt DB (multi-agent compatible)
- `dolt` CLI NOT needed — beads embeds it; `bd vc` is the interface

## Implementation Sequence

### Step 1: Plugin Config & Scripts

**`preflight.json`** — Setup becomes just `bd init`:
```json
{ "name": "beads", "check": "test -d .beads", "run": "bd init" }
```

**`post-push-prune.sh`** — Remove bd sync, simplify comments. Keep prune logic only.

### Step 2: Rules

**Section 4.1** — Remove `bd sync` from quick reference commands.

**Section 4.2** — Remove step 7 "Sync beads: `bd sync`". Renumber 8->7, 9->8, 10->9.

### Step 3: Specifications

- **TC-009**: "Beads state persisted via embedded dolt database; writes immediate; version control via `bd vc`"
- **REQ-027**: Remove sync.branch, mass-delete config, and `bd hooks install`. Setup = `bd init`.
- **FS-027**: Remove beads-sync and hooks references. Describe dolt-backed persistence.
- **DD-003**: Rewrite to "Dolt-Native Persistence (Reversed from Sync Branch)"
- **DD-011**: Update to remove beads-sync references
- **UC-025**: Simplify to: `bd init` -> no AGENTS.md -> beads manages `.beads/.gitignore`
- **UC-027**: Remove step 2e (bd sync after prune)
- **UC-028**: Remove step 6 (bd sync). Renumber.
- **test-coverage.md**: Update DD-003 row summary
- **TODO-008**: Move to completed

### Step 4: Tests

**`unit-beads-git.yaml`**:
- Rename: "Unit: beads dolt backend — no sync, no hooks"
- Case 3 `preflight_has_hooks_install` -> `preflight_no_hooks_install` (invert: assert absent)
- Case 4 `rules_has_bd_sync` -> `rules_no_bd_sync` (invert: assert absent)
- Add Case 10: `preflight_no_sync_branch` (assert sync.branch absent from preflight)
- Add Case 11: `post_push_prune_no_sync` (assert `bd sync` absent from hook)
- Add Case 12: `preflight_setup_is_bd_init_only` (assert run command is exactly `bd init`)

### Step 5: Documentation & Root Cleanup

- **plugins/yf/README.md**: Replace beads-sync note with dolt persistence note
- **CHANGELOG.md**: Add v2.22.0 section
- **`.gitattributes`**: Remove JSONL merge driver lines
- **`.beads/config.yaml`**: Remove `sync-branch: "beads-sync"` line

### Step 6: Git Cleanup (destructive, with confirmation)

```bash
git config --unset core.hooksPath          # restore default .git/hooks
git branch -d beads-sync                   # delete local branch
git push origin --delete beads-sync        # delete remote branch
```

## Completion Criteria

- [ ] `bash tests/run-tests.sh --unit-only` — all tests pass
- [ ] `bash plugins/yf/scripts/spec-sanity-check.sh all` — 6/6 pass
- [ ] `grep -r 'beads-sync\|bd sync\|bd hooks install\|sync.branch' plugins/yf/` — returns nothing
- [ ] `git config core.hooksPath` — returns empty (default)
- [ ] `git branch -a | grep beads-sync` — returns nothing
