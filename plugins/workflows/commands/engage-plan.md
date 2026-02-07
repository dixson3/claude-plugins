---
name: engage-plan
description: Plan lifecycle state machine - manages Draft, Ready, Executing, Paused, and Completed states
arguments:
  - name: action
    description: "Lifecycle action: draft, ready, execute, pause, resume, complete (auto-detected from context if omitted)"
    required: false
---

# Engage Plan Command

Full lifecycle state machine for plan management. Transitions plans through Draft, Ready, Executing, Paused, and Completed states.

## State Machine

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
```

| State | Trigger | What Happens |
|---|---|---|
| **Draft** | "engage the plan" | Plan saved to `docs/plans/`. No beads created. |
| **Ready** | "the plan is ready" / "activate the plan" | Beads created via `/workflows:plan_to_beads`. Gate open on root epic. Tasks deferred. |
| **Executing** | "execute the plan" / "start the plan" / "run the plan" | Gate resolved. Tasks undeferred. Dispatch loop begins via `/workflows:execute_plan`. |
| **Paused** | "pause the plan" / "stop the plan" | New gate created. Pending tasks deferred. In-flight tasks finish. |
| **Completed** | Automatic (or "mark plan complete") | All plan tasks closed. Gate closed. Plan status updated. |

## Workflow

### Transition: → Draft

When the user says "engage the plan" during plan mode:

1. **Determine plan index**: Check existing plans in `docs/plans/`, find highest index, use next (zero-padded: 01, 02, 03...)
2. **Save master plan**: Create `docs/plans/plan-<idx>.md`

```markdown
# Plan <idx>: <Title>

**Status:** Draft
**Date:** YYYY-MM-DD

## Overview
<consolidated plan content from discussion>

## Implementation Sequence
<ordered list of phases/steps>

## Completion Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

3. **Factor into parts** (if complex): Create `plan-<idx>-part<N>-<name>.md` files with:
   - Status, Parent reference, Dependencies
   - Detailed content, files to create, completion criteria

4. **Update MEMORY.md**: Add plan reference under "Current Plans"

5. **Present summary**: Show what was saved, offer next steps

**Important**: `/engage-plan` does NOT imply `ExitPlanMode`. They are independent actions.

### Transition: → Ready

When the user says "the plan is ready" or "activate the plan":

1. **Locate plan**: Find the most recent Draft plan in `docs/plans/`
2. **Update plan status**: Change status from "Draft" to "Ready"
3. **Create beads**: Invoke `/workflows:plan_to_beads` with the plan file
   - This creates the epic/task hierarchy, gates, labels, and defers all tasks
4. **Report**: Show created beads summary and root epic ID

### Transition: → Executing

When the user says "execute the plan", "start the plan", or "run the plan":

1. **Find root epic**: Locate the plan's root epic by `plan:<idx>` label
2. **Update plan status**: Change from "Ready" or "Paused" to "In Progress"
3. **Start execution**: Run `plan-exec.sh start <root-epic-id>`
   - Resolves the gate, undefers tasks
4. **Begin dispatch**: Invoke `/workflows:execute_plan` to orchestrate work

### Transition: → Paused

When the user says "pause the plan" or "stop the plan":

1. **Find root epic**: Locate by `plan:<idx>` label
2. **Update plan status**: Change to "Paused"
3. **Pause execution**: Run `plan-exec.sh pause <root-epic-id>`
   - Creates new gate, defers pending tasks, in-flight tasks finish

### Transition: → Completed

Automatic when all plan tasks are closed, or manual via "mark plan complete":

1. **Update plan status**: Change to "Completed"
2. **Close root epic**: If not already closed
3. **Report**: Summary of completed work

### Transition: Resume (→ Executing from Paused)

When the user says "resume the plan":

Same as → Executing transition. `plan-exec.sh start` handles both Ready and Paused states.

## Plan File Conventions

### Naming
| Type | Format | Example |
|------|--------|---------|
| Master | `plan-<idx>.md` | `plan-03.md` |
| Part | `plan-<idx>-part<N>-<name>.md` | `plan-03-part1-api.md` |

### Status Values
- `Draft` - Plan saved, no beads
- `Ready` - Beads created, gate open, tasks deferred
- `In Progress` - Executing, tasks undeferred
- `Paused` - Gate re-opened, pending tasks deferred
- `Completed` - All criteria met
- `Abandoned` - Will not implement

## Guidelines

- Create `docs/plans/` if it doesn't exist
- Include enough detail for implementation without original conversation
- Reference specific file paths and code patterns
- List dependencies between parts
- Always use beads for tracking once plan reaches Ready state
