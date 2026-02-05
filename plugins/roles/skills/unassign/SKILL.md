---
name: unassign
description: Remove agents from a role's applies-to list
arguments:
  - name: role
    description: Name of the role file (without .md extension)
    required: true
  - name: from
    description: Comma-separated list of agent names to remove (use --from flag)
    required: true
---

# Roles Unassign Skill

Remove one or more agents from a role's `applies-to` list.

## Instructions

1. Parse the role name and agent list from arguments
2. Locate the role file at `.claude/roles/<role>.md`
3. Update the YAML frontmatter to remove agents from the `applies-to` list
4. Report success or failure

## Behavior

When invoked with `/roles:unassign <role> --from <agents>`:

1. **Validate inputs**: Check role file exists and agents are specified
2. **Parse frontmatter**: Read the YAML frontmatter from the role file
3. **Remove agents**: Remove each agent from the `applies-to` list
4. **Write file**: Update the role file with the new frontmatter
5. **Confirm**: Output the updated applies-to list

## Usage Examples

```bash
# Unassign a single agent
/roles:unassign watch-for-chronicle-worthiness --from agent2

# Unassign multiple agents
/roles:unassign watch-for-chronicle-worthiness --from agent1,agent2

# Remove all assignments (leaves applies-to empty)
/roles:unassign security-conscious --from primary,agent1
```

## Implementation Notes

- The role file must already exist in `.claude/roles/`
- Agents not in the list are silently skipped
- If all agents are removed, `applies-to` becomes an empty list
- Use `/roles:list` to verify assignments afterward
