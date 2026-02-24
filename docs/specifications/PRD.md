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
- TC-003: Plugin must work within Claude Code's plugin system (plugin.json strict schema, auto-discovered skills/agents)
- TC-004: Hooks must be fail-open (exit 0 always) -- never block user operations on internal errors
- TC-005: Rules are behavioral guidance (agent compliance) -- hooks provide mechanical enforcement
- TC-006: All ephemeral state must be gitignored; only committed config is `.yoshiko-flow/config.json`
- TC-007: Symlink-based rule management -- single source of truth in plugin source, no file copies
- TC-008: Task state persisted as JSON files under `.yoshiko-flow/` subdirectories; writes immediate via filesystem
- TC-009: The plugin system uses `${CLAUDE_PLUGIN_ROOT}` for path resolution in hook commands

## 3. Requirement Traceability Matrix

| ID | Requirement | Priority | Capability | Source | Code Reference |
|----|-------------|----------|------------|--------|----------------|
| REQ-001 | Plugin marketplace must support multiple plugins with namespace isolation (colon for skills, underscore for agents, hyphen for rules) | P0 | Marketplace | Plan 01, Plan 13, Plan 21 | `/Users/james/workspace/dixson3/d3-claude-plugins/DEVELOPERS.md` |
| REQ-002 | Preflight system must automatically install/update/remove rule symlinks on SessionStart with <50ms fast path | P0 | Marketplace | Plan 10, Plan 17 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plugin-preflight.sh` |
| REQ-003 | Plans must be convertible into a task hierarchy (epics, tasks, dependencies, gates) with agent assignments | P0 | Plan Lifecycle | Plan 03, Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_create_tasks/SKILL.md` |
| REQ-004 | Plan lifecycle must enforce state transitions: Draft -> Ready -> Executing <-> Paused -> Completed | P0 | Plan Lifecycle | Plan 03, Plan 05 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh` |
| REQ-005 | Code-gate hook must block Edit/Write on implementation files when plan is saved but not yet executing | P0 | Plan Lifecycle | Plan 05 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/code-gate.sh` |
| REQ-006 | ExitPlanMode must auto-chain the full lifecycle: format plan -> reconcile specs -> create tasks -> start execution -> begin dispatch | P0 | Plan Lifecycle | Plan 08 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/auto-chain-plan.md` |
| REQ-007 | Plan intake rule must catch pasted/manual plans and route through proper lifecycle regardless of entry path | P0 | Plan Lifecycle | Plan 11, Plan 31 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-intake.md` |
| REQ-008 | Task pump must read `yft_list --ready`, group tasks by `agent:<name>` label, and dispatch parallel Task tool calls with appropriate subagent_type | P0 | Plan Lifecycle | Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_pump/SKILL.md` |
| REQ-009 | Chronicle entries must be captured automatically at session boundaries (SessionStart, SessionEnd, PreCompact) and plan lifecycle boundaries | P1 | Chronicler | Plan 11, Plan 22, Plan 25 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/chronicle-check.sh` |
| REQ-010 | Open chronicle summaries must be output to agent context on SessionStart for automatic context recovery | P1 | Chronicler | Plan 22 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/session-recall.sh` |
| REQ-011 | Chronicle entries must be composable into diary entries -- permanent markdown narratives of how and why changes were made | P0 | Chronicler | Plan 02, Plan 12 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/chronicle_diary/SKILL.md` |
| REQ-012 | Chronicle gates must prevent diary generation until plan execution completes, ensuring full-arc diary entries | P1 | Chronicler | Plan 07 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh` |
| REQ-013 | Research findings must be capturable as archive entries and processable into indexed `docs/research/<topic>/SUMMARY.md` files | P1 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_capture/SKILL.md` |
| REQ-014 | Design decisions must be capturable as archive entries and processable into indexed `docs/decisions/DEC-NNN-<slug>/SUMMARY.md` files | P1 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_process/SKILL.md` |
| REQ-015 | Git history must be scannable for archive candidates (research/decision keywords in commits) | P2 | Archivist | Plan 19 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/archive-suggest.sh` |
| REQ-016 | Swarm formulas must define reusable multi-agent workflow templates with step dependencies and agent annotations | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/` |
| REQ-017 | Swarm dispatch loop must instantiate formulas as wisps, dispatch steps to specialized agents, and squash wisps on completion | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_dispatch/SKILL.md` |
| REQ-018 | Agents within a swarm must communicate via structured comments (FINDINGS, CHANGES, REVIEW, TESTS) on the parent task | P1 | Swarm | Plan 28 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-comment-protocol.md` |
| REQ-019 | Formula labels must be auto-assigned to plan tasks based on title keyword heuristics during task creation | P1 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_select_formula/SKILL.md` |
| REQ-020 | Formulas must support nested composition via `compose` field with max depth 2 | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-nesting.md` |
| REQ-021 | Reactive bugfix formula must auto-spawn on REVIEW:BLOCK or test failures with retry budget and design-BLOCK exclusion | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_react/SKILL.md` |
| REQ-022 | Code-review qualification gate must run before plan completion, configurable as blocking/advisory/disabled | P2 | Swarm | Plan 29 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_qualify/SKILL.md` |
| REQ-023 | Specification documents (PRD, EDD, IG, TODO) must be synthesizable from existing project context (plans, diary, research, decisions, codebase) | P1 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_analyze_project/SKILL.md` |
| REQ-024 | Plans must be reconcilable against existing specifications before execution, with configurable enforcement mode | P1 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_reconcile/SKILL.md` |
| REQ-025 | Specification drift must be detectable during work via advisory watch rule | P2 | Engineer | Plan 34 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/watch-for-spec-drift.md` |
| REQ-026 | Closed tasks must be automatically pruned at plan completion (plan-scoped) and after git push (global) | P2 | Task Management | Plan 32 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-prune.sh` |
| REQ-027 | Task directories must be automatically created under `.yoshiko-flow/` during preflight | P1 | Task Management | Plan 27, Plan 45 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/preflight.json` |
| REQ-028 | Setup must be zero-question with automatic installation of rules, directories, and task configuration. Setup requires no external CLI dependencies. | P0 | Plugin | Plan 33 | `plugins/yf/skills/plugin_setup/SKILL.md` |
| REQ-029 | Project `.gitignore` must be automatically managed with sentinel-bracketed block for yf ephemeral files | P1 | Core | Plan 23 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/setup-project.sh` |
| REQ-030 | All new work must include automated test scenarios in YAML format, runnable via `bash tests/run-tests.sh --unit-only` | P0 | Testing | Plan 06 | `/Users/james/workspace/dixson3/d3-claude-plugins/tests/run-tests.sh` |
| REQ-031 | Go test harness must support both unit tests (shell-only) and integration tests (Claude sessions via --resume) | P1 | Testing | Plan 06 | `/Users/james/workspace/dixson3/d3-claude-plugins/tests/harness/` |
| REQ-032 | Code implementation must support standards-driven workflows with dedicated research, coding, testing, and review agents via the `code-implement` formula | P1 | Coder | Plan 35 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/code-implement.formula.json` |
| REQ-033 | Specification integrity gates must run at plan intake (contradiction check, new capability check, test-spec alignment, test deprecation, change chronicles, structural consistency) and plan completion (diary generation, staleness checks, spec self-reconciliation) | P1 | Engineer | Plan 40 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/spec-sanity-check.sh` |
| REQ-034 | Plugin must enforce two-condition activation gate: (1) `.yoshiko-flow/config.json` exists, (2) `enabled != false`. All skills except `/yf:plugin_setup` refuse when any condition fails. | P0 | Plugin | Plan 42 | `plugins/yf/scripts/yf-activation-check.sh` |
| REQ-035 | Preflight must create `.yoshiko-flow/` subdirectories and manage rule symlinks | P0 | Core | Plan 42 | `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plugin-preflight.sh` |
| REQ-036 | Plugin must support user-scope installation with per-project activation. Installing yf globally does not activate it in any project; explicit `/yf:plugin_setup` is required per-project. | P0 | Plugin | Plan 42 | `plugins/yf/skills/plugin_setup/SKILL.md` |
| REQ-037 | MEMORY.md must be reconcilable against specifications and CLAUDE.md. Contradictions resolved in favor of specs, gaps promoted to specs with operator approval, ephemeral duplicates removed. | P2 | Memory | Plan 43 | `plugins/yf/skills/memory_reconcile/SKILL.md` |
| REQ-038 | Chronicle entries must be auto-created at skill decision points (gate verdicts, spec mutations, qualification outcomes, scope changes) and at swarm step completion when formula flags are enabled. | P1 | Chronicler | Plan 44 | `plugins/yf/rules/yf-rules.md` (Rule 5.3) |
| REQ-039 | Pre-push hook must block `git push` when uncommitted changes or in-progress tasks exist, with actionable checklist output. `/yf:session_land` skill orchestrates full session close-out with operator confirmation for push. | P1 | Session | Plan 46 | `plugins/yf/hooks/pre-push-land.sh`, `plugins/yf/skills/session_land/SKILL.md` |
| REQ-040 | Plan intake must auto-classify and commit uncommitted changes before plan lifecycle begins — foreshadowing commits for plan-overlapping changes, ad-hoc commits for unrelated changes. | P2 | Plan Lifecycle | Plan 46 | `plugins/yf/skills/plan_intake/SKILL.md` |
| REQ-041 | Session boundaries must track uncommitted-change state via dirty-tree markers, warning the next session about left-behind work. | P2 | Session | Plan 46 | `plugins/yf/hooks/session-end.sh`, `plugins/yf/scripts/session-recall.sh` |
| REQ-042 | Plugin issues (bugs/enhancements against yf itself) must be reportable via `/yf:plugin_issue` using `gh` CLI against the plugin repository. Manually initiated only — never suggested proactively. | P2 | Plugin | Plan 50 | `plugins/yf/skills/plugin_issue/SKILL.md` |
| REQ-043 | Project issues must be stageable as `ys:issue` tasks via `/yf:issue_capture` for deferred submission to a remote tracker. | P1 | Issue | Plan 50 | `plugins/yf/skills/issue_capture/SKILL.md` |
| REQ-044 | Staged issue tasks must be processable via `/yf:issue_process` with triage agent consolidation, duplicate detection, and batch submission to the configured tracker (GitHub, GitLab, or file-based). | P1 | Issue | Plan 50 | `plugins/yf/skills/issue_process/SKILL.md` |
| REQ-045 | Tracker detection must auto-detect project tracker from git remote origin with explicit config override and file-based fallback. Never returns "none" — file backend is always available. | P1 | Issue | Plan 50 | `plugins/yf/scripts/tracker-detect.sh` |
| REQ-046 | Plugin issues and project issues must be disambiguated — Rule 1.5 hard enforcement prevents cross-routing between plugin repo and project tracker. | P1 | Issue | Plan 50 | `plugins/yf/rules/yf-rules.md` (Rule 1.5) |
| REQ-047 | Issue worthiness advisory (Rule 5.6) must suggest `/yf:issue_capture` for deferred improvements, incidental bugs, enhancement opportunities, and technical debt discovered during work. Project issues only — never suggests `/yf:plugin_issue`. | P2 | Issue | Plan 50 | `plugins/yf/rules/yf-rules.md` (Rule 5.6) |

## 4. Functional Specifications

### 4.1 Marketplace

- FS-001: Plugin directory structure follows standard layout: `.claude-plugin/`, `skills/`, `agents/`, `rules/`, `scripts/`, `hooks/`
- FS-002: Skills and agents are auto-discovered from directory structure, NOT listed in plugin.json
- FS-003: Plugin manifest (`plugin.json`) contains only official Claude Code schema fields; custom fields live in `preflight.json`
- FS-004: Marketplace catalog (`.claude-plugin/marketplace.json`) registers all available plugins with name, source, description, version

### 4.2 Plan Lifecycle

- FS-005: Plan state machine supports Draft, Ready, Executing, Paused, Completed transitions
- FS-006: Three enforcement layers: task-native (gates/defer), scripts (plan-exec.sh), hooks (code-gate.sh, plan-exec-guard.sh)
- FS-007: Auto-chain on ExitPlanMode drives full lifecycle without manual intervention
- FS-008: Plan files are stored in `docs/plans/plan-NN.md` with standard structure
- FS-009: Task pump dispatches tasks grouped by agent label, launching parallel Task tool calls per batch
- FS-010: Non-trivial tasks must be decomposed before coding (breakdown-the-work rule)

### 4.3 Swarm Execution

- FS-011: Six formula templates shipped: feature-build, research-spike, code-review, bugfix, build-test, code-implement (see FS-034)
- FS-012: Formula instantiation creates ephemeral wisps; results persist as comments on parent task
- FS-013: Seven specialized swarm agents: researcher (read-only, FINDINGS), reviewer (read-only, REVIEW), tester (TESTS) for general formulas; code-researcher (read-only), code-writer (full-capability), code-tester (limited-write), code-reviewer (read-only) for the code-implement formula (see FS-034)
- FS-014: Implicit formula triggers: auto-select at task creation, nested composition, reactive bugfix, qualification gate, planning research advisory

### 4.4 Chronicler

- FS-015: Chronicle entries capture context snapshots with plan-scoped tagging
- FS-016: Automatic draft creation via chronicle-check.sh analyzing git commits for keywords, significant files, and activity volume
- FS-017: Session boundary hooks (SessionStart, SessionEnd, PreCompact) provide zero-effort context recovery and preservation
- FS-018: Diary agent triages draft entries, enriches worthy ones, closes unworthy ones, consolidates duplicates

### 4.5 Archivist

- FS-019: Two archive types: research (docs/research/) and decisions (docs/decisions/)
- FS-020: Advisory rules suggest archiving during work; operator decides when to capture
- FS-021: Archive processing generates indexed SUMMARY.md files with _index.md cross-references

### 4.6 Engineer

- FS-022: Spec synthesis is idempotent -- does not overwrite existing specs unless forced
- FS-023: Reconciliation fires automatically in auto-chain between plan save and task creation
- FS-024: No specs means no enforcement -- zero cost for projects that do not opt in
- FS-025: Single watch rule covers PRD, EDD, and IG drift monitoring
- FS-038: Mechanical sanity check script validates six structural dimensions (count parity, ID contiguity, coverage arithmetic, UC range alignment, test file existence, formula count) with configurable enforcement mode; intake gate enforces spec-as-anchor-document principle with operator approval for all changes
- FS-039: Plan completion includes spec self-reconciliation (PRD→EDD→IG traceability, test-coverage consistency, orphaned/stale entry detection) and deprecated artifact pruning verification
- FS-040: Two-condition activation gate checks `.yoshiko-flow/config.json` existence and `enabled` field. `yf-activation-check.sh` outputs structured JSON with reason and remediation action. Skills read this JSON before executing.
- FS-042: Memory reconciliation classifies MEMORY.md items as contradictions (spec wins), gaps (promote to specs), or ephemeral duplicates (remove). Agent-interpreted — the LLM reads both documents and reasons semantically. Operator approval required for all spec changes per Rule 1.4. Idempotent — clean memory is a no-op.
- FS-043: Skill-level chronicle capture fires deterministically at decision points — verdicts, spec mutations, scope changes. Formula-level chronicle capture fires via `"chronicle": true` step flag on terminal swarm steps. Write-capable swarm agents capture plan deviations and unexpected discoveries directly via `yft_create`. Read-only agents signal chronicle-worthy content via `CHRONICLE-SIGNAL:` lines in structured comments, consumed by `swarm_dispatch` Step 6c.

### 4.7 Task Management

- FS-026: File-based tasks are the source of truth for all plan work; Claude TaskCreate/TaskList is NOT used for plan work
- FS-028: Automatic pruning: plan-scoped on completion, global on push, configurable thresholds. File deletion is immediate.

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

### 4.10 Session

- FS-049: Plugin issue reporting uses `gh` CLI against configurable `plugin_repo` (default: `dixson3/d3-claude-plugins`). Cross-route guard compares plugin repo against project tracker slug — error if they match.
- FS-050: Issue capture mirrors `chronicle_capture` pattern: analyze context, create task with `ys:issue` label and type/priority metadata, auto-detect plan context.
- FS-051: Issue processing uses `yf_issue_triage` agent for judgment work — duplicate detection, augmentation of existing remote issues, relation cross-referencing, disambiguation flagging. Returns structured JSON action plan for operator confirmation.
- FS-052: Tracker detection priority: (1) explicit config, (2) git remote auto-detect (GitHub/GitLab), (3) file fallback. Handles SSH and HTTPS URL formats. File backend uses `docs/specifications/TODO.md` + `docs/todos/` directories.
- FS-053: Three tracker backends: GitHub (`gh`), GitLab (`glab`), file-based (`TODO.md` + `docs/todos/`). `tracker-api.sh` provides uniform interface for create, list, view, transition operations.
- FS-054: Pre-push hook warns about open `ys:issue` tasks (advisory, non-blocking) via existing `warn_open_tasks` function.
- FS-044: Pre-push blocking hook checks two conditions: uncommitted changes and in-progress tasks. Exit 2 (block) when either condition fails, exit 0 when both pass.
- FS-045: `/yf:session_land` skill orchestrates full close-out: dirty tree check, in-progress tasks, chronicle capture, diary generation, quality gates, memory reconciliation, session prune, commit, push with operator confirmation, handoff.
- FS-046: Plan foreshadowing at intake auto-classifies uncommitted files as plan-overlapping (foreshadowing) or unrelated, commits each group separately with descriptive messages.
- FS-047: Dirty-tree marker (`.yoshiko-flow/.dirty-tree`) written at session end when uncommitted changes exist, consumed and reported at next session start.
- FS-048: yf manages the git commit/push workflow via `/yf:session_land` and `pre-push-land.sh`.
