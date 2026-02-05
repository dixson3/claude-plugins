# Hello World Plugin

A placeholder plugin demonstrating all Claude plugin components for the Yoshiko Studios Claude Marketplace.

## Overview

This plugin serves as a reference implementation showing how to create Claude plugins with:
- **Commands** - Slash commands users can invoke directly
- **Skills** - Automatic behaviors Claude can use contextually
- **Agents** - Specialized agents for specific tasks

## Installation

### From Marketplace

```bash
claude --plugin-dir /path/to/yoshiko-studios-marketplace
```

### Standalone

```bash
claude --plugin-dir /path/to/hello-world
```

## Usage

### Commands

#### `/hello-world:greet [name]`

A friendly greeting command that welcomes users.

```
/hello-world:greet Alice
```

Output: A personalized welcome message for Alice.

### Skills

#### `hello`

Automatically activates when users greet Claude or ask for marketplace introductions. No manual invocation needed.

### Agents

#### `greeter`

A friendly agent that can introduce users to the marketplace and guide them to relevant plugins.

## File Structure

```
hello-world/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/
│   └── greet.md          # Greet command definition
├── skills/
│   └── hello/
│       └── SKILL.md      # Hello skill definition
├── agents/
│   └── greeter.md        # Greeter agent definition
└── README.md             # This file
```

## Author

- **Name**: James Dixson
- **Email**: dixson3@gmail.com
- **Organization**: Yoshiko Studios LLC
- **GitHub**: [dixson3](https://github.com/dixson3)

## License

MIT License - See [LICENSE](../../LICENSE) for details.
