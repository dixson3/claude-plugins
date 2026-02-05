---
name: init_beads
description: Initialize beads issue tracking in the current project
arguments: []
---

# Initialize Beads Skill

Set up beads-cli for issue tracking in the current project.

## Instructions

Initialize beads in the project to enable issue/bead tracking.

## Behavior

When invoked with `/workflows:init_beads`:

1. **Check beads-cli**: Verify beads-cli is installed (`bd --version`)
2. **Check existing setup**: Look for existing `.beads/` directory
3. **Initialize beads**: Run `bd init` if not already initialized
4. **Verify setup**: Confirm initialization was successful

## Prerequisites

- **beads-cli** >= 0.44.0 must be installed
- Project must be a git repository

## Usage

```bash
/workflows:init_beads
```

## Expected Output

```
Initializing beads in project...
beads-cli version: 0.44.0
Created .beads/ directory
Beads initialized successfully!
```

If already initialized:
```
Beads already initialized in this project.
.beads/ directory exists.
```

## Error Handling

- If beads-cli is not installed, provide installation instructions
- If not in a git repository, explain the requirement
- If initialization fails, show the error and suggest remediation

## Post-Initialization

After beads is initialized, you can use:
- `bd create` - Create a new issue/bead
- `bd list` - List issues
- `bd close` - Close an issue
- Labels like `ys:chronicle` for categorization
