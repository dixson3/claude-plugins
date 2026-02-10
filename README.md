# Yoshiko Studios Claude Marketplace

A plugin marketplace for Claude Code. The plugins here automate the organizational discipline that keeps software maintainable — structured plans, captured rationale, and archived research — so knowledge survives beyond the session that produced it.

## Quick Start

```bash
# Load the marketplace
claude --plugin-dir /path/to/yoshiko-studios-marketplace

# Or from the repo root
claude --plugin-dir .
```

On first session start, the preflight system automatically installs rules and creates artifact directories. Run `/yf:setup` to configure capabilities.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [yf](plugins/yf/) | Yoshiko Flow — plan lifecycle, context persistence, and research/decision archiving | 2.10.0 |

## Plugin Overview

### yf (Yoshiko Flow)

Yoshiko Flow freezes the context that makes software maintainable. It breaks plans into tracked task graphs, captures observations as diary entries that trace how and why changes were made, and preserves research and decisions as permanent documentation.

**Plan Lifecycle** — Converts plans into a dependency graph of tracked tasks with automatic decomposition, scheduling, and dispatch.

| Skill | Description |
|-------|-------------|
| `/yf:plan_engage` | State machine for all lifecycle transitions |
| `/yf:plan_create_beads` | Convert plan docs to beads hierarchy |
| `/yf:plan_intake` | Intake checklist for plans entering outside the auto-chain |
| `/yf:plan_execute` | Orchestrated task dispatch with dependency ordering |
| `/yf:plan_pump` | Pull ready beads into parallel agent dispatch |
| `/yf:plan_breakdown` | Recursive decomposition of non-trivial tasks |
| `/yf:plan_select_agent` | Auto-discover agents and match to tasks |
| `/yf:plan_dismiss_gate` | Escape hatch to abandon plan gate |

**Chronicler (Context Persistence)** — Captures observations and context as work progresses, then composes diary entries that trace how and why changes were made.

| Skill | Description |
|-------|-------------|
| `/yf:chronicle_capture` | Capture context as a chronicle bead |
| `/yf:chronicle_recall` | Restore context from open chronicles |
| `/yf:chronicle_diary` | Generate diary entries from chronicles |
| `/yf:chronicle_disable` | Close chronicles without diary generation |

**Archivist (Research & Decision Records)** — Flags research findings and design decisions during work, then processes them into permanent indexed documentation for PRDs and ERDs.

| Skill | Description |
|-------|-------------|
| `/yf:archive_capture` | Capture research or decisions as archive beads |
| `/yf:archive_process` | Process archive beads into permanent docs |
| `/yf:archive_disable` | Close archive beads without generating docs |
| `/yf:archive_suggest` | Scan git history for archive candidates |

**Configuration**

| Skill | Description |
|-------|-------------|
| `/yf:setup` | Configure Yoshiko Flow for a project |

## Plugin Structure

Each plugin in this marketplace follows a standard structure:

```
plugin-name/
├── .claude-plugin/
│   ├── plugin.json       # Plugin manifest (required)
│   └── preflight.json    # Artifact declarations (optional)
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

## Creating a New Plugin

1. Create a new directory under `plugins/`
2. Add a `.claude-plugin/plugin.json` manifest
3. Add your skills, agents, rules, scripts, and/or hooks
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Add documentation in a README.md

See the [yf](plugins/yf/) plugin for a full-featured example, and [DEVELOPERS.md](plugins/yf/DEVELOPERS.md) for the developer guide.

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
├── tests/
│   ├── harness/            # Go test harness source
│   ├── scenarios/          # YAML test scenarios (unit-*.yaml)
│   └── run-tests.sh        # Test runner script
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
