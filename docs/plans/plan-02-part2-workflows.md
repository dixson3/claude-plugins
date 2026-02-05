# Plan 02 - Part 2: Workflows Plugin

**Status:** Completed
**Parent:** plan-02.md

## Overview

Create the `workflows` plugin providing beads initialization and workflow utilities.

## Directory Structure

```
plugins/workflows/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── init_beads/SKILL.md      # /workflows:init_beads
└── README.md
```

## Files to Create

### 1. `plugins/workflows/.claude-plugin/plugin.json`

```json
{
  "name": "workflows",
  "version": "1.0.0",
  "description": "Workflow utilities including beads initialization",
  "author": {
    "name": "James Dixson",
    "email": "dixson3@gmail.com",
    "organization": "Yoshiko Studios LLC",
    "github": "dixson3"
  },
  "license": "MIT",
  "dependencies": {
    "cli": { "beads-cli": ">=0.44.0" }
  },
  "skills": [
    "skills/init_beads/SKILL.md"
  ]
}
```

### 2. `plugins/workflows/skills/init_beads/SKILL.md`

```markdown
---
name: init_beads
description: Initialize beads issue tracking in the current project
---

# Workflows Init Beads Skill

Initialize the beads issue tracking system for the current project.

## Prerequisites

- `beads-cli` >= 0.44.0 must be installed (`pip install beads-cli` or `uv pip install beads-cli`)

## Behavior

### Step 1: Check if Already Initialized

Check if `.beads/` directory exists or if `bd list` works.
If already initialized, report status and exit.

### Step 2: Verify beads-cli Installation

Run `bd --version` to check if beads-cli is installed.
If not installed, provide installation instructions and abort.

### Step 3: Initialize Beads

Run:
```bash
bd --no-daemon init --prefix ys-
```

The `ys-` prefix is for Yoshiko Studios namespace.

### Step 4: Verify Initialization

Run `bd list` to confirm beads is working.

### Step 5: Report Success

```
Beads initialized successfully!

- Directory: .beads/
- Prefix: ys-
- Version: <version>

You can now create issues with: bd create --title "..."
```

## Usage

```
/workflows:init_beads
```

## Error Handling

- If beads-cli not installed: Provide installation command
- If already initialized: Report current status
- If init fails: Show error message and suggest troubleshooting
```

### 3. `plugins/workflows/README.md`

```markdown
# Workflows Plugin

Workflow utilities for the Yoshiko Studios Claude Marketplace.

## Skills

### /workflows:init_beads

Initialize the beads issue tracking system in your project.

**Prerequisites:**
- beads-cli >= 0.44.0

**Installation:**
```bash
pip install beads-cli
# or
uv pip install beads-cli
```

**Usage:**
```
/workflows:init_beads
```

This will:
1. Check if beads is already initialized
2. Verify beads-cli is installed
3. Initialize beads with `ys-` prefix
4. Confirm successful setup

## Author

- **Name**: James Dixson
- **Email**: dixson3@gmail.com
- **Organization**: Yoshiko Studios LLC
- **GitHub**: [dixson3](https://github.com/dixson3)

## License

MIT License
```

## Update Marketplace

Add to `.claude-plugin/marketplace.json` plugins array:

```json
{
  "name": "workflows",
  "path": "plugins/workflows",
  "description": "Workflow utilities including beads initialization",
  "version": "1.0.0"
}
```

## Verification

```bash
# Verify plugin structure
ls -la plugins/workflows/

# Test init_beads
/workflows:init_beads

# Verify beads works
bd --version
bd list
```

## Completion Criteria

- [x] Directory structure created
- [x] plugin.json manifest written
- [x] init_beads skill written
- [x] README.md written
- [x] marketplace.json updated
