# Plan 10: Plugin Preflight & Declarative Artifact Management

**Status:** Completed
**Date:** 2026-02-08

## Overview

Replaced manual `init` skills with a declarative artifact manifest in `plugin.json` and an automatic preflight sync script that runs on SessionStart. Each plugin declares its rules, directories, and setup commands; the preflight engine installs, updates, and removes artifacts with checksum-based conflict detection.

## Implementation

- **Artifact manifests** in `plugin.json` (`artifacts` key with `rules`, `directories`, `setup`)
- **Plugin dependencies** (`dependencies` array, topological ordering)
- **Preflight script** (`scripts/plugin-preflight.sh`) — bash 3.2 compatible
- **Lock file** (`.claude/plugin-lock.json`) — tracks versions, checksums, setup state
- **SessionStart hook** (`preflight-wrapper.sh`) — automatic on every session
- **Static BEADS.md** — moved from generated content to a copy artifact

## Key Behaviors

- Fast path (<50ms when up to date)
- Conflict detection: user-modified rules preserved, warnings emitted
- Stale removal: artifacts in lock but not in manifest are deleted
- Removed plugin cleanup: artifacts from unregistered plugins are cleaned up
- Fail-open: errors warn but never block sessions

## Files Changed

| File | Action |
|------|--------|
| `scripts/plugin-preflight.sh` | Created |
| `plugins/workflows/hooks/preflight-wrapper.sh` | Created |
| `plugins/workflows/rules/BEADS.md` | Created |
| `plugins/workflows/.claude-plugin/plugin.json` | Modified (artifacts, deps, SessionStart hook, v1.5.0) |
| `plugins/chronicler/.claude-plugin/plugin.json` | Modified (artifacts, deps, v1.3.0) |
| `.claude-plugin/marketplace.json` | Modified (v1.7.0) |
| `plugins/workflows/skills/init/` | Deleted |
| `plugins/workflows/skills/init_beads/` | Deleted |
| `plugins/chronicler/skills/init/` | Deleted |
| `CLAUDE.md` | Updated |
| `CHANGELOG.md` | Updated |
| `.gitignore` | Updated (plugin-lock.json) |
| `tests/scenarios/unit-preflight.yaml` | Created |
| `tests/scenarios/unit-preflight-stale.yaml` | Created |
| `tests/scenarios/unit-preflight-conflict.yaml` | Created |
| `tests/scenarios/unit-chronicler-init.yaml` | Updated |
