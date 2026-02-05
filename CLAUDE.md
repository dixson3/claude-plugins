# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yoshiko Studios Claude Marketplace - A marketplace for Claude plugins, hosting a collection of commands, skills, and agents.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog with plugin registry
├── plugins/
│   └── <plugin-name>/      # Individual plugins
│       ├── .claude-plugin/
│       │   └── plugin.json # Plugin manifest
│       ├── commands/       # Slash commands (*.md)
│       ├── skills/         # Auto-invoked skills (*/SKILL.md)
│       ├── agents/         # Specialized agents (*.md)
│       └── README.md       # Plugin documentation
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
claude --plugin-dir /Users/james/workspace/spikes/marketplace/plugins/hello-world

# Test the greet command
/hello-world:greet Test User
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
     "commands": ["commands/command.md"],
     "skills": ["skills/skill-name/SKILL.md"],
     "agents": ["agents/agent.md"]
   }
   ```

3. **Add commands** (optional): `commands/<command>.md`
   - Frontmatter with `name`, `description`, `arguments`
   - Instructions for Claude to follow

4. **Add skills** (optional): `skills/<skill>/SKILL.md`
   - Frontmatter with `name`, `description`, `triggers`
   - Behavior guidelines for automatic invocation

5. **Add agents** (optional): `agents/<agent>.md`
   - Frontmatter with `name`, `description`
   - Role, personality, and interaction guidelines

6. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

7. **Document**: Add `README.md` to the plugin directory

## Plugin Components

### Commands
User-invocable slash commands (e.g., `/hello-world:greet`). Defined in markdown with frontmatter specifying name, description, and arguments.

### Skills
Automatic behaviors Claude can invoke contextually based on triggers. Defined in `SKILL.md` files with trigger keywords.

### Agents
Specialized agents for specific tasks. Defined in markdown with role, personality, and interaction guidelines.

## Current Plugins

- **hello-world** (v1.0.0) - Placeholder plugin demonstrating all components
