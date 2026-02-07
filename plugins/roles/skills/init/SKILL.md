---
name: roles:init
description: Initialize the roles plugin - installs roles directory and apply script
arguments: []
---

# Roles Init Skill

Initialize the roles system for selective role loading.

## Instructions

Set up all components needed for roles to function.

## Behavior

When invoked with `/roles:init`:

### Step 1: Create Roles Directory

```bash
mkdir -p .claude/roles
```

### Step 2: Install Roles Script

Copy `roles-apply.sh` from the plugin's `scripts/` directory to `.claude/roles/`.

```bash
cp plugins/roles/scripts/roles-apply.sh .claude/roles/roles-apply.sh
```

### Step 3: Make Script Executable

```bash
chmod +x .claude/roles/roles-apply.sh
```

### Step 4: Verify Installation

```bash
test -d .claude/roles && echo "roles directory: OK"
test -x .claude/roles/roles-apply.sh && echo "roles-apply.sh: OK"
```

## Expected Output

```
Initializing roles plugin...

[1/4] Creating .claude/roles/ directory...
      Directory created.

[2/4] Installing roles-apply.sh script...
      Script installed to .claude/roles/roles-apply.sh

[3/4] Making script executable...
      roles-apply.sh is executable.

[4/4] Verifying installation...
      roles directory: OK
      roles-apply.sh: OK

Roles plugin initialized!

Available commands:
  /roles:apply     Load roles for current agent
  /roles:assign    Add agents to role
  /roles:unassign  Remove agents from role
  /roles:list      Show all roles and assignments
```

## Post-Initialization

After initialization:
- Use `/roles:assign <role> --to <agent>` to assign roles to agents
- Use `/roles:apply` at session start to load assigned roles
- Role files are stored in `.claude/roles/` as markdown with frontmatter
