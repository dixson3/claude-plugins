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
| [hello-world](plugins/hello-world/) | Placeholder plugin demonstrating all plugin components | 1.0.0 |

## Plugin Structure

Each plugin in this marketplace follows a standard structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest (required)
├── commands/             # Slash commands
│   └── *.md
├── skills/               # Automatic skills
│   └── skill-name/
│       └── SKILL.md
├── agents/               # Specialized agents
│   └── *.md
└── README.md             # Plugin documentation
```

## Quick Start

### Using the Greet Command

```
/hello-world:greet Your Name
```

### Testing Locally

```bash
# Load the marketplace
claude --plugin-dir /Users/james/workspace/spikes/marketplace

# Try the greet command
/hello-world:greet Test User
```

## Creating a New Plugin

1. Create a new directory under `plugins/`
2. Add a `.claude-plugin/plugin.json` manifest
3. Add your commands, skills, and/or agents
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Add documentation in a README.md

See the [hello-world](plugins/hello-world/) plugin for a complete example.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
├── plugins/
│   └── hello-world/        # Example plugin
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
