# Product Requirements Document (PRD)

## 1. Purpose & Goals

### 1.1 Product Vision

D3 Claude Plugins is a plugin marketplace for Claude Code that automates the organizational discipline required to keep software maintainable. The primary plugin, Yoshiko Flow (yf), freezes the context that makes software maintainable -- structured plans, captured rationale, and archived research -- so knowledge survives beyond the session that produced it.

### 1.2 Problem Statement

Agentic coding generates context faster than humans can catalog it. Each Claude Code session starts with a blank slate -- insights, rationale, research findings, and working state accumulated during a session vanish on compaction, context clear, or session end. Plans written in sessions disappear. Design decisions are buried in conversation history. Research findings are lost once the conversation ends.

### 1.3 Goals

- G1: Provide a plugin marketplace architecture for Claude Code that supports multiple independent plugins with namespace isolation
- G2: Convert plans into persistent, dependency-ordered task graphs that survive across sessions and machines
- G3: Automate context capture and diary generation at lifecycle boundaries with zero manual intervention
- G4: Preserve research findings and design decisions as permanent, indexed documentation
- G5: Enable structured multi-agent workflows using formula-driven swarm execution
- G6: Synthesize and maintain living specification documents (PRD, EDD, IG, TODO) from project context
- G7: Achieve zero-configuration setup with fail-open hooks and explicit per-project activation

## 2. Technical Constraints

- TC-001: All shell scripts must be bash 3.2 compatible (macOS default)
- TC-002: Scripts use jq for JSON processing (external dependency)
- TC-003: beads-cli >= 0.50.0 required for issue tracking (external dependency); beads Claude Code plugin (`steveyegge/beads`) required for agent-facing task operations; `dolt` backend required (default since 0.50.0)
- TC-004: Plugin must work within Claude Code's plugin system (plugin.json strict schema, auto-discovered skills/agents)
- TC-005: Hooks must be fail-open (exit 0 always) -- never block user operations on internal errors
- TC-006: Rules are behavioral guidance (agent compliance) -- hooks provide mechanical enforcement
- TC-007: All ephemeral state must be gitignored; only committed config is `.yoshiko-flow/config.json`
- TC-008: Symlink-based rule management -- single source of truth in plugin source, no file copies
- TC-009: Beads state synchronized via `beads-sync` git branch -- code branches stay clean
- TC-010: The plugin system uses `${CLAUDE_PLUGIN_ROOT}` for path resolution in hook commands

## 3. Requirement Traceability Matrix

| ID | Requirement | Priority | Capability | Source | Code Reference |
|----|-------------|----------|------------|--------|----------------|
| REQ-001 | Plugin marketplace must support multiple plugins with namespace isolation (colon for skills, underscore for agents, hyphen for rules) | P0 | Marketplace | Plan 01, Plan 13, Plan 21 | `/Users/james/workspace/dixson3/d3-claude-plugins/DEVELOPERS.md` |
| REQ-002 | Preflight system must automatically install/update/remove rule symlinks on SessionStart with <50ms fast path | P0 | Marketplace | Plan 10, Plan 17 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plugin-preflight.sh` |
| REQ-003 | Plans must be convertible into a beads hierarchy (epics, tasks, dependencies, gates) with agent assignments | P0 | Plan Lifecycle | Plan 03, Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_create_beads/SKILL.md` |
| REQ-004 | Plan lifecycle must enforce state transitions: Draft -> Ready -> Executing <-> Paused -> Completed | P0 | Plan Lifecycle | Plan 03, Plan 05 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh` |
| REQ-005 | Code-gate hook must block Edit/Write on implementation files when plan is saved but not yet executing | P0 | Plan Lifecycle | Plan 05 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/code-gate.sh` |
| REQ-006 | ExitPlanMode must auto-chain the full lifecycle: format plan -> reconcile specs -> create beads -> start execution -> begin dispatch | P0 | Plan Lifecycle | Plan 08 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/auto-chain-plan.md` |
| REQ-007 | Plan intake rule must catch pasted/manual plans and route through proper lifecycle regardless of entry path | P0 | Plan Lifecycle | Plan 11, Plan 31 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-intake.md` |
| REQ-008 | Task pump must read `bd ready`, group by `agent:<name>` label, and dispatch parallel Task tool calls with appropriate subagent_type | P0 | Plan Lifecycle | Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_pump/SKILL.md` |
| REQ-009 | Chronicle beads must be captured automatically at session boundaries (SessionStart, SessionEnd, PreCompact) and plan lifecycle boundaries | P1 | Chronicler | Plan 11, Plan 22, Plan 25 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/chronicle-check.sh` |
| REQ-010 | Open chronicle summaries must be output to agent context on SessionStart for automatic context recovery | P1 | Chronicler | Plan 22 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/session-recall.sh` |
| REQ-011 | Chronicle beads must be composable into diary entries -- permanent markdown narratives of how and why changes were made | P0 | Chronicler | Plan 02, Plan 12 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/chronicle_diary/SKILL.md` |
| REQ-012 | Chronicle gate beads must prevent diary generation until plan execution completes, ensuring full-arc diary entries | P1 | Chronicler | Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh` |
| REQ-013 | Research findings must be capturable as archive beads and processable into indexed `docs/research/<topic>/SUMMARY.md` files | P1 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_capture/SKILL.md` |
| REQ-014 | Design decisions must be capturable as archive beads and processable into indexed `docs/decisions/DEC-NNN-<slug>/SUMMARY.md` files | P1 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_process/SKILL.md` |
| REQ-015 | Git history must be scannable for archive candidates (research/decision keywords in commits) | P2 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/archive-suggest.sh` |
| REQ-016 | Swarm formulas must define reusable multi-agent workflow templates with step dependencies and agent annotations | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/` |
| REQ-017 | Swarm dispatch loop must instantiate formulas as wisps, dispatch steps to specialized agents, and squash wisps on completion | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_dispatch/SKILL.md` |
| REQ-018 | Agents within a swarm must communicate via structured comments (FINDINGS, CHANGES, REVIEW, TESTS) on the parent bead | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-comment-protocol.md` |
| REQ-019 | Formula labels must be auto-assigned to plan tasks based on title keyword heuristics during bead creation | P1 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_select_formula/SKILL.md` |
| REQ-020 | Formulas must support nested composition via `compose` field with max depth 2 | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-nesting.md` |
| REQ-021 | Reactive bugfix formula must auto-spawn on REVIEW:BLOCK or test failures with retry budget and design-BLOCK exclusion | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_react/SKILL.md` |
| REQ-022 | Code-review qualification gate must run before plan completion, configurable as blocking/advisory/disabled | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_qualify/SKILL.md` |
| REQ-023 | Specification documents (PRD, EDD, IG, TODO) must be synthesizable from existing project context (plans, diary, research, decisions, codebase) | P1 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_analyze_project/SKILL.md` |
| REQ-024 | Plans must be reconcilable against existing specifications before execution, with configurable enforcement mode | P1 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_reconcile/SKILL.md` |
| REQ-025 | Specification drift must be detectable during work via advisory watch rule | P2 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/watch-for-spec-drift.md` |
| REQ-026 | Closed beads must be automatically pruned at plan completion (plan-scoped) and after git push (global) with soft-delete tombstones | P2 | Beads Integration | Plan 32 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-prune.sh` |
| REQ-027 | Beads must be initialized with `dolt` backend (default), `beads-sync` branch, standard `bd hooks install` hooks, and no AGENTS.md (plugin provides beads rules via custom rule file). Custom pre-push hooks are prohibited — all sync uses standard beads hooks. | P1 | Beads Integration | Plan 27 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/preflight.json` |
| REQ-028 | Setup must be zero-question with automatic installation of rules, directories, and beads configuration. Setup requires beads plugin to be installed; `/yf:setup` checks for beads plugin and blocks activation if absent. | P0 | Core | Plan 33 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/setup/SKILL.md` |
| REQ-029 | Project `.gitignore` must be automatically managed with sentinel-bracketed block for yf ephemeral files | P1 | Core | Plan 23 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/setup-project.sh` |
| REQ-030 | All new work must include automated test scenarios in YAML format, runnable via `bash tests/run-tests.sh --unit-only` | P0 | Testing | Plan 06 | `/Users/james/workspace/dixson3/d3-claude-plugins/tests/run-tests.sh` |
| REQ-031 | Go test harness must support both unit tests (shell-only) and integration tests (Claude sessions via --resume) | P1 | Testing | Plan 06 | `/Users/james/workspace/dixson3/d3-claude-plugins/tests/harness/` |
| REQ-032 | Code implementation must support standards-driven workflows with dedicated research, coding, testing, and review agents via the `code-implement` formula | P1 | Coder | Plan 35 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/code-implement.formula.json` |
| REQ-033 | Specification integrity gates must run at plan intake (contradiction check, new capability check, test-spec alignment, test deprecation, change chronicles, structural consistency) and plan completion (diary generation, staleness checks, spec self-reconciliation) | P1 | Engineer | Plan 40 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/spec-sanity-check.sh` |
| REQ-034 | Plugin must enforce three-condition activation gate: (1) `.yoshiko-flow/config.json` exists, (2) `enabled: true` in config, (3) beads plugin installed. All skills except `/yf:setup` refuse when any condition fails. | P0 | Core | Plan 42 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/yf-activation-check.sh` |
| REQ-035 | Plugin must declare and enforce dependency on beads plugin (`steveyegge/beads`). Preflight emits dependency-missing signal when beads is not installed and removes rule symlinks. | P0 | Core | Plan 42 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plugin-preflight.sh` |
| REQ-036 | Plugin must support user-scope installation with per-project activation. Installing yf globally does not activate it in any project; explicit `/yf:setup` is required per-project. | P0 | Core | Plan 42 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/setup/SKILL.md` |
| REQ-037 | MEMORY.md must be reconcilable against specifications and CLAUDE.md. Contradictions resolved in favor of specs, gaps promoted to specs with operator approval, ephemeral duplicates removed. | P2 | Memory | Plan 43 | `plugins/yf/skills/memory_reconcile/SKILL.md` |
| REQ-038 | Chronicle beads must be auto-created at skill decision points (gate verdicts, spec mutations, qualification outcomes, scope changes) and at swarm step completion when formula flags are enabled. | P1 | Chronicler | Plan 44 | `plugins/yf/rules/yf-rules.md` (Rule 5.3) |

## 4. Functional Specifications

### 4.1 Marketplace

- FS-001: Plugin directory structure follows standard layout: `.claude-plugin/`, `skills/`, `agents/`, `rules/`, `scripts/`, `hooks/`
- FS-002: Skills and agents are auto-discovered from directory structure, NOT listed in plugin.json
- FS-003: Plugin manifest (`plugin.json`) contains only official Claude Code schema fields; custom fields live in `preflight.json`
- FS-004: Marketplace catalog (`.claude-plugin/marketplace.json`) registers all available plugins with name, source, description, version

### 4.2 Plan Lifecycle

- FS-005: Plan state machine supports Draft, Ready, Executing, Paused, Completed transitions
- FS-006: Three enforcement layers: beads-native (gates/defer), scripts (plan-exec.sh), hooks (code-gate.sh, plan-exec-guard.sh)
- FS-007: Auto-chain on ExitPlanMode drives full lifecycle without manual intervention
- FS-008: Plan files are stored in `docs/plans/plan-NN.md` with standard structure
- FS-009: Task pump dispatches beads grouped by agent label, launching parallel Task tool calls per batch
- FS-010: Non-trivial tasks must be decomposed before coding (breakdown-the-work rule)

### 4.3 Swarm Execution

- FS-011: Six formula templates shipped: feature-build, research-spike, code-review, bugfix, build-test, code-implement (see FS-034)
- FS-012: Formula instantiation creates ephemeral wisps; results persist as comments on parent bead
- FS-013: Seven specialized swarm agents: researcher (read-only, FINDINGS), reviewer (read-only, REVIEW), tester (TESTS) for general formulas; code-researcher (read-only), code-writer (full-capability), code-tester (limited-write), code-reviewer (read-only) for the code-implement formula (see FS-034)
- FS-014: Implicit formula triggers: auto-select at bead creation, nested composition, reactive bugfix, qualification gate, planning research advisory

### 4.4 Chronicler

- FS-015: Chronicle beads capture context snapshots with plan-scoped tagging
- FS-016: Automatic draft creation via chronicle-check.sh analyzing git commits for keywords, significant files, and activity volume
- FS-017: Session boundary hooks (SessionStart, SessionEnd, PreCompact) provide zero-effort context recovery and preservation
- FS-018: Diary agent triages draft beads, enriches worthy ones, closes unworthy ones, consolidates duplicates

### 4.5 Archivist

- FS-019: Two archive types: research (docs/research/) and decisions (docs/decisions/)
- FS-020: Advisory rules suggest archiving during work; operator decides when to capture
- FS-021: Archive processing generates indexed SUMMARY.md files with _index.md cross-references

### 4.6 Engineer

- FS-022: Spec synthesis is idempotent -- does not overwrite existing specs unless forced
- FS-023: Reconciliation fires automatically in auto-chain between plan save and beads creation
- FS-024: No specs means no enforcement -- zero cost for projects that do not opt in
- FS-025: Single watch rule covers PRD, EDD, and IG drift monitoring
- FS-038: Mechanical sanity check script validates six structural dimensions (count parity, ID contiguity, coverage arithmetic, UC range alignment, test file existence, formula count) with configurable enforcement mode; intake gate enforces spec-as-anchor-document principle with operator approval for all changes
- FS-039: Plan completion includes spec self-reconciliation (PRD→EDD→IG traceability, test-coverage consistency, orphaned/stale entry detection) and deprecated artifact pruning verification
- FS-040: Three-condition activation gate checks `.yoshiko-flow/config.json` existence, `enabled` field, and beads plugin installation. `yf-activation-check.sh` outputs structured JSON with reason and remediation action. Skills read this JSON before executing.
- FS-041: Preflight dependency check parses `~/.claude/plugins/installed_plugins.json` for `beads@*` key. Fallback: `command -v bd`. When beads is missing: emit `YF_DEPENDENCY_MISSING` signal, remove rule symlinks (same as disabled path), exit.
- FS-042: Memory reconciliation classifies MEMORY.md items as contradictions (spec wins), gaps (promote to specs), or ephemeral duplicates (remove). Agent-interpreted — the LLM reads both documents and reasons semantically. Operator approval required for all spec changes per Rule 1.4. Idempotent — clean memory is a no-op.
- FS-043: Skill-level chronicle capture fires deterministically at decision points — verdicts, spec mutations, scope changes. Formula-level chronicle capture fires via `"chronicle": true` step flag on terminal swarm steps. Write-capable swarm agents capture plan deviations and unexpected discoveries directly via `bd create`. Read-only agents signal chronicle-worthy content via `CHRONICLE-SIGNAL:` lines in structured comments, consumed by `swarm_dispatch` Step 6c.

### 4.7 Beads Integration

- FS-026: Beads is the source of truth for all plan work; Claude TaskCreate/TaskList is NOT used for plan work
- FS-027: Git-tracked beads with `dolt` backend, `beads-sync` branch, and standard `bd hooks install` hooks (pre-commit, post-merge, pre-push, post-checkout, prepare-commit-msg). No custom pre-push hook — standard beads hooks handle all sync. No AGENTS.md generated — the plugin provides beads workflow context via its own rule file and `bd prime` hook injection.
- FS-028: Automatic pruning: plan-scoped on completion, global on push, configurable thresholds
- FS-029: Safety net hook (REQ-027, DD-005) warns on destructive `bd delete` operations without plan lifecycle or chronicle capture

### 4.8 Testing

- FS-030: YAML-based test scenarios with Go test harness
- FS-031: Unit tests run shell scripts directly without Claude sessions
- FS-032: Integration tests use multi-turn Claude sessions via `--resume`
- FS-033: 486+ unit tests across 40 test scenario files

### 4.9 Coder

- FS-034: Four specialized code agents (researcher, writer, tester, reviewer) with appropriate tool profiles
- FS-035: `code-implement` formula with 4-step pipeline: research-standards, implement, test, review
- FS-036: Code researcher checks existing IGs before proposing new standards
- FS-037: Code reviewer references IGs for specification alignment in reviews
