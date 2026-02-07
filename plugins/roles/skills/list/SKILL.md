---
name: roles:list
description: Show all roles and their agent assignments
arguments: []
---

# Roles List Skill

Display all available roles and which agents they are assigned to.

## Instructions

1. Scan the `.claude/roles/` directory for role files (*.md)
2. Parse the `applies-to` list from each role's frontmatter
3. Display the roles and their assignments in a readable format

## Behavior

When invoked with `/roles:list`:

1. **Check directory**: Verify `.claude/roles/` exists
2. **Scan for roles**: Find all `.md` files (excluding `roles-apply.sh`)
3. **Parse frontmatter**: Extract `name` and `applies-to` from each role
4. **Display output**: Format and show the role assignments

## Output Format

```
Available Roles:
----------------
watch-for-chronicle-worthiness: primary, agent1, chronicler_recall
security-conscious: primary
code-reviewer: (no agents assigned)
```

## Usage Examples

```bash
# List all roles and assignments
/roles:list
```

## Implementation Notes

- Only `.md` files in `.claude/roles/` are considered roles
- Roles without an `applies-to` field show "(no agents assigned)"
- The script `roles-apply.sh` is not listed as a role
- If no roles exist, display "No roles found in .claude/roles/"
