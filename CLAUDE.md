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
│   └── <plugin-name>/      # Individual plugins
│       ├── .claude-plugin/
│       │   └── plugin.json # Plugin manifest
│       ├── skills/         # Auto-invoked skills (*/SKILL.md)
│       ├── agents/         # Specialized agents (*.md)
│       ├── rules/          # Behavioral rules (*.md)
│       ├── scripts/        # Shell scripts (*.sh)
│       ├── hooks/          # Pre/post tool-use hooks (*.sh)
│       └── README.md       # Plugin documentation
├── docs/
│   └── plans/              # Plan documentation
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
claude --plugin-dir /Users/james/workspace/spikes/marketplace/plugins/workflows
```

## Naming & Namespacing Convention

All skills and agents MUST be namespaced with their plugin name to prevent collisions when multiple plugins are installed.

### Skills

The `name` field in SKILL.md frontmatter uses `plugin:skill_name` format:

```yaml
---
name: myplugin:do_thing          # CORRECT — namespaced
description: Does the thing
---
```

```yaml
---
name: do_thing                   # WRONG — will collide with other plugins
---
```

Cross-plugin skill references in content also use this format: `/workflows:init_beads`, `/roles:apply`, `/chronicler:capture`.

### Agents

Agent `name` fields use a `plugin_` prefix (underscore, not colon):

```yaml
---
name: chronicler_recall          # CORRECT — prefixed with plugin name
description: Context recovery agent
---
```

### Rules

Rule files installed to `.claude/rules/` should use descriptive names that indicate origin (e.g., `BEADS.md`, `engage-the-plan.md`). Rules are project-scoped, not plugin-scoped, so avoid generic names like `rules.md`.

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`

   Skills and agents are auto-discovered from directory structure — do NOT list them in the manifest. Only include metadata and hooks.

   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": { "name": "James Dixson", "email": "dixson3@gmail.com" },
     "license": "MIT"
   }
   ```

   With hooks (optional):
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

3. **Add skills** (optional): `skills/<skill_name>/SKILL.md`
   - Frontmatter `name` MUST be `plugin:skill_name` (namespaced)
   - Include `description` and `arguments` in frontmatter
   - Behavior guidelines and instructions in body

4. **Add agents** (optional): `agents/<plugin_agentname>.md`
   - Frontmatter `name` MUST be prefixed with plugin name (e.g., `chronicler_recall`)
   - Include `description` and optional `on-start` in frontmatter
   - Role, personality, and interaction guidelines in body

5. **Add rules** (optional): `rules/<descriptive-name>.md`
   - Behavioral enforcement installed to `.claude/rules/`
   - Use descriptive names, not generic ones

6. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

7. **Document**: Add `README.md` to the plugin directory

## Plugin Components

### Skills
Automatic behaviors Claude can invoke contextually. Defined in `skills/<name>/SKILL.md` — the directory name determines the skill identifier. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Agents
Specialized agents for specific tasks. Defined in `agents/<name>.md`. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Rules
Behavioral rules installed to `.claude/rules/` that enforce conventions across all agents.

### Scripts
Shell scripts for deterministic operations (e.g., state transitions). Referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/` in hooks and skills.

### Hooks
Pre/post tool-use hooks declared in `plugin.json` under the `hooks` key. Hook commands use `${CLAUDE_PLUGIN_ROOT}` to reference the plugin directory.

## Current Plugins

- **roles** (v1.0.0) - Selective role loading for agents
- **workflows** (v1.1.0) - Plan lifecycle, beads decomposition, and execution orchestration
- **chronicler** (v1.0.0) - Context persistence using beads and diary generation
