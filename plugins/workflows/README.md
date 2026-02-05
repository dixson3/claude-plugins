# Workflows Plugin

Workflow utilities for Claude projects.

## Overview

The workflows plugin provides common workflow initialization and utilities that other plugins depend on.

## Skills

### `/workflows:init_beads`

Initialize beads-cli issue tracking in the current project.

```bash
/workflows:init_beads
```

This skill:
1. Checks that beads-cli is installed
2. Initializes beads in the project if not already done
3. Verifies the setup is complete

## Dependencies

- **beads-cli** >= 0.44.0 - Git-backed issue tracker
  - Install: See beads-cli documentation

## Used By

- **chronicler** - Uses beads for context persistence

## License

MIT License - Yoshiko Studios LLC
