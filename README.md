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
| [yf](plugins/yf/) | Yoshiko Flow — plan lifecycle, execution orchestration, context persistence, and diary generation | 2.0.0 |

## Plugin Overview

### yf (Yoshiko Flow)

Unified plan lifecycle management, execution orchestration, context persistence, and diary generation.

**Plan Lifecycle & Orchestration:**
- `/yf:engage_plan` — State machine: Draft → Ready → Executing → Paused → Completed
- `/yf:plan_to_beads` — Convert plan docs to beads hierarchy (epics, tasks, dependencies)
- `/yf:execute_plan` — Orchestrated task dispatch with parallel agent routing
- `/yf:breakdown_task` — Recursive decomposition of non-trivial tasks
- `/yf:select_agent` — Auto-discover agents and match to tasks
- `/yf:dismiss_gate` — Escape hatch to abandon plan gate

**Context Persistence & Diary:**
- `/yf:capture` — Capture context as a chronicle bead
- `/yf:recall` — Restore context from open chronicles
- `/yf:diary` — Generate diary entries from chronicles
- `/yf:disable` — Close chronicles without diary generation

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
```

The preflight system automatically installs rules, creates directories, and initializes beads on first session start.

## Creating a New Plugin

1. Create a new directory under `plugins/`
2. Add a `.claude-plugin/plugin.json` manifest
3. Add your skills, agents, rules, scripts, and/or hooks
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Add documentation in a README.md

See the [yf](plugins/yf/) plugin for a full-featured example.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
├── plugins/
│   └── yf/                 # Yoshiko Flow — unified plugin
├── docs/
│   ├── plans/              # Plan documentation
│   └── diary/              # Generated diary entries
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
