---
name: chronicler:init
description: Initialize chronicler - sets up beads, roles, hooks, and diary directory
arguments: []
---

# Chronicler Init Skill

Initialize the chronicler system for context persistence.

## Instructions

Set up all components needed for chronicler to function:
1. Initialize beads via `/workflows:init_beads`
2. Initialize roles via `/roles:init`
3. Install the `watch-for-chronicle-worthiness` role to `.claude/roles/`
4. Assign the role to all agents by default
5. Create `docs/diary/` directory
6. Install rules to `.claude/rules/`

## Behavior

When invoked with `/chronicler:init`:

### Step 1: Initialize Beads
```bash
# Invoke the workflows plugin
/workflows:init_beads
```

### Step 2: Initialize Roles
```bash
# Invoke the roles plugin
/roles:init
```

### Step 3: Install Role File
Copy `roles/watch-for-chronicle-worthiness.md` from the plugin to `.claude/roles/`.

### Step 4: Assign Role to Agents
```bash
/roles:assign watch-for-chronicle-worthiness --to primary
```

### Step 5: Create Diary Directory
```bash
mkdir -p docs/diary
```

### Step 6: Install Rules

Copy rules from the plugin to `.claude/rules/`:

```bash
mkdir -p .claude/rules
cp plugins/chronicler/rules/plan-transition-chronicle.md .claude/rules/
```

## Expected Output

```
Initializing chronicler...

[1/6] Initializing beads...
      Beads initialized successfully.

[2/6] Initializing roles...
      Roles plugin initialized.

[3/6] Installing watch-for-chronicle-worthiness role...
      Role installed to .claude/roles/watch-for-chronicle-worthiness.md

[4/6] Assigning role to primary agent...
      Role assigned to: primary

[5/6] Creating docs/diary/ directory...
      Directory created.

[6/6] Installing rules...
      plan-transition-chronicle.md → .claude/rules/

Chronicler initialized successfully!

Next steps:
- Run /roles:apply at session start to load roles
- Use /chronicler:capture to save context
- Use /chronicler:recall to restore context
- Use /chronicler:diary before pushing to generate diary entries
```

## Post-Initialization

After initialization:
- The `watch-for-chronicle-worthiness` role will remind you to capture context
- Use `/chronicler:capture` to save important context to beads
- Use `/chronicler:recall` at session start to restore context
- Use `/chronicler:diary` to consolidate captures into diary entries
