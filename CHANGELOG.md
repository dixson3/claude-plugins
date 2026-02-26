# Changelog

All notable changes to the Yoshiko Studios Claude Marketplace will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2026-02-25

### Changed

- **Formula execution replaces swarm orchestration** — collapsed 3-layer stack (`swarm_run` → `swarm_dispatch` → `swarm_react`) into single `formula_execute` skill with inline reactive bugfix
- Renamed all `swarm_*` skills to `formula_*`: `formula_execute`, `formula_qualify`, `formula_select`, `formula_list`
- Renamed all `yf_swarm_*` agents to `yf_formula_*`: `yf_formula_researcher`, `yf_formula_tester`, `yf_formula_reviewer`
- Renamed `swarm-worktree.sh` → `formula-worktree.sh`
- Renamed `dispatch-state.sh` store from `swarm` to `formula` (state file: `formula-state.json`)
- Renamed `IG/swarm-execution.md` → `IG/formula-execution.md`
- Updated `plan_pump`, `plan_execute`, `plan_create_tasks` to dispatch via `/yf:formula_execute`
- Updated `yf-rules.md` sections: Rule 1.3 "Route Through Formula Execute", Section 3 "Formula Execution", Section 5 bridges
- Updated formula JSON files: removed `compose` field from `feature-build`, updated SUBAGENT refs in `code-implement`
- Updated all specification files (PRD REQ-016–022, EDD, all IGs) to reflect formula terminology

### Removed

- `swarm_run`, `swarm_dispatch`, `swarm_react`, `swarm_status`, `swarm_qualify`, `swarm_select_formula`, `swarm_list_formulas` skills
- `yf_swarm_researcher`, `yf_swarm_tester`, `yf_swarm_reviewer` agents
- `swarm-worktree.sh` script
- Formula composition (`compose` field) — nested formula dispatch dropped in favor of flat step sequences

## [3.1.0] - 2026-02-24

### Added

- `plugins/yf/hooks/pre-push-version.sh` — blocking pre-push hook that prevents `git push` when plugin code has changed without a version bump (Plan 63)
- Session land Step 8c — interactive version bump prompt (patch/minor/major/skip) before commit (Plan 63)
- Spec entries: REQ-048, DD-021, UC-048, UC-049 for semver enforcement
- `tests/scenarios/unit-pre-push-version.yaml` — 5 test cases (11 assertions) for version check hook
- `IG/script-complexity.md` specification with UC-042 through UC-046 (Plan 62)

### Changed

- `plugins/yf/.claude-plugin/plugin.json` — registered `pre-push-version.sh` in hook chain (land → version → diary)
- `plugins/yf/skills/session_land/SKILL.md` — added Step 8c for version bump check

### Fixed

- `yft_mol_wisp()` JSON validation bug — was rejecting valid multi-variable substitutions (Plan 61)
- Diary fact-check inaccuracies — corrected Plan 47→42 references and brew tap path (Plan 61)
- Batched `jq` calls in `yft_update()` (7 forks → 2) and `yft_mol_wisp()` (Plan 62)
- Replaced `sed` with parameter expansion in `yft_comment()` (Plan 62)
- Removed dead `yft_mol_show()` function (Plan 62)
- Consolidated `chronicle-validate.sh` boundary checks (Plan 62)
- Parametrized prune checkers in `session-prune.sh` (Plan 62)
- Stale beads-cli terminology fixes across skills and agents (Plan 58)
- Test coverage corrections and new task system test scenarios (Plan 59)
- Added `completed-plans` subcommand to `session-prune.sh` for cleanup of orphaned gates, completed plan epics, and closed chronicle files (Plan 60)

## [3.0.0] - 2026-02-23

### BREAKING CHANGE

- **Removed beads-cli dependency**: The entire `bd` (beads-cli) external dependency has been replaced with a file-based task management system. No external tooling is required beyond `jq`.
  - New `yf-tasks.sh` shell library with `yft_*` functions (create, show, update, close, delete, list, count, label, dep, comment, gate, mol)
  - New `yf-task-cli.sh` CLI wrapper for agent use: `bash "$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh" <command> <args>`
  - All work items (tasks, epics, gates, chronicles, archives, issues, todos, molecules) stored as JSON files under `.yoshiko-flow/` subdirectories
  - ID convention: `task-NNNN-xxxxx` (epics), `task-NNNN-xxxxx.NN` (child tasks), `chron-NNNN-xxxxx`, `arch-NNNN-xxxxx`, `mol-NNNN-xxxxx`, `issue-NNNN-xxxxx`, `todo-NNNN-xxxxx`
  - Activation gate simplified from 3 conditions to 2: config exists + enabled != false (no more `bd` check)

### Removed

- `beads-setup.sh` script — no longer needed
- `bd-safety-net.sh` hook — no longer needed (was advisory for `bd delete`)
- `beads_setup` skill — no longer needed
- `bd` CLI matchers in `plugin.json` hooks (`Bash(bd update*)`, `Bash(bd close*)`, `Bash(bd delete*)`)
- `yf_bd_available()` function from `yf-config.sh`

### Changed

- **All 10 core scripts**: Replaced `bd` CLI calls with `yft_*` library functions (plan-exec.sh, chronicle-check.sh, chronicle-staleness.sh, chronicle-validate.sh, plan-chronicle.sh, archive-suggest.sh, session-recall.sh, session-prune.sh, plan-prune.sh, swarm-worktree.sh)
- **All 8 hooks**: Replaced `bd` CLI calls and guards (code-gate.sh, pre-push-land.sh, pre-push-diary.sh, session-end.sh, pre-compact.sh, worktree-create.sh, plan-exec-guard.sh, exit-plan-gate.sh)
- **All 30+ skills**: Replaced `bd` command references with `yf-task-cli.sh` equivalents
- **All 13 agents**: Replaced `bd` command references with `yf-task-cli.sh` equivalents
- **Session markers**: Moved from `.beads/` to `.yoshiko-flow/` (.pending-diary, .dirty-tree)
- **Skill rename**: `plan_create_beads` → `plan_create_tasks`
- **Rules**: Updated all beads references to tasks terminology
- **Plugin version**: 2.30.0 → 3.0.0

### Added

- `plugins/yf/scripts/yf-tasks.sh` — file-based task management library (sourceable, `yft_*` API)
- `plugins/yf/scripts/yf-task-cli.sh` — CLI wrapper for agent use
- `.yoshiko-flow/` subdirectories: `tasks/`, `chronicler/`, `archivist/`, `issues/`, `todos/`, `molecules/` (all gitignored)

## [2.30.0] - 2026-02-22

### Added

- **Hybrid idx-hash ID generation** (`yf-id.sh`): All generated IDs now support an optional `scope` argument that produces `PREFIX-NNNN-xxxxx` format (e.g., `REQ-0005-k4m9q`, `plan-0054-a3x7m`). The 4-digit sequential index provides human-readable ordering while the 5-char hash preserves collision safety across parallel worktrees. Without scope, legacy `PREFIX-xxxxx` format is preserved for backward compatibility.
- **Plan index registry** (`docs/plans/_index.md`): New index file tracking all plans with sequential index, ID, title, date, and status. Bootstrapped from all 54 existing plans. `exit-plan-gate.sh` auto-appends new entries on plan creation.
- **New test file**: `unit-yf-id.yaml` — 7 test cases for core hybrid ID generation (legacy format, file scope, directory scope, empty scope, part file exclusion, cross-file counting, uniqueness).

### Changed

- **Plan ID generation**: `exit-plan-gate.sh` passes `$PLANS_DIR` as scope to `yf_generate_id`, producing `plan-NNNN-xxxxx.md` filenames (was `plan-xxxxx.md`). Creates `_index.md` entry on each new plan.
- **TODO ID generation**: `tracker-api.sh` `_next_todo_id()` simplified to a single `yf_generate_id "TODO" "$TODO_FILE"` call. Manual collision-check loop removed.
- **DEC ID generation**: `archive_capture/SKILL.md` simplified to `yf_generate_id "DEC" "docs/decisions/_index.md"`. Manual collision-check loop removed.
- **Spec ID generation**: `engineer_update/SKILL.md` and `yf_engineer_synthesizer.md` pass scope paths to `yf_generate_id` for hybrid IDs.
- **Spec sanity check**: `spec-sanity-check.sh` uniqueness regex widened from `PREFIX-[a-z0-9]+` to `PREFIX-[a-z0-9-]+` to match hybrid `PREFIX-NNNN-xxxxx` format. Old-format IDs still match.
- **Plan-idx extraction**: Sed patterns in `code-gate.sh`, `bd-safety-net.sh`, and `session-recall.sh` changed from `sed -n 's/^plan-\([a-z0-9]*\).*/\1/p'` to `basename ... .md | sed 's/^plan-//'` — handles hyphens in hybrid IDs.
- **Plugin version**: 2.29.0 → 2.30.0.
- **Test updates**: `unit-exit-plan-gate.yaml` Case 4 verifies hybrid naming and `_index.md` creation. `unit-tracker-api.yaml` Cases 3-4 updated regex for hybrid TODO IDs.

## [2.29.0] - 2026-02-22

### Added

- **WorktreeCreate/WorktreeRemove hooks**: Automatic yf setup in any worktree context (`claude --worktree`, `EnterWorktree`, Task `isolation: "worktree"`).
  - `worktree-create.sh` — Creates git worktree, sets up beads redirect and rule symlinks when yf is active. Activation-gated: always creates worktree, only runs yf setup when active.
  - `worktree-remove.sh` — Fire-and-forget cleanup of yf artifacts (rule symlinks, `.yoshiko-flow` symlink).
  - Registered in `plugin.json` as `WorktreeCreate` and `WorktreeRemove` hook types.
- **Worktree hook tests**: `unit-worktree-hooks.yaml` with 9 test cases covering creation, idempotency, beads redirect, activation gating, branch fallback, and cleanup.

### Changed

- **Plugin version**: 2.28.0 → 2.29.0.

## [2.28.0] - 2026-02-22

### Added

- **Prompt Text Quality rule** in CLAUDE.md: Five review criteria for concision and effectiveness of rules, skills, and agents.
- **`yf_regression_check` agent**: Lightweight agent that runs the unit test suite and returns a structured pass/fail summary.

### Changed

- **Rules consolidation**: Merged `yf-worktree-lifecycle.md` into `yf-rules.md` as section 1.6 (Worktree Lifecycle). Removed separate rule file and preflight entry. Single consolidated rule file.
- **Advisory monitoring tightened**: Removed redundant negation lines ("NOT chronicle-worthy", "NOT issue-worthy") from rules 5.3 and 5.6. Removed exposition from rule 4.2.
- **Agent text optimization** (12 files, ~428 lines saved): Removed all Personality sections, compressed Error Handling to 2-3 lines, compressed Tools sections to standardized patterns, compressed Chronicle Signal (8→3 lines) and Chronicle Protocol (15→7 lines), compressed markdown templates to section-name lists, compressed JSON examples to minimal structure.
- **Skill text optimization** (31 files, ~630 lines saved): Removed redundant "When to Invoke" sections where frontmatter description covers it, compressed verbose output templates and report blocks, compressed spec templates to section-name lists.
- **Plugin version**: 2.27.0 → 2.28.0.

## [2.27.0] - 2026-02-21

### Added

- **Hash-based ID generation** (`yf-id.sh`): All generated IDs (plan, TODO, REQ, DD, NFR, UC, DEC) now use SHA-256 hashed, base36-encoded, 5-character identifiers instead of sequential numbers. Collision-safe across parallel worktrees with 36^5 = 60M value space. macOS compatible (`shasum -a 256`). Existing sequential IDs remain valid — both formats coexist.
- **`worktree` capability**: Epic worktree lifecycle for isolated development branches.
  - `/yf:worktree_create` — Create a git worktree with new branch, `.beads/redirect` setup, and worktree-aware config resolution.
  - `/yf:worktree_land` — Validate, rebase, re-validate, and fast-forward merge a worktree back into the base branch with automatic cleanup.
  - `worktree-ops.sh` script — Core operations: create, validate, rebase, land.
  - `yf-worktree-lifecycle.md` rule — Enforces use of yf skills (not raw git commands) for epic worktree operations.
- **Swarm worktree isolation**: Write-capable swarm agents dispatch with `isolation: "worktree"` via Claude Code's Task tool parameter.
  - `swarm-worktree.sh` script — Helper for setup, merge-back (`-X theirs` strategy), cleanup, and conflict detection.
  - `swarm_dispatch/SKILL.md` Step 3b — Determines isolation mode per step (read-only agents skip isolation).
  - `swarm_dispatch/SKILL.md` Step 4 — Adds `isolation: "worktree"` and beads-setup injection for write-capable agents.
  - `swarm_dispatch/SKILL.md` Step 6a — Sequential merge-back with escalating conflict resolution (theirs → Claude-driven → re-dispatch → human escalation).
- **Worktree-aware config resolution**: `yf-config.sh` falls back to main repo's `.yoshiko-flow/config.json` when in a worktree.
  - `yf_main_repo_root()` — Resolves main repo root from a worktree.
  - `yf_is_worktree()` — Detects worktree context.

### Changed

- **Plan ID generation**: `exit-plan-gate.sh` generates hash-based plan IDs (`plan-a3x7m.md`) instead of sequential (`plan-52.md`). Collision guard with retry.
- **TODO ID generation**: `tracker-api.sh` `_next_todo_id()` generates hash-based IDs (`TODO-b7rpz`) instead of sequential (`TODO-034`).
- **DEC ID generation**: `archive_capture/SKILL.md` generates hash-based DEC IDs instead of sequential (`DEC-k4m9q`).
- **Spec ID generation**: `engineer_update/SKILL.md` and `yf_engineer_synthesizer.md` use `yf_generate_id()` for REQ, DD, NFR, UC, and TODO IDs instead of sequential assignment.
- **Spec sanity check**: `spec-sanity-check.sh` contiguity check replaced with uniqueness check (no duplicate IDs) — sequential contiguity no longer applies for hash IDs.
- **Sed pattern widening**: Plan ID extraction patterns in 4 scripts (`exit-plan-gate.sh`, `code-gate.sh`, `bd-safety-net.sh`, `session-recall.sh`) widened from `[0-9]*` to `[a-z0-9]*` — backwards compatible with existing sequential IDs.
- **Plugin version**: 2.26.0 → 2.27.0.

## [2.26.0] - 2026-02-21

### Added

- **`plugin` capability** (replaces Core): Merged the existing `setup` skill into the new `plugin` prefix. `/yf:setup` renamed to `/yf:plugin_setup`. Added `/yf:plugin_issue` skill for reporting bugs and enhancements against the plugin repository via `gh`.
- **`issue` capability**: Full project issue tracking lifecycle with deferred staging, agent-driven triage, and multi-backend submission.
  - `/yf:issue_capture` — Stage project issues as `ys:issue` beads (deferred submission)
  - `/yf:issue_process` — Evaluate, consolidate, and submit staged issues via `yf_issue_triage` agent
  - `/yf:issue_list` — Combined view of remote tracker issues and locally staged beads
  - `/yf:issue_plan` — Pull a remote issue into a yf planning session
  - `/yf:issue_disable` — Close staged issues without submission
  - Agent: `yf_issue_triage` — Evaluates open issue beads, detects duplicates, augments existing remote issues
- **`tracker-detect.sh` script**: Auto-detects project tracker from config or git remote origin. Supports GitHub, GitLab, and file fallback. Bash 3.2 compatible.
- **`tracker-api.sh` script**: Tracker abstraction layer with uniform `create`, `list`, `view`, `transition` interface across GitHub (`gh`), GitLab (`glab`), and file backends.
- **Config accessors**: `yf_plugin_repo`, `yf_project_tracker`, `yf_project_slug`, `yf_tracker_tool` in `yf-config.sh`.
- **Rule 1.5 — Issue Disambiguation**: Hard enforcement preventing cross-routing between plugin issues and project issues.
- **Rule 5.6 — Issue Worthiness**: Advisory monitoring that suggests `/yf:issue_capture` for deferred improvements, incidental bugs, and technical debt.
- **Pre-push advisory**: `pre-push-diary.sh` now warns about open `ys:issue` beads before push.
- **File-based issue backend**: `docs/specifications/TODO.md` register with `docs/todos/TODO-NNN/` artifact folders.
- **Unit tests**: `unit-tracker-detect.yaml` (8 cases), `unit-tracker-api.yaml` (8 cases), `unit-issue-disambiguation.yaml` (6 cases).

### Changed

- **`/yf:setup` → `/yf:plugin_setup`**: Renamed across all active files (~25 files). Historical docs (plans, diary) left as-is.
- **Capability table**: Core capability merged into Plugin. Issue capability added.
- **Plugin version**: 2.25.0 → 2.26.0.

## [2.25.0] - 2026-02-19

### Added

- **`/yf:beads_setup` skill**: Doctor-driven beads initialization and repair. Runs `bd doctor`, classifies warnings as must-fix vs acceptable, attempts auto-repair for must-fix issues, and goes inactive on failure. Idempotent and fail-open.
- **`beads-setup.sh` script**: Standalone repair script encoding all beads configuration knowledge. Handles: stale metadata.json, database name normalization, no-git-ops enforcement, hook removal, dolt change commits, and full doctor validation.
- **Integration test infrastructure**: New `TestProject` factory (`project.go`) provisions real git repos with bare remotes, cloned working copies, optional beads init, and symlinked plugin sources. 7 new assertion types: `bd_list_contains`, `bd_count`, `git_log_contains`, `git_status_clean`, `remote_has_ref`, `symlink_exists`, `config_value`.
- **5 integration test scenarios**: `integ-beads-setup.yaml` (fresh project E2E), `integ-activation-gate.yaml` (three-condition gate), `integ-preflight-sync.yaml` (rule symlinks, directories, gitignore), `integ-code-gate.yaml` (plan-gate enforcement), `integ-pre-push.yaml` (landing enforcement).
- **`--integration-only` flag**: Test harness supports filtering to integration scenarios only.
- **`type: integration` field**: YAML scenarios declare their type for filtering.

### Changed

- **Preflight setup consolidated**: Replaced two separate setup entries (`beads` + `beads-no-git-ops`) with single `beads-setup` entry that runs `beads-setup.sh`.
- **`plugin-preflight.sh`**: Now detects `BEADS_SETUP_FAILED` signal from setup commands and deactivates plugin (removes rules, emits `YF_BEADS_UNHEALTHY`).
- **`run-tests.sh`**: Integration test section now auto-discovers `integ-*.yaml` files.
- **Test harness**: `runner.go` wires project provisioning, expands `$REMOTE_DIR`, passes extra env vars. `scenario.go` adds `Type` and `Project` fields.
- **Plugin version**: 2.24.0 → 2.25.0.

### Fixed

- **This project's beads**: Fixed stale `metadata.json` (SQLite-era values), committed 5 pending dolt changes.

## [2.24.0] - 2026-02-18

### Removed

- **Beads plugin dependency** (`steveyegge/beads`): yf no longer depends on the beads Claude Code plugin. All operations use `bd` CLI directly. The `dependencies` array has been removed from `preflight.json`.
- **Stale `.beads/` artifacts**: Removed git-tracked hooks (`post-checkout`, `post-merge`, `pre-commit`, `pre-push`, `prepare-commit-msg`), `issues.jsonl`, `metadata.json`, and `README.md` — all no-ops with the dolt backend.
- **`installed_plugins.json` registry check**: `yf_beads_installed()` no longer checks the plugin registry; replaced by `yf_bd_available()` which checks `command -v bd`.

### Changed

- **Activation gate simplified**: Condition 3 changed from "beads plugin installed" to "bd CLI available". `yf_bd_available()` is the new canonical function; `yf_beads_installed()` retained as backwards-compatible alias.
- **DD-016 reversed**: Hybrid beads routing (agent operations through beads plugin skills) marked as reversed — all operations use `bd` CLI directly.
- **Setup dependency check**: `/yf:setup` checks `command -v bd` instead of parsing `installed_plugins.json`.
- **Preflight messages**: "beads plugin" references replaced with "bd CLI" / "beads-cli" throughout.
- **`.beads/.gitignore`**: Added patterns for `hooks/`, `issues.jsonl`, `interactions.jsonl`, `metadata.json`, `README.md`.
- **Plugin version**: 2.23.0 → 2.24.0.
- **Test updates**: `unit-activation.yaml` cases 7-8 updated from registry checks to `yf_bd_available()` / PATH-based tests. `unit-yf-config.yaml` case 13 updated to test `yf_bd_available()` and alias.

## [2.23.0] - 2026-02-18

### Added

- **`/yf:session_land` skill** (REQ-039, UC-028, DD-017): Full session close-out orchestrator — dirty tree check, in-progress beads triage, chronicle capture, diary generation, quality gates, memory reconciliation, session prune, commit, and push with operator confirmation via AskUserQuestion.
- **`pre-push-land.sh` blocking hook** (REQ-039, UC-039, DD-017): PreToolUse hook on `Bash(git push*)` that blocks push (exit 2) when uncommitted changes or in-progress beads exist. Structured checklist output with actionable guidance.
- **Plan foreshadowing** (REQ-040, UC-040): Plan intake Step 0 auto-classifies uncommitted files as plan-overlapping (foreshadowing commits) or unrelated (ad-hoc commits) before plan lifecycle begins. Both commits automatic.
- **Dirty-tree markers** (REQ-041, UC-041): `session-end.sh` writes `.beads/.dirty-tree` marker when session ends with uncommitted changes. `session-recall.sh` consumes marker and warns next session.
- **`beads-no-git-ops` preflight setup** (DD-017, FS-048): Configures `bd config set no-git-ops true` to suppress `bd prime` SESSION CLOSE PROTOCOL git commands. yf manages the git commit/push workflow.
- **Spec entries**: REQ-039/040/041, DD-017, FS-044/045/046/047/048, UC-039/040/041.
- **New test files**: `unit-session-land.yaml`, `unit-pre-push-land.yaml`.

### Changed

- **`yf-rules.md` optimized**: Trimmed from ~275 lines to ~120 lines of self-contained action directives. Removed informational content (Rule 4.1 beads quick reference, Rule 5.3 tiers 1-2, Rule 2.4 full report template). No IG cross-references — rules reference skills only.
- **Rule 4.2 rewritten**: "Landing the Plane" now directs to `/yf:session_land` skill. Notes that this protocol supersedes `bd prime` SESSION CLOSE PROTOCOL.
- **`plugin.json` hook declarations**: `Bash(git push*)` now fires two PreToolUse hooks in sequence — `pre-push-land.sh` (blocking) then `pre-push-diary.sh` (advisory).
- **IG/beads-integration.md**: UC-028 expanded from 7 to 11 steps with full session_land flow. Added UC-039 (pre-push enforcement) and UC-041 (dirty-tree markers).
- **IG/plan-lifecycle.md**: UC-002 expanded with detection criteria and foreshadowing reference. Added UC-040 (plan foreshadowing). UC-001 expanded with chronicle/archive guidance.
- **Plugin version**: 2.22.0 → 2.23.0.
- **Test updates**: `unit-session-end.yaml` (dirty-tree marker write), `unit-session-recall.yaml` (dirty-tree marker consumption).

## [2.22.0] - 2026-02-17

### Removed

- **`bd sync` references**: Removed from rules (Section 4.1 Quick Reference, Section 4.2 Landing the Plane), post-push-prune.sh hook, and all specification documents. `bd sync` is a no-op in dolt mode (beads v0.52.0).
- **`bd hooks install`**: Removed from preflight setup. All 5 beads git hooks (pre-commit, post-merge, pre-push, post-checkout, prepare-commit-msg) are silent no-ops in dolt mode. `issues.jsonl` does not exist.
- **`sync.branch` and `mass_delete` config**: Removed from preflight setup command. Beads setup is now just `bd init`.
- **JSONL merge driver**: Removed `.gitattributes` entry for `.beads/issues.jsonl merge=beads`.
- **`beads-sync` branch**: Deleted local and remote branches. The JSONL export pipeline is non-functional in dolt mode.
- **`core.hooksPath` override**: Unset git config that pointed to `.beads/hooks/`.
- **`sync-branch` config**: Removed from `.beads/config.yaml`.

### Changed

- **DD-003 rewritten**: "Beads-Sync Branch Strategy" → "Dolt-Native Persistence (Reversed from Sync Branch)" — documents the full arc from local-only → sync branch → dolt-native.
- **TC-009 updated**: Beads state now persisted via embedded dolt database with immediate writes.
- **REQ-027 simplified**: Setup is `bd init` only. No hooks, no sync branch, no mass-delete config.
- **FS-027 updated**: Describes dolt-backed persistence instead of beads-sync + hooks.
- **UC-025 simplified**: Setup flow reduced from 8 steps to 5 (removed sync.branch, mass-delete, hooks install).
- **UC-027 updated**: Removed `bd sync` step from automatic pruning flow.
- **UC-028 updated**: Removed `bd sync` step from session close protocol; renumbered.
- **TODO-008 resolved**: Monitoring beads-sync is moot after dolt-native persistence.
- **Plugin version**: 2.21.0 → 2.22.0.
- **Test suite**: `unit-beads-git.yaml` renamed and expanded from 9 to 12 cases — inverted sync/hooks assertions, added negative tests for sync.branch, bd sync in hooks, and bd init exactness.

## [2.21.0] - 2026-02-17

### Added

- **Three-condition activation gate** (REQ-034, DD-015): yf only activates when `.yoshiko-flow/config.json` exists, `enabled: true`, AND beads plugin is installed. Fail-closed activation replaces previous fail-open behavior. G7 revised to "fail-open hooks and explicit per-project activation."
- **yf-activation-check.sh**: Standalone activation check script outputting structured JSON (`{"active":true}` or `{"active":false,"reason":"...","action":"..."}`). Used by all skill guards.
- **yf_beads_installed()** config helper in `yf-config.sh` — checks `~/.claude/plugins/installed_plugins.json` for beads plugin, falls back to `command -v bd`.
- **Skill activation guards**: All 27 skills (except `/yf:setup`) check activation status before executing and report reason/remediation when inactive.
- **Beads plugin dependency** (REQ-035): `preflight.json` declares `steveyegge/beads` as required dependency. Preflight emits `YF_DEPENDENCY_MISSING` signal and removes rules when beads is absent.
- **Per-project activation** (REQ-036): Installing yf globally no longer activates it everywhere. Explicit `/yf:setup` required per-project.
- **Rule 1.0 — Activation Gate**: Hard enforcement rule documenting the three-condition gate.
- **Hybrid beads routing** (DD-016): Agent-facing instructions reference beads skills (`/beads:ready`, `/beads:close`); shell scripts continue using `bd` CLI.
- **Setup beads check**: `/yf:setup` verifies beads plugin before writing config.
- **Spec entries**: REQ-034/035/036, FS-040/041, DD-015/016, UC-035/036, TODO-027/028; revised G7, TC-003, REQ-028, UC-023, UC-025.
- **New test file** `unit-activation.yaml` with 8 test cases for activation gate.
- **11 new test steps** across `unit-yf-config.yaml`, `unit-preflight.yaml`, `unit-preflight-disabled.yaml`.
- **Memory reconciliation skill** (REQ-037, FS-042, UC-037): `/yf:memory_reconcile` automates MEMORY.md hygiene — classifies items as contradictions (spec wins), gaps (promote to specs), or ephemeral duplicates (remove). Operator approval required for spec changes per Rule 1.4.
- **Rule 4.2 step 4.5**: Memory reconciliation integrated into "Landing the Plane" session close protocol, running after quality gates and before commit.
- **Spec entries**: REQ-037, FS-042, UC-037, TODO-029.
- **New test file** `unit-memory-reconcile.yaml` with 7 existence-check test cases.
- **Skill-level chronicle auto-capture** (REQ-038, FS-043, UC-038): Chronicle beads auto-created at decision points — reconciliation conflicts (`engineer_reconcile` Step 7.5), spec mutations (`engineer_update` Step 3.5), qualification verdicts (`swarm_qualify` Step 6.5), scope changes (`plan_breakdown` Step 5.5), and intake reconciliation (`plan_intake` Step 1.5g).
- **Formula chronicle flags**: `"chronicle": true` enabled on terminal steps of 5 formulas (feature-build, code-implement, build-test, code-review, bugfix). Dispatch loop auto-creates chronicle beads for flagged steps.
- **Agent chronicle protocol**: Write-capable agents (`yf_code_writer`, `yf_code_tester`, `yf_swarm_tester`) create chronicle beads on plan deviations, unexpected discoveries, and non-obvious failures. Read-only agents (`yf_swarm_researcher`, `yf_swarm_reviewer`, `yf_code_researcher`, `yf_code_reviewer`) signal chronicle-worthy findings via `CHRONICLE-SIGNAL:` in structured comments.
- **CHRONICLE-SIGNAL dispatch**: `swarm_dispatch` Step 6c reads `CHRONICLE-SIGNAL:` lines from step comments and auto-creates chronicle beads, giving read-only agents a path to trigger chronicles.
- **Spec entries**: REQ-038, FS-043, UC-038, TODO-030.
- **New test file** `unit-chronicle-worthiness.yaml` with 13 existence-check test cases.

### Changed

- **yf_is_enabled()** rewritten from `_yf_check_flag '.enabled'` (fail-open) to three-condition check (fail-closed). No config = inactive.
- **plugin-preflight.sh**: No config exits early without installing rules. Missing beads removes rules and exits.
- **Rule 4.1**: Beads quick reference updated to show beads skills alongside `bd` CLI.
- **Rule 5.3**: Rewritten from vague categories ("significant progress", "important decisions") to concrete 3-tier taxonomy — Tier 1: auto-capture at skill decision points, Tier 2: agent-initiated for write-capable agents, Tier 3: advisory for main orchestrator.

## [2.20.0] - 2026-02-16

### Added

- **Specification integrity gates**: Two gatekeeping checklists — plan intake (6-part: contradiction, new capability, test-spec alignment, test deprecation, chronicle changes, structural consistency) and plan completion (staleness check, spec self-reconciliation, deprecated artifact verification) — enforce specs as anchor documents at lifecycle boundaries.
- **spec-sanity-check.sh**: Mechanical consistency script validating six structural dimensions (count parity, ID contiguity, coverage arithmetic, UC range alignment, test file existence, formula count). Fail-open, configurable via `sanity_check_mode`.
- **Rule 1.4 — Specifications Are Anchor Documents**: Hard enforcement rule establishing that plans conform to specs (not vice versa), new capabilities require spec coverage, tests align to specs first, and all spec changes require operator approval.
- **yf_sanity_check_mode()** config helper in `yf-config.sh` (default: `blocking`).
- **Spec entries**: REQ-033, FS-038, FS-039, DD-014, UC-033, UC-034, TODO-026.
- **14 new test steps** in `unit-spec-sanity.yaml` covering all six checks with pass/fail scenarios.

### Fixed

- **test-coverage.md**: Stale reference to removed `unit-swarm-state.yaml` updated to `unit-dispatch-state.yaml`.

## [2.19.0] - 2026-02-16

### Changed

- **Rule consolidation**: 24 separate rule files consolidated into a single `yf-rules.md` organized by priority — hard enforcement, plan lifecycle, swarm execution, session protocol, and advisory monitoring (~210 lines, down from ~1400). Stale symlinks auto-cleaned by preflight.
- **code-gate.sh beads safety net upgraded**: Advisory warning replaced with blocking enforcement (exit 2). When a non-completed plan file exists without beads, Edit/Write on implementation files is blocked. Includes 60-second TTL cache, exempt file patterns, and `.yoshiko-flow/plan-intake-skip` escape hatch. Addresses GitHub issue #11.
- **dispatch-state.sh**: Merged `pump-state.sh` and `swarm-state.sh` into unified `dispatch-state.sh <pump|swarm> <command>`. All skill callers updated.
- **plugin-preflight.sh pruned**: Removed ~93 lines of migration logic (yf.json rename, .claude/ directory migration, chronicler/archivist field pruning, beads git workflow migration, legacy flat rule cleanup). Inlined `install-beads-push-hook.sh` as a function.
- **setup-project.sh simplified**: Removed `cleanup_agents` function and AGENTS.md management. Now only handles gitignore.

### Removed

- 24 individual rule files in `plugins/yf/rules/` (replaced by consolidated `yf-rules.md`)
- `plugins/yf/scripts/pump-state.sh` (merged into `dispatch-state.sh`)
- `plugins/yf/scripts/swarm-state.sh` (merged into `dispatch-state.sh`)
- `plugins/yf/scripts/install-beads-push-hook.sh` (inlined into `plugin-preflight.sh`)
- `tests/scenarios/unit-migration.yaml` (tested removed migration paths)
- `tests/scenarios/unit-pump-state.yaml` (replaced by `unit-dispatch-state.yaml`)
- `tests/scenarios/unit-swarm-state.yaml` (merged into `unit-dispatch-state.yaml`)

### Fixed

- **GitHub issue #11**: Agent no longer bypasses `plan-intake` when user says "Implement the following plan." The `code-gate.sh` hook now blocks implementation edits until beads are created via the plan intake lifecycle.

## [2.18.1] - 2026-02-14

### Fixed

- **exit-plan-gate.sh**: Look for plan files in `~/.claude/plans/` (global) instead of `$PROJECT_DIR/.claude/plans/` (local). Claude Code stores all plan files globally, so the hook was silently exiting without emitting the auto-chain signal.
- **plugin-preflight.sh**: Clean up legacy flat-format `yf-*.md` symlinks during full sync, not just during the disabled branch. When upgrading across a marketplace rename with no lock file, dangling symlinks would persist and block rule loading.

## [2.18.0] - 2026-02-14

### Added

- **Coder capability**: Standards-driven code generation with dedicated agents for research, implementation, testing, and review
  - `yf_code_researcher` agent — Read-only; researches technology standards and coding patterns, checks existing IGs before proposing new standards
  - `yf_code_writer` agent — Full-capability; implements code following upstream standards from FINDINGS and IGs
  - `yf_code_tester` agent — Limited-write; creates and runs tests, posts TESTS with pass/fail results
  - `yf_code_reviewer` agent — Read-only; reviews against IGs, coding standards, and quality criteria
  - `code-implement` formula — 4-step pipeline: research-standards → implement → test → review
  - Reactive bugfix inherited from existing swarm infrastructure (TESTS failures and REVIEW:BLOCK trigger bugfix formula)
  - `swarm_select_formula` heuristic: matches `code`, `write`, `program`, `develop` with technology/language context
  - `plan_select_agent` registry updated with 4 new code agents
- **Swarm-to-spec bridge rule**: Advisory suggestion to update specifications after feature-build/build-test/code-implement swarm completes with REVIEW:PASS
- **Swarm-to-chronicle bridge rule**: Auto-captures chronicle when reactive bugfix triggers (not advisory — fires automatically)
- **Progressive chronicle/archive in swarm dispatch**: Opt-in per formula step via `"chronicle": true` / `"archive_findings": true` in step JSON
- **More aggressive chronicle triggers**: 3 new categories — implementation adjustments, swarm execution events, plan compliance adjustments (10-15 min frequency)
- **Spec-test traceability matrix**: `docs/specifications/test-coverage.md` mapping all REQ, DD, NFR, UC to test scenarios
- **Coder IG**: `docs/specifications/IG/coder.md` with UC-029 through UC-032
- Test scenarios: `unit-formula-dispatch.yaml` (7 cases), `unit-swarm-comment-protocol.yaml` (16 cases), `unit-code-implement.yaml` (13 cases)
- Behavioral test enhancements: `unit-swarm-reactive.yaml` (+5), `unit-engineer.yaml` (+5), `unit-archive-suggest.yaml` (+3), `unit-chronicle-check.yaml` (+7)

### Changed

- **Plan pump dual-track dispatch**: `plan_pump/SKILL.md` Step 4 now classifies beads into formula track (swarm_run) and agent track (bare Task); formula labels take priority over agent labels
- **Plan execute formula dispatch**: `plan_execute/SKILL.md` Step 3c dispatches formula-labeled beads via `/yf:swarm_run` before existing agent dispatch path
- **Swarm run enhanced chronicle**: Step 4c Auto-Chronicle (E1) now includes structured execution narrative with formula name, step count, retry attempts, BLOCK verdicts, and step results
- **Swarm archive bridge broadened**: Now fires after any formula completion, not just feature-build
- **Swarm researcher structured sources**: FINDINGS Sources section split into Internal and External subsections
- **Swarm reviewer IG reference**: Reviews now check `docs/specifications/IG/` for relevant implementation guides
- **PRD updated**: Added REQ-032 (coding standards workflow), FS-034 through FS-037 (Coder section)
- **EDD updated**: Added DD-013 (standards-driven code implementation formula design)
- **TODO updated**: Added TODO-019 through TODO-025 for spec-test gaps and coder end-to-end testing
- Plugin version bumped: 2.17.0 → 2.18.0
- `preflight.json`: Added 2 new rules (swarm-chronicle-bridge, swarm-spec-bridge) — 24 rules total

## [2.17.0] - 2026-02-14

### Added

- **Engineer capability**: Synthesize and maintain specification artifacts (PRD, EDD, Implementation Guides, TODO register) from existing project context
  - `/yf:engineer_analyze_project` — Scan plans, diary, research, decisions, and codebase to generate spec documents. Idempotent (no overwrite unless `force`).
  - `/yf:engineer_update` — Add, update, or deprecate individual spec entries (REQ-xxx, DD-xxx, NFR-xxx, UC-xxx, TODO-xxx) with cross-reference suggestions.
  - `/yf:engineer_reconcile` — Check plans against PRD/EDD/IG specs before execution. Fires in auto-chain between plan save and beads creation. Configurable: `blocking` (default), `advisory`, `disabled`.
  - `/yf:engineer_suggest_updates` — Advisory suggestions for spec updates after plan completion.
  - `yf_engineer_synthesizer` agent — Read-only agent that synthesizes spec content (same tool profile as `yf_swarm_researcher`).
  - `watch-for-spec-drift` rule — Advisory monitoring for PRD/EDD/IG drift during work.
  - `engineer-reconcile-on-plan` rule — Auto-chain integration for plan-to-spec reconciliation.
  - `engineer-suggest-on-completion` rule — Triggers spec update suggestions after plan completion.
- Preflight creates `docs/specifications/`, `docs/specifications/EDD/`, `docs/specifications/IG/` directories
- Code-gate exempts `docs/specifications/*` files when plan gate is active
- Plan completion report includes Section 7: Specification Status
- Plan execute step 3.5: suggest spec updates if specs exist

### Changed

- Auto-chain plan rule: step 1.5 reconciles plans against specifications when specs exist
- Plugin description updated to include "specification artifacts"

## [2.16.0] - 2026-02-14

### Changed

- **Zero-question setup**: `/yf:setup` now enables yf silently with no interactive questions. Chronicler and archivist are always on — no longer toggleable.
- **Config simplified**: `chronicler_enabled` and `archivist_enabled` fields removed from config. Old configs are automatically pruned on first preflight run.
- **Setup interface**: `/yf:setup disable` to disable yf, `/yf:setup artifact_dir:<name>` to override artifact directory.

### Removed

- `yf_is_chronicler_on()` and `yf_is_archivist_on()` config functions
- Feature guards for chronicler/archivist in all hooks and scripts
- Conditional rule installation/removal based on feature toggles in preflight
- Test files: `unit-preflight-chronicler.yaml`, `unit-preflight-archivist.yaml`, `unit-archivist-config.yaml`
- Test cases for disabled chronicler/archivist guards across 10 test files

### Added

- Config pruning in preflight: strips deprecated `chronicler_enabled`/`archivist_enabled` fields on first run
- New test case `config_pruning` in `unit-preflight.yaml` verifying the pruning behavior

## [2.15.0] - 2026-02-14

### Added

- **Automatic bead pruning**: Closed beads are automatically cleaned up at two trigger points
  - **Plan-scoped prune**: When `plan-exec.sh status` returns `completed`, closed beads for that plan are soft-deleted (tombstones, 30-day recovery)
  - **Global prune**: After `git push` via PostToolUse hook, all closed beads older than configurable threshold (default: 7 days) are cleaned up, plus closed ephemeral wisps
  - `plan-prune.sh` script with `plan <label>` and `global` subcommands, `--dry-run` support
  - `post-push-prune.sh` PostToolUse hook — runs global prune after push, then `bd sync` to push pruned state to beads-sync
  - Both operations are fail-open (exit 0 always) and configurable via `.yoshiko-flow/config.json`:
    ```json
    { "config": { "auto_prune": { "on_plan_complete": true, "on_push": true, "older_than_days": 7 } } }
    ```
  - `yf_is_prune_on_complete()` and `yf_is_prune_on_push()` config helpers in `yf-config.sh`
- Test scenarios: `unit-plan-prune.yaml` (8 cases), `unit-yf-config.yaml` cases 8-11

### Changed

- Plugin version bumped: 2.14.1 → 2.15.0
- Plugin description updated to include automatic bead pruning
- `plan-exec.sh`: Plan completion path now calls `plan-prune.sh plan` in fail-open subshell
- `plugin.json`: Added `PostToolUse` hook section for `Bash(git push*)` → `post-push-prune.sh`

## [2.14.1] - 2026-02-14

### Added

- **bd-safety-net.sh**: PreToolUse hook on `Bash(bd delete*)` that warns when destructive bd operations lack plan lifecycle or chronicle capture
  - Warns when an incomplete plan exists without beads (missing plan-intake)
  - Warns on bulk deletes (>5 targets) with no open chronicle
  - Advisory only (always exits 0), matching code-gate.sh safety net pattern
- Test scenarios: `unit-bd-safety-net.yaml` (9 scenarios)
- Session-recall.sh plan state check: warns at session start when plan exists without beads

### Changed

- Plugin version bumped: 2.14.0 → 2.14.1
- **plan-intake.md**: Added explicit no-exception language — rule has NO override for agent judgment
- **watch-for-chronicle-worthiness.md**: Added "Database or Infrastructure Operations" capture trigger (bulk bead deletions, migrations, config changes)
- Session-recall.sh: Added plan-without-beads warning and new test cases (Cases 8-9)

## [2.14.0] - 2026-02-13

### Added

- **Implicit swarm formula triggering**: Formulas fire automatically based on lifecycle events, task semantics, and runtime signals
  - T1: Automatic formula selection at bead creation — `/yf:swarm_select_formula` assigns `formula:<name>` labels during `plan_create_beads` Step 8b based on task title keywords
  - T2: Nested formula composition — `compose` field in formula steps triggers sub-swarms (max depth 2), with scoped state tracking in `swarm-state.sh`
  - T3: Reactive bugfix on failure — `/yf:swarm_react` spawns `bugfix` formula on REVIEW:BLOCK or test failures, with retry budget and design-BLOCK exclusion
  - T4: Code review qualification gate — `/yf:swarm_qualify` runs `code-review` formula before plan completion, blocking on REVIEW:BLOCK (configurable: blocking/advisory/disabled)
  - T5: Research spike during planning — advisory rule suggests `research-spike` formula during heavy planning research (3+ web searches)
- 3 new swarm skills: `/yf:swarm_select_formula`, `/yf:swarm_react`, `/yf:swarm_qualify`
- 4 new rules: `swarm-formula-select.md`, `swarm-nesting.md`, `swarm-reactive.md`, `swarm-planning-research.md`
- `plan-exec.sh start` records starting commit SHA as `start-sha:<hash>` label for qualification review scope
- `plan-exec.sh status` returns `qualifying` when all tasks closed but qualification gate still open
- `swarm-state.sh`: Added `mark-retrying` command and `--scope` flag for scoped clear
- `feature-build.formula.json`: Added `compose: "build-test"` on implement step
- `research-spike.formula.json`: Added `planning_safe: true`
- Test scenarios: `unit-swarm-formula-select.yaml`, `unit-swarm-nesting.yaml`, `unit-swarm-reactive.yaml`, `unit-swarm-qualify.yaml`

### Changed

- Plugin version bumped: 2.13.0 → 2.14.0
- `preflight.json`: Added 4 new rules to artifacts (19 total)
- `plan_create_beads/SKILL.md`: Added Step 8b (formula selection) and Step 9c (qualification gate)
- `swarm_dispatch/SKILL.md`: Added compose detection in Step 3, compose dispatch in Step 4, reactive check in Step 6b
- `swarm_run/SKILL.md`: Added `depth` parameter for nesting control
- `plan_execute/SKILL.md`: Added qualification gate check (Step 3e) before completion
- `plan-completion-report.md`: Added Qualification section to report format
- `README.md`: Added Implicit Triggers subsection, updated skill/rule counts
- `DEVELOPERS.md`: Updated swarm capability with 3 new skills

## [2.13.0] - 2026-02-13

### Added

- **Swarm execution capability**: Formula-driven parallel agent workflows using beads formulas, wisps, and molecules
  - 5 formula templates: `feature-build` (research→implement→review), `research-spike` (investigate→synthesize→archive), `code-review` (analyze→report), `bugfix` (diagnose→fix→verify), `build-test` (implement→test→review)
  - 3 swarm agents: `yf_swarm_researcher` (read-only, Explore-typed, posts FINDINGS), `yf_swarm_reviewer` (read-only, posts REVIEW with PASS/BLOCK verdict), `yf_swarm_tester` (test-writing, posts TESTS)
  - 4 swarm skills: `/yf:swarm_run` (full lifecycle entry point), `/yf:swarm_dispatch` (core dispatch loop), `/yf:swarm_status` (active swarm state), `/yf:swarm_list_formulas` (list available formulas)
  - `swarm-state.sh` script — tracks dispatched/done swarm steps to prevent double-dispatch
  - Comment protocol: agents communicate via structured `FINDINGS:`, `CHANGES:`, `REVIEW:`, `TESTS:` comments on parent beads
  - Plan integration: tasks labeled `formula:<name>` auto-dispatch through swarm system
- **Chronicler/archivist integration enhancements**:
  - E1: Swarm completion auto-creates chronicle bead with squash summary
  - E2: Diary agent reads swarm comments (`ys:swarm`-tagged chronicles) for structured evidence
  - E3: `chronicle-check.sh` detects wisp squashes as significant activity
  - E4: `research-spike` formula auto-creates archive bead in final step
  - E5: `swarm-archive-bridge.md` rule suggests archiving swarm output with external sources
  - E6: Researcher agent FINDINGS format aligns with archivist research template
- 3 new rules: `swarm-comment-protocol.md`, `swarm-formula-dispatch.md`, `swarm-archive-bridge.md`
- Test scenario: `unit-swarm-state.yaml`

### Changed

- Plugin version bumped: 2.12.0 → 2.13.0
- Plugin description updated to include swarm execution
- `preflight.json`: Added 3 new rules to artifacts
- `yf_chronicle_diary` agent: Added swarm-aware enrichment (reads step comments)
- `chronicle-check.sh`: Added wisp-squash detection alongside git commit analysis
- `README.md`: Added Swarm Execution section, updated rule/script counts
- `DEVELOPERS.md`: Added swarm capability to capability table

## [2.12.0] - 2026-02-13

### Changed

- **Beads git workflow integration**: `.beads/` transitions from local-only to git-tracked with `beads-sync` branch strategy
  - Reversed the local-only decision from v2.5.0 (Plan 18) — beads now uses git hooks for JSONL sync and a dedicated sync branch
  - `setup-project.sh`: Removed `.beads/` from yf-managed `.gitignore` block (beads manages its own `.beads/.gitignore`)
  - `preflight.json`: `bd init` no longer uses `--skip-hooks`; chains `bd config set sync.branch beads-sync`, mass-delete protection, and `bd hooks install`
  - `plugin-preflight.sh`: Added automatic migration for legacy local-only deployments (detects `.beads/` in yf-managed gitignore, configures sync branch, installs hooks, records migration in lock)
  - `rules/beads.md`: Rewritten — "Beads Are Local" replaced with "Beads Git Workflow" explaining sync branch strategy; `bd sync` added to Quick Reference; session-close protocol includes sync step
  - `README.md`: Updated beads note from "local-only" to "beads-sync branch" description
  - `DEVELOPERS.md`: Updated gitignore managed block example and AGENTS.md cleanup rationale

### Added

- `install-beads-push-hook.sh` script — idempotent installer for pre-push hook that auto-pushes `beads-sync` branch alongside code pushes (fail-open, sentinel-marked, appends to existing hooks)
- Test scenario: `unit-beads-git.yaml` (9 cases) — validates gitignore block, preflight commands, beads.md content, README, hook installer, and setup-project.sh

### Removed

- Test scenario: `unit-beads-local.yaml` — replaced by `unit-beads-git.yaml`

## [2.11.0] - 2026-02-13

### Changed

- **State directory migration: `.claude/` → `.yoshiko-flow/`**: All yf config and state files moved to a dedicated `.yoshiko-flow/` directory
  - Config (`yf.json`) is now committable to git — team members share the same configuration
  - Lock state split into separate `lock.json` (gitignored) — clean separation of config vs ephemeral state
  - State files renamed: `.task-pump.json` → `task-pump.json`, `.plan-gate` → `plan-gate`, `.plan-intake-ok` → `plan-intake-ok`
  - `.yoshiko-flow/.gitignore` auto-created to ignore everything except `yf.json`
  - Automatic migration on first preflight run: splits old `.claude/yf.json` into config + lock, moves state files
  - `.gitignore` managed block simplified (removed yf-specific entries from `.claude/`)
- All scripts updated: `yf-config.sh`, `plugin-preflight.sh`, `pump-state.sh`, `plan-exec.sh`, `setup-project.sh`
- All hooks updated: `code-gate.sh` (added `.yoshiko-flow/` exempt pattern), `exit-plan-gate.sh`
- All skills updated: `setup`, `plan_intake`, `plan_engage`, `plan_dismiss_gate`
- Rule updated: `yf-auto-chain-plan.md` (gate path reference)
- `preflight.json`: Added `.yoshiko-flow` to directories array
- Plugin version bumped: 2.10.0 → 2.11.0

### Added

- Test scenario: `unit-migration.yaml` — validates config/lock split, state file migration, `.gitignore` creation, cleanup, and idempotent re-run

## [2.10.0] - 2026-02-09

### Added

- **Setup-managed `.gitignore` and AGENTS.md cleanup**: Preflight now manages project environment for external installations
  - `setup-project.sh` script — maintains a sentinel-bracketed block of `.gitignore` entries for yf ephemeral files (`.beads/`, `.claude/yf.json`, `.claude/rules/yf-*.md`, etc.)
  - AGENTS.md cleanup — detects and removes conflicting `bd init` / `bd onboard` content (mandatory sync/push language) that conflicts with yf's local-only beads model
  - Idempotent: creates, updates, or skips `.gitignore` block as needed; preserves user entries outside the sentinel block
  - Called from `plugin-preflight.sh` after setup commands, catching drift on every session
  - Fast path extended with gitignore sentinel check
  - Respects `enabled` guard (no-op when yf is disabled), always exits 0 (fail-open)
- Test scenarios: `unit-setup-project.yaml` (10 cases)

### Changed

- `plugin-preflight.sh`: Calls `setup-project.sh all` after setup commands; fast path checks for gitignore sentinel
- `setup` SKILL.md: Documents automatic project environment behavior
- Plugin version bumped: 2.9.0 → 2.10.0

## [2.9.0] - 2026-02-09

### Added

- **Automatic session boundary hooks for chronicler**: Zero-effort context recovery and preservation at session boundaries
  - `session-recall.sh` script — SessionStart hook outputs open chronicle summaries to agent context, detects and consumes `.beads/.pending-diary` marker from previous session
  - `session-end.sh` hook — SessionEnd hook runs `chronicle-check.sh` to create draft beads, writes `.beads/.pending-diary` marker when open chronicles exist
  - `pre-compact.sh` hook — PreCompact hook runs `chronicle-check.sh` to capture work before context erasure
  - All three hooks are fail-open (exit 0 always) and respect `enabled` + `chronicler_enabled` config guards
  - Pending-diary marker bridges sessions: SessionEnd writes it, next SessionStart consumes it and suggests `/yf:chronicle_diary`
- Test scenarios: `unit-session-recall.yaml` (7 cases), `unit-session-end.yaml` (5 cases), `unit-pre-compact.yaml` (5 cases)

### Changed

- `plugin.json`: SessionStart now runs both `preflight-wrapper.sh` and `session-recall.sh`; added `SessionEnd` and `PreCompact` hook event arrays
- Plugin version bumped: 2.8.0 → 2.9.0

## [2.8.0] - 2026-02-08

### Changed

- **Capability-prefixed skill naming convention**: All 17 skills renamed to follow `yf:<capability>_<action>` pattern
  - Chronicler: `yf:capture` → `yf:chronicle_capture`, `yf:recall` → `yf:chronicle_recall`, `yf:diary` → `yf:chronicle_diary`, `yf:disable` → `yf:chronicle_disable`
  - Archivist: `yf:archive` → `yf:archive_capture` (archive_process, archive_disable, archive_suggest unchanged)
  - Plan lifecycle: `yf:engage_plan` → `yf:plan_engage`, `yf:plan_to_beads` → `yf:plan_create_beads`, `yf:execute_plan` → `yf:plan_execute`, `yf:task_pump` → `yf:plan_pump`, `yf:breakdown_task` → `yf:plan_breakdown`, `yf:select_agent` → `yf:plan_select_agent`, `yf:dismiss_gate` → `yf:plan_dismiss_gate`
  - Core: `yf:setup` and `yf:plan_intake` unchanged
- **Capability-prefixed agent naming**: All 3 agents renamed
  - `yf_recall` → `yf_chronicle_recall`, `yf_diary` → `yf_chronicle_diary`, `yf_archivist` → `yf_archive_process`
- All cross-references updated in skills, agents, rules, hooks, scripts, and documentation
- Convention documented in CLAUDE.md for future plugin development
- Plugin version bumped: 2.7.1 → 2.8.0

## [2.7.1] - 2026-02-08

### Fixed

- **Plan detection accuracy**: `chronicle-check.sh` and `archive-suggest.sh` now filter for `exec:executing` label when detecting the active plan, instead of assuming the first open epic is the current plan
- **Silent error swallowing**: `pre-push-diary.sh` now surfaces `chronicle-check.sh` stderr (`2>&1`) instead of discarding it (`2>/dev/null`), making failures visible while remaining non-blocking
- **Fragile arithmetic**: `archive-suggest.sh` open-bead count uses subshell with `set +e` instead of fragile `$(( $(...) ))` arithmetic that could fail on empty input

### Changed

- **`yf-config.sh` consolidation**: Three identical flag-check functions (`yf_is_enabled`, `yf_is_chronicler_on`, `yf_is_archivist_on`) now delegate to a single `_yf_check_flag` helper (78 → 62 lines)
- **`pre-push-diary.sh` deduplication**: Identical chronicle/archive warning blocks replaced with a parameterized `warn_open_beads` function (71 → 60 lines)
- **`plugin-preflight.sh` filter consolidation**: Duplicate `is_chronicle_rule`/`is_archivist_rule` functions merged into a single `is_feature_rule` helper with thin wrappers
- **`plan-exec.sh` cleanup**: Removed dead `COUNT` variable in `start` command (replaced with inline `wc -l`); extracted chronicle gate auto-close logic from `status` into a dedicated `close_chronicle_gates` function
- **`pump-state.sh` simplification**: Removed write-only `done` dict — `mark-done` now simply removes from `dispatched` instead of moving to a second tracking object (76 → 75 lines)
- **`code-gate.sh` early exit**: Beads safety-net subshell now skips entirely when `docs/plans/` doesn't exist or has no plan files, avoiding unnecessary `bd` queries on every Edit/Write
- Plugin version bumped: 2.7.0 → 2.7.1

## [2.7.0] - 2026-02-08

### Added

- **Automatic chronicle creation at pre-push**: Draft chronicle beads are auto-created when significant work is detected, removing the human-in-the-loop for capture decisions
  - `chronicle-check.sh` script — analyzes git commits for keywords, significant file changes, and activity volume
  - Keyword detection: decided, chose, realized, discovered, architecture, pattern, refactored, capability, breaking change, new skill/agent/rule, etc.
  - Significant file detection: changes to plugins/, skills/, agents/, rules/, hooks/, scripts/, docs/plans/, CLAUDE.md, CHANGELOG.md, etc.
  - High activity volume detection: 5+ commits in the analysis window
  - Daily dedup via `.beads/.chronicle-drafted-YYYYMMDD` file (prevents duplicate drafts on repeated pushes)
  - Auto-tags drafts with `plan:<idx>` when a plan is executing
  - Two modes: `check` (returns count) and `pre-push` (formatted output)
  - Labels: `ys:chronicle,ys:chronicle:draft` (plus optional plan label)
- **Diary agent draft handling**: `yf_diary` agent now triages draft chronicle beads
  - Evaluates each draft for chronicle-worthiness
  - Enriches worthy drafts with full context from git history and file contents
  - Closes non-worthy drafts with reason
  - Consolidates duplicate drafts into single enriched entries
- Test scenarios: `unit-chronicle-check.yaml` (7 cases), `unit-pre-push-chronicle-check.yaml` (3 cases)

### Changed

- `pre-push-diary.sh` hook now calls `chronicle-check.sh pre-push` before the advisory warning — drafts are **created**, not just warned about
- Plugin version bumped: 2.6.0 → 2.7.0

## [2.6.0] - 2026-02-08

### Added

- **Archivist capability**: Captures research findings and design decisions as permanent, indexed documentation
  - `/yf:archive type:<type> [area:<area>]` — Create archive beads for research findings or design decisions with structured templates
  - `/yf:archive_process [plan_idx]` — Process archive beads into `docs/research/` and `docs/decisions/` SUMMARY.md files with indexes
  - `/yf:archive_disable` — Close open archive beads without generating documentation
  - `/yf:archive_suggest [--draft] [--since]` — Scan git history for archive candidates (research/decision keywords)
  - `yf_archivist` agent — Converts archive beads into structured documentation with index management
  - `yf-watch-for-archive-worthiness.md` rule — Monitors for research and decision events worth archiving
  - `yf-plan-transition-archive.md` rule — Archives research/decisions during plan auto-chain transitions
  - `archive-suggest.sh` script — Commit scanner for research/decision activity keywords
- **Config-aware archivist**: `config.archivist_enabled` flag (default: true) controls archivist rule installation
  - `yf_is_archivist_on()` function in `yf-config.sh`
  - Preflight conditionally installs/removes archivist rules based on config
  - `/yf:setup` asks archivist configuration question (Q4)
- **Archive output structure**: `docs/research/<topic>/SUMMARY.md` and `docs/decisions/DEC-NNN-<slug>/SUMMARY.md` with `_index.md` files
- **Beads label scheme**: `ys:archive`, `ys:archive:research`, `ys:archive:decision`, `ys:archive:draft`, `ys:area:<slug>`
- **Lifecycle integration**:
  - `pre-push-diary.sh` warns about open archive beads (advisory, non-blocking)
  - `execute_plan` completion step processes archive beads into documentation
  - `code-gate.sh` exempts `docs/research/` and `docs/decisions/` paths
- Test scenarios: `unit-archivist-config.yaml`, `unit-preflight-archivist.yaml`, `unit-archive-suggest.yaml`, `unit-pre-push-archive.yaml`

### Changed

- Plugin version bumped: 2.5.0 → 2.6.0
- Plugin description updated to include research/decision archiving
- `preflight.json`: Added archivist rules and `docs/research`, `docs/decisions` directories

## [2.5.0] - 2026-02-08

### Changed

- **Beads local-only**: `.beads/` is now gitignored and not committed to git
  - Removed `sync-branch` and `daemon.auto-sync` from `.beads/config.yaml`
  - Deleted `beads-sync` branch (local and remote) and associated worktree
  - Removed all beads git hooks (pre-commit, post-merge, post-checkout, pre-push, prepare-commit-msg)
- **`yf-beads.md` rule rewrite**: Removed mandatory `bd sync` and `git push` language
  - Added "Beads Are Local" section explaining local-only model
  - Session close no longer auto-pushes; push only when user requests
  - Removed "Work is NOT complete until git push succeeds" enforcement
- **Preflight setup**: `bd init` → `bd init --skip-hooks` (git hooks serve no purpose in local-only mode)
- Plugin version bumped: 2.4.0 → 2.5.0

### Fixed

- Stale `/yf:init` references in agents and skills updated to `/yf:setup`

### Removed

- Git tracking of `.beads/` directory (14 files untracked via `git rm --cached`)
- `beads-sync` branch and worktree
- Beads git hooks (`.beads/hooks/*`)
- `bd sync` references from rules and quick reference

## [2.4.0] - 2026-02-08

### Changed

- **Symlink-based rule management**: Preflight now creates symlinks in `.claude/rules/` pointing to plugin source files instead of copying them
  - Single source of truth — edits to `plugins/yf/rules/` are immediately active
  - Eliminates checksum/conflict detection (symlinks can't diverge)
  - Fast path uses `readlink` comparison instead of SHA256 checksums
  - Relative symlinks when plugin is in project tree, absolute when outside
- **Single-file config model**: All config consolidated into `.claude/yf.json` (gitignored)
  - Replaced prior two-file model (`yf.json` + `yf.local.json`) with a single gitignored `yf.json`
  - Holds both user config (`enabled`, `config.artifact_dir`, `config.chronicler_enabled`) and preflight lock state
  - Setup skill (`/yf:setup`) simplified — removed "share config?" question, all writes go to `yf.json`
- **Zero git footprint**: Rule symlinks and config are gitignored — enabling the plugin leaves no committed artifacts outside `plugins/`
- **Lock format**: `mode: "symlink"` field, `link` field replaces `checksum` per rule entry
- `plugin-preflight.sh` reduced from ~455 to ~180 lines
- Plugin version bumped: 2.3.0 → 2.4.0
- **Documentation audit**: Aligned versions and content across all project documentation
  - `README.md`: Bumped version, added missing skills (`/yf:task_pump`, `/yf:plan_intake`, `/yf:setup`), added `tests/` to repo structure
  - `plugins/yf/README.md`: Added version, missing skills, Configuration section, fixed lifecycle table
  - `CLAUDE.md`: Added `tests/` to structure, switched to relative paths, clarified symlink-based rules
  - `marketplace.json`: Bumped marketplace and plugin versions to 2.4.0

### Removed

- Checksum calculation and comparison logic (`sha256_file()`)
- Conflict detection ("modified by user, skipping update")
- File copy operations (replaced by `ln -sf`)
- Two-file config model (`yf.json` + `yf.local.json`) — replaced by single `yf.json`
- All legacy migration logic (plugin-lock.json v0, yf.json v1, yf.local.json v2)
- `unit-preflight-conflict.yaml`, `unit-yf-config-merge.yaml`, `unit-yf-migration.yaml`, `unit-yf-v2-migration.yaml` test scenarios

### Added

- `unit-preflight-symlinks.yaml` — 6 test cases for symlink-specific behavior (creation, broken symlink repair, copy→symlink migration, target validation, content resolution, fast-path detection)
- `unit-yf-config.yaml` — 7 test cases for single-file config reading
- Copy-to-symlink migration: regular files (from older versions) automatically replaced by symlinks on preflight run

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

## [2.1.0] - 2026-02-08

### Added

- **`/yf:setup` skill**: Interactive configuration wizard for per-project setup
  - Asks 3 questions via `AskUserQuestion`: enable YF, artifact directory, chronicler enabled
  - Merges answers into `yf.json` without overwriting `preflight` section
  - Idempotent — works for both first-run and reconfiguration
- **Config-aware preflight**: Rules conditionally installed based on configuration
  - `enabled=false` removes all rule symlinks from the project
  - `chronicler_enabled=false` skips chronicle-specific rules (`yf-watch-for-chronicle-worthiness.md`, `yf-plan-transition-chronicle.md`)
- **`YF_SETUP_NEEDED` signal**: Preflight outputs this when no `yf.json` exists and no old lock file to migrate, prompting user to run `/yf:setup`
- Test scenarios: `unit-preflight-chronicler.yaml`, `unit-preflight-disabled.yaml`, `unit-preflight-setup.yaml`

### Changed

- **Self-contained preflight**: Moved `plugin-preflight.sh` from marketplace root (`scripts/`) into the plugin (`plugins/yf/scripts/`). Resolves its own plugin root via `BASH_SOURCE` — works identically from source tree or Claude Code plugin cache
- **Enabled guards in hooks**: All 4 behavioral hooks (`code-gate.sh`, `exit-plan-gate.sh`, `plan-exec-guard.sh`, `pre-push-diary.sh`) exit 0 immediately when `enabled=false` in `yf.json`
  - `pre-push-diary.sh` has additional `chronicler_enabled` guard
- Plugin version bumped: 2.0.0 → 2.1.0

### Removed

- Marketplace-level `scripts/plugin-preflight.sh` (404 lines) — replaced by self-contained version in plugin (389 lines)

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
- Split `plugin.json` into `plugin.json` + `preflight.json` for Claude Code strict schema compliance
  - `plugin.json` contains only official Claude Code schema fields (name, version, hooks, etc.)
  - `preflight.json` contains custom fields (`dependencies`, `artifacts`) used by the preflight system
  - Fixes plugin installation failure via Claude Code's `/plugin` command
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
- `workflows` plugin: Auto-chain plan lifecycle triggered by ExitPlanMode
  - `auto-chain-plan.md` rule — drives full lifecycle (plan_to_beads → plan-exec.sh start → execute_plan) when ExitPlanMode fires
  - `exit-plan-gate.sh` now outputs "Auto-chaining" signal with parseable `PLAN_IDX`/`PLAN_FILE` for the rule to consume
  - Hook + rule mechanism: shell hook handles deterministic work (save plan, create gate), behavioral rule drives AI-dependent steps (beads creation, execution)
  - If user explicitly says "engage the plan" (gate already exists), hook exits silently and auto-chain does NOT double-fire
- `chronicler` plugin: `plan-transition-chronicle.md` rule — captures planning context as a chronicle bead between plan save and beads creation during auto-chain

### Changed

- `engage-the-plan.md` rule: Draft triggers removed (now handled by auto-chain); kept Pause/Resume/Complete
- `engage_plan` SKILL.md: Draft section annotated as legacy fallback
- Updated workflows plugin to v1.2.0
- Test scenario: `unit-exit-plan-gate.yaml` — added auto-chain output format case

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
