# Changelog

All notable changes to the Yoshiko Studios Claude Marketplace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
