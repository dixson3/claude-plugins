# TODO Register

## Active Items

| ID | Description | Priority | Source | Status | GH |
|----|-------------|----------|--------|--------|----|
| TODO-001 | PostToolUse ambient session log for chronicler -- creates low-overhead context capture during work without explicit invocation | P3 | Plan 22 (Phase 3, deferred) | Deferred | [#4](https://github.com/dixson3/claude-plugins/issues/4) |
| TODO-002 | Agent Teams integration hooks (TeammateIdle, TaskCompleted) for persistent multi-session coordination | P3 | Plan 07 (Phase 2.2, optional) | Deferred | [#9](https://github.com/dixson3/claude-plugins/issues/9) |
| TODO-003 | End-to-end validation of auto-formula selection during a real `plan_create_beads` run | P2 | Diary 26-02-13.23-25 (Next Steps) | Open | [#18](https://github.com/dixson3/claude-plugins/issues/18) |
| TODO-004 | Test nested composition with feature-build composing build-test end-to-end | P2 | Diary 26-02-13.23-25 (Next Steps) | Open | [#18](https://github.com/dixson3/claude-plugins/issues/18) |
| TODO-005 | Verify reactive bugfix triggers correctly on REVIEW:BLOCK in a real swarm execution | P2 | Diary 26-02-13.23-25 (Next Steps) | Open | [#18](https://github.com/dixson3/claude-plugins/issues/18) |
| TODO-006 | Verify formula cooking with `bd cook --dry-run` for all 6 formulas (feature-build, research-spike, code-review, bugfix, build-test, code-implement) | P2 | Diary 26-02-13.22-30 (Next Steps) | Open | [#18](https://github.com/dixson3/claude-plugins/issues/18) |
| TODO-007 | Verify reconciliation behavior on a project with existing specification documents | P2 | Diary 26-02-14.18-00 (Next Steps) | Open | [#30](https://github.com/dixson3/claude-plugins/issues/30) |
| TODO-009 | Validate automatic migration for legacy local-only beads deployments in external projects | P2 | Diary 26-02-13.17-52 (Next Steps) | Open | [#22](https://github.com/dixson3/claude-plugins/issues/22) |
| TODO-012 | Monitor symlinks on different platforms or CI environments for compatibility issues | P3 | Diary 26-02-08.19-00 (Next Steps) | Open | [#23](https://github.com/dixson3/claude-plugins/issues/23) |
| TODO-013 | Consider per-subsystem EDD files for complex projects (currently only CORE.md template) | P3 | Plan 34 (artifact structure) | Deferred | [#24](https://github.com/dixson3/claude-plugins/issues/24) |
| TODO-015 | `bd create --type=gate` produces validation errors in some beads-cli versions; gates created as tasks with `ys:gate` labels as workaround | P2 | Diary 26-02-08.19-00, Diary 26-02-13.22-30 | Open | [#25](https://github.com/dixson3/claude-plugins/issues/25) |
| TODO-016 | Verify config pruning works on an existing installation with old chronicler/archivist toggle keys | P2 | Diary 26-02-14.14-30 (Next Steps) | Open | [#26](https://github.com/dixson3/claude-plugins/issues/26) |
| TODO-018 | Confirm chronicle safety net fires appropriately during plan execution without false positives | P2 | Diary 26-02-13.17-52 (Next Steps) | Open | [#27](https://github.com/dixson3/claude-plugins/issues/27) |
| TODO-019 | UC-008 behavioral test: reactive bugfix eligibility logic (depth check, label dedup, design-BLOCK exclusion) | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open | [#20](https://github.com/dixson3/claude-plugins/issues/20) |
| TODO-020 | UC-018-021 behavioral tests: engineer synthesis, reconciliation, drift detection, update suggestions | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open | [#20](https://github.com/dixson3/claude-plugins/issues/20) |
| TODO-021 | UC-014-017 behavioral tests: archivist capture, process, suggestion, git scan workflows | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open | [#20](https://github.com/dixson3/claude-plugins/issues/20) |
| TODO-022 | Integration test maintenance: refresh gate-enforcement.yaml, full-lifecycle.yaml, dismiss-gate.yaml | P2 | Plan 35 Phase 3 (spec-test reconciliation) | Open | [#20](https://github.com/dixson3/claude-plugins/issues/20) |
| TODO-023 | End-to-end test: code-implement formula dispatched from plan pump via swarm_run | P2 | Plan 35 Phase 5 (coder capability) | Open | [#19](https://github.com/dixson3/claude-plugins/issues/19) |
| TODO-024 | End-to-end test: code-researcher checks existing IGs before researching standards | P2 | Plan 35 Phase 5 (coder capability) | Open | [#19](https://github.com/dixson3/claude-plugins/issues/19) |
| TODO-025 | End-to-end test: reactive bugfix triggers on REVIEW:BLOCK within code-implement swarm | P2 | Plan 35 Phase 5 (coder capability) | Open | [#19](https://github.com/dixson3/claude-plugins/issues/19) |
| TODO-026 | E2E validation of intake integrity gate during real plan with spec changes | P2 | Plan 40 (spec integrity gates) | Open | [#21](https://github.com/dixson3/claude-plugins/issues/21) |
| TODO-029 | E2E validation of memory reconciliation with real MEMORY.md and spec files | P2 | Plan 43 (memory reconcile) | Open | [#21](https://github.com/dixson3/claude-plugins/issues/21) |
| TODO-030 | E2E validation of skill-level chronicle capture during real plan execution | P2 | Plan 44 (chronicle worthiness) | Open | [#21](https://github.com/dixson3/claude-plugins/issues/21) |
| TODO-031 | Fix `unit-chronicle-check.yaml` test failures — uses relative `./plugins/yf/` paths that resolve to WORK_DIR instead of PLUGIN_DIR | P2 | Plan 48 (test overhaul) | Open | [#28](https://github.com/dixson3/claude-plugins/issues/28) |
| TODO-032 | `code-gate.sh` glob patterns (e.g. `*/docs/plans/*`) require absolute path prefix — relative paths like `docs/plans/plan-1.md` don't match case statements | P3 | Plan 48 (integ-code-gate) | Open | [#29](https://github.com/dixson3/claude-plugins/issues/29) |

## Completed Items

| ID | Description | Completed | Source |
|----|-------------|-----------|--------|
| TODO-C01 | Make `.beads/` local-only (same pattern as gitignored rules) | v2.5.0 (reversed in v2.12.0) | Plan 18, Diary 26-02-08.19-00 |
| TODO-C02 | Implement research-spike formula with auto-archive step | v2.13.0 | Plan 28 |
| TODO-C03 | Strengthen chronicle watch rule for infrastructure operations | v2.14.1 | Plan 31 |
| TODO-C04 | Add config pruning for deprecated chronicler/archivist fields | v2.16.0 | Plan 33 |
| TODO-C05 | Monitor beads-sync branch strategy — moot after dolt-native persistence (DD-003) | v2.22.0 | Plan 45 |
| TODO-008 | Monitor beads-sync branch strategy in multi-session workflows for sync reliability | v2.22.0 | Diary 26-02-13.17-52 |
| TODO-010 | Marketplace version in `marketplace.json` is 2.11.0, behind plugin version 2.17.0 | v2.19.0 | `.claude-plugin/marketplace.json` |
| TODO-011 | Root README.md plugin table shows version 2.11.0, behind actual version 2.17.0 | v2.19.0 | `README.md` |
| TODO-014 | Integration tests not maintained since Plan 06 — replaced by 5 new integration scenarios in Plan 48 | v2.25.0 | `tests/scenarios/integ-*.yaml` |
| TODO-017 | Plan 24 and Plan 26 status still shows "Draft" in plan files but work appears completed | v2.20.0 | `docs/plans/plan-24.md`, `docs/plans/plan-26.md` |
| TODO-027 | E2E validation of activation gate — covered by `integ-activation-gate.yaml` (Plan 48) | v2.25.0 | Plan 42 (activation gate) |
| TODO-028 | Validate hybrid beads routing — moot after DD-016 reversal (beads plugin removed) | v2.25.0 | Plan 42 (activation gate) |
| TODO-033 | Define and use a subagent for plan-to-beads breakdown — `plan_breakdown` skill exists; GH #17 closed | v2.25.0 | GitHub issue #17 |
