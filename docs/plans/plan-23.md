# Plan 23: Setup-Managed .gitignore and AGENTS.md Cleanup

**Status:** Completed
**Date:** 2026-02-09

## Context

When the yf plugin is installed in external projects (not the marketplace repo), two things don't happen:

1. The target project's `.gitignore` doesn't receive entries for `.beads/`, `.claude/settings.local.json`, `.claude/rules/yf-*.md`, etc. The marketplace's own `.gitignore` was hand-crafted but nothing replicates those entries in target projects.
2. `bd init --skip-hooks` (run by preflight setup) creates an `AGENTS.md` with `bd sync`, mandatory `git push`, and "Work is NOT complete until git push succeeds" — all of which directly conflict with yf's local-only beads model defined in the `yf-beads.md` rule.

## Overview

Add a new script `setup-project.sh` that manages a sentinel-bracketed block of `.gitignore` entries and removes conflicting `bd init`/`bd onboard` content from `AGENTS.md`. Called from `plugin-preflight.sh` after setup commands on every session (catching drift).

## Implementation Sequence

### 1. New Script: `plugins/yf/scripts/setup-project.sh`

Two responsibilities, selectable by mode argument (`gitignore`, `agents`, or `all`):

**Gitignore management** — maintains a sentinel-bracketed block in the project root `.gitignore`:

```
# >>> yf-managed >>>
# Beads issue tracker (local-only)
.beads/

# Claude Code local files
.claude/settings.local.json
.claude/CLAUDE.local.md

# yf plugin config & state
.claude/yf.json
.claude/rules/yf-*.md
.claude/.task-pump.json
.claude/.plan-gate
.claude/.plan-intake-ok
# <<< yf-managed <<<
```

Logic:
1. No `.gitignore` → create with managed block
2. Has sentinel block → compare, replace if different (idempotent update)
3. Has `.gitignore` but no sentinel → append block at end
4. Use awk for block replacement (bash 3.2 compatible, avoids macOS sed `-i` quirks)

**AGENTS.md cleanup** — removes `bd init`/`bd onboard` content:

Logic:
1. No AGENTS.md → no-op
2. Entire file is bd content (`# Agent Instructions` heading with only bd/beads sections) → delete file
3. File has mixed content with bd sections → remove bd sections, keep rest
4. After cleanup, if file is whitespace-only → delete it

Guards: `yf_is_enabled || exit 0`. Always exit 0 (fail-open).

### 2. Modify: `plugins/yf/scripts/plugin-preflight.sh`

**Insert call** after setup commands (after `bd init --skip-hooks` runs) and before rules section.

**Extend fast path** — add gitignore sentinel check.

### 3. Modify: `plugins/yf/skills/setup/SKILL.md`

Add documentation about automatic project environment behavior.

### 4. New Tests: `tests/scenarios/unit-setup-project.yaml`

10 test cases covering all gitignore and AGENTS.md scenarios.

### 5. Documentation Updates

- `plugins/yf/README.md`: Scripts 7→8, add gitignore mention in Getting Started
- `plugins/yf/DEVELOPERS.md`: Document sentinel pattern in Preflight section
- `CHANGELOG.md`: v2.10.0 entry
- `plugins/yf/.claude-plugin/plugin.json`: Bump 2.9.0 → 2.10.0

## Completion Criteria

- [ ] `setup-project.sh gitignore` creates sentinel-bracketed block in `.gitignore`
- [ ] `setup-project.sh gitignore` is idempotent
- [ ] `setup-project.sh gitignore` preserves existing `.gitignore` content
- [ ] `setup-project.sh agents` removes bd-only AGENTS.md
- [ ] `setup-project.sh agents` preserves non-bd content in mixed AGENTS.md
- [ ] `setup-project.sh agents` is a no-op when no AGENTS.md exists
- [ ] Respects yf enabled guard, always exits 0
- [ ] `plugin-preflight.sh` calls it after setup commands
- [ ] Fast path includes gitignore sentinel check
- [ ] All unit tests pass
- [ ] `bash tests/run-tests.sh --unit-only` passes
- [ ] Documentation updated
