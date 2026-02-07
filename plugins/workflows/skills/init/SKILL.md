---
name: workflows:init
description: Initialize the workflows plugin - installs rules, scripts, and hooks
arguments: []
---

# Workflows Init Skill

Initialize the full workflows plugin: beads, rules, scripts, and hooks.

## Instructions

Set up all components needed for the plan lifecycle and execution orchestration.

## Behavior

When invoked with `/workflows:init`:

### Step 1: Initialize Beads

Invoke beads initialization (also installs `.claude/rules/BEADS.md`):
```
/workflows:init_beads
```

### Step 2: Create Rules Directory

```bash
mkdir -p .claude/rules
```

### Step 3: Install Rules

Copy the following rules from the plugin to `.claude/rules/`:

1. **engage-the-plan.md** — Plan lifecycle trigger phrases
2. **plan-to-beads.md** — Beads-before-implementation enforcement
3. **breakdown-the-work.md** — Task decomposition before coding

Source: `plugins/workflows/rules/`
Target: `.claude/rules/`

```bash
cp plugins/workflows/rules/engage-the-plan.md .claude/rules/
cp plugins/workflows/rules/plan-to-beads.md .claude/rules/
cp plugins/workflows/rules/breakdown-the-work.md .claude/rules/
```

### Step 4: Verify Script is Executable

```bash
chmod +x plugins/workflows/scripts/plan-exec.sh
chmod +x plugins/workflows/hooks/plan-exec-guard.sh
```

### Step 5: Install Hook Configuration

Add the plan-exec-guard hook to `.claude/settings.local.json` under `hooks.PreToolUse`.

Read the existing file (if any), merge in the new hook entries, and write back:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(bd update*--status*in_progress*)",
        "command": "plugins/workflows/hooks/plan-exec-guard.sh"
      },
      {
        "matcher": "Bash(bd update*--claim*)",
        "command": "plugins/workflows/hooks/plan-exec-guard.sh"
      },
      {
        "matcher": "Bash(bd close*)",
        "command": "plugins/workflows/hooks/plan-exec-guard.sh"
      }
    ]
  }
}
```

**Important:** Merge with existing hooks — do not overwrite other hook configurations.

### Step 6: Verify Installation

Check that all components are in place:

```bash
# Beads initialized + BEADS.md rule
test -d .beads && echo "beads: OK"
test -f .claude/rules/BEADS.md && echo "BEADS.md rule: OK"

# Rules installed
ls .claude/rules/engage-the-plan.md
ls .claude/rules/plan-to-beads.md
ls .claude/rules/breakdown-the-work.md

# Scripts executable
test -x plugins/workflows/scripts/plan-exec.sh && echo "plan-exec.sh: OK"
test -x plugins/workflows/hooks/plan-exec-guard.sh && echo "plan-exec-guard.sh: OK"
```

## Expected Output

```
Initializing workflows plugin...

[1/6] Initializing beads...
      Beads initialized successfully.
      Installed .claude/rules/BEADS.md

[2/6] Creating .claude/rules/ directory...
      Directory exists.

[3/6] Installing rules...
      engage-the-plan.md → .claude/rules/
      plan-to-beads.md → .claude/rules/
      breakdown-the-work.md → .claude/rules/

[4/6] Verifying scripts are executable...
      plan-exec.sh: OK
      plan-exec-guard.sh: OK

[5/6] Installing hook configuration...
      Added 3 PreToolUse hooks to .claude/settings.local.json

[6/6] Verifying installation...
      All components installed successfully.

Workflows plugin initialized!

Available commands:
  /workflows:engage_plan    Plan lifecycle management
  /workflows:plan_to_beads  Convert plan to beads hierarchy
  /workflows:execute_plan   Orchestrate plan execution
  /workflows:breakdown_task Decompose non-trivial tasks
  /workflows:select_agent   Match tasks to agents
```

## Post-Initialization

After initialization:
- Say "engage the plan" during planning to save plans
- Say "the plan is ready" to create beads from a plan
- Say "execute the plan" to start orchestrated execution
- The breakdown-the-work rule will fire automatically when claiming tasks
