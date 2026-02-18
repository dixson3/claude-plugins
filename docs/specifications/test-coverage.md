# Test Coverage Traceability Matrix

Maps each specification item to its test coverage. Status key: **tested** (behavioral assertions), **existence-only** (file/field existence checks), **untested** (no test coverage).

## Requirements (REQ-xxx)

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| REQ-001 | Namespace isolation | unit-naming-convention.yaml | tested |
| REQ-002 | Preflight symlinks <50ms | unit-preflight.yaml, unit-preflight-symlinks.yaml | tested |
| REQ-003 | Plans to beads hierarchy | unit-plan-exec-gate.yaml | existence-only |
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
| REQ-026 | Bead auto-pruning | unit-plan-prune.yaml | tested |
| REQ-027 | Beads git-tracked | unit-beads-git.yaml | tested |
| REQ-028 | Zero-question setup | unit-setup-project.yaml | tested |
| REQ-029 | Gitignore management | unit-setup-project.yaml | tested |
| REQ-030 | YAML test scenarios | unit-yf-structure.yaml | existence-only |
| REQ-031 | Go test harness | unit-yf-structure.yaml | existence-only |
| REQ-032 | Standards-driven code implementation | unit-code-implement.yaml | tested |
| REQ-033 | Spec integrity gates at intake/completion | unit-spec-sanity.yaml | tested |
| REQ-034 | Three-condition activation gate | unit-activation.yaml, unit-yf-config.yaml | tested |
| REQ-035 | Beads plugin dependency enforcement | unit-activation.yaml, unit-preflight.yaml | tested |
| REQ-036 | User-scope install with per-project activation | unit-activation.yaml, unit-preflight.yaml | tested |
| REQ-037 | Memory reconciliation | unit-memory-reconcile.yaml | existence-only |
| REQ-038 | Skill-level chronicle auto-capture | unit-chronicle-worthiness.yaml | existence-only |

## Design Decisions (DD-xxx)

Aligned to EDD/CORE.md DD-001 through DD-014.

| ID | Summary | Test File | Status |
|----|---------|-----------|--------|
| DD-001 | Beads as persistent task store | unit-pump-dispatch.yaml | tested |
| DD-002 | Symlink-based rule management | unit-preflight-symlinks.yaml | tested |
| DD-003 | Dolt-native persistence (no sync, no hooks) | unit-beads-git.yaml | tested |
| DD-004 | Auto-chain lifecycle on ExitPlanMode | unit-exit-plan-gate.yaml | existence-only |
| DD-005 | Hook + rule mechanism for plan enforcement | unit-code-gate.yaml | tested |
| DD-006 | Formula-driven swarm with wisps | unit-swarm-lifecycle.yaml | tested |
| DD-007 | Heuristic-based formula auto-selection | unit-swarm-formula-select.yaml | tested |
| DD-008 | Zero-question setup with always-on capabilities | unit-setup-project.yaml | tested |
| DD-009 | Blocking specification reconciliation (default) | unit-engineer.yaml | tested |
| DD-010 | Plugin consolidation (historical) | unit-preflight.yaml | existence-only |
| DD-011 | Soft-delete bead pruning | unit-plan-prune.yaml | tested |
| DD-012 | State directory migration (.claude/ -> .yoshiko-flow/) | unit-preflight.yaml | existence-only |
| DD-013 | Standards-driven code implementation formula | unit-code-implement.yaml | tested |
| DD-014 | Specifications as anchor documents | unit-spec-sanity.yaml | tested |
| DD-015 | Three-condition activation model | unit-activation.yaml, unit-yf-config.yaml | tested |
| DD-016 | Hybrid beads routing | — | untested |

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

Aligned to IG files: plan-lifecycle (UC-001–005), swarm-execution (UC-006–009), chronicler (UC-010–013, UC-037–038), archivist (UC-014–017), engineer (UC-018–021, UC-033–034), marketplace (UC-022–024, UC-035–036), beads-integration (UC-025–028), coder (UC-029–032).

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
| UC-025 | Beads setup and git workflow | beads-integration | unit-beads-git.yaml | tested |
| UC-026 | Bead lifecycle during plan execution | beads-integration | unit-plan-exec-gate.yaml | existence-only |
| UC-027 | Automatic bead pruning | beads-integration | unit-plan-prune.yaml | tested |
| UC-028 | Session close protocol | beads-integration | unit-pre-push-chronicle-check.yaml | existence-only |
| UC-029 | Standards-driven code implementation | coder | unit-code-implement.yaml | tested |
| UC-030 | Code-implement formula selection | coder | unit-code-implement.yaml | tested |
| UC-031 | IG-first standards research | coder | unit-code-implement.yaml | tested |
| UC-032 | Standards compliance review | coder | unit-code-implement.yaml | tested |
| UC-033 | Plan intake spec integrity gate | engineer | unit-spec-sanity.yaml | tested |
| UC-034 | Plan completion spec self-reconciliation | engineer | unit-spec-sanity.yaml | existence-only |
| UC-035 | Plugin activation gate check | marketplace | unit-activation.yaml | tested |
| UC-036 | Per-project activation via /yf:setup | marketplace | unit-activation.yaml | tested |
| UC-037 | Memory reconciliation | chronicler | unit-memory-reconcile.yaml | existence-only |
| UC-038 | Skill-level auto-chronicle at decision points | chronicler | unit-chronicle-worthiness.yaml | existence-only |

## Coverage Summary

| Category | Total | Tested | Existence-Only | Untested |
|----------|-------|--------|----------------|----------|
| REQ | 38 | 24 | 14 | 0 |
| DD | 16 | 13 | 2 | 1 |
| NFR | 7 | 6 | 1 | 0 |
| UC | 38 | 21 | 16 | 1 |
| **Total** | **99** | **64** | **33** | **2** |

Total assertions: **667** (across all unit test scenarios)

## Priority Gaps

Remaining items needing behavioral test upgrades or initial coverage:

1. **UC-016** — Archive processing into docs: untested (requires live agent interaction)
2. **UC-018, UC-020-021** — Engineer spec synthesis, individual update, and post-completion suggestions (existence-only)
3. **UC-014-017** — Archivist capture, process, suggestion, and git scan (existence-only)
4. **REQ-003, REQ-006** — Plans-to-beads hierarchy and auto-chain (existence-only)
