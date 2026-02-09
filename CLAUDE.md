# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yoshiko Studios Claude Marketplace - A marketplace for Claude plugins, hosting a collection of skills, agents, rules, scripts, and hooks.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog with plugin registry
├── plugins/
│   └── yf/                 # Yoshiko Flow — unified plugin
│       ├── .claude-plugin/
│       │   ├── plugin.json     # Plugin manifest
│       │   └── preflight.json  # Artifact declarations
│       ├── skills/         # Auto-invoked skills (*/SKILL.md)
│       ├── agents/         # Specialized agents (*.md)
│       ├── rules/          # Behavioral rules (*.md)
│       ├── scripts/        # Shell scripts (*.sh)
│       ├── hooks/          # Pre/post tool-use hooks (*.sh)
│       └── README.md       # Plugin documentation
├── docs/
│   ├── plans/              # Plan documentation
│   └── diary/              # Generated diary entries
├── CLAUDE.md               # This file
├── README.md               # Marketplace overview
├── LICENSE                 # MIT License
└── CHANGELOG.md            # Version history
```

## Build / Test Commands

```bash
# Test marketplace locally
claude --plugin-dir /Users/james/workspace/spikes/marketplace

# Test a specific plugin
claude --plugin-dir /Users/james/workspace/spikes/marketplace/plugins/yf

# Run unit tests
bash tests/run-tests.sh --unit-only
```

## Naming & Namespacing Convention

All skills and agents MUST be namespaced with their plugin name to prevent collisions when multiple plugins are installed.

### Skills

The `name` field in SKILL.md frontmatter uses `plugin:skill_name` format:

```yaml
---
name: yf:capture          # CORRECT — namespaced
description: Capture context
---
```

```yaml
---
name: capture              # WRONG — will collide with other plugins
---
```

Cross-plugin skill references in content also use this format: `/yf:execute_plan`, `/yf:capture`.

### Agents

Agent `name` fields use a `plugin_` prefix (underscore, not colon):

```yaml
---
name: yf_recall              # CORRECT — prefixed with plugin name
description: Context recovery agent
---
```

### Rules

Rule files installed to `.claude/rules/` use `yf-` prefix (e.g., `yf-beads.md`, `yf-engage-the-plan.md`). Rules are project-scoped, not plugin-scoped, so the prefix prevents collisions.

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`

   Skills and agents are auto-discovered from directory structure — do NOT list them in the manifest. Only include official Claude Code schema fields (name, version, description, author, license, hooks, etc.). Custom fields like `dependencies` and `artifacts` go in `preflight.json` (see step 2b).

   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": { "name": "James Dixson", "email": "dixson3@gmail.com" },
     "license": "MIT",
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash(some-command*)",
           "hooks": [
             {
               "type": "command",
               "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-hook.sh"
             }
           ]
         }
       ]
     }
   }
   ```

2b. **Add preflight config** (optional): `.claude-plugin/preflight.json`

   Artifact declarations, dependencies, and setup commands go here — separate from `plugin.json` to avoid Claude Code's strict schema validation.

   ```json
   {
     "dependencies": [],
     "artifacts": {
       "rules": [
         { "source": "rules/my-rule.md", "target": ".claude/rules/my-rule.md" }
       ],
       "directories": ["docs/my-dir"],
       "setup": [
         { "name": "my-setup", "check": "test -d .my-dir", "run": "my-init-cmd" }
       ]
     }
   }
   ```

3. **Add skills** (optional): `skills/<skill_name>/SKILL.md`
   - Frontmatter `name` MUST be `plugin:skill_name` (namespaced)
   - Include `description` and `arguments` in frontmatter
   - Behavior guidelines and instructions in body

4. **Add agents** (optional): `agents/<plugin_agentname>.md`
   - Frontmatter `name` MUST be prefixed with plugin name (e.g., `yf_recall`)
   - Include `description` and optional `on-start` in frontmatter
   - Role, personality, and interaction guidelines in body

5. **Add rules** (optional): `rules/<descriptive-name>.md`
   - Behavioral enforcement installed to `.claude/rules/`
   - Use plugin-prefixed names (e.g., `yf-beads.md`)

6. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

7. **Document**: Add `README.md` to the plugin directory

## Plugin Components

### Skills
Automatic behaviors Claude can invoke contextually. Defined in `skills/<name>/SKILL.md` — the directory name determines the skill identifier. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Agents
Specialized agents for specific tasks. Defined in `agents/<name>.md`. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Rules
Behavioral rules declared in `preflight.json` under `artifacts.rules`. Source files live in `rules/` within the plugin; they are synced to `.claude/rules/` in the project by the preflight system.

### Scripts
Shell scripts for deterministic operations (e.g., state transitions). Referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/` in hooks and skills.

### Hooks
Pre/post tool-use hooks declared in `plugin.json` under the `hooks` key. Hook commands use `${CLAUDE_PLUGIN_ROOT}` to reference the plugin directory.

## Preflight System

Plugins declare their artifacts (rules, directories, setup commands) in `.claude-plugin/preflight.json` (separate from `plugin.json` to comply with Claude Code's strict manifest schema). A preflight script (`scripts/plugin-preflight.sh`) runs automatically on SessionStart and syncs artifacts to the project using **symlinks** (not copies):

- **Install**: Missing rules are created as symlinks pointing to the plugin source files
- **Update**: Broken or incorrect symlinks are recreated; regular files (from older versions) are migrated to symlinks
- **Remove**: Symlinks for rules no longer in the manifest are deleted
- **Fast path**: Checks `readlink` targets and symlink count — skips sync when all symlinks are correct

Configuration:
- **`.claude/yf.json`** — Gitignored config + preflight lock state (`enabled`, `config`, `updated`, `preflight`).

Rules in `.claude/rules/yf-*.md` are gitignored symlinks pointing to `plugins/yf/rules/`. Edits to plugin source rules are immediately active — no re-sync needed.

## Current Plugins

- **yf** (v2.4.0) - Yoshiko Flow — plan lifecycle, execution orchestration, context persistence, and diary generation
