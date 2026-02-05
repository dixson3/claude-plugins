# Plan 02 - Part 1: Roles Plugin

**Status:** Completed
**Parent:** plan-02.md

## Overview

Create the `roles` plugin providing infrastructure for selective role loading per-agent.

## Directory Structure

```
plugins/roles/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── apply/SKILL.md           # /roles:apply <agent>
│   ├── assign/SKILL.md          # /roles:assign <role> --to <agents>
│   ├── unassign/SKILL.md        # /roles:unassign <role> --from <agents>
│   └── list/SKILL.md            # /roles:list
├── scripts/
│   └── roles-apply.sh           # Filter script (installed to .claude/roles/)
└── README.md
```

## Files to Create

### 1. `plugins/roles/.claude-plugin/plugin.json`

```json
{
  "name": "roles",
  "version": "1.0.0",
  "description": "Selective role loading for agents based on frontmatter applies-to lists",
  "author": {
    "name": "James Dixson",
    "email": "dixson3@gmail.com",
    "organization": "Yoshiko Studios LLC",
    "github": "dixson3"
  },
  "license": "MIT",
  "skills": [
    "skills/apply/SKILL.md",
    "skills/assign/SKILL.md",
    "skills/unassign/SKILL.md",
    "skills/list/SKILL.md"
  ],
  "installs": {
    "scripts": ["scripts/roles-apply.sh"]
  }
}
```

### 2. `plugins/roles/scripts/roles-apply.sh`

```bash
#!/bin/bash
# .claude/roles/roles-apply.sh
# Usage: roles-apply.sh <agent-name>
# Returns concatenated content of all roles that apply to the agent

AGENT_NAME="${1:-primary}"
ROLES_DIR="$(dirname "$0")"

for role_file in "$ROLES_DIR"/*.md; do
  [ -f "$role_file" ] || continue

  # Extract applies-to list from frontmatter
  if grep -q "applies-to:" "$role_file"; then
    # Check if agent is in the applies-to list
    if sed -n '/^---$/,/^---$/p' "$role_file" | grep -qE "^\s*-\s*${AGENT_NAME}\s*$"; then
      echo "---"
      echo "# Active Role: $(basename "$role_file" .md)"
      echo ""
      # Output content after frontmatter
      sed -n '/^---$/,/^---$/d; p' "$role_file"
      echo ""
    fi
  fi
done
```

### 3. `plugins/roles/skills/apply/SKILL.md`

```markdown
---
name: apply
description: Load active roles for the current agent
arguments:
  - name: agent
    description: Agent identifier (default: "primary" for interactive session)
    required: false
---

# Roles Apply Skill

Run the roles filter script to load applicable roles for this agent.

## Behavior

1. Determine agent name (from argument or default to "primary")
2. Execute: `.claude/roles/roles-apply.sh <agent-name>`
3. Output the concatenated role content

The output becomes part of the agent's active context.

## Usage

```
/roles:apply              # Load roles for primary session
/roles:apply agent1       # Load roles for agent1
```
```

### 4. `plugins/roles/skills/assign/SKILL.md`

```markdown
---
name: assign
description: Add agents to a role's applies-to list
arguments:
  - name: role
    description: The role name (without .md extension)
    required: true
  - name: to
    description: Comma-separated list of agent names to add
    required: true
---

# Roles Assign Skill

Add agents to a role's applies-to list in its frontmatter.

## Behavior

1. Locate role file at `.claude/roles/<role>.md`
2. Parse the YAML frontmatter
3. Add each agent to the `applies-to` list (if not already present)
4. Write updated frontmatter back to file

## Usage

```
/roles:assign watch-for-chronicle-worthiness --to primary,agent1
```

## Implementation

Read the role file, parse frontmatter, update applies-to array, write back.
If role file doesn't exist, report error.
```

### 5. `plugins/roles/skills/unassign/SKILL.md`

```markdown
---
name: unassign
description: Remove agents from a role's applies-to list
arguments:
  - name: role
    description: The role name (without .md extension)
    required: true
  - name: from
    description: Comma-separated list of agent names to remove
    required: true
---

# Roles Unassign Skill

Remove agents from a role's applies-to list in its frontmatter.

## Behavior

1. Locate role file at `.claude/roles/<role>.md`
2. Parse the YAML frontmatter
3. Remove each agent from the `applies-to` list
4. Write updated frontmatter back to file

## Usage

```
/roles:unassign watch-for-chronicle-worthiness --from agent2
```
```

### 6. `plugins/roles/skills/list/SKILL.md`

```markdown
---
name: list
description: List all roles and their agent assignments
---

# Roles List Skill

Display all roles in `.claude/roles/` and their applies-to assignments.

## Behavior

1. Scan `.claude/roles/*.md` files
2. For each role, extract the `applies-to` list from frontmatter
3. Display in format: `role-name: agent1, agent2, agent3`

## Usage

```
/roles:list
```

## Example Output

```
watch-for-chronicle-worthiness: primary, agent1, agent2
security-conscious: primary
code-reviewer: primary, reviewer-agent
```
```

### 7. `plugins/roles/README.md`

Document the roles plugin with:
- Overview of the roles system
- Role file format (frontmatter with applies-to)
- Available skills
- Installation instructions
- Usage examples

## Update Marketplace

Add to `.claude-plugin/marketplace.json` plugins array:

```json
{
  "name": "roles",
  "path": "plugins/roles",
  "description": "Selective role loading for agents",
  "version": "1.0.0"
}
```

## Verification

```bash
# Verify plugin structure
ls -la plugins/roles/

# Test /roles:list (should show no roles initially)
/roles:list

# Create a test role manually, then test assign/apply/unassign
```

## Completion Criteria

- [x] Directory structure created
- [x] plugin.json manifest written
- [x] roles-apply.sh script written and executable
- [x] All 4 skills written (apply, assign, unassign, list)
- [x] README.md written
- [x] marketplace.json updated
