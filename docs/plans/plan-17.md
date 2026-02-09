# Plan 17: Zero-Commit Rule Management — Symlink-Based Preflight

**Status:** Completed
**Date:** 2026-02-08

## Context

The yf plugin currently copies 9 rule files from `plugins/yf/rules/` into `.claude/rules/` via the preflight system, and these copies are committed to git. The config file `.claude/yf.json` is also designed to be committable. This means enabling the plugin leaves a footprint in the repo's git history — tracked rules, config choices, and lock state.

The goal is to make the plugin **fully local**: enable it for a repo and have zero control artifacts committed. Rule definitions stay in the plugin folder as the single source of truth. The preflight system creates symlinks (not copies) in `.claude/rules/` pointing back to the plugin source. Everything outside `plugins/` is gitignored.

## Approach: Symlinks + Simplified Preflight

**Why symlinks over gitignored copies:**
- Single source of truth (no file duplication)
- Edits to plugin source rules are immediately active (no re-sync needed)
- Eliminates the checksum/conflict detection system entirely (symlinks can't diverge)
- Dramatically simplifies `plugin-preflight.sh` (~455 → ~180 lines)

**Why not CLAUDE.local.md concatenation:**
- Loses individual rule granularity (can't tell which rule fired)
- CLAUDE.local.md is a user-owned file; auto-generating it conflicts with other uses
- All-or-nothing activation (can't conditionally skip chronicle rules)

**Symlink safety:** Claude Code discovers rules via standard `fs.readFile` on `.claude/rules/*.md`. Symlinks are transparent to all standard file I/O on macOS/Linux. Gitignored status doesn't gate rule loading — all `.md` files in the directory are read.

## Implementation Sequence

### Phase 1: Verify Symlinks Work (~5 min)

Quick experiment before committing to the approach:
1. Create a test symlink: `ln -sf ../../plugins/yf/rules/yf-beads.md .claude/rules/test-symlink.md`
2. Verify it reads: `cat .claude/rules/test-symlink.md`
3. Clean up: `rm .claude/rules/test-symlink.md`

If symlinks don't resolve correctly (e.g., plugin is loaded from a cache outside the repo), fall back to absolute symlinks using `$PLUGIN_ROOT`.

### Phase 2: Git Cleanup — Untrack Rules

**`.gitignore`** — add patterns:
```
# Plugin-managed rules (symlinked by preflight)
.claude/rules/yf-*.md
```

**Untrack committed copies:**
```bash
git rm --cached .claude/rules/yf-*.md
```

Note: `.claude/yf.json` is already untracked (confirmed via `git ls-files`).

### Phase 3: Rewrite `plugin-preflight.sh`

**File:** `plugins/yf/scripts/plugin-preflight.sh`

Major simplification. The new script structure:

1. **Resolve paths** (same as today — `BASH_SOURCE` based)
2. **Source `yf-config.sh`**
3. **Migration: v0/v1 → v2 → v3** — detect old formats, merge into `yf.local.json`, delete `yf.json` if it has v2 config
4. **Migration: copies → symlinks** — detect regular files in `.claude/rules/yf-*.md`, replace with symlinks
5. **Setup needed signal** (same)
6. **Read merged config** (same)
7. **Disabled handler** — remove symlinks instead of files; do NOT create `yf.json`
8. **Fast path** — check: version matches, rule count matches, all symlinks exist and point to correct targets (`readlink` comparison instead of checksum)
9. **Full sync** — for each rule in `preflight.json`:
   - If chronicle rule and chronicler disabled: skip (remove symlink if exists)
   - Compute symlink target (relative if plugin is in project tree, absolute otherwise)
   - If correct symlink exists: skip
   - If regular file exists (old copy): remove, create symlink
   - If missing: create symlink
10. **Remove dangling** — yf-* symlinks in `.claude/rules/` not in current manifest
11. **Directories & setup commands** (same as today)
12. **Chmod scripts/hooks** (same)
13. **Write lock to `yf.local.json` only** — no `yf.json` writes. Lock format changes: `checksum` → `link` (symlink target), add `mode: "symlink"`
14. **Summary output**

### Phase 4: Simplify Config Model — Local Only

**File:** `plugins/yf/scripts/yf-config.sh`

The `yf_merged_config` function already handles single-file mode. No functional changes needed — but update the header comments to reflect the new model (local-only, no committed config).

### Phase 5: Update Setup Skill

**File:** `plugins/yf/skills/setup/SKILL.md`

- Remove Question 4 ("Share config?") — all config is local now
- Remove the "If sharing (committed to git)" code path
- All writes go to `yf.local.json`
- Update report output: remove "committed to git" / "local only" distinction
- Update "Read existing config" section to only reference `yf.local.json`

### Phase 6: Update `preflight.json`

**File:** `plugins/yf/.claude-plugin/preflight.json`

Optional but documenting intent — add `"mode": "symlink"` at top level.

### Phase 7: Bump Version

**File:** `plugins/yf/.claude-plugin/plugin.json`

Bump `2.3.0` → `2.4.0`.

### Phase 8: Update Tests

### Phase 9: Update Documentation

## Completion Criteria

- [ ] All 9 rules are symlinks (not regular files) in `.claude/rules/`
- [ ] `git ls-files .claude/rules/` returns empty
- [ ] `git ls-files .claude/yf.json` returns empty
- [ ] Only `yf.local.json` exists (no `yf.json`)
- [ ] `plugin-preflight.sh` creates symlinks, not copies
- [ ] No checksum/conflict detection code remains
- [ ] Setup skill writes to `yf.local.json` only
- [ ] All unit tests pass
- [ ] Migration from v2 copies to v3 symlinks works
