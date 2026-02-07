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

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`
   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": { "name": "James Dixson", "email": "dixson3@gmail.com" },
     "license": "MIT",
     "skills": ["skills/skill-name/SKILL.md"],
     "agents": ["agents/agent.md"]
   }
   ```

3. **Add skills** (optional): `skills/<skill>/SKILL.md`
   - Frontmatter with `name`, `description`, `arguments`
   - Behavior guidelines for automatic invocation

4. **Add agents** (optional): `agents/<agent>.md`
   - Frontmatter with `name`, `description`
   - Role, personality, and interaction guidelines

5. **Add rules** (optional): `rules/<rule>.md`
   - Behavioral enforcement installed to `.claude/rules/`

6. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

7. **Document**: Add `README.md` to the plugin directory

## Plugin Components

### Skills
Automatic behaviors Claude can invoke contextually based on triggers. Defined in `SKILL.md` files with trigger keywords.

### Agents
Specialized agents for specific tasks. Defined in markdown with role, personality, and interaction guidelines.

### Rules
Behavioral rules installed to `.claude/rules/` that enforce conventions across all agents.

### Scripts
Shell scripts for deterministic operations (e.g., state transitions).

### Hooks
Pre/post tool-use hooks that enforce constraints on tool operations.

## Current Plugins

- **roles** (v1.0.0) - Selective role loading for agents
- **workflows** (v1.1.0) - Plan lifecycle, beads decomposition, and execution orchestration
- **chronicler** (v1.0.0) - Context persistence using beads and diary generation
