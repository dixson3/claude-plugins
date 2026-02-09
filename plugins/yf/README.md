# Yoshiko Flow (yf) Plugin — v2.4.0

Unified plan lifecycle management, execution orchestration, context persistence, and diary generation for Claude projects.

## Overview

The yf plugin is a consolidated system that bridges plan documentation and tracked work. It provides:

- **Plan lifecycle state machine** — Draft, Ready, Executing, Paused, Completed
- **Plan-to-beads conversion** — Structured epic/task hierarchy from plan docs
- **Execution orchestration** — Dispatches tasks to agents respecting dependencies
- **Task decomposition** — Breaks non-trivial tasks into atomic work items
- **Agent selection** — Matches tasks to the best available agent
- **Context persistence** — Captures context as chronicle beads across sessions
- **Diary generation** — Consolidates chronicles into markdown diary entries
- **Enforcement** — Gates, defer/undefer, and hooks prevent out-of-state operations

## Plan Lifecycle

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
```

| State | Trigger Phrase | What Happens |
|---|---|---|
| **Draft** | ExitPlanMode (auto) | Plan saved to `docs/plans/`. Auto-chain drives through to Executing. |
| **Ready** | "the plan is ready" | Beads created. Gate open. Tasks deferred. |
| **Executing** | "execute the plan" | Gate resolved. Tasks undeferred. Dispatch active. |
| **Paused** | "pause the plan" | New gate. Pending tasks deferred. In-flight finish. |
| **Completed** | Automatic | All tasks closed. Plan status updated. Diary generated. |

### Enforcement Layers

1. **Beads-native**: Gates control execution state. Deferred tasks hidden from `bd ready`.
2. **Scripts**: `plan-exec.sh` handles atomic state transitions.
3. **Hooks**: `plan-exec-guard.sh` blocks claim/close on non-executing plans.

## Skills

### Plan Lifecycle & Orchestration

| Skill | Description |
|-------|-------------|
| `/yf:engage_plan` | Plan lifecycle state machine — manages all state transitions |
| `/yf:plan_to_beads [plan_file]` | Convert a plan document into a beads hierarchy |
| `/yf:execute_plan [plan_idx]` | Orchestrate plan execution via task pump dispatch |
| `/yf:task_pump [plan_idx]` | Pull ready beads and dispatch to agents in parallel |
| `/yf:breakdown_task <task_id>` | Decompose a non-trivial task into child beads |
| `/yf:select_agent <task_id>` | Match a task to the best available agent |
| `/yf:plan_intake` | Intake checklist for plans entering outside the auto-chain |
| `/yf:dismiss_gate` | Remove the plan gate (abandon plan lifecycle) |

### Context Persistence & Diary

| Skill | Description |
|-------|-------------|
| `/yf:capture [topic:<topic>]` | Capture current context as a chronicle bead |
| `/yf:recall` | Recall and summarize open chronicle beads |
| `/yf:diary [plan_idx]` | Generate diary entries from open chronicles |
| `/yf:disable` | Close all open chronicles without diary generation |

### Configuration

| Skill | Description |
|-------|-------------|
| `/yf:setup` | Configure Yoshiko Flow for a project (first-run and reconfiguration) |

## Configuration

All config lives in `.claude/yf.json` (gitignored). This single file holds both user settings and preflight lock state.

```json
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs",
    "chronicler_enabled": true
  },
  "preflight": { "..." }
}
```

- **`enabled`** — Master switch. When `false`, preflight removes all rule symlinks.
- **`config.artifact_dir`** — Base directory for plans and diary (default: `docs`).
- **`config.chronicler_enabled`** — When `false`, chronicle rules are not installed.
- **`preflight`** — Lock state managed by `plugin-preflight.sh` (do not edit manually).

Run `/yf:setup` to create or reconfigure this file interactively.

## Agents

| Agent | Description |
|-------|-------------|
| `yf_recall` | Context recovery agent — synthesizes open chronicles into a summary |
| `yf_diary` | Diary generation agent — consolidates chronicles into markdown entries |

## Rules (9)

All rules are prefixed with `yf-` and symlinked into `.claude/rules/` (gitignored, pointing to `plugins/yf/rules/`):

| Rule | Purpose |
|------|---------|
| `yf-beads.md` | Agent instructions for beads workflow and session close protocol |
| `yf-engage-the-plan.md` | Maps trigger phrases to plan lifecycle transitions |
| `yf-plan-to-beads.md` | Enforces beads must exist before implementing a plan |
| `yf-breakdown-the-work.md` | Enforces task decomposition before coding non-trivial tasks |
| `yf-auto-chain-plan.md` | Drives automatic lifecycle after ExitPlanMode |
| `yf-beads-drive-tasks.md` | Enforces beads as source of truth for plan work |
| `yf-plan-intake.md` | Catches manual/pasted plans for lifecycle processing |
| `yf-watch-for-chronicle-worthiness.md` | Monitors for chronicle-worthy events |
| `yf-plan-transition-chronicle.md` | Captures planning context during transitions |

## Scripts

| Script | Description |
|--------|-------------|
| `plugin-preflight.sh` | Symlink-based artifact sync engine |
| `yf-config.sh` | Sourceable shell library for config access |
| `plan-exec.sh` | Deterministic state transitions for plan execution |
| `pump-state.sh` | Tracks dispatched/done beads to prevent double-dispatch |

## Hooks (5)

| Hook | Trigger | Description |
|------|---------|-------------|
| `preflight-wrapper.sh` | SessionStart | Triggers plugin preflight sync |
| `exit-plan-gate.sh` | ExitPlanMode | Saves plan and creates gate |
| `code-gate.sh` | Edit, Write | Blocks implementation edits when plan not executing |
| `plan-exec-guard.sh` | `bd update/close` | Blocks task ops on non-executing plans |
| `pre-push-diary.sh` | `git push` | Reminds about open chronicles before push |

## Dependencies

- **beads-cli** >= 0.44.0 — Git-backed issue tracker
- **jq** — JSON processing (used by scripts)

## License

MIT License - Yoshiko Studios LLC
