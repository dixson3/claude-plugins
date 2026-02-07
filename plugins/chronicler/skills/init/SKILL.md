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
2. Install the watch-for-chronicle-worthiness role to `.claude/roles/`
3. Install the roles-apply.sh script if not present
4. Assign the role to all agents by default
5. Create `docs/diary/` directory
6. Configure session start hook for auto-recall (optional)
7. Configure pre-push hook for diary generation

## Behavior

When invoked with `/chronicler:init`:

### Step 1: Initialize Beads
```bash
# Invoke the workflows plugin
/workflows:init_beads
```

### Step 2: Create Roles Directory
```bash
mkdir -p .claude/roles
```

### Step 3: Install Role File
Copy `roles/watch-for-chronicle-worthiness.md` from the plugin to `.claude/roles/`.

### Step 4: Install Roles Script
Copy `roles-apply.sh` from the roles plugin to `.claude/roles/` if not already present.

### Step 5: Assign Role to Agents
```bash
/roles:assign watch-for-chronicle-worthiness --to primary
```

### Step 6: Create Diary Directory
```bash
mkdir -p docs/diary
```

### Step 7: Configure Hooks (Manual Step)
Inform the user to add the pre-push hook to their `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git push:*)",
        "command": ".claude/hooks/pre-push-diary.sh"
      }
    ]
  }
}
```

## Expected Output

```
Initializing chronicler...

[1/6] Initializing beads...
      Beads initialized successfully.

[2/6] Creating .claude/roles/ directory...
      Directory created.

[3/6] Installing watch-for-chronicle-worthiness role...
      Role installed to .claude/roles/watch-for-chronicle-worthiness.md

[4/6] Installing roles-apply.sh script...
      Script installed to .claude/roles/roles-apply.sh

[5/6] Assigning role to primary agent...
      Role assigned to: primary

[6/6] Creating docs/diary/ directory...
      Directory created.

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
