# TODO Register

## Active Items

| ID | Description | Priority | Source | Status |
|----|-------------|----------|--------|--------|
| TODO-001 | PostToolUse ambient session log for chronicler -- creates low-overhead context capture during work without explicit invocation | P3 | Plan 22 (Phase 3, deferred) | Deferred |
| TODO-002 | Agent Teams integration hooks (TeammateIdle, TaskCompleted) for persistent multi-session coordination | P3 | Plan 07 (Phase 2.2, optional) | Deferred |
| TODO-003 | End-to-end validation of auto-formula selection during a real `plan_create_beads` run | P2 | Diary 26-02-13.23-25 (Next Steps) | Open |
| TODO-004 | Test nested composition with feature-build composing build-test end-to-end | P2 | Diary 26-02-13.23-25 (Next Steps) | Open |
| TODO-005 | Verify reactive bugfix triggers correctly on REVIEW:BLOCK in a real swarm execution | P2 | Diary 26-02-13.23-25 (Next Steps) | Open |
| TODO-006 | Verify formula cooking with `bd cook --dry-run` for all 6 formulas (feature-build, research-spike, code-review, bugfix, build-test, code-implement) | P2 | Diary 26-02-13.22-30 (Next Steps) | Open |
| TODO-007 | Verify reconciliation behavior on a project with existing specification documents | P2 | Diary 26-02-14.18-00 (Next Steps) | Open |
| TODO-008 | ~~Monitor beads-sync branch strategy in multi-session workflows for sync reliability~~ | P2 | Diary 26-02-13.17-52 (Next Steps) | Resolved |
| TODO-009 | Validate automatic migration for legacy local-only beads deployments in external projects | P2 | Diary 26-02-13.17-52 (Next Steps) | Open |
| TODO-010 | ~~Marketplace version in `marketplace.json` is 2.11.0, behind plugin version 2.17.0~~ | P1 | `.claude-plugin/marketplace.json` | Resolved |
| TODO-011 | ~~Root README.md plugin table shows version 2.11.0, behind actual version 2.17.0~~ | P1 | `README.md` line 18 | Resolved |
| TODO-012 | Monitor symlinks on different platforms or CI environments for compatibility issues | P3 | Diary 26-02-08.19-00 (Next Steps) | Open |
| TODO-013 | Consider per-subsystem EDD files for complex projects (currently only CORE.md template) | P3 | Plan 34 (artifact structure) | Deferred |
| TODO-014 | Integration tests (non-unit) have not been maintained since Plan 06 -- scenarios may be outdated | P2 | `tests/scenarios/gate-enforcement.yaml`, `full-lifecycle.yaml`, `dismiss-gate.yaml` | Open |
| TODO-015 | `bd create --type=gate` produces validation errors in some beads-cli versions; gates created as tasks with `ys:gate` labels as workaround | P2 | Diary 26-02-08.19-00, Diary 26-02-13.22-30 | Open |
| TODO-016 | Verify config pruning works on an existing installation with old chronicler/archivist toggle keys | P2 | Diary 26-02-14.14-30 (Next Steps) | Open |
| TODO-017 | ~~Plan 24 and Plan 26 status still shows "Draft" in plan files but work appears completed~~ | P1 | `docs/plans/plan-24.md`, `docs/plans/plan-26.md` | Resolved |
| TODO-018 | Confirm chronicle safety net fires appropriately during plan execution without false positives | P2 | Diary 26-02-13.17-52 (Next Steps) | Open |
| TODO-019 | UC-008 behavioral test: reactive bugfix eligibility logic (depth check, label dedup, design-BLOCK exclusion) | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open |
| TODO-020 | UC-018-021 behavioral tests: engineer synthesis, reconciliation, drift detection, update suggestions | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open |
| TODO-021 | UC-014-017 behavioral tests: archivist capture, process, suggestion, git scan workflows | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open |
| TODO-022 | Integration test maintenance: refresh gate-enforcement.yaml, full-lifecycle.yaml, dismiss-gate.yaml (see TODO-014) | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open |
| TODO-023 | End-to-end test: code-implement formula dispatched from plan pump via swarm_run | P2 | Plan 35 Phase 5 (coder capability) | Open |
| TODO-024 | End-to-end test: code-researcher checks existing IGs before researching standards | P2 | Plan 35 Phase 5 (coder capability) | Open |
| TODO-025 | End-to-end test: reactive bugfix triggers on REVIEW:BLOCK within code-implement swarm | P2 | Plan 35 Phase 5 (coder capability) | Open |
| TODO-026 | E2E validation of intake integrity gate during real plan with spec changes | P2 | Plan 40 (spec integrity gates) | Open |
| TODO-027 | E2E validation of activation gate: verify skill refusal when beads plugin missing, when config absent, and when `enabled: false` | P2 | Plan 42 (activation gate) | Open |
| TODO-028 | Validate hybrid beads routing: confirm agent operations use beads skills and shell scripts use bd CLI without regression | P2 | Plan 42 (activation gate) | Open |
| TODO-029 | E2E validation of memory reconciliation with real MEMORY.md and spec files | P2 | Plan 43 (memory reconcile) | Open |
| TODO-030 | E2E validation of skill-level chronicle capture during real plan execution | P2 | Plan 44 (chronicle worthiness) | Open |

## Completed Items

| ID | Description | Completed | Source |
|----|-------------|-----------|--------|
| TODO-C01 | Make `.beads/` local-only (same pattern as gitignored rules) | v2.5.0 (reversed in v2.12.0) | Plan 18, Diary 26-02-08.19-00 |
| TODO-C02 | Implement research-spike formula with auto-archive step | v2.13.0 | Plan 28 |
| TODO-C03 | Strengthen chronicle watch rule for infrastructure operations | v2.14.1 | Plan 31 |
| TODO-C04 | Add config pruning for deprecated chronicler/archivist fields | v2.16.0 | Plan 33 |
| TODO-C05 | Monitor beads-sync branch strategy — moot after dolt-native persistence (DD-003) | v2.22.0 | Plan 45 |
