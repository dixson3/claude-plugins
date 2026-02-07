# Workflows Plugin

Plan lifecycle management, beads decomposition, and execution orchestration for Claude projects.

## Overview

The workflows plugin bridges plan documentation and tracked work. It provides:

- **Plan lifecycle state machine** — Draft, Ready, Executing, Paused, Completed
- **Plan-to-beads conversion** — Structured epic/task hierarchy from plan docs
- **Execution orchestration** — Dispatches tasks to agents respecting dependencies
- **Task decomposition** — Breaks non-trivial tasks into atomic work items
- **Agent selection** — Matches tasks to the best available agent
- **Enforcement** — Gates, defer/undefer, and hooks prevent out-of-state operations

## Installation

```
/workflows:init
```

This installs rules, verifies scripts, and configures hooks.

## Plan Lifecycle

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
```

| State | Trigger Phrase | What Happens |
|---|---|---|
| **Draft** | "engage the plan" | Plan saved to `docs/plans/`. No beads. |
| **Ready** | "the plan is ready" | Beads created. Gate open. Tasks deferred. |
| **Executing** | "execute the plan" | Gate resolved. Tasks undeferred. Dispatch active. |
| **Paused** | "pause the plan" | New gate. Pending tasks deferred. In-flight finish. |
| **Completed** | Automatic | All tasks closed. Plan status updated. |

### Enforcement Layers

1. **Beads-native**: Gates control execution state. Deferred tasks hidden from `bd ready`.
2. **Scripts**: `plan-exec.sh` handles atomic state transitions.
3. **Hooks**: `plan-exec-guard.sh` blocks claim/close on non-executing plans.

## Commands

### `/workflows:engage-plan`

Plan lifecycle state machine. Detects intent from context and transitions the plan.

## Skills

### `/workflows:init`

Initialize the workflows plugin: beads, rules, scripts, hooks.

### `/workflows:init_beads`

Initialize beads-cli issue tracking in the project.

### `/workflows:plan_to_beads [plan_file]`

Convert a plan document into a beads hierarchy:
- Master plan → root epic
- Plan parts → child epics
- Steps/files → tasks
- Dependencies wired automatically
- Agent labels assigned
- Gate created (Ready state)
- All tasks deferred until execution

### `/workflows:execute_plan [plan_idx]`

Orchestrate plan execution:
- Gets ready tasks via `plan-exec.sh next`
- Groups by agent label
- Dispatches independent tasks in parallel
- Loops until all work complete
- Auto-completes plan when done

### `/workflows:breakdown_task <task_id>`

Decompose a non-trivial task into child beads:
- Assesses scope (atomic vs. non-trivial)
- Creates child epics/tasks with dependencies
- Assigns agent labels to children
- Recursive — children decompose further if needed

### `/workflows:select_agent <task_id>`

Match a task to the best available agent:
- Scans `plugins/*/agents/*.md` for all agents
- Compares task content against agent capabilities
- Labels task with `agent:<name>` if matched
- No label = primary agent handles it

## Scripts

### `plan-exec.sh`

Deterministic state transitions for plan execution.

```bash
plan-exec.sh start  <root-epic-id>   # Ready/Paused → Executing
plan-exec.sh pause  <root-epic-id>   # Executing → Paused
plan-exec.sh status <root-epic-id>   # Query current state
plan-exec.sh next   <root-epic-id>   # Guarded bd ready
plan-exec.sh guard  <task-id>        # Check if task's plan allows execution
```

## Hooks

### `plan-exec-guard.sh`

Pre-tool-use hook that blocks `bd update --status in_progress`, `bd update --claim`, and `bd close` operations when the task's plan is not in Executing state.

## Rules

### `engage-the-plan.md`

Maps trigger phrases to plan lifecycle transitions.

### `plan-to-beads.md`

Enforces that beads must exist before implementing a plan.

### `breakdown-the-work.md`

Enforces task decomposition before coding on non-trivial tasks. Applies to all agents.

## Dependencies

- **beads-cli** >= 0.44.0 — Git-backed issue tracker
- **jq** — JSON processing (used by scripts)

## Used By

- **chronicler** — Uses beads for context persistence
- Any project using plan-driven development

## License

MIT License - Yoshiko Studios LLC
