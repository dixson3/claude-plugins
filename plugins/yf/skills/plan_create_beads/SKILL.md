---
name: yf:plan_create_beads
description: Convert a plan document into a beads hierarchy with epics, tasks, gates, and dependencies
arguments:
  - name: plan_file
    description: "Path to plan file (default: most recent plan in docs/plans/)"
    required: false
  - name: dry_run
    description: "If true, show what would be created without creating"
    required: false
---

## Activation Guard

Before proceeding, check that yf is active:

```bash
ACTIVATION=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-activation-check.sh")
IS_ACTIVE=$(echo "$ACTIVATION" | jq -r '.active')
```

If `IS_ACTIVE` is not `true`, read the `reason` and `action` fields from `$ACTIVATION` and tell the user:

> Yoshiko Flow is not active: {reason}. {action}

Then stop. Do not execute the remaining steps.


# Plan to Beads Skill

Reads a plan document and creates a structured beads hierarchy with proper dependencies, labels, gates, and deferred state.

## When to Invoke

- Called by `/yf:engage_plan` during the Draft -> Ready transition
- Can be invoked directly: `/yf:plan_to_beads [plan_file]`

## Behavior

### Step 1: Locate Plan

If `plan_file` not specified, find the most recent plan:
```bash
ls -t docs/plans/plan-*.md | head -1
```

Extract the plan index from the filename (e.g., `plan-03.md` -> `03`).

### Step 2: Check Idempotency

Check for existing beads with this plan label:
```bash
bd list -l plan:<idx> --limit=1
```

If issues already exist for this plan, report and skip creation. Do not create duplicates.

### Step 3: Parse Plan Structure

Read the master plan file and any part files (`plan-<idx>-part*`).

**Mapping rules:**

| Plan Element | Beads Type | Key Fields |
|---|---|---|
| Master plan title | Epic | `--description`, `--design`, `--acceptance`, `--notes` |
| Part/phase heading | Epic (child of master) | `--parent`, `--description`, `--design`, `--acceptance` |
| File/step within a part | Task (child of part epic) | `--parent`, `--description`, `--notes`, `--priority` |

### Step 4: Create Root Epic

```bash
bd create --title="<Plan Title>" \
  --type=epic \
  --priority=1 \
  --description="<Overview section>" \
  --design="<Architectural decisions from plan>" \
  --acceptance="<Completion Criteria section>" \
  --notes="Source: docs/plans/plan-<idx>.md" \
  -l ys:plan,plan:<idx> \
  --silent
```

### Step 5: Create Part Epics

For each part file (`plan-<idx>-part<N>-<name>.md`):

```bash
bd create --title="Part <N>: <Part Title>" \
  --type=epic \
  --parent=<root-epic-id> \
  --description="<Part overview>" \
  --design="<Part design decisions>" \
  --acceptance="<Part completion criteria>" \
  --notes="Source: docs/plans/plan-<idx>-part<N>-<name>.md" \
  -l ys:plan,plan:<idx>,plan-part:<idx>-<N> \
  --silent
```

### Step 6: Create Tasks

For each actionable item within a part:

```bash
bd create --title="<Task description>" \
  --type=task \
  --parent=<part-epic-id> \
  --description="<What to do>" \
  --notes="<File refs, research, context>" \
  --priority=2 \
  -l ys:plan,plan:<idx>,plan-part:<idx>-<N> \
  --silent
```

**Context embedding:**
- `--description`: What to do, extracted from plan section
- `--design`: Architectural decisions, patterns to follow
- `--acceptance`: How to verify completion
- `--notes`: Source plan path, file references, related research

### Step 7: Wire Dependencies

1. **Cross-part dependencies**: Parse `**Dependencies:**` sections in part files
   ```bash
   bd dep add <dependent-task> <dependency-task>
   ```

2. **Sequential ordering**: For ordered tasks within a part, wire sequential deps
   ```bash
   bd dep add <task-2> <task-1>  # task-2 depends on task-1
   ```

### Step 8: Agent Selection

For each created task:
```
/yf:select_agent <task-id>
```

This assigns `agent:<name>` labels where appropriate.

### Step 8b: Formula Selection

After agent selection, evaluate each task for swarm formula assignment:

```
/yf:swarm_select_formula <task-id>
```

This applies `formula:<name>` labels based on task semantics (title keywords, type). Atomic/trivial tasks are skipped — they use bare agent dispatch. Tasks with explicit `formula:*` labels from the plan text are also skipped (author override).

The existing `swarm-formula-dispatch` rule handles dispatching labeled tasks through the swarm system during plan pump execution. No changes to the pump are needed.

### Step 9: Create Execution Gate

Create a human gate on the root epic to control execution state:

```bash
bd create --type=gate \
  --title="Plan execution gate" \
  --parent=<root-epic-id> \
  -l plan-exec,plan:<idx> \
  --silent
```

The gate starts open (not resolved) -- plan is Ready but not Executing.

### Step 9b: Create Chronicle Gate

Create a chronicle gate so diary generation waits for plan completion:

```bash
bd create --type=gate \
  --title="Generate diary from plan-<idx> chronicles" \
  --parent=<root-epic-id> \
  -l ys:chronicle-gate,plan:<idx> \
  --silent
```

This gate stays open until all plan tasks close. When `plan-exec.sh status` detects completion, it closes this gate, signaling that `/yf:chronicle_diary plan:<idx>` can now generate the full-arc diary.

### Step 9c: Create Qualification Gate

Create a qualification gate for the code-review step that runs before plan completion:

```bash
bd create --type=task \
  --title="Qualification review for plan-<idx>" \
  --parent=<root-epic-id> \
  --description="Code review qualification gate. Must pass before plan completion." \
  -l ys:qualification-gate,plan:<idx> \
  --silent
```

This gate stays open until `/yf:swarm_qualify` runs the code-review formula and it passes. If `qualification_gate` is set to `"disabled"` in `.yoshiko-flow/config.json`, skip this step.

### Step 10: Defer All Tasks

Defer all created tasks so they don't appear in `bd ready` until execution starts:

```bash
bd update <task-id> --defer=+100y
```

Use a far-future defer date. Tasks will be undeferred when `plan-exec.sh start` runs.

### Step 11: Output Summary

Report:
- Root epic ID
- Number of part epics created
- Number of tasks created
- Number of dependencies wired
- Gate ID
- Agent assignments made

```
Plan-to-Beads Summary
=====================
Plan: plan-03 — <Title>
Root Epic: marketplace-abc
Parts: 3 epics created
Tasks: 12 tasks created
Dependencies: 8 wired
Gate: marketplace-xyz (open — Ready state)
Agent assignments: 2 tasks assigned

All tasks deferred. Say "execute the plan" to start.
```

## Dry Run Mode

If `dry_run` is specified, show what would be created without actually creating:
- List all epics and tasks that would be created
- Show dependency wiring plan
- Show agent assignments
- Do not call `bd create` or `bd dep add`

## Error Handling

- If plan file not found, report and exit
- If beads-cli not available, report the error
- If duplicate plan detected (idempotency check), report existing beads
