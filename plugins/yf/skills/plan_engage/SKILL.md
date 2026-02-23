---
name: yf:plan_engage
description: Plan lifecycle state machine - manages Draft, Ready, Executing, Paused, and Completed states
arguments:
  - name: action
    description: "Lifecycle action: draft, ready, execute, pause, resume, complete (auto-detected from context if omitted)"
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


# Engage Plan Skill

Full lifecycle state machine for plan management. Transitions plans through Draft, Ready, Executing, Paused, and Completed states.

## State Machine

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
```

| State | Trigger | What Happens |
|---|---|---|
| **Draft** | "engage the plan" | Plan saved to `docs/plans/`. No beads created. |
| **Ready** | "the plan is ready" / "activate the plan" | Beads created via `/yf:plan_create_beads`. Gate open on root epic. Tasks deferred. |
| **Executing** | "execute the plan" / "start the plan" / "run the plan" | Gate resolved. Tasks undeferred. Dispatch loop begins via `/yf:plan_execute`. |
| **Paused** | "pause the plan" / "stop the plan" | New gate created. Pending tasks deferred. In-flight tasks finish. |
| **Completed** | Automatic (or "mark plan complete") | All plan tasks closed. Gate closed. Plan status updated. |

## Workflow

### Transition: -> Draft (Legacy Fallback)

> **Note:** The Draft transition is normally handled automatically by the ExitPlanMode auto-chain (see `auto-chain-plan.md` rule). This section is retained as a manual fallback for when the user explicitly says "engage the plan" during plan mode.

When the user says "engage the plan" during plan mode:

1. **Determine plan index**: Check existing plans in `docs/plans/`, find highest index, use next. Format is hybrid idx-hash (e.g., `0056-x7k3m`) — zero-padded 4-digit index plus 5-char hash suffix.
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

3. **Create plan gate**: Write `.yoshiko-flow/plan-gate` with plan metadata:
   ```bash
   mkdir -p .yoshiko-flow
   cat > .yoshiko-flow/plan-gate <<GATE_EOF
   {"plan_idx":"<idx>","plan_file":"docs/plans/plan-<idx>.md","created":"<ISO-8601 timestamp>"}
   GATE_EOF
   ```
   This blocks Edit/Write operations on implementation files until the plan reaches Executing state.
   To dismiss: `/yf:plan_dismiss_gate`

4. **Factor into parts** (if complex): Create `plan-<idx>-part<N>-<name>.md` files with:
   - Status, Parent reference, Dependencies
   - Detailed content, files to create, completion criteria

5. **Update MEMORY.md**: Add plan reference under "Current Plans"

6. **Present summary**: Show what was saved, offer next steps
   Plan gate active — code edits blocked until lifecycle completes.
   Next: "the plan is ready" -> "execute the plan"
   Or: /yf:plan_dismiss_gate to abandon

**Important**: `/yf:plan_engage` does NOT imply `ExitPlanMode`. They are independent actions.

### Transition: -> Ready

When the user says "the plan is ready" or "activate the plan":

1. **Locate plan**: Find the most recent Draft plan in `docs/plans/`
2. **Update plan status**: Change status from "Draft" to "Ready"
3. **Create beads**: Invoke `/yf:plan_create_beads` with the plan file
   - This creates the epic/task hierarchy, gates, labels, and defers all tasks
4. **Report**: Show created beads summary and root epic ID

### Transition: -> Executing

When the user says "execute the plan", "start the plan", or "run the plan":

1. **Find root epic**: Locate the plan's root epic by `plan:<idx>` label
2. **Update plan status**: Change from "Ready" or "Paused" to "In Progress"
3. **Start execution**: Run `plan-exec.sh start <root-epic-id>`
   - Resolves the gate, undefers tasks
4. **Begin dispatch**: Invoke `/yf:plan_execute` to orchestrate work

### Transition: -> Paused

When the user says "pause the plan" or "stop the plan":

1. **Find root epic**: Locate by `plan:<idx>` label
2. **Update plan status**: Change to "Paused"
3. **Pause execution**: Run `plan-exec.sh pause <root-epic-id>`
   - Creates new gate, defers pending tasks, in-flight tasks finish

### Transition: -> Completed

Automatic when all plan tasks are closed, or manual via "mark plan complete":

1. **Update plan status**: Change to "Completed"
2. **Close root epic**: If not already closed
3. **Report**: Summary of completed work

### Transition: Resume (-> Executing from Paused)

When the user says "resume the plan":

Same as -> Executing transition. `plan-exec.sh start` handles both Ready and Paused states.

## Plan File Conventions

### Naming
| Type | Format | Example |
|------|--------|---------|
| Master | `plan-<idx>.md` | `plan-0003-a3x7m.md` |
| Part | `plan-<idx>-part<N>-<name>.md` | `plan-0003-a3x7m-part1-api.md` |

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
