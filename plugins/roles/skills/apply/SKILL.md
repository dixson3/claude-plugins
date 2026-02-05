---
name: apply
description: Load active roles for the current agent
arguments:
  - name: agent
    description: Agent identifier (default "primary" for interactive session)
    required: false
---

# Roles Apply Skill

Load and output all roles that apply to the specified agent.

## Instructions

1. Determine the agent name from the argument (default to "primary" for interactive sessions)
2. Execute the roles filter script: `.claude/roles/roles-apply.sh <agent-name>`
3. Output the concatenated role content

## Behavior

When invoked:

1. **Check for roles directory**: Verify `.claude/roles/` exists
2. **Run the filter script**: Execute `.claude/roles/roles-apply.sh` with the agent name
3. **Output role content**: Display all matching roles

The output becomes part of the agent's active context for the session.

## Usage Examples

```bash
# Load roles for primary session
/roles:apply

# Load roles for a specific agent
/roles:apply agent1

# Load roles in agent definition
/roles:apply chronicler_recall
```

## Expected Output

The script will output the content of all roles whose `applies-to` frontmatter includes the specified agent name, separated by markers indicating which role is active.

If no roles apply to the agent, no output is produced.
