# Plan: Review yf Test Cases Against v3.0.0 Specs

## Context

The yf plugin underwent a major v3.0.0 migration (beads-cli removal, file-based task system). The test suite has 823/824 passing but contains stale references, an inaccurate coverage matrix, and gaps for the new task system. This plan systematically fixes the one failing test, corrects the coverage matrix, updates stale terminology, and adds new tests for the v3.0.0 task API.

## Phase 1: Fix the Failing Test (CRITICAL)

**File**: `tests/scenarios/unit-formula-dispatch.yaml:68`

The grep pattern references `parent_bead:` but the skill now uses `parent_task:`. This is the single failing test (confirmed by `run-tests.sh`).

- Change `parent_bead:` to `parent_task:` in the Case 7 grep pattern

## Phase 2: Fix Stale Terminology in Comments

**File**: `tests/scenarios/unit-pump-dispatch.yaml`
- Line 6: "dispatched bead stays dispatched" -> "dispatched task stays dispatched"
- Line 31: "Done bead no longer in pending" -> "Done task no longer in pending"

These are comment-only fixes (test logic is correct).

## Phase 3: Correct Coverage Matrix Misclassifications

**File**: `docs/specifications/test-coverage.md`

10 items are marked "untested" but actually have behavioral test coverage. Verified by reading each test file — they call real scripts, check exit codes, parse JSON output, and validate structured output.

| Item | Current | Correct | Evidence |
|------|---------|---------|----------|
| REQ-039 | untested | tested | `unit-pre-push-land.yaml` — 5 cases testing exit codes 0/2, dirty tree blocking, in-progress task blocking, structured output |
| REQ-041 | untested | tested | `unit-session-end.yaml` Cases 5-6 (dirty-tree markers), `unit-session-recall.yaml` Cases 9-10 |
| REQ-045 | untested | tested | `unit-tracker-detect.yaml` — 8 cases testing explicit/auto config, fallback, JSON validity |
| REQ-046 | untested | tested | `unit-issue-disambiguation.yaml` — 6 cases testing collision detection, custom repo, defaults |
| DD-017 | untested | tested | `unit-pre-push-land.yaml` (same 5 cases) |
| DD-019 | untested | tested | `unit-tracker-detect.yaml` + `unit-tracker-api.yaml` |
| DD-020 | untested | tested | `unit-issue-disambiguation.yaml` |
| UC-039 | untested | tested | `unit-pre-push-land.yaml` |
| UC-041 | untested | tested | `unit-session-end.yaml` + `unit-session-recall.yaml` |
| UC-045 | untested | tested | `unit-tracker-detect.yaml` |

Items that remain legitimately untested (require live Claude/`gh` sessions):
- REQ-040, REQ-042, REQ-043, REQ-044, REQ-047
- UC-040, UC-042, UC-043, UC-044, UC-046, UC-047

Update the coverage summary table counts accordingly.

## Phase 4: Add Task System Tests (NEW — Coverage Gap)

The `yf-tasks.sh` library and `yf-task-cli.sh` CLI are the core v3.0.0 replacements for beads-cli. Currently **zero** direct test scenarios exist for them (only 2 indirect references across all test files).

### 4a: `tests/scenarios/unit-yf-tasks.yaml` (~12 cases)

Source `yf-tasks.sh` directly, call `yft_*` functions, verify JSON output with jq:

1. `yft_create` — basic task creation, verify JSON file written with correct fields
2. `yft_create` with `--type epic` — verify `_epic.json` directory structure
3. `yft_create` with `--parent` — verify child task linked to parent
4. `yft_create` with `--type gate` — verify gate type set correctly
5. `yft_show` — verify task details returned (plain text and `--json`)
6. `yft_update` — status transition (open -> in_progress -> closed)
7. `yft_update` — label modification
8. `yft_close` — verify task closed with reason
9. `yft_list` — filter by type, status, label
10. `yft_list --ready` — only returns open, non-deferred, unblocked tasks
11. `yft_dep_add` + `--ready` filtering — blocked task excluded from ready list
12. `yft_comment` — add structured comment, verify in task JSON

### 4b: `tests/scenarios/unit-yf-task-cli.yaml` (~6 cases)

Call `yf-task-cli.sh` as a subprocess, verify dispatch:

1. `create` command creates task file
2. `list` command returns task list
3. `ready` command filters to ready tasks only
4. `show` command displays task details
5. `help` outputs usage info
6. Unknown command exits 1

## Phase 5: Run Tests & Update Counts

1. Run `bash tests/run-tests.sh --unit-only` — verify 0 failures
2. Update `test-coverage.md` assertion count from 824 to reflect new total
3. Update coverage summary table with corrected counts

## Files to Modify

- `tests/scenarios/unit-formula-dispatch.yaml` — fix `parent_bead:` -> `parent_task:`
- `tests/scenarios/unit-pump-dispatch.yaml` — fix 2 stale comments
- `docs/specifications/test-coverage.md` — correct 10 misclassified statuses + update counts

## Files to Create

- `tests/scenarios/unit-yf-tasks.yaml` — task library behavioral tests
- `tests/scenarios/unit-yf-task-cli.yaml` — CLI wrapper tests

## Key References

- `plugins/yf/scripts/yf-tasks.sh` — task library API (functions to test)
- `plugins/yf/scripts/yf-task-cli.sh` — CLI wrapper (interface to test)
- `plugins/yf/skills/plan_execute/SKILL.md:92` — confirms `parent_task:` is current

## Verification

```bash
# After all changes:
bash tests/run-tests.sh --unit-only
# Expected: 0 failures, assertion count increases by ~36 (18 new scenarios x 2 avg assertions)
```
