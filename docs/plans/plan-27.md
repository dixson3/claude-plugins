# Plan 27: Beads Git Workflow Integration

**Status:** Draft
**Date:** 2026-02-13

## Overview

The yf plugin currently treats `.beads/` as entirely local-only (introduced in v2.5.0, Plan 18). This refactor reverses that decision, aligning with the beads-git-workflow-guide-v2.md: `.beads/` becomes git-tracked with a `beads-sync` branch strategy, git hooks for automated JSONL sync, and a custom pre-push hook for auto-pushing the sync branch.

**Key architectural shift:** Beads manages its own `.beads/.gitignore` (tracking `issues.jsonl`, `config.yaml`, `metadata.json`, `interactions.jsonl`; ignoring `*.db`, daemon files). The project-level `.gitignore` no longer needs to ignore `.beads/`.

## Implementation Sequence

### Phase 1: Setup Infrastructure

**1.1 `plugins/yf/scripts/setup-project.sh`** — Remove `.beads/` from managed gitignore block

- Change `MANAGED_BLOCK` to remove `.beads/` lines
- Keep AGENTS.md cleanup unchanged

**1.2 Create `plugins/yf/scripts/install-beads-push-hook.sh`** (new file)

- Idempotent installer for pre-push hook that auto-pushes `beads-sync`
- Uses sentinel markers (`BEADS-SYNC-PUSH`) for detection
- Appends to existing `.git/hooks/pre-push` if present
- Fail-open: always exits 0

### Phase 2: Preflight Changes

**2.1 `plugins/yf/.claude-plugin/preflight.json`** — Update beads setup command

- Change from `bd init --skip-hooks` to full init chain with sync config + hooks

**2.2 `plugins/yf/scripts/plugin-preflight.sh`** — Add migration + hook installer

- Migration detection and steps for legacy deployments
- Run `install-beads-push-hook.sh` unconditionally (idempotent)

### Phase 3: Rules and Documentation

**3.1 `plugins/yf/rules/beads.md`** — Rewrite for git-tracked model
**3.2 `plugins/yf/README.md`** — Update beads note
**3.3 `plugins/yf/DEVELOPERS.md`** — Update managed block + rationale

### Phase 4: Tests

**4.1** Delete `unit-beads-local.yaml`, create `unit-beads-git.yaml` with 9 test cases

### Phase 5: Version Bump and Changelog

**5.1 `CHANGELOG.md`** — Add [2.12.0] entry
**5.2 `plugins/yf/.claude-plugin/plugin.json`** — Bump to 2.12.0

## Completion Criteria

- [ ] `.beads/` not in project gitignore managed block
- [ ] `bd init` runs without `--skip-hooks`, with sync branch config + hooks
- [ ] Pre-push hook auto-pushes beads-sync
- [ ] `rules/beads.md` documents git workflow, includes `bd sync` in quick ref
- [ ] Migration detects legacy deployments and converts automatically
- [ ] All unit tests pass (old beads-local tests replaced)
- [ ] README and DEVELOPERS docs updated
