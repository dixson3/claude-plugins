# Yoshiko Studios Claude Marketplace

A marketplace for Claude plugins, providing a collection of commands, skills, and agents to extend Claude's capabilities.

## Installation

To use plugins from this marketplace, point Claude to the marketplace directory:

```bash
claude --plugin-dir /path/to/yoshiko-studios-marketplace
```

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [roles](plugins/roles/) | Selective role loading for agents | 1.0.0 |
| [workflows](plugins/workflows/) | Plan lifecycle, beads decomposition, and execution orchestration | 1.1.0 |
| [chronicler](plugins/chronicler/) | Context persistence using beads and diary generation | 1.0.0 |

## Plugins Overview

### roles

Infrastructure plugin for selective role loading. Agents receive only the roles assigned to them.

- `/roles:apply` — Load active roles for current agent
- `/roles:assign` / `/roles:unassign` — Manage role assignments
- `/roles:list` — List all roles and assignments

### workflows

Plan lifecycle management with three enforcement layers: beads gates, scripts, and hooks.

- `/workflows:engage_plan` — State machine: Draft → Ready → Executing → Paused → Completed
- `/workflows:plan_to_beads` — Convert plan docs to beads hierarchy (epics, tasks, dependencies)
- `/workflows:execute_plan` — Orchestrated task dispatch with parallel agent routing
- `/workflows:breakdown_task` — Recursive decomposition of non-trivial tasks
- `/workflows:select_agent` — Auto-discover agents and match to tasks
- `/workflows:init` — Install rules, scripts, and hooks

### chronicler

Context persistence across sessions using beads and diary generation.

- `/chronicler:capture` — Capture context as a chronicle bead
- `/chronicler:recall` — Restore context from open chronicles
- `/chronicler:diary` — Generate diary entries from chronicles
- `/chronicler:init` — Initialize chronicler system

## Plugin Structure

Each plugin in this marketplace follows a standard structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest (required)
├── skills/               # Automatic skills
│   └── skill-name/
│       └── SKILL.md
├── agents/               # Specialized agents
│   └── *.md
├── rules/                # Behavioral rules
│   └── *.md
├── scripts/              # Shell scripts
│   └── *.sh
├── hooks/                # Pre/post tool-use hooks
│   └── *.sh
└── README.md             # Plugin documentation
```

## Quick Start

```bash
# Load the marketplace
claude --plugin-dir /Users/james/workspace/spikes/marketplace

# Initialize workflows (beads, rules, hooks)
/workflows:init

# Initialize chronicler (beads, roles, diary directory)
/chronicler:init
```

## Creating a New Plugin

1. Create a new directory under `plugins/`
2. Add a `.claude-plugin/plugin.json` manifest
3. Add your skills, agents, rules, scripts, and/or hooks
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Add documentation in a README.md

See the [workflows](plugins/workflows/) plugin for a full-featured example.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
├── plugins/
│   ├── roles/              # Role management
│   ├── workflows/          # Plan lifecycle & execution
│   └── chronicler/         # Context persistence
├── docs/
│   └── plans/              # Plan documentation
├── CLAUDE.md               # Claude Code guidance
├── README.md               # This file
├── LICENSE                 # MIT License
└── CHANGELOG.md            # Version history
```

## Author

- **Name**: James Dixson
- **Email**: dixson3@gmail.com
- **Organization**: Yoshiko Studios LLC
- **GitHub**: [dixson3](https://github.com/dixson3)

## License

MIT License - See [LICENSE](LICENSE) for details.
