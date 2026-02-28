# Fix: code-gate.sh blocks edits after completed plan tasks are pruned

**Issue:** [#42](https://github.com/dixson3/claude-plugins/issues/42)

## Context

After a plan completes, `plan-exec.sh status` prunes all closed tasks, then returns "completed". However, the plan file's `Status:` line is only updated to "Completed" by the `plan_engage` agent skill — an agent-driven step that may not run (or may run after a cache expiry). When `code-gate.sh` re-evaluates after the 60-second cache expires, it:

1. Reads the plan file — finds `Status: Active` (not yet updated)
2. Queries `yft_list -l "plan:<idx>" --type=epic` — finds **zero** epics (pruned)
3. Concludes the plan has no tasks → **BLOCKED**

The root cause is that `plan-exec.sh` prunes tasks without ensuring the plan file status is durably marked as "Completed" first.

## Approach

**Update `plan-exec.sh` to write "Completed" status into the plan file as part of the completion flow**, before pruning tasks. This makes the completed state durable and self-contained — the code-gate's existing `grep -q 'Status: Completed'` check (line 94) already handles this case correctly.

### Changes

#### 1. `plugins/yf/scripts/plan-exec.sh` — Mark plan file as Completed on completion

In the `status` command's completion branch (around line 255), before pruning:

- Extract the plan index from `$PLAN_LABEL` (strip `plan:` prefix)
- Find the plan file at `docs/plans/plan-${PLAN_IDX}.md`
- Use `sed` to replace the `Status:` line with `Status: Completed`
- Also update `_index.md` status column for this plan to "Completed"

This ensures that even after pruning, `code-gate.sh` will find "Status: Completed" in the plan file and skip the intake check.

```bash
# Update plan file status to Completed (before prune, so code-gate sees it)
PLAN_IDX="${PLAN_LABEL#plan:}"
PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/docs/plans"
PLAN_FILE=$(ls "$PLANS_DIR"/plan-*"${PLAN_IDX}"*.md 2>/dev/null | head -1)
if [[ -n "$PLAN_FILE" ]]; then
  sed -i '' 's/\(Status:\?\) .*/\1 Completed/' "$PLAN_FILE" 2>/dev/null || true
fi
# Update _index.md
INDEX_FILE="$PLANS_DIR/_index.md"
if [[ -f "$INDEX_FILE" ]]; then
  sed -i '' "s/| ${PLAN_IDX} |\\(.*\\)| Active |/| ${PLAN_IDX} |\\1| Completed |/" "$INDEX_FILE" 2>/dev/null || true
fi
```

#### 2. `tests/scenarios/unit-code-gate-intake.yaml` — Add test case for pruned-completed plan

New Case 9: Plan file with Active status but no tasks, simulating the pruned state. Currently this blocks (the bug). After fix, `plan-exec.sh` would have already updated the status, but we should also test the existing completed-plan bypass to confirm it works end-to-end with the update.

More importantly, add a Case 10 that exercises the full flow: plan file starts "Active", tasks exist, then tasks are removed (simulating prune), confirm the block fires — then update status to "Completed" and confirm the block clears.

### Files to modify

| File | Change |
|------|--------|
| `plugins/yf/scripts/plan-exec.sh` | Add plan file + index status update in completion branch (before prune) |
| `tests/scenarios/unit-code-gate-intake.yaml` | Add test case for post-prune completed plan |

## Verification

1. Run existing tests to confirm no regressions:
   ```bash
   bash tests/run-tests.sh --unit-only --scenarios tests/scenarios/unit-code-gate-intake.yaml
   ```

2. Run the new test case to confirm the fix works

3. Run full unit suite:
   ```bash
   bash tests/run-tests.sh --unit-only
   ```
