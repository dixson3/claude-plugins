# Changelog

All notable changes to the Yoshiko Studios Claude Marketplace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-02-07

### Added

- `workflows` plugin: Task pump dispatch system
  - `/workflows:task_pump` skill — reads `bd ready`, groups by `agent:<name>`, dispatches parallel Task tool calls with `subagent_type`
  - `pump-state.sh` script — tracks dispatched/done beads to prevent double-dispatch
  - `beads-drive-tasks.md` rule — enforces beads as source of truth for plan work
- `workflows` plugin: Chronicle gating to plan execution
  - `plan_to_beads` creates `ys:chronicle-gate` bead that stays open until plan completes
  - `plan-exec.sh` auto-closes chronicle gates when all plan tasks are done
  - Diary generation sees the full arc of plan execution before producing entries
- `chronicler` plugin: Plan-context auto-detection
  - `/chronicler:capture` auto-tags chronicles with `plan:<idx>` when a plan is executing
  - `/chronicler:diary` accepts optional `plan_idx` argument to filter plan-specific chronicles
  - Chronicle gate warning when attempting diary generation on an in-progress plan
- Test scenarios: `unit-pump-state.yaml`, `unit-pump-dispatch.yaml`, `unit-chronicle-gate.yaml`

### Changed

- Refactored `/workflows:execute_plan` to use task pump for cleaner batch dispatch
  - Pump reads beads, groups by agent, dispatches parallel Task calls
  - Pump state prevents double-dispatch across loop iterations
  - Architecture section documents beads → pump → Task tool flow
- Updated workflows plugin to v1.3.0
- Updated marketplace to v1.5.0
- Added `.claude/.task-pump.json` and `.claude/.plan-gate` to `.gitignore`

## [1.4.0] - 2026-02-07

### Added

- `workflows` plugin: Plan gate enforcement system
  - `code-gate.sh` hook — blocks Edit/Write on implementation files when plan is saved but not yet executing
  - `exit-plan-gate.sh` hook — saves plan and creates gate on ExitPlanMode (hybrid trigger)
  - `/workflows:dismiss_gate` skill — escape hatch to abandon plan gate
  - `exit-plan-gate.md` rule — advisory backup ensuring engage_plan is called before ExitPlanMode
  - Gate created by engage_plan skill (Draft transition) and/or ExitPlanMode hook
  - Gate removed by `plan-exec.sh start` (Ready/Paused → Executing transition)

### Changed

- Updated workflows plugin to v1.2.0

## [1.3.0] - 2026-02-07

### Added

- `roles` plugin: `/roles:init` skill for plugin initialization (creates roles directory, installs apply script)

### Changed

- `chronicler` plugin: Replaced manual `roles-apply.sh` copy with `/roles:init` invocation (removes cross-plugin coupling)
- `chronicler` plugin: Removed redundant Step 7 (manual hook config) from init — `plugin.json` handles it automatically
- `chronicler` plugin: Updated `pre-push-diary.sh` header comments to reflect automatic installation
- `chronicler` plugin: Updated README pre-push hook section to note automatic configuration
- `workflows` plugin: Fixed hook format in init SKILL.md Step 5 to use nested `hooks[]` format
- Updated `CLAUDE.md` plugin structure to include `roles/` directory
- Version bumps: roles 1.0.0 → 1.1.0, chronicler 1.0.0 → 1.1.0, marketplace 1.2.0 → 1.3.0

## [1.2.0] - 2026-02-07

### Added

- `workflows` plugin: plan lifecycle state machine (Draft → Ready → Executing → Paused → Completed)
  - `/workflows:engage_plan` - Plan lifecycle management
  - `/workflows:plan_to_beads` - Convert plan docs to beads hierarchy
  - `/workflows:execute_plan` - Orchestrated task dispatch with agent routing
  - `/workflows:breakdown_task` - Recursive task decomposition
  - `/workflows:select_agent` - Auto-discover agents and match to tasks
  - `/workflows:init` - Plugin initialization (rules, scripts, hooks)
  - `plan-exec.sh` script for atomic state transitions
  - `plan-exec-guard.sh` hook for execution state enforcement
  - `engage-the-plan.md` rule for trigger phrase mapping
  - `plan-to-beads.md` rule for beads-before-implementation
  - `breakdown-the-work.md` rule for decomposition enforcement

### Changed

- Migrated `engage-plan` from `.claude/commands/` into workflows plugin as a skill
- Updated workflows plugin to v1.1.0

### Removed

- `hello-world` plugin (placeholder, no longer needed)
- `.claude/commands/engage-plan.md` (replaced by `/workflows:engage_plan`)
- `.claude/rules/engage-the-plan.md` (replaced by plugin-installed rule)

## [1.1.0] - 2026-02-04

### Added

- `roles` plugin for selective role loading
  - `/roles:apply` - Load roles for current agent
  - `/roles:assign` - Add agents to role
  - `/roles:unassign` - Remove agents from role
  - `/roles:list` - Show all roles and assignments
  - `roles-apply.sh` filter script

- `workflows` plugin for workflow utilities
  - `/workflows:init_beads` - Initialize beads issue tracking

- `chronicler` plugin for context persistence
  - `/chronicler:init` - Initialize chronicler system
  - `/chronicler:capture` - Capture context as chronicle bead
  - `/chronicler:recall` - Recall context from open chronicles
  - `/chronicler:diary` - Generate diary entries from chronicles
  - `/chronicler:disable` - Close chronicles without diary
  - `chronicler_recall` agent for context recovery
  - `chronicler_diary` agent for diary generation
  - `watch-for-chronicle-worthiness` role
  - `pre-push-diary.sh` hook script

## [1.0.0] - 2026-02-04

### Added

- Initial marketplace structure with plugin registry
- `hello-world` placeholder plugin demonstrating all plugin components:
  - `/hello-world:greet` command for friendly greetings
  - `hello` skill for automatic greeting interactions
  - `greeter` agent for marketplace introductions
- Marketplace catalog (`.claude-plugin/marketplace.json`)
- MIT License
- Project documentation (README.md, CLAUDE.md)
