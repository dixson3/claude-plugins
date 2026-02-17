# Plan: Test Suite Refactor — Spec-Aligned Pruning and Gap Coverage

## Context

The test suite has grown organically across 20+ plans with different drivers. While all 597 assertions pass, the suite has three problems: (1) three unmaintained integration tests that can't run in `--unit-only` mode, (2) the traceability matrix (`test-coverage.md`) has errors — some tests exist but aren't tracked, and (3) significant spec items have only existence-only coverage (grep for text in files) rather than behavioral assertions that exercise script logic.

This refactor prunes dead weight, corrects the traceability matrix, and creates new behavioral tests for the highest-priority coverage gaps.

## Phase 1: Prune Integration Tests

Delete 3 files — unmaintained since Plan 06 (TODO-014), require live Claude sessions, and duplicate coverage already in unit tests:

| File | Covered By |
|------|-----------|
| `tests/scenarios/gate-enforcement.yaml` | `unit-code-gate.yaml` |
| `tests/scenarios/dismiss-gate.yaml` | `unit-code-gate.yaml` |
| `tests/scenarios/full-lifecycle.yaml` | `unit-plan-exec-gate.yaml`, `unit-exit-plan-gate.yaml` |

Update `tests/run-tests.sh` if it references these files explicitly.

## Phase 2: Fix Traceability Matrix Errors

`unit-code-implement.yaml` already has 13 test cases covering:
- REQ-032 (standards-driven code implementation)
- DD-013 (code-implement formula)
- UC-029 through UC-032 (coder use cases)

These are marked "untested" in `test-coverage.md` — update to "tested" with the correct test file reference.

## Phase 3: New Behavioral Tests

### 3a. `unit-plan-state-machine.yaml` (NEW)
**Covers:** REQ-004, FS-005, UC-004 (plan state transitions)
**Currently:** existence-only in `unit-plan-exec-gate.yaml`

Test `plan-exec.sh` state machine with mock beads:
1. `engage` sets state to "ready" (status output)
2. `start` sets state to "executing"
3. `pause` sets state to "paused"
4. `resume` returns to "executing"
5. `start` on non-ready state fails gracefully (exit 0, error message)
6. `status` reports correct state string after each transition
7. `complete` transition with qualifying gate step

**Scripts:** `plugins/yf/scripts/plan-exec.sh`

### 3b. `unit-swarm-lifecycle.yaml` (NEW)
**Covers:** UC-006, REQ-017, DD-006 (full swarm lifecycle)
**Currently:** untested (UC-006) / existence-only (REQ-017, DD-006)

Test `dispatch-state.sh` swarm lifecycle operations:
1. `swarm create-wisp` initializes wisp state file
2. `swarm mark-dispatched` for each step in sequence
3. `swarm is-dispatched` returns correct status
4. `swarm pending` returns undispatched steps
5. `swarm squash-wisp` clears wisp state
6. Scoped clear doesn't affect pump state
7. Re-dispatch after squash starts clean

**Scripts:** `plugins/yf/scripts/dispatch-state.sh`

### 3c. `unit-nfr-behavioral.yaml` (NEW)
**Covers:** NFR-001 through NFR-007
**Currently:** all existence-only

| NFR | Test | Assertion |
|-----|------|-----------|
| NFR-001 | Run preflight with up-to-date lock; measure wall time | output_contains "up to date" + timing < 100ms |
| NFR-002 | Feed malformed JSON to code-gate.sh | exit_code 0 (fail-open) |
| NFR-003 | `bash -n` syntax check on all .sh scripts | exit_code 0 per file |
| NFR-004 | Run preflight in git repo, check `git status --porcelain` | only .yoshiko-flow/config.json modified |
| NFR-005 | Run preflight twice in sequence | second run identical output, lock unchanged |
| NFR-007 | Create old config format, run preflight | config migrated, old keys removed |

NFR-006 (test coverage minimum) is self-referential — skip behavioral test.

**Scripts:** `plugins/yf/scripts/plugin-preflight.sh`, `plugins/yf/hooks/code-gate.sh`

### 3d. Upgrade `unit-swarm-reactive.yaml` (+3 cases)
**Covers:** REQ-021, UC-008 (reactive bugfix behavioral)
**Currently:** 13 steps, mostly existence checks on SKILL.md text

Add behavioral tests using `dispatch-state.sh`:
1. `mark-retrying` after `mark-done` is a no-op (can't retry completed step)
2. `mark-retrying` on never-dispatched step still succeeds (idempotent)
3. After `mark-retrying`, `pending` includes the step (ready for redispatch)

### 3e. Upgrade `unit-swarm-qualify.yaml` (+3 cases)
**Covers:** REQ-022 (qualification gate config modes)
**Currently:** 10 steps, mostly existence checks

Add behavioral tests using `yf-config.sh`:
1. Default config has `qualification_mode: blocking` (or absent = blocking)
2. `plan-exec.sh status` shows "qualifying" state when appropriate
3. `plan-exec.sh start` records `start-sha` in state file (verify file content, not just grep)

### 3f. Upgrade `unit-engineer.yaml` (+4 cases)
**Covers:** REQ-024, DD-009, UC-019 (spec reconciliation behavior)
**Currently:** 4 steps, all existence checks

Add behavioral tests:
1. Default config reconciliation mode is "blocking"
2. Config with `reconciliation_mode: disabled` reads correctly via `yf-config.sh`
3. `spec-sanity-check.sh` with valid specs exits 0
4. `spec-sanity-check.sh` with intentionally mismatched counts exits non-zero

**Scripts:** `plugins/yf/scripts/yf-config.sh`, `plugins/yf/scripts/spec-sanity-check.sh`

## Phase 4: Update Traceability Matrix

Update `docs/specifications/test-coverage.md`:
1. Fix REQ-032, DD-013, UC-029-032 → "tested" referencing `unit-code-implement.yaml`
2. Add new test file references for all Phase 3 tests
3. Promote upgraded items from "existence-only" to "tested"
4. Remove deleted integration test references
5. Update coverage summary counts
6. Update FS-033 assertion count to match actual total after changes

## Go Test Harness Assessment

**Verdict: No changes needed.** The harness is well-structured, production-quality Go code with a single dependency (yaml.v3). It supports all assertion types needed for this refactor (exit_code, output_contains, file_exists, file_contains, json_field).

**Known limitations** (documented, not blocking):
- No regex assertions — all new tests use substring matching
- No nested JSON path queries — tests use `jq` in shell commands instead
- No subprocess timeout enforcement — acceptable for unit tests
- No parallel scenario execution — 597 assertions complete in ~30s

## Verification

After all phases:
```bash
bash tests/run-tests.sh --unit-only   # All pass, 0 failures
```

Expected outcomes:
- 3 integration test files deleted
- 3 new unit test files created
- 3 existing unit test files upgraded with additional cases
- Traceability matrix corrected and updated
- ~30 new assertions added, total ~620+
- No spec items regress from "tested"

## Critical Files

| File | Action |
|------|--------|
| `tests/scenarios/gate-enforcement.yaml` | Delete |
| `tests/scenarios/dismiss-gate.yaml` | Delete |
| `tests/scenarios/full-lifecycle.yaml` | Delete |
| `tests/scenarios/unit-plan-state-machine.yaml` | Create |
| `tests/scenarios/unit-swarm-lifecycle.yaml` | Create |
| `tests/scenarios/unit-nfr-behavioral.yaml` | Create |
| `tests/scenarios/unit-swarm-reactive.yaml` | Edit (add 3 cases) |
| `tests/scenarios/unit-swarm-qualify.yaml` | Edit (add 3 cases) |
| `tests/scenarios/unit-engineer.yaml` | Edit (add 4 cases) |
| `docs/specifications/test-coverage.md` | Edit |
| `plugins/yf/scripts/plan-exec.sh` | Read-only (test target) |
| `plugins/yf/scripts/dispatch-state.sh` | Read-only (test target) |
| `plugins/yf/scripts/spec-sanity-check.sh` | Read-only (test target) |
| `plugins/yf/hooks/code-gate.sh` | Read-only (test target) |
| `plugins/yf/scripts/plugin-preflight.sh` | Read-only (test target) |
