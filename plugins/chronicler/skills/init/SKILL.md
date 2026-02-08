---
name: chronicler:init
description: Initialize chronicler - sets up beads, rules, hooks, and diary directory
arguments: []
---

# Chronicler Init Skill

Initialize the chronicler system for context persistence.

## Instructions

Set up all components needed for chronicler to function:
1. Initialize beads via `/workflows:init_beads`
2. Create `docs/diary/` directory
3. Install rules to `.claude/rules/`
4. Verify installation

## Behavior

When invoked with `/chronicler:init`:

### Step 1: Initialize Beads
```bash
# Invoke the workflows plugin
/workflows:init_beads
```

### Step 2: Create Diary Directory
```bash
mkdir -p docs/diary
```

### Step 3: Install Rules

Copy rules from the plugin to `.claude/rules/`:

```bash
mkdir -p .claude/rules
cp plugins/chronicler/rules/plan-transition-chronicle.md .claude/rules/
cp plugins/chronicler/rules/watch-for-chronicle-worthiness.md .claude/rules/
```

### Step 4: Verify Installation

Confirm all components are in place:
- `.claude/rules/watch-for-chronicle-worthiness.md` exists
- `.claude/rules/plan-transition-chronicle.md` exists
- `docs/diary/` directory exists

## Expected Output

```
Initializing chronicler...

[1/4] Initializing beads...
      Beads initialized successfully.

[2/4] Creating docs/diary/ directory...
      Directory created.

[3/4] Installing rules...
      watch-for-chronicle-worthiness.md → .claude/rules/
      plan-transition-chronicle.md → .claude/rules/

[4/4] Verifying installation...
      watch-for-chronicle-worthiness rule: OK
      plan-transition-chronicle rule: OK
      diary directory: OK

Chronicler initialized successfully!

Next steps:
- Use /chronicler:capture to save context
- Use /chronicler:recall to restore context
- Use /chronicler:diary before pushing to generate diary entries
```

## Post-Initialization

After initialization:
- The `watch-for-chronicle-worthiness` rule will remind you to capture context
- Use `/chronicler:capture` to save important context to beads
- Use `/chronicler:recall` at session start to restore context
- Use `/chronicler:diary` to consolidate captures into diary entries
