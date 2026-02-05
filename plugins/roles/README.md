# Roles Plugin

Selective role loading for Claude agents. Roles are like rules, but can be assigned to specific agents rather than loading globally.

## Overview

The roles system allows you to:
- Define roles that can be selectively applied to agents
- Assign roles to specific agents (primary session, subagents, etc.)
- Load only applicable roles at session/agent start

## Installation

The roles plugin installs:
- `.claude/roles/roles-apply.sh` - Filter script for loading roles

## Usage

### List Available Roles

```bash
/roles:list
```

Shows all roles in `.claude/roles/` and their agent assignments.

### Apply Roles

```bash
# For primary session
/roles:apply

# For a specific agent
/roles:apply agent1
```

Outputs the content of all roles assigned to the specified agent.

### Assign Roles

```bash
# Assign to one agent
/roles:assign my-role --to primary

# Assign to multiple agents
/roles:assign my-role --to primary,agent1,agent2
```

### Unassign Roles

```bash
# Remove from one agent
/roles:unassign my-role --from agent2

# Remove from multiple agents
/roles:unassign my-role --from agent1,agent2
```

## Role File Format

Roles are markdown files in `.claude/roles/` with YAML frontmatter:

```markdown
---
name: my-role
applies-to:
  - primary
  - agent1
  - agent2
---

# Role: My Role

Role instructions here...
```

## How It Works

1. Role files live in `.claude/roles/`
2. Each role has an `applies-to` list in its frontmatter
3. When `/roles:apply <agent>` runs, only roles where `<agent>` is in `applies-to` are loaded
4. This allows selective role activation per-agent

## Differences from Rules

| Feature | Rules (`.claude/rules/`) | Roles (`.claude/roles/`) |
|---------|--------------------------|--------------------------|
| Loading | Always global | Per-agent selective |
| Control | None | `applies-to` frontmatter |
| Use case | Universal behaviors | Agent-specific behaviors |

## Auto-Loading Roles

Add to your `CLAUDE.md` or agent definitions:

```markdown
## Session Initialization

At session start, run `/roles:apply` to load applicable roles.
```

Or in agent frontmatter:

```yaml
---
name: agent1
on-start: /roles:apply agent1
---
```

## License

MIT License - Yoshiko Studios LLC
