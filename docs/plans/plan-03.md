# Plan 03: Plan-to-Beads Workflow Plugin

**Status:** Completed
**Date:** 2026-02-07

## Overview

When planning is complete and ready for implementation, there is no structured bridge between plan documentation and tracked work. Plans get captured as markdown files, but beads issues are created ad-hoc during implementation. Dependencies aren't captured upfront, progress can't be measured, and plan context gets lost between sessions.

Additionally, behavioral guidance in skills is suggestive rather than enforced. Execution state (running vs paused), task decomposition, and agent selection need mechanical enforcement — not just conventions Claude might follow.

This plan builds a workflow plugin with three enforcement layers:
1. **Beads-native**: Gates for execution state, defer/undefer for task visibility
2. **Scripts**: Atomic state transitions with deterministic logic
3. **Hooks**: Pre-tool-use guards that block operations violating state

## Plan Lifecycle

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
                      (gate resolved,  (gate open,   (auto when
                       tasks undeferred) tasks deferred) all closed)
```

| State | Trigger | Mechanism |
|---|---|---|
| **Draft** | "engage the plan" | Plan saved to `docs/plans/`. No beads. |
| **Ready** | "the plan is ready" | Beads created. Gate created (open) on root epic. Tasks deferred. |
| **Executing** | "execute the plan" | Gate resolved. Tasks undeferred. Dispatch loop active. |
| **Paused** | "pause the plan" | New gate created. Pending tasks deferred. In-flight tasks finish. |
| **Completed** | Automatic | All plan tasks closed → gate closed, plan status updated. |

## Deliverables

### 1. Migrate engage-plan into the workflows plugin

Moved from `.claude/commands/` and `.claude/rules/` into `plugins/workflows/skills/engage_plan/` and `plugins/workflows/rules/`. Originals deleted.

### 2. `/workflows:engage_plan` skill

Full lifecycle state machine with per-transition behavior for Draft, Ready, Executing, Paused, and Completed states.

### 3. `/workflows:plan_to_beads` skill

Reads a plan file, creates beads hierarchy (epics, tasks), wires dependencies, assigns agent labels, creates gates, and defers all tasks.

### 4. `/workflows:select_agent` skill

Standalone agent-to-task matching. Auto-discovers agents from `plugins/*/agents/*.md`, compares task content against agent capabilities, and labels with `agent:<name>`.

### 5. `/workflows:breakdown_task` skill

Decomposes non-trivial tasks into child beads with dependencies and agent assignments. Recursive — children decompose further if needed.

### 6. `plan-exec.sh` script

Deterministic state transitions: `start`, `pause`, `status`, `next`, `guard`. Handles gates, defer/undefer, and execution state labels.

### 7. `plan-exec-guard.sh` hook

Pre-tool-use hook blocking `bd update --status in_progress`, `bd update --claim`, and `bd close` when the task's plan is not in Executing state.

### 8. `/workflows:execute_plan` skill

Orchestrates plan execution: gets ready tasks, groups by agent label, dispatches independent tasks in parallel, loops until complete.

### 9. Rules

- **engage-the-plan.md** — Trigger phrase mapping to lifecycle transitions
- **plan-to-beads.md** — Beads-before-implementation enforcement
- **breakdown-the-work.md** — Task decomposition before coding (all agents)

### 10. `/workflows:init` skill

Installs rules, verifies scripts, configures hooks.

### 11. Plugin manifest and README

Updated to v1.1.0 with all new components registered.

## Files Summary

| Action | File |
|--------|------|
| Create | `plugins/workflows/skills/engage_plan/SKILL.md` |
| Create | `plugins/workflows/skills/init/SKILL.md` |
| Create | `plugins/workflows/skills/plan_to_beads/SKILL.md` |
| Create | `plugins/workflows/skills/execute_plan/SKILL.md` |
| Create | `plugins/workflows/skills/breakdown_task/SKILL.md` |
| Create | `plugins/workflows/skills/select_agent/SKILL.md` |
| Create | `plugins/workflows/scripts/plan-exec.sh` |
| Create | `plugins/workflows/hooks/plan-exec-guard.sh` |
| Create | `plugins/workflows/rules/engage-the-plan.md` |
| Create | `plugins/workflows/rules/plan-to-beads.md` |
| Create | `plugins/workflows/rules/breakdown-the-work.md` |
| Modify | `plugins/workflows/.claude-plugin/plugin.json` |
| Modify | `plugins/workflows/README.md` |
| Delete | `.claude/commands/engage-plan.md` |
| Delete | `.claude/rules/engage-the-plan.md` |

## Completion Criteria

- [x] Init: `/workflows:init` installs 3 rules, script executable, hook registered
- [x] All skills registered in plugin manifest
- [x] `plan-exec.sh` passes bash syntax check
- [x] `plan-exec-guard.sh` passes bash syntax check
- [x] Old `.claude/commands/engage-plan.md` and `.claude/rules/engage-the-plan.md` deleted
- [x] Marketplace manifest updated to v1.1.0
- [x] Full README documentation
