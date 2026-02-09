# Changelog

All notable changes to the Yoshiko Studios Claude Marketplace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.0] - 2026-02-08

### Added

- **`yf:plan_intake` skill**: Encapsulates the 5-step plan intake checklist (save plan, create beads, start execution, capture context, dispatch) as a concrete, invocable skill
- **Code-gate beads safety net**: `code-gate.sh` now warns (not blocks) on first non-exempt Edit/Write if an active plan has no beads — prompts agent to run `/yf:plan_intake`
  - One-shot warning via `.claude/.plan-intake-ok` marker (ephemeral session state)
  - Fail-open: any error in the check → proceed silently
  - Requires `bd` CLI; skips gracefully if not available
- Test scenario: `unit-code-gate-intake.yaml` (6 cases for beads safety net)

### Changed

- `yf-plan-intake.md` rule: Simplified — now references `/yf:plan_intake` skill instead of listing 5 manual steps
- `unit-plan-intake.yaml`: Added cases verifying skill file exists and rule references the skill
- Plugin version bumped: 2.2.0 → 2.3.0

## [2.2.0] - 2026-02-08

### Added

- **Two-file config model**: Split `.claude/yf.json` into committable shared config + gitignored local overrides
  - `.claude/yf.json` — version 2 shared config (committed to git): `{version, enabled, config}`
  - `.claude/yf.local.json` — local overrides + preflight lock state (gitignored): `{updated, preflight}`
  - Local keys always win on merge (`jq -s '.[0] * .[1]'`)
- **`yf-config.sh` shared library**: Sourceable shell library (bash 3.2 compatible) for config access
  - `yf_merged_config`, `yf_is_enabled`, `yf_is_chronicler_on`, `yf_read_field`, `yf_config_exists`
- **v1→v2 migration**: Automatic split of single-file v1 format into two-file v2 format
- **Setup wizard Q4**: "Should this config be committed to git (shared with team)?"
- Test scenarios: `unit-yf-config-merge.yaml` (8 cases), `unit-yf-v2-migration.yaml` (7 cases)

### Changed

- All 4 behavioral hooks now source `yf-config.sh` instead of inline jq guards
- `plugin-preflight.sh` reads/writes two-file model; preflight lock state goes to `yf.local.json`
- `.gitignore` no longer ignores `.claude/yf.json` (now committable); keeps `.claude/yf.local.json` ignored
- Plugin version bumped: 2.1.0 → 2.2.0
- All existing preflight test scenarios updated for two-file model

## [2.0.0] - 2026-02-08

### Added

- **yf** plugin (Yoshiko Flow) v2.0.0 — consolidated from `workflows` + `chronicler`
  - 11 skills: `yf:plan_to_beads`, `yf:execute_plan`, `yf:task_pump`, `yf:breakdown_task`, `yf:select_agent`, `yf:dismiss_gate`, `yf:engage_plan`, `yf:capture`, `yf:recall`, `yf:diary`, `yf:disable`
  - 2 agents: `yf_recall`, `yf_diary`
  - 9 rules: all `yf-` prefixed (e.g., `yf-beads.md`, `yf-auto-chain-plan.md`)
  - 5 hooks: `code-gate.sh`, `exit-plan-gate.sh`, `plan-exec-guard.sh`, `preflight-wrapper.sh`, `pre-push-diary.sh`
  - 2 scripts: `plan-exec.sh`, `pump-state.sh`
- Lock file migration: `.claude/plugin-lock.json` → `.claude/yf.json` with `preflight` nesting
  - Automatic migration on first preflight run
  - New JSON structure: `{version, updated, preflight: {plugins: {...}}}`
- Test scenario: `unit-yf-migration.yaml` — verifies old lock file migrates to new format

### Removed

- `workflows` plugin (v1.7.0) — merged into `yf`
- `chronicler` plugin (v1.3.0) — merged into `yf`
- Old un-prefixed rule files from `.claude/rules/` (auto-cleaned by preflight stale artifact removal)

### Changed

- All skill names: `/workflows:*` → `/yf:*`, `/chronicler:*` → `/yf:*`
- All agent names: `chronicler_recall` → `yf_recall`, `chronicler_diary` → `yf_diary`
- All rule filenames: `BEADS.md` → `yf-beads.md`, `engage-the-plan.md` → `yf-engage-the-plan.md`, etc.
- Lock file path: `.claude/plugin-lock.json` → `.claude/yf.json`
- Lock file JSON structure: flat `{plugins: {...}}` → nested `{preflight: {plugins: {...}}}`
- `.gitignore`: updated lock file entry
- Marketplace version: 1.9.0 → 2.0.0
- All test scenarios updated for new paths, names, and JSON structure

## [1.9.0] - 2026-02-08

### Added

- Automatic diary generation at lifecycle boundaries:
  - **Plan completion**: `execute_plan` skill Step 4 now invokes `/chronicler:diary plan:<idx>` after chronicle capture, generating plan-scoped diary entries automatically
  - **Session close**: BEADS.md "Landing the Plane" step 1.6 invokes `/chronicler:diary` to process all open chronicles into diary entries before the final commit
- Test cases verifying diary generation references in `execute_plan` and BEADS.md

### Changed

- Version bumps: workflows 1.6.0 → 1.7.0, marketplace 1.8.0 → 1.9.0
- `execute_plan` completion report now includes diary file paths instead of a manual diary reminder
- BEADS.md Landing the Plane protocol: added step 1.6 for diary generation after chronicle capture

## [1.8.0] - 2026-02-08

### Added

- `workflows` plugin: `plan-intake.md` rule — catches pasted/manual plans and redirects through the proper lifecycle (save plan file, create beads via `plan_to_beads`, start execution via `plan-exec.sh`, dispatch via `execute_plan`)
  - Detects when a plan is being implemented without the auto-chain having fired
  - Ensures plans always go through structured lifecycle regardless of entry path
  - Captures planning context as a chronicle bead at plan start
- Semi-automatic chronicle capture at lifecycle boundaries:
  - **Plan start**: `plan-intake.md` invokes `/chronicler:capture topic:planning`
  - **Plan completion**: `execute_plan` skill invokes `/chronicler:capture topic:completion`
  - **Session close**: BEADS.md "Landing the Plane" step 1.5 invokes `/chronicler:capture topic:session-close`
- Test scenario: `unit-plan-intake.yaml` — verifies rule content, manifest entry, and preflight sync

### Changed

- Version bumps: workflows 1.5.0 → 1.6.0, marketplace 1.7.0 → 1.8.0
- `BEADS.md` rule: Added chronicle capture step 1.5 to Landing the Plane protocol
- `execute_plan` skill: Added chronicle capture on plan completion (Step 4, before marking complete)

## [1.7.0] - 2026-02-08

### Added

- Declarative artifact management via `plugin.json` manifests
  - Plugins declare rules, directories, and setup commands in an `artifacts` section
  - Plugin dependencies declared in a `dependencies` array (topological ordering)
  - `scripts/plugin-preflight.sh` — marketplace-level sync engine that installs, updates, and removes artifacts
  - `.claude/plugin-lock.json` tracks installed artifact state with checksums
  - Conflict detection: user-modified rules are not overwritten; stale artifacts are cleaned up
  - Fast path: when all versions and checksums match, preflight exits in <50ms
- `plugins/workflows/hooks/preflight-wrapper.sh` — SessionStart hook triggers preflight automatically
- `plugins/workflows/rules/BEADS.md` — static source artifact (previously generated by init)
- `workflows` plugin: `beads-drive-tasks.md` now included in artifact manifest (was missing from init)

### Removed

- `workflows` plugin: `/workflows:init` and `/workflows:init_beads` skills — replaced by preflight
- `chronicler` plugin: `/chronicler:init` skill — replaced by preflight

### Changed

- Version bumps: workflows 1.4.0 → 1.5.0, chronicler 1.2.0 → 1.3.0, marketplace 1.6.0 → 1.7.0
- `CLAUDE.md`: Updated plugin documentation with artifact manifest format and preflight system description

## [1.6.0] - 2026-02-08

### Removed

- `roles` plugin — deleted entirely. The plugin was non-functional: the sole role (`watch-for-chronicle-worthiness`) never loaded for the primary session, and both chronicler agents had `on-start: /roles:apply` calls that matched zero roles.
  - 5 skills removed: `/roles:init`, `/roles:apply`, `/roles:assign`, `/roles:unassign`, `/roles:list`
  - `roles-apply.sh` script removed
  - `.claude/roles/` directory removed

### Changed

- `chronicler` plugin: Migrated `watch-for-chronicle-worthiness` from a role to a rule
  - Now installed to `.claude/rules/` (auto-loaded by Claude Code) instead of `.claude/roles/` (never auto-loaded)
  - Removed `on-start: /roles:apply` from `chronicler_recall` and `chronicler_diary` agents (was a no-op)
  - Simplified `/chronicler:init` — no longer depends on roles plugin (4 steps instead of 6)
  - Removed roles plugin from chronicler dependencies
- Version bumps: chronicler 1.1.0 → 1.2.0, marketplace 1.5.0 → 1.6.0

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
