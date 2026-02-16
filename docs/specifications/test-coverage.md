# Test Coverage Traceability Matrix

Maps each specification item to its test coverage. Status key: **tested** (behavioral assertions), **existence-only** (file/field existence checks), **untested** (no test coverage).

## Requirements (REQ-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| REQ-001 | Namespace isolation | unit-naming-convention.yaml | tested |
| REQ-002 | Preflight symlinks <50ms | unit-preflight.yaml, unit-preflight-symlinks.yaml | tested |
| REQ-003 | Plans to beads hierarchy | unit-plan-exec-gate.yaml | existence-only |
| REQ-004 | Plan state transitions | unit-plan-exec-gate.yaml | existence-only |
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
| REQ-017 | Swarm dispatch loop | unit-dispatch-state.yaml | existence-only |
| REQ-018 | Structured swarm comments | unit-swarm-comment-protocol.yaml | tested |
| REQ-019 | Formula auto-assignment | unit-swarm-formula-select.yaml | tested |
| REQ-020 | Nested composition depth 2 | unit-swarm-nesting.yaml | tested |
| REQ-021 | Reactive bugfix | unit-swarm-reactive.yaml | existence-only |
| REQ-022 | Qualification gate | unit-swarm-qualify.yaml | existence-only |
| REQ-023 | Spec synthesis | unit-engineer.yaml | existence-only |
| REQ-024 | Plan-spec reconciliation | unit-engineer.yaml | existence-only |
| REQ-025 | Spec drift watch | unit-engineer.yaml | existence-only |
| REQ-026 | Bead auto-pruning | unit-plan-prune.yaml | tested |
| REQ-027 | Beads git-tracked | unit-beads-git.yaml | tested |
| REQ-028 | Zero-question setup | unit-setup-project.yaml | tested |
| REQ-029 | Gitignore management | unit-setup-project.yaml | tested |
| REQ-030 | YAML test scenarios | unit-yf-structure.yaml | existence-only |
| REQ-031 | Go test harness | unit-yf-structure.yaml | existence-only |
| REQ-032 | Standards-driven code implementation | — | untested |
| REQ-033 | Spec integrity gates at intake/completion | unit-spec-sanity.yaml | tested |

## Design Decisions (DD-xxx)

Aligned to EDD/CORE.md DD-001 through DD-013.

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| DD-001 | Beads as persistent task store | unit-pump-dispatch.yaml | tested |
| DD-002 | Symlink-based rule management | unit-preflight-symlinks.yaml | tested |
| DD-003 | Beads-sync branch strategy | unit-beads-git.yaml | tested |
| DD-004 | Auto-chain lifecycle on ExitPlanMode | unit-exit-plan-gate.yaml | existence-only |
| DD-005 | Hook + rule mechanism for plan enforcement | unit-code-gate.yaml | tested |
| DD-006 | Formula-driven swarm with wisps | unit-dispatch-state.yaml | existence-only |
| DD-007 | Heuristic-based formula auto-selection | unit-swarm-formula-select.yaml | tested |
| DD-008 | Zero-question setup with always-on capabilities | unit-setup-project.yaml | tested |
| DD-009 | Blocking specification reconciliation (default) | unit-engineer.yaml | existence-only |
| DD-010 | Plugin consolidation (historical) | unit-preflight.yaml | existence-only |
| DD-011 | Soft-delete bead pruning | unit-plan-prune.yaml | tested |
| DD-012 | State directory migration (.claude/ -> .yoshiko-flow/) | unit-preflight.yaml | existence-only |
| DD-013 | Standards-driven code implementation formula | — | untested |
| DD-014 | Specifications as anchor documents | unit-spec-sanity.yaml | tested |

## Non-Functional Requirements (NFR-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| NFR-001 | Preflight <50ms fast path | unit-preflight.yaml | existence-only |
| NFR-002 | Fail-open hooks | unit-code-gate.yaml | existence-only |
| NFR-003 | Bash 3.2 compatibility | (all script tests) | existence-only |
| NFR-004 | Zero git footprint | unit-preflight-symlinks.yaml | existence-only |
| NFR-005 | Idempotent operations | unit-plan-intake.yaml | existence-only |
| NFR-006 | Test coverage minimum | unit-yf-structure.yaml | existence-only |
| NFR-007 | Migration safety | unit-preflight.yaml | existence-only |

## Use Cases (UC-xxx)

Aligned to IG files: plan-lifecycle (UC-001–005), swarm-execution (UC-006–009), chronicler (UC-010–013), archivist (UC-014–017), engineer (UC-018–021, UC-033–034), marketplace (UC-022–024), beads-integration (UC-025–028), coder (UC-029–032).

| ID | Summary | IG Source | Test File | Status |
|----|---------|-----------|-----------|--------|
| UC-001 | Auto-chain via ExitPlanMode | plan-lifecycle | unit-exit-plan-gate.yaml | existence-only |
| UC-002 | Manual plan intake (pasted plan) | plan-lifecycle | unit-plan-intake.yaml | tested |
| UC-003 | Task pump dispatch | plan-lifecycle | unit-formula-dispatch.yaml | tested |
| UC-004 | Plan completion | plan-lifecycle | unit-plan-exec-gate.yaml | existence-only |
| UC-005 | Code gate enforcement | plan-lifecycle | unit-code-gate.yaml | tested |
| UC-006 | Full swarm lifecycle | swarm-execution | — | untested |
| UC-007 | Formula auto-selection | swarm-execution | unit-swarm-formula-select.yaml | tested |
| UC-008 | Reactive bugfix on failure | swarm-execution | unit-swarm-reactive.yaml | existence-only |
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
| UC-019 | Plan-spec reconciliation | engineer | unit-engineer.yaml | existence-only |
| UC-020 | Individual spec entry update | engineer | unit-engineer.yaml | existence-only |
| UC-021 | Post-completion spec suggestions | engineer | unit-engineer.yaml | existence-only |
| UC-022 | Plugin registration | marketplace | unit-yf-structure.yaml | existence-only |
| UC-023 | Preflight artifact sync | marketplace | unit-preflight.yaml, unit-preflight-symlinks.yaml | tested |
| UC-024 | Running tests | marketplace | unit-yf-structure.yaml | existence-only |
| UC-025 | Beads setup and git workflow | beads-integration | unit-beads-git.yaml | tested |
| UC-026 | Bead lifecycle during plan execution | beads-integration | unit-plan-exec-gate.yaml | existence-only |
| UC-027 | Automatic bead pruning | beads-integration | unit-plan-prune.yaml | tested |
| UC-028 | Session close protocol | beads-integration | unit-pre-push-chronicle-check.yaml | existence-only |
| UC-029 | Standards-driven code implementation | coder | — | untested |
| UC-030 | Code-implement formula selection | coder | — | untested |
| UC-031 | IG-first standards research | coder | — | untested |
| UC-032 | Standards compliance review | coder | — | untested |
| UC-033 | Plan intake spec integrity gate | engineer | unit-spec-sanity.yaml | tested |
| UC-034 | Plan completion spec self-reconciliation | engineer | unit-spec-sanity.yaml | existence-only |

## Coverage Summary

| Category | Total | Tested | Existence-Only | Untested |
|----------|-------|--------|----------------|----------|
| REQ | 33 | 15 | 17 | 1 |
| DD | 14 | 9 | 3 | 2 |
| NFR | 7 | 0 | 7 | 0 |
| UC | 34 | 11 | 17 | 6 |
| **Total** | **88** | **35** | **44** | **9** |

## Priority Gaps

Items needing behavioral test upgrades (from existence-only) or initial coverage:

1. **REQ-032, UC-029-032** — Coder capability: no test coverage at all (see TODO-023, TODO-024, TODO-025)
2. **DD-013** — Standards-driven code implementation formula: no test coverage
3. **UC-008** — Reactive bugfix eligibility (depth check, label dedup, design-BLOCK exclusion)
4. **UC-018-021** — Engineer spec synthesis, reconciliation, drift, and update suggestions
5. **UC-014-017** — Archivist capture, process, suggestion, and git scan behavioral tests
6. **REQ-021** — Reactive bugfix guard rails (depth limit, retry budget)
7. **REQ-022** — Qualification gate config modes (blocking/advisory/disabled)
8. **NFR-001-007** — All NFRs have existence-only coverage; no behavioral assertions
