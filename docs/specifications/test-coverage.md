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
| REQ-017 | Swarm dispatch loop | unit-swarm-state.yaml | existence-only |
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

## Design Decisions (DD-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| DD-001 | Beads as persistent store | unit-pump-dispatch.yaml | tested |
| DD-002 | Symlink rule management | unit-preflight-symlinks.yaml | tested |
| DD-003 | Layered enforcement | unit-code-gate.yaml | tested |
| DD-004 | Always-on chronicler | unit-chronicle-check.yaml | tested |
| DD-005 | beads-sync branch | unit-beads-git.yaml | tested |
| DD-006 | Wisps for formula instances | unit-swarm-state.yaml | existence-only |
| DD-007 | Comment protocol | unit-swarm-comment-protocol.yaml | tested |
| DD-008 | Heuristic formula selection | unit-swarm-formula-select.yaml | tested |
| DD-009 | Preflight artifact declarations | unit-preflight.yaml | existence-only |
| DD-010 | Git hooks for beads sync | unit-beads-git.yaml | existence-only |
| DD-011 | Spec synthesis from context | unit-engineer.yaml | existence-only |
| DD-012 | Reconciliation modes | unit-engineer.yaml | existence-only |

## Non-Functional Requirements (NFR-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| NFR-001 | Preflight <50ms fast path | unit-preflight.yaml | existence-only |
| NFR-002 | Fail-open hooks | unit-code-gate.yaml | existence-only |
| NFR-003 | Zero-config setup | unit-setup-project.yaml | existence-only |
| NFR-004 | Bash 3.2 compatibility | (all script tests) | existence-only |
| NFR-005 | Idempotent operations | unit-plan-intake.yaml | existence-only |
| NFR-006 | Plan gate < 10ms check | unit-code-gate.yaml | existence-only |
| NFR-007 | Graceful degradation | unit-preflight-disabled.yaml | existence-only |

## Use Cases (UC-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| UC-001 | Plugin installation | unit-preflight-setup.yaml | tested |
| UC-002 | Plan creation and execution | unit-plan-exec-gate.yaml | existence-only |
| UC-003 | Formula dispatch integration | unit-formula-dispatch.yaml | tested |
| UC-004 | Auto-chain lifecycle | unit-exit-plan-gate.yaml | existence-only |
| UC-005 | Plan intake (pasted) | unit-plan-intake.yaml | tested |
| UC-006 | Full swarm lifecycle | — | untested |
| UC-007 | Formula auto-selection | unit-swarm-formula-select.yaml | tested |
| UC-008 | Reactive bugfix | unit-swarm-reactive.yaml | existence-only |
| UC-009 | Nested composition | unit-swarm-nesting.yaml | tested |
| UC-010 | Qualification gate | unit-swarm-qualify.yaml | existence-only |
| UC-011 | Chronicle capture | unit-chronicle-check.yaml | tested |
| UC-012 | Session recall | unit-session-recall.yaml | tested |
| UC-013 | Diary generation | unit-plan-exec-chronicle.yaml | existence-only |
| UC-014 | Archive capture | unit-archive-suggest.yaml | existence-only |
| UC-015 | Archive processing | — | untested |
| UC-016 | Archive suggestion | unit-archive-suggest.yaml | existence-only |
| UC-017 | Git history archive scan | unit-archive-suggest.yaml | existence-only |
| UC-018 | Spec synthesis | unit-engineer.yaml | existence-only |
| UC-019 | Plan reconciliation | unit-engineer.yaml | existence-only |
| UC-020 | Spec drift detection | unit-engineer.yaml | existence-only |
| UC-021 | Spec update suggestions | unit-engineer.yaml | existence-only |
| UC-022 | Bead pruning on completion | unit-plan-prune.yaml | tested |
| UC-023 | Beads git sync | unit-beads-git.yaml | tested |
| UC-024 | Zero-question setup | unit-setup-project.yaml | tested |
| UC-025 | Code-gate enforcement | unit-code-gate.yaml | tested |
| UC-026 | Plan intake with gate | unit-code-gate-intake.yaml | tested |
| UC-027 | Pre-push chronicle check | unit-pre-push-chronicle-check.yaml | tested |
| UC-028 | Pre-push archive check | unit-pre-push-archive.yaml | tested |

## Coverage Summary

| Category | Total | Tested | Existence-Only | Untested |
|----------|-------|--------|----------------|----------|
| REQ | 31 | 14 | 17 | 0 |
| DD | 12 | 8 | 4 | 0 |
| NFR | 7 | 0 | 7 | 0 |
| UC | 28 | 14 | 12 | 2 |
| **Total** | **78** | **36** | **40** | **2** |

## Priority Gaps

Items needing behavioral test upgrades (from existence-only):

1. **UC-008** — Reactive bugfix eligibility (depth check, label dedup, design-BLOCK exclusion)
2. **UC-018-021** — Engineer spec synthesis, reconciliation, drift, and update suggestions
3. **UC-014-017** — Archivist capture, process, suggestion, and git scan behavioral tests
4. **REQ-021** — Reactive bugfix guard rails (depth limit, retry budget)
5. **REQ-022** — Qualification gate config modes (blocking/advisory/disabled)
