# Engineering Design Document

## Overview

D3 Claude Plugins implements a plugin marketplace for Claude Code with the Yoshiko Flow (yf) plugin as its primary offering. The architecture is built on six artifact types (skills, agents, rules, scripts, hooks, preflight), with beads-cli as the external persistence layer and Claude Code's plugin system as the runtime environment.

## Architecture

### System Layers

```
+---------------------------------+
|  Claude Code Runtime            |
|  (plugin discovery, hooks,      |
|   skill/agent auto-discovery)   |
+-----------+---------------------+
            |
+-----------v---------------------+
|  Activation Gate                |
|  (three-condition check:        |
|   config + enabled + beads)     |
+-----------+---------------------+
            |
+-----------v---------------------+
|  Marketplace Layer              |
|  (.claude-plugin/marketplace.   |
|   json, plugin registry)        |
+-----------+---------------------+
            |
+-----------v---------------------+
|  YF Plugin Layer                |
|  (skills, agents, rules,        |
|   scripts, hooks, formulas)     |
+-----------+---------------------+
            |
+-----------v---------------------+
|  Beads Persistence Layer        |
|  (.beads/dolt/, embedded dolt,  |
|   immediate write persistence)  |
+-----------+---------------------+
            |
+-----------v---------------------+
|  Project Artifacts Layer        |
|  (docs/plans, docs/diary,       |
|   docs/research, docs/decisions,|
|   docs/specifications)          |
+----------------------------------+
```

### Enforcement Model

The system uses a layered enforcement approach:

1. **Hooks (mechanical)**: PreToolUse/PostToolUse shell scripts that block or warn on operations. Exit code semantics: 0=allow, 2=block. Always fail-open on internal errors.
2. **Rules (behavioral)**: Markdown files loaded into agent context. The agent reads and follows them. No performance cost, relies on agent compliance.
3. **Scripts (deterministic)**: Shell scripts for state transitions, config access, and data analysis. Called from hooks, skills, and rules.
4. **Beads (persistent)**: Git-backed issue tracker providing gates, dependencies, labels, and deferred state.
5. **Activation gate (skill-level)**: `yf-activation-check.sh` outputs JSON status; skills read and refuse when inactive. Defense-in-depth -- hooks also enforce via `yf_is_enabled`.

### Data Flow

```
Plan Mode -> ExitPlanMode hook -> plan-gate created
  -> auto-chain rule -> format plan -> reconcile specs
  -> plan_create_beads -> beads DAG created
  -> plan-exec.sh start -> gate removed, tasks undeferred
  -> plan_execute -> plan_pump -> Task tool dispatch
  -> agents claim/work/close beads
  -> chronicle capture at boundaries
  -> plan complete -> diary generated, beads pruned
```

## Design Decisions

### DD-001: Beads as Persistent Task Store, Not Claude Native Tasks

**Context**: Claude Code offers TaskCreate/TaskList for task management and the Task tool with `subagent_type` for agent dispatch. The system needed persistent, cross-session task tracking with dependencies.

**Decision**: Use beads-cli as the persistent store for all plan work. The Task tool with `subagent_type` is the execution mechanism. TaskCreate/TaskList is not used.

**Rationale**: Beads are git-backed and persist across sessions, machines, and context compaction. They support rich metadata (labels, notes, design, acceptance criteria), querying/filtering, and dependency ordering. Native Tasks are session-scoped and ephemeral.

**Consequences**: External dependency on beads-cli. All task state management goes through `bd` commands. The task pump bridges beads and Claude's Task tool.

**Source**: Plan 07 (diary `26-02-07.22-50.architecture.md`)

### DD-002: Symlink-Based Rule Management

**Context**: The preflight system originally copied rule files from the plugin into `.claude/rules/`, maintaining checksums for conflict detection. This left committed artifacts in the project's git history and required complex sync logic (~455 lines).

**Decision**: Replace file copies with symlinks. Rules in `.claude/rules/yf/` are symlinks pointing back to `plugins/yf/rules/`. All rule symlinks are gitignored.

**Rationale**: Single source of truth -- edits to plugin source rules are immediately active without re-syncing. Eliminates the entire checksum/conflict detection system. Script reduced from ~455 to ~180 lines. Zero git footprint outside `plugins/`.

**Consequences**: Symlinks must resolve correctly on the target OS (verified on macOS/Linux). When plugin is loaded from a cache outside the project tree, absolute symlinks are used instead of relative. The `compute_link_target()` function handles this distinction.

**Source**: Plan 17, diary `26-02-08.19-00.symlink-preflight.md`

### DD-003: Dolt-Native Persistence (Reversed from Sync Branch)

**Context**: v2.5.0 (Plan 18) made `.beads/` local-only. v2.12.0 (Plan 27) reversed with a `beads-sync` git branch. beads v0.52.0 introduced dolt backend where writes persist immediately, making `bd sync`, JSONL export hooks, and the beads-sync branch all obsolete.

**Decision**: Beads uses an embedded dolt database (`.beads/dolt/beads/`) that persists writes immediately. The dolt database is gitignored. Version control uses `bd vc commit/status/merge`. Setup is just `bd init` -- no hooks, no sync branch.

**Rationale**: Dolt eliminates the entire sync layer. No merge conflicts on JSONL, no sync branch maintenance, no hooks redirecting core.hooksPath, no `bd sync` in session protocols. All five beads git hooks are no-ops in dolt mode.

**Consequences**: `bd sync` is a no-op. `core.hooksPath` stays at default. Session close protocol omits sync step. Setup simplified from `bd init && bd config set sync.branch ... && bd hooks install` to `bd init`.

**Source**: Plan 27, Plan 45, beads v0.52.0

### DD-004: Auto-Chain Lifecycle on ExitPlanMode

**Context**: The plan lifecycle originally required 4 manual steps after designing a plan (save, create beads, start execution, begin dispatch). Users frequently bypassed steps or forgot the sequence.

**Decision**: ExitPlanMode triggers an automatic chain: hook saves plan and creates gate -> rule drives format -> reconcile specs -> create beads -> start execution -> begin dispatch. No user input between steps.

**Rationale**: Reduces friction from 4 manual steps to zero. The plan-intake rule serves as a fallback for when auto-chain does not fire (pasted plans, new sessions, bypassed ExitPlanMode).

**Consequences**: The auto-chain depends on the ExitPlanMode hook firing. A behavioral rule (plan-intake.md) catches scenarios where it does not fire. The rule has explicit no-exception language after a real-world bypass incident (Plan 30/31).

**Source**: Plan 08, Plan 11, Plan 31

### DD-005: Hook + Rule Mechanism for Plan Enforcement

**Context**: The system needs both deterministic enforcement (block operations that violate state) and advisory guidance (suggest actions based on context). Hooks add latency to tool calls; rules have zero performance cost but rely on agent compliance.

**Decision**: Use hooks for deterministic enforcement (code-gate.sh blocks edits, plan-exec-guard.sh blocks task ops) and rules for behavioral guidance (engage-the-plan, plan-intake, watch-for-chronicle-worthiness). Rules are preferred over hooks when advisory behavior suffices.

**Rationale**: Hooks fire on every tool call and add latency. Rules fire based on context with zero performance cost. The combination provides mechanical enforcement where needed and lightweight guidance elsewhere.

**Consequences**: Some behaviors rely on agent compliance (e.g., plan-intake rule). The bd-safety-net hook (Plan 31) was added as a mechanical backstop after a real-world rule bypass.

**Source**: Plan 05, Plan 11, diary `26-02-08.12-30.lifecycle-resilience.md`

### DD-006: Formula-Driven Swarm Execution with Wisps

**Context**: The plan lifecycle dispatches tasks one-at-a-time to agents. But many tasks have internal structure (research before implementation, review after). Running these as separate beads loses tight coupling.

**Decision**: Use beads formulas to define reusable multi-agent workflow templates. Formulas are instantiated as wisps (ephemeral molecules). Agents communicate via structured comments on the parent bead. Results survive wisp squashing.

**Rationale**: Formulas are reusable templates. Wisps keep orchestration ephemeral (not synced via git). Comments provide a readable audit trail. Six formulas cover common patterns: feature-build, research-spike, code-review, bugfix, build-test, code-implement (see DD-013).

**Consequences**: Requires beads-cli >= 0.50.0 (see TC-003). SUBAGENT annotations in formula descriptions are parsed by the dispatch skill (not by beads). Formula JSON files live at `plugins/yf/formulas/`.

**Source**: Plan 28, diary `26-02-13.22-30.swarm-execution.md`

### DD-007: Heuristic-Based Formula Auto-Selection

**Context**: Swarm formulas initially required manual `formula:<name>` labeling or explicit invocation. This created friction and inconsistency.

**Decision**: Auto-assign formula labels during `plan_create_beads` Step 8b using keyword heuristics (implement->feature-build, fix->bugfix, research->research-spike, etc.). Atomic tasks are skipped.

**Rationale**: Simpler, more predictable, and easier to debug than ML/embedding approaches. Author overrides via explicit `formula:X` labels are respected.

**Consequences**: Heuristic may mis-assign formulas for ambiguous task titles. The swarm-formula-select rule documents the heuristic table for transparency.

**Source**: Plan 29, diary `26-02-13.23-25.implicit-swarm-triggers.md`

### DD-008: Zero-Question Setup with Always-On Capabilities

**Context**: The `/yf:setup` wizard originally asked 4 interactive questions (enable yf, artifact dir, chronicler, archivist). Chronicler and archivist were always enabled in practice.

**Decision**: Remove all interactive questions. Setup enables everything silently with `docs/` as default artifact dir. Old config fields (`chronicler_enabled`, `archivist_enabled`) are auto-pruned on first preflight run.

**Rationale**: The toggle served no real purpose since both features were recommended-on by default, and the conditional branches they guarded were effectively dead code. Removing ~80 lines of feature-toggle logic from preflight.

**Consequences**: No per-feature opt-out. `/yf:setup disable` disables the entire plugin. Config pruning handles legacy configs silently.

**Source**: Plan 33, diary `26-02-14.14-30.simplify-setup.md`

### DD-009: Blocking Specification Reconciliation (Default)

**Context**: The engineer capability reconciles plans against existing specifications. The enforcement mode needed to be configurable.

**Decision**: Reconciliation mode defaults to `blocking` but is configurable as `advisory` or `disabled`. No specs means no enforcement (zero cost for projects that do not opt in).

**Rationale**: Conservative default protects specification integrity. Advisory mode allows projects to see drift without blocking execution. Disabled mode supports projects that do not use specification artifacts.

**Consequences**: Projects with specs must configure reconciliation mode explicitly if they want non-blocking behavior.

**Source**: Plan 34, diary `26-02-14.18-00.engineer-capability.md`

### DD-010: Plugin Consolidation (workflows + chronicler -> yf)

**Context**: The system started as three separate plugins (roles, workflows, chronicler). The roles plugin was non-functional, and the workflows and chronicler plugins were tightly coupled.

**Decision**: Consolidate into a single `yf` (Yoshiko Flow) plugin. Delete the roles plugin entirely (its sole role became a rule). Rename all skills to `yf:<capability>_<action>` and agents to `yf_<capability>_<role>`.

**Rationale**: Reduces cross-plugin coupling, simplifies dependency management, and provides a clean namespace hierarchy. Single plugin manifest, single preflight run, single version.

**Consequences**: Breaking change for users of the old skill/agent names. Lock file migration handles the transition automatically.

**Source**: Plan 09, Plan 13, Plan 21

### DD-011: Soft-Delete Bead Pruning with Fail-Open Semantics

**Context**: Closed beads accumulate over time (278 found in Plan 30 gap analysis). Manual pruning confirmed all content was duplicated in diary entries, plan docs, and CHANGELOG.

**Decision**: Automatic pruning at two trigger points: plan-scoped on completion, global on push. Soft-delete only (tombstones with 30-day recovery window). Both operations are fail-open and configurable.

**Rationale**: Tombstones prevent resurrection issues. PostToolUse hook (not PreToolUse) ensures code is safely remote before cleanup.

**Consequences**: Requires `bd admin cleanup` support in beads-cli. Config keys `auto_prune.on_plan_complete` and `auto_prune.on_push` provide escape hatches.

**Source**: Plan 30, Plan 32, diary `26-02-14.12-00.automatic-bead-pruning.md`

### DD-012: State Directory Migration (.claude/ -> .yoshiko-flow/)

**Context**: yf stored config and state in `.claude/` alongside Claude Code's own files. This coupled plugin state to the IDE directory and made config unshared.

**Decision**: Move to a dedicated `.yoshiko-flow/` directory. Split config (committed `config.json`) from lock state (gitignored `lock.json`). Rule symlinks remain in `.claude/rules/` (Claude Code's discovery location).

**Rationale**: Separates concerns, enables team-shared config via git, isolates ephemeral state behind its own `.gitignore`.

**Consequences**: Migration logic moves old `.claude/yf.json` + state files on first preflight run. All scripts, hooks, and skills updated to reference new paths.

**Source**: Plan 24

### DD-013: Standards-Driven Code Implementation Formula

**Context**: Implementation tasks were handled by generic agents without technology-specific standards, dedicated review criteria, or test feedback loops. The existing `feature-build` formula focuses on codebase research, while coding tasks need upstream standards research.

**Decision**: Create a `code-implement` formula with four specialized agents: code-researcher (read-only, IG + standards research), code-writer (full-capability, standards-following implementation), code-tester (limited-write, test creation and execution), code-reviewer (read-only, IG + standards compliance review). Research step checks for existing IGs before proposing new standards.

**Rationale**: Separating concerns across specialized agents enforces standards compliance at each stage. The IG-first approach ensures new code follows documented patterns. Reactive bugfix is inherited from existing swarm infrastructure (TESTS failures and REVIEW:BLOCK trigger bugfix formula via `swarm_react`).

**Consequences**: Additional overhead per coding task (4 agent invocations vs 1). Only justified for non-trivial implementation tasks — atomic tasks use bare agent dispatch. The `swarm_select_formula` heuristic distinguishes code-implement from feature-build by technology/language context.

**Source**: Plan 35, Phase 5

### DD-014: Specifications as Anchor Documents

**Context**: Specifications are living documents that drift when plans add new capabilities, tests reference only implementation details, and structural consistency goes unchecked. Manual reviews caught systemic drift but no gates prevented recurrence.

**Decision**: Specifications are the contract. Plans conform to specs, not vice versa. New capabilities require spec additions before or during implementation. All spec changes require explicit operator approval. A mechanical sanity check script validates six structural dimensions. Default sanity check mode is `blocking`, consistent with reconciliation default (DD-009).

**Rationale**: Conservative default treats specs as anchor documents. Blocking mode catches drift at lifecycle boundaries (plan intake and completion) rather than after the fact. Advisory mode remains available for projects with pre-existing inconsistencies.

**Consequences**: The plan intake checklist (Step 1.5) adds operator approval gates that may slow plan startup. The structural checks are fail-open (exit 0 always) and configurable via `.config.engineer.sanity_check_mode`.

**Source**: Plan 40

### DD-015: Three-Condition Activation Model

**Context**: yf activated on every project where installed, even without setup. G7 said "fail-open" which conflated hook behavior (always exit 0 on errors) with activation behavior (enabled by default).

**Decision**: Separate hook fail-open (TC-005, unchanged) from activation fail-closed. Three conditions: config exists + enabled:true + bd CLI available. `yf_is_enabled()` enforces all three. `_yf_check_flag` remains fail-open for optional sub-config flags.

**Rationale**: User-scope installation should not impose yf on every project. Explicit activation (`/yf:setup`) is the only entry point. The bd CLI provides the task tracking infrastructure that yf depends on.

**Consequences**: Projects without explicit setup become inactive. `YF_SETUP_NEEDED` signal in preflight guides users. Existing projects with `config.json` and `enabled: true` remain active if bd CLI is available.

**Source**: Plan 42

### DD-016: Hybrid Beads Routing — **Reversed**

**Context**: yf references `bd` CLI commands in rules, skills, and shell scripts. The beads plugin provided agent-facing skills (`/beads:create`, `/beads:close`, etc.) that offered richer context.

**Decision**: **Reversed.** The beads plugin (`steveyegge/beads`) has been uninstalled. All operations use `bd` CLI directly. yf's own rules provide the authoritative workflow context, and all bd operations are called directly from rules, skills, and shell scripts.

**Rationale**: The beads plugin was only providing: (1) an activation gate check against `installed_plugins.json`, (2) a `dependencies` declaration in `preflight.json`, (3) `bd prime` context injection hooks, and (4) thin skill wrappers. None of these are needed since yf's own rules provide the authoritative workflow context and all bd operations are called directly.

**Consequences**: No beads plugin dependency. Activation gate checks for `bd` CLI availability instead of plugin registry. `preflight.json` has no `dependencies` array.

**Source**: Plan 42 (original), Plan 47 (reversed)

### DD-017: Session Close Enforcement via Blocking Hook + Orchestrator Skill

**Context**: The session close protocol (Rule 4.2, UC-028) was a behavioral rule with no mechanical enforcement. Agents could skip commits, forget to push, or start plans with uncommitted changes. The beads `bd prime` SESSION CLOSE PROTOCOL still referenced `bd sync` (a no-op after DD-003).

**Decision**: Add mechanical enforcement: a blocking pre-push hook (`pre-push-land.sh`) that checks for uncommitted changes and in-progress beads before allowing push, plus an orchestrator skill (`/yf:session_land`) that runs the full close-out checklist. Suppress the beads `bd prime` SESSION CLOSE PROTOCOL via `no-git-ops` beads config since yf manages the git workflow.

**Rationale**: Behavioral rules alone are insufficient for critical session-boundary operations. The hook provides a mechanical backstop (consistent with DD-005: hook + rule enforcement model). The skill provides an invocable entry point for the full checklist. Suppressing `bd prime` git ops eliminates confusion about which protocol to follow.

**Consequences**: `git push` is blocked until the working tree is clean and all beads are closed or updated. The `bd prime` SESSION CLOSE PROTOCOL no longer includes `bd sync` or `git push` steps. Dirty-tree markers bridge uncommitted state across sessions.

**Source**: Plan 46

## Non-Functional Requirements

### NFR-001: Preflight Performance

**Requirement**: The preflight fast path must complete in under 50ms when all artifacts are up to date.

**Measure**: Wall-clock time from SessionStart hook invocation to preflight exit when version, rule count, and symlink targets all match.

**Source**: Plan 10, Plan 17

### NFR-002: Fail-Open Reliability

**Requirement**: All hooks and scripts must exit 0 on internal errors. Plugin infrastructure must never block user operations.

**Measure**: Every hook wraps error-prone operations in `set +e` subshells with `|| true` guards. No hook returns exit code 2 on internal error.

**Source**: All plans, explicit in TC-005

### NFR-003: Bash 3.2 Compatibility

**Requirement**: All shell scripts must work on macOS's default bash 3.2. No bashisms from bash 4+ (associative arrays, `|&`, etc.).

**Measure**: `bash --version` returns 3.2.x on macOS. All scripts pass `bash -n` syntax check.

**Source**: Plan 17 (awk for block replacement instead of macOS sed quirks)

### NFR-004: Zero Git Footprint

**Requirement**: Enabling the plugin must leave no committed artifacts outside `plugins/` and `.yoshiko-flow/config.json`. Rule symlinks, lock state, and ephemeral state files must be gitignored.

**Measure**: `git status` shows no untracked or modified files after plugin activation (excluding config.json).

**Source**: Plan 17, DD-002

### NFR-005: Idempotent Operations

**Requirement**: All setup, preflight, migration, and pruning operations must be idempotent -- safe to re-run without side effects.

**Measure**: Running any operation twice in succession produces the same state as running it once.

**Source**: Plan 10, Plan 33

### NFR-006: Test Coverage

**Requirement**: All new capabilities must include automated test scenarios. Minimum 486 unit tests across the test suite.

**Measure**: `bash tests/run-tests.sh --unit-only` passes all tests. Each new plan adds test scenarios.

**Source**: Plan 06, DEVELOPERS.md

### NFR-007: Migration Safety

**Requirement**: Config format changes must include automatic migration logic that preserves user settings. No manual intervention required.

**Measure**: Migration test scenarios validate old-format-to-new-format transitions. Stale files are cleaned up. Chain migrations work (v0 -> v1 -> v2 -> v3).

**Source**: Plan 13, Plan 15, Plan 17, Plan 24, Plan 26
