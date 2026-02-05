---
name: assign
description: Add agents to a role's applies-to list
arguments:
  - name: role
    description: Name of the role file (without .md extension)
    required: true
  - name: to
    description: Comma-separated list of agent names to assign (use --to flag)
    required: true
---

# Roles Assign Skill

Add one or more agents to a role's `applies-to` list.

## Instructions

1. Parse the role name and agent list from arguments
2. Locate the role file at `.claude/roles/<role>.md`
3. Update the YAML frontmatter to add agents to the `applies-to` list
4. Report success or failure

## Behavior

When invoked with `/roles:assign <role> --to <agents>`:

1. **Validate inputs**: Check role file exists and agents are specified
2. **Parse frontmatter**: Read the YAML frontmatter from the role file
3. **Add agents**: Add each agent to the `applies-to` list (skip duplicates)
4. **Write file**: Update the role file with the new frontmatter
5. **Confirm**: Output the updated applies-to list

## Usage Examples

```bash
# Assign a single agent
/roles:assign watch-for-chronicle-worthiness --to primary

# Assign multiple agents
/roles:assign watch-for-chronicle-worthiness --to primary,agent1,agent2

# Assign to all common agents
/roles:assign security-conscious --to primary,chronicler_recall,chronicler_diary
```

## Implementation Notes

- The role file must already exist in `.claude/roles/`
- Agents already in the list are silently skipped
- If `applies-to` doesn't exist in frontmatter, it will be created
- Use `/roles:list` to verify assignments afterward
