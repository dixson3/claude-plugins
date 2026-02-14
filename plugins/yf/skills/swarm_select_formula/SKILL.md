---
name: yf:swarm_select_formula
description: Auto-assign formula labels to beads based on task semantics
arguments:
  - name: task_id
    description: "Bead ID to evaluate for formula assignment"
    required: true
---

# Swarm Formula Selection

Evaluates a task bead's title, description, and type to determine the best swarm formula, then applies a `formula:<name>` label. Designed to be called during `plan_create_beads` Step 8b after agent selection.

## When to Invoke

- Called by `/yf:plan_create_beads` Step 8b for each task
- Can be invoked directly: `/yf:swarm_select_formula <task-id>`

## Behavior

### Step 1: Read Task

```bash
bd show <task_id> --json 2>/dev/null
```

Extract: title, description, type, and existing labels.

### Step 2: Check for Existing Formula Label

```bash
bd label list <task_id> --json 2>/dev/null | jq -r '.[] | select(startswith("formula:"))'
```

If a `formula:*` label already exists, skip this task (author override). Report and exit.

### Step 3: Check for Atomic/Trivial Tasks

A task is considered **atomic** (no formula needed) when:
- Title references a single file or single concern
- Description mentions only one file to create or modify
- Type is `chore`
- Labels include `atomic` or `trivial`

If atomic, skip — bare agent dispatch is sufficient.

### Step 4: Apply Heuristic Matching

Match task title and description against keyword patterns (case-insensitive):

| Keywords in Title/Description | Formula | Rationale |
|------|---------|-----------|
| create, add, build, implement, develop, design | `feature-build` | Multi-step implementation work |
| fix, resolve, debug, repair, patch, bugfix | `bugfix` | Diagnostic → fix → verify cycle |
| research, investigate, evaluate, spike, compare, explore, analyze | `research-spike` | Deep investigation with synthesis |
| review, audit, inspect, assess | `code-review` | Analysis and reporting |
| test, spec, coverage, verify (as primary action) | `build-test` | Implementation + test + review |

**Priority rules:**
1. If multiple patterns match, prefer the first match in the table order above
2. If the task title starts with a verb from the table, weight that match higher
3. If no patterns match, skip (no formula assigned)

### Step 5: Apply Label

```bash
bd label add <task_id> formula:<selected-formula>
```

Report the assignment.

## Output

```
Formula Selection: <task_id>
  Title: <task title>
  Match: <matched keywords> → formula:<name>
  (or: No match — bare agent dispatch)
```

## Important

- This skill is **idempotent** — existing `formula:*` labels are never overwritten
- Atomic tasks should NOT get formulas — the overhead of a multi-agent swarm is not justified for single-file changes
- The heuristic is intentionally conservative — when in doubt, skip (bare dispatch works fine)
- The `swarm-formula-dispatch` rule in the plan pump already handles dispatching tasks with `formula:<name>` labels
