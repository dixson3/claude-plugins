# Plan 25: Resilient Chronicle Auto-Capture

**Status:** Completed
**Date:** 2026-02-13

## Overview

Chronicle capture currently depends on the LLM noticing chronicle-worthy moments via the `yf-watch-for-chronicle-worthiness` rule. This is fragile — the LLM forgets after context compaction, and session-boundary hooks only detect git activity (not in-progress beads). The goal is to move capture triggers from LLM judgment into deterministic hooks and scripts, while keeping the existing suggest-only rule for ambiguous moments.

Implement 4 of 5 recommendations. Defer "strengthen the watch rule" (Rec 4) — the deterministic changes cover the critical gaps, and making the rule auto-capture risks unwanted bead creation.

## Implementation Sequence

### Phase 1: Beads-State Analysis in `chronicle-check.sh`
Add a new analysis pass (after existing keyword/significant-file/volume checks, before draft creation):
- Query `bd list --status=in_progress --type=task`
- If count > 0, add `in-progress-beads:N` to `CANDIDATE_REASONS`
- Include in-progress titles (head 5) in the draft description

### Phase 2: Plan Lifecycle Auto-Chronicles in `plan-exec.sh`
Add `create_transition_chronicle()` helper function:
- Guards: `yf_is_chronicler_on`, `bd` available
- Dedup: `.beads/.chronicle-transition-YYYYMMDD` with key `plan-<label>-<transition>`
- Labels: `ys:chronicle,ys:chronicle:auto,ys:topic:planning,<plan-label>`
- Includes plan state snapshot (ready/in-progress/closed task counts)
- Wire into: `start`, `pause`, and `status` (completion detection) commands

### Phase 3: Staleness Detection Script + Hook Wiring
New `chronicle-staleness.sh`:
- Guards: yf enabled, chronicler enabled, `bd` + `jq` available
- Checks: in-progress beads exist AND most recent chronicle is older than threshold
- Default threshold: 2 hours (1 hour for pre-compact)
- Dedup: `.beads/.chronicle-staleness-YYYYMMDD` with hourly key `staleness-check-HH`
- Labels: `ys:chronicle,ys:chronicle:checkpoint`
- Always exit 0 (fail-open)
- Wire into `session-end.sh` and `pre-compact.sh`

### Phase 4: Periodic Nudge in `code-gate.sh`
Add lightweight staleness nudge inside the "no gate file" fast path (subshell, fail-open):
- Time-gated: `.yoshiko-flow/.chronicle-nudge` file stores last nudge epoch
- Interval: 30 minutes between nudges
- Fires only when: in-progress beads exist AND no chronicle within 1 hour
- Output: advisory `NOTE:` message (stdout), never blocks (exit 0)

### Phase 5: Tests
- New: `unit-chronicle-staleness.yaml` (8 cases)
- New: `unit-plan-exec-chronicle.yaml` (5 cases)
- Modified: `unit-chronicle-check.yaml` (+2 cases)
- Modified: `unit-code-gate.yaml` (+1 case)

## Completion Criteria

- [ ] `chronicle-check.sh` detects in-progress beads as candidates
- [ ] `plan-exec.sh` creates transition chronicles on start/pause/complete
- [ ] `chronicle-staleness.sh` creates checkpoint beads when work is stale
- [ ] `session-end.sh` and `pre-compact.sh` call staleness check
- [ ] `code-gate.sh` emits nudge when chronicles are stale
- [ ] All existing tests pass
- [ ] New tests cover all new functionality
- [ ] Dedup prevents excessive bead creation
