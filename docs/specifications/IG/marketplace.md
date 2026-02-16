# Implementation Guide: Marketplace

## Overview

The marketplace provides the plugin architecture for Claude Code -- plugin registration, installation, preflight artifact management, and testing infrastructure.

## Use Cases

### UC-022: Plugin Registration

**Actor**: Plugin Developer

**Preconditions**: Plugin directory exists with `plugin.json`.

**Flow**:
1. Create plugin directory: `plugins/<name>/`
2. Add manifest: `.claude-plugin/plugin.json` with name, version, description, author, license, hooks
3. Add preflight config: `.claude-plugin/preflight.json` with rules, directories, setup commands
4. Add skills, agents, rules as needed (auto-discovered from directory structure)
5. Register in marketplace: update `.claude-plugin/marketplace.json`
6. Test: `claude --plugin-dir ./plugins/<name>`

**Postconditions**: Plugin available in marketplace. Skills and agents auto-discovered.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/.claude-plugin/marketplace.json`
- `/Users/james/workspace/dixson3/d3-claude-plugins/DEVELOPERS.md`

### UC-023: Preflight Artifact Sync

**Actor**: System (SessionStart hook)

**Preconditions**: Plugin loaded in Claude Code session.

**Flow**:
1. `preflight-wrapper.sh` triggers `plugin-preflight.sh`
2. Script sources `yf-config.sh` for config access
3. Script checks fast path: version matches, rule count matches, all symlinks correct
4. If fast path passes: exit in <50ms
5. If full sync needed: for each rule in `preflight.json`:
   a. Compute symlink target (relative if in project tree, absolute if external)
   b. If correct symlink exists: skip
   c. If regular file exists (old copy): remove, create symlink
   d. If missing: create symlink
6. Remove dangling symlinks not in current manifest
7. Create directories listed in `preflight.json`
8. Run setup commands (e.g., `bd init`)
9. Run `setup-project.sh` for gitignore management (no AGENTS.md is created — see REQ-027; legacy AGENTS.md files are removed if present)
10. Write lock state to `.yoshiko-flow/lock.json`

**Postconditions**: Rule symlinks installed. Directories created. Lock updated.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plugin-preflight.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/preflight-wrapper.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/preflight.json`

### UC-024: Running Tests

**Actor**: Developer

**Preconditions**: Go test harness built. Test scenarios exist.

**Flow**:
1. Developer runs `bash tests/run-tests.sh --unit-only`
2. Script builds Go harness from `tests/harness/`
3. Script discovers `tests/scenarios/unit-*.yaml` files
4. For each scenario: harness executes steps with command, env, and expect assertions
5. Assertions check exit codes, stdout content, file existence
6. Harness reports pass/fail per scenario
7. Script reports total: `N passed, M failed`

**Postconditions**: Test results displayed. Non-zero exit on failures.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/tests/run-tests.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/tests/harness/`
