# Test Coverage Traceability Matrix

Maps each specification item to its test coverage. Status key: **tested** (behavioral assertions), **existence-only** (file/field existence checks), **untested** (no test coverage).

## Requirements (REQ-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| REQ-001 | Namespace isolation | unit-naming-convention.yaml | tested |
| REQ-002 | Preflight symlinks <50ms | unit-preflight.yaml, unit-preflight-symlinks.yaml | tested |
| REQ-003 | Plans to task hierarchy | unit-plan-exec-gate.yaml | existence-only |
| REQ-004 | Plan state transitions | unit-plan-state-machine.yaml | tested |
| REQ-005 | Code-gate blocks edits | unit-code-gate.yaml | tested |
| REQ-006 | ExitPlanMode auto-chain | unit-exit-plan-gate.yaml | existence-only |
| REQ-007 | Plan intake catches pasted plans | unit-plan-intake.yaml | tested |
| REQ-008 | Task pump dispatch | unit-pump-dispatch.yaml, unit-formula-dispatch.yaml | tested |
| REQ-009 | Chronicle auto-capture | unit-chronicle-check.yaml | tested |
| REQ-010 | Session recall | unit-session-recall.yaml | tested |
| REQ-011 | Chronicle diary composability | unit-chronicle-check.yaml | existence-only |
| REQ-012 | Chronicle gate blocking | unit-chronicle-gate.yaml | tested |
| REQ-013 | Research archive capture | unit-archive-suggest.yaml | existence-only |
| REQ-014 | Decision archive capture | unit-archive-suggest.yaml | existence-only |
| REQ-015 | Git history scan for archives | unit-archive-suggest.yaml | existence-only |
| REQ-016 | Formula workflow templates | unit-swarm-comment-protocol.yaml | tested |
| REQ-017 | Swarm dispatch loop | unit-swarm-lifecycle.yaml | tested |
| REQ-018 | Structured swarm comments | unit-swarm-comment-protocol.yaml | tested |
| REQ-019 | Formula auto-assignment | unit-swarm-formula-select.yaml | tested |
| REQ-020 | Nested composition depth 2 | unit-swarm-nesting.yaml | tested |
| REQ-021 | Reactive bugfix | unit-swarm-reactive.yaml | tested |
| REQ-022 | Qualification gate | unit-swarm-qualify.yaml | tested |
| REQ-023 | Spec synthesis | unit-engineer.yaml | existence-only |
| REQ-024 | Plan-spec reconciliation | unit-engineer.yaml | tested |
| REQ-025 | Spec drift watch | unit-engineer.yaml | existence-only |
| REQ-026 | Task auto-pruning | unit-plan-prune.yaml | tested |
| REQ-027 | ~~Beads git-tracked~~ (removed in v3.0.0 — file-based task system supersedes) | — | removed |
| REQ-028 | Zero-question setup | unit-setup-project.yaml | tested |
| REQ-029 | Gitignore management | unit-setup-project.yaml | tested |
| REQ-030 | YAML test scenarios | unit-yf-structure.yaml | existence-only |
| REQ-031 | Go test harness | unit-yf-structure.yaml | existence-only |
| REQ-032 | Standards-driven code implementation | unit-code-implement.yaml | tested |
| REQ-033 | Spec integrity gates at intake/completion | unit-spec-sanity.yaml | tested |
| REQ-034 | Two-condition activation gate | unit-activation.yaml, unit-yf-config.yaml | tested |
| REQ-035 | Preflight directory management | unit-activation.yaml, unit-preflight.yaml | tested |
| REQ-036 | User-scope install with per-project activation | unit-activation.yaml, unit-preflight.yaml | tested |
| REQ-037 | Memory reconciliation | unit-memory-reconcile.yaml | existence-only |
| REQ-038 | Skill-level chronicle auto-capture | unit-chronicle-worthiness.yaml | existence-only |
| REQ-039 | Pre-push enforcement + session_land | unit-pre-push-land.yaml, unit-session-land.yaml | tested |
| REQ-040 | Plan foreshadowing at intake | unit-plan-intake.yaml | untested |
| REQ-041 | Dirty-tree cross-session markers | unit-session-end.yaml, unit-session-recall.yaml | tested |
| REQ-042 | Plugin issue reporting via gh CLI | unit-issue-disambiguation.yaml | untested |
| REQ-043 | Project issue staging as ys:issue tasks | unit-issue-disambiguation.yaml | untested |
| REQ-044 | Issue processing with triage agent | unit-issue-disambiguation.yaml | untested |
| REQ-045 | Tracker auto-detection with file fallback | unit-tracker-detect.yaml | tested |
| REQ-046 | Plugin/project issue disambiguation | unit-issue-disambiguation.yaml | tested |
| REQ-047 | Issue worthiness advisory (Rule 5.6) | unit-issue-disambiguation.yaml | untested |

## Design Decisions (DD-xxx)

Aligned to EDD/CORE.md DD-001 through DD-020.

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| DD-001 | File-based persistent task store | unit-pump-dispatch.yaml | tested |
| DD-002 | Symlink-based rule management | unit-preflight-symlinks.yaml | tested |
| DD-003 | ~~Dolt-native persistence~~ (superseded in v3.0.0 — file-based JSON replaces Dolt) | — | removed |
| DD-004 | Auto-chain lifecycle on ExitPlanMode | unit-exit-plan-gate.yaml | existence-only |
| DD-005 | Hook + rule mechanism for plan enforcement | unit-code-gate.yaml | tested |
| DD-006 | Formula-driven swarm with wisps | unit-swarm-lifecycle.yaml | tested |
| DD-007 | Heuristic-based formula auto-selection | unit-swarm-formula-select.yaml | tested |
| DD-008 | Zero-question setup with always-on capabilities | unit-setup-project.yaml | tested |
| DD-009 | Blocking specification reconciliation (default) | unit-engineer.yaml | tested |
| DD-010 | Plugin consolidation (historical) | unit-preflight.yaml | existence-only |
| DD-011 | Soft-delete task pruning | unit-plan-prune.yaml | tested |
| DD-012 | State directory migration (.claude/ -> .yoshiko-flow/) | unit-preflight.yaml | existence-only |
| DD-013 | Standards-driven code implementation formula | unit-code-implement.yaml | tested |
| DD-014 | Specifications as anchor documents | unit-spec-sanity.yaml | tested |
| DD-015 | Two-condition activation model | unit-activation.yaml, unit-yf-config.yaml | tested |
| DD-016 | ~~Hybrid beads routing~~ (reversed; removed in v3.0.0) | — | removed |
| DD-017 | Session close enforcement (hook + skill) | unit-pre-push-land.yaml, unit-session-land.yaml | tested |
| DD-018 | Core merged into plugin prefix | unit-activation.yaml | tested |
| DD-019 | Tracker abstraction with file fallback | unit-tracker-detect.yaml, unit-tracker-api.yaml | tested |
| DD-020 | Plugin vs project issue disambiguation | unit-issue-disambiguation.yaml | tested |

## Non-Functional Requirements (NFR-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| NFR-001 | Preflight <50ms fast path | unit-nfr-behavioral.yaml | tested |
| NFR-002 | Fail-open hooks | unit-nfr-behavioral.yaml | tested |
| NFR-003 | Bash 3.2 compatibility | unit-nfr-behavioral.yaml | tested |
| NFR-004 | Zero git footprint | unit-nfr-behavioral.yaml | tested |
| NFR-005 | Idempotent operations | unit-nfr-behavioral.yaml | tested |
| NFR-006 | Test coverage minimum | unit-yf-structure.yaml | existence-only |
| NFR-007 | Migration safety | unit-nfr-behavioral.yaml | tested |

## Use Cases (UC-xxx)

Aligned to IG files: plan-lifecycle (UC-001–005), swarm-execution (UC-006–009), chronicler (UC-010–013, UC-037–038), archivist (UC-014–017), engineer (UC-018–021, UC-033–034), marketplace (UC-022–024, UC-035–036, UC-042), task-integration (UC-025–028, UC-039, UC-041), coder (UC-029–032), issue-tracking (UC-043–047).

| ID | Summary | IG Source | Test File | Status |
|----|---------|-----------|-----------|--------|
| UC-001 | Auto-chain via ExitPlanMode | plan-lifecycle | unit-exit-plan-gate.yaml | existence-only |
| UC-002 | Manual plan intake (pasted plan) | plan-lifecycle | unit-plan-intake.yaml | tested |
| UC-003 | Task pump dispatch | plan-lifecycle | unit-formula-dispatch.yaml | tested |
| UC-004 | Plan completion | plan-lifecycle | unit-plan-state-machine.yaml | tested |
| UC-005 | Code gate enforcement | plan-lifecycle | unit-code-gate.yaml | tested |
| UC-006 | Full swarm lifecycle | swarm-execution | unit-swarm-lifecycle.yaml | tested |
| UC-007 | Formula auto-selection | swarm-execution | unit-swarm-formula-select.yaml | tested |
| UC-008 | Reactive bugfix on failure | swarm-execution | unit-swarm-reactive.yaml | tested |
| UC-009 | Nested formula composition | swarm-execution | unit-swarm-nesting.yaml | tested |
| UC-010 | Chronicle capture | chronicler | unit-chronicle-check.yaml | tested |
| UC-011 | Session recall | chronicler | unit-session-recall.yaml | tested |
| UC-012 | Automatic draft creation | chronicler | unit-chronicle-check.yaml | existence-only |
| UC-013 | Diary generation | chronicler | unit-plan-exec-chronicle.yaml | existence-only |
| UC-014 | Archive research findings | archivist | unit-archive-suggest.yaml | existence-only |
| UC-015 | Archive design decisions | archivist | unit-archive-suggest.yaml | existence-only |
| UC-016 | Process archives into docs | archivist | — | untested |
| UC-017 | Git history archive scan | archivist | unit-archive-suggest.yaml | existence-only |
| UC-018 | Spec synthesis from context | engineer | unit-engineer.yaml | existence-only |
| UC-019 | Plan-spec reconciliation | engineer | unit-engineer.yaml | tested |
| UC-020 | Individual spec entry update | engineer | unit-engineer.yaml | existence-only |
| UC-021 | Post-completion spec suggestions | engineer | unit-engineer.yaml | existence-only |
| UC-022 | Plugin registration | marketplace | unit-yf-structure.yaml | existence-only |
| UC-023 | Preflight artifact sync | marketplace | unit-preflight.yaml, unit-preflight-symlinks.yaml | tested |
| UC-024 | Running tests | marketplace | unit-yf-structure.yaml | existence-only |
| UC-025 | Task system setup | task-integration | unit-preflight.yaml, unit-setup-project.yaml | tested |
| UC-026 | Task lifecycle during plan execution | task-integration | unit-plan-exec-gate.yaml | existence-only |
| UC-027 | Automatic task pruning | task-integration | unit-plan-prune.yaml | tested |
| UC-028 | Session close protocol | task-integration | unit-pre-push-land.yaml, unit-session-land.yaml | existence-only |
| UC-042 | Completed-plans cleanup (gates, epics, chronicles) | task-integration | unit-session-prune-completed.yaml | untested |
| UC-029 | Standards-driven code implementation | coder | unit-code-implement.yaml | tested |
| UC-030 | Code-implement formula selection | coder | unit-code-implement.yaml | tested |
| UC-031 | IG-first standards research | coder | unit-code-implement.yaml | tested |
| UC-032 | Standards compliance review | coder | unit-code-implement.yaml | tested |
| UC-033 | Plan intake spec integrity gate | engineer | unit-spec-sanity.yaml | tested |
| UC-034 | Plan completion spec self-reconciliation | engineer | unit-spec-sanity.yaml | existence-only |
| UC-035 | Plugin activation gate check | marketplace | unit-activation.yaml | tested |
| UC-036 | Per-project activation via /yf:plugin_setup | marketplace | unit-activation.yaml | tested |
| UC-037 | Memory reconciliation | chronicler | unit-memory-reconcile.yaml | existence-only |
| UC-038 | Skill-level auto-chronicle at decision points | chronicler | unit-chronicle-worthiness.yaml | existence-only |
| UC-039 | Pre-push enforcement | task-integration | unit-pre-push-land.yaml | tested |
| UC-040 | Plan foreshadowing at intake | plan-lifecycle | unit-plan-intake.yaml | untested |
| UC-041 | Dirty-tree cross-session awareness | task-integration | unit-session-end.yaml, unit-session-recall.yaml | tested |
| UC-042 | Plugin issue reporting | marketplace | unit-issue-disambiguation.yaml | untested |
| UC-043 | Project issue capture and staging | issue-tracking | unit-issue-disambiguation.yaml | untested |
| UC-044 | Issue processing and batch submission | issue-tracking | unit-issue-disambiguation.yaml | untested |
| UC-045 | Tracker detection and selection | issue-tracking | unit-tracker-detect.yaml | tested |
| UC-046 | Issue plan import from remote tracker | issue-tracking | — | untested |
| UC-047 | Issue list (combined remote + staged) | issue-tracking | — | untested |

## Coverage Summary

| Category | Total | Tested | Existence-Only | Untested | Removed |
|----------|-------|--------|----------------|----------|---------|
| REQ | 47 | 27 | 14 | 5 | 1 |
| DD | 20 | 16 | 2 | 0 | 2 |
| NFR | 7 | 6 | 1 | 0 | 0 |
| UC | 47 | 24 | 16 | 7 | 0 |
| **Total** | **121** | **73** | **33** | **12** | **3** |

Total assertions: **860** (across all unit test scenarios)

## Priority Gaps

Remaining items needing behavioral test upgrades or initial coverage:

1. **UC-016** — Archive processing into docs: untested (requires live agent interaction)
2. **UC-018, UC-020-021** — Engineer spec synthesis, individual update, and post-completion suggestions (existence-only)
3. **UC-014-017** — Archivist capture, process, suggestion, and git scan (existence-only)
4. **REQ-003, REQ-006** — Plans-to-task hierarchy and auto-chain (existence-only)
