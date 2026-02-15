# Plan 37: Make chronicles deterministic at plan lifecycle boundaries

**Status:** Completed
**Date:** 2026-02-14

## Context

Chronicles during plan execution rely on agent compliance with rules and skill instructions. Agents skip chronicle steps during complex multi-step work — the agent is told "REQUIRED: capture a chronicle" but skips it under cognitive load. This happened in plan 36 execution where plan_intake Step 4 was skipped entirely.

The PRD requirement: chronicles MUST happen deterministically at plan lifecycle boundaries. No agent judgment, no skipping.

### Current State

Two tiers of chronicle triggers exist:

| Tier | Mechanism | Reliability |
|------|-----------|-------------|
| **Deterministic** | Shell hooks/scripts (`plan-exec.sh`, `chronicle-check.sh`, `session-end.sh`) | High — no agent judgment |
| **Agent-dependent** | Rules/skill instructions (`plan-transition-chronicle`, `plan_intake` Step 4, `plan_execute` Step 4.1) | Low — agents skip under load |

`plan-exec.sh` already has a `create_transition_chronicle()` function (lines 74-116) that fires deterministically at `start`, `pause`, and `complete` transitions. This is the proven pattern. The gap is the **plan-save** boundary (ExitPlanMode / intake) which has no deterministic mechanism.

## Solution: Hybrid Stub + Optional Enrichment

Shell scripts create **guaranteed stub chronicles** at every plan boundary. Agents **optionally enrich** them. A stub that exists beats a rich chronicle that doesn't.

### Architecture

```
BEFORE (unreliable):
  ExitPlanMode hook → agent told to chronicle → agent skips it
  plan_intake skill → agent told to chronicle → agent skips it

AFTER (deterministic + optional enrichment):
  ExitPlanMode hook → plan-chronicle.sh save  → stub GUARANTEED
  plan_intake skill → bash plan-chronicle.sh  → stub GUARANTEED
  plan-exec.sh start/complete                 → stub GUARANTEED (already works)
  plan-exec.sh status=completed               → chronicle-validate.sh verifies all gaps filled
```

## Implementation (9 changes across 7 files + 2 new)

### 1. New: `plugins/yf/scripts/plan-chronicle.sh`

Deterministic plan boundary chronicle creation. Reuses the `create_transition_chronicle` pattern from `plan-exec.sh`.

```bash
#!/bin/bash
# plan-chronicle.sh — Deterministic chronicle stub at plan boundaries
# Usage:
#   plan-chronicle.sh save   <plan_label> [plan_file_path]
#   plan-chronicle.sh intake <plan_label> [plan_file_path]
```

- `save`: Creates stub chronicle when ExitPlanMode saves a plan. Reads first ~20 lines of plan file for context.
- `intake`: Creates stub chronicle when plan_intake imports a plan.
- Dedup: one per plan-boundary per day via `.yoshiko-flow/.chronicle-plan-<date>` file.
- Labels: `ys:chronicle,ys:chronicle:auto,ys:topic:planning,plan:<idx>`
- Fail-open: always exits 0.

### 2. New: `plugins/yf/scripts/chronicle-validate.sh`

Post-completion belt-and-suspenders check.

```bash
#!/bin/bash
# chronicle-validate.sh — Verify chronicle coverage for a plan
# Usage:
#   chronicle-validate.sh <plan_label>
```

- Queries `bd list -l ys:chronicle,<plan_label>` for all plan chronicles
- Checks for: plan-save/intake boundary, start transition, complete transition
- Creates fallback stubs for any missing boundary (label: `ys:chronicle:fallback`)
- Reports: `3/3 boundaries covered` or `2/3, created 1 fallback`

### 3. Edit: `plugins/yf/hooks/exit-plan-gate.sh` (line ~77)

Add deterministic chronicle call after plan save, before `exit 0`:

```bash
# Deterministic chronicle: capture plan-save boundary
bash "$SCRIPT_DIR/scripts/plan-chronicle.sh" save "plan:${NEXT_PAD}" "$DEST" 2>/dev/null || true
```

### 4. Edit: `plugins/yf/skills/plan_intake/SKILL.md` — Step 4

Replace the current "invoke `/yf:chronicle_capture`" instruction with a two-part approach:

**Step 4a (DETERMINISTIC):** `bash plugins/yf/scripts/plan-chronicle.sh intake "plan:<idx>" "docs/plans/plan-<idx>.md"`
**Step 4b (OPTIONAL):** If significant design rationale exists beyond the plan file, invoke `/yf:chronicle_capture topic:planning` to create a richer chronicle.

The key change: the guaranteed part is a `bash` command (agents reliably execute bash), not a skill invocation (agents skip under load).

### 5. Edit: `plugins/yf/skills/plan_execute/SKILL.md` — Step 4.1

Change from "invoke `/yf:chronicle_capture topic:completion`" to a validate-then-fallback pattern:

```bash
# Verify completion chronicle exists (plan-exec.sh already created one)
bd list -l "ys:chronicle:auto,plan:<idx>" --status=open --json | jq '[.[] | select(.title | contains("complete"))] | length'
```

If count > 0, stub exists — optionally enrich. If 0, invoke `/yf:chronicle_capture` as fallback.

### 6. Edit: `plugins/yf/scripts/plan-exec.sh` — status=completed block (line ~261)

Add `chronicle-validate.sh` call after `close_chronicle_gates`:

```bash
bash "$SCRIPT_DIR/chronicle-validate.sh" "$PLAN_LABEL" 2>/dev/null || true
```

### 7. Edit: `plugins/yf/rules/plan-transition-chronicle.md`

Shift from "create" to "enrich existing stub":

> A plan-save chronicle stub was automatically created by exit-plan-gate.sh. If the planning discussion had significant design rationale beyond what the plan file captures, invoke `/yf:chronicle_capture topic:planning` to create an enriched chronicle.

### 8. Edit: `plugins/yf/rules/auto-chain-plan.md`

Remove the chronicle creation instruction from the auto-chain sequence. The hook (`exit-plan-gate.sh`) now handles it deterministically. Add note that enrichment is optional.

### 9. New: `tests/scenarios/unit-plan-chronicle.yaml`

Test scenarios:
- `plan-chronicle.sh save` creates a bead with correct labels
- Dedup prevents duplicate save chronicles
- `plan-chronicle.sh intake` creates a bead with plan file excerpt
- `chronicle-validate.sh` detects missing boundaries and creates fallbacks
- `chronicle-validate.sh` reports full coverage when all stubs exist

## File Summary

| File | Type | Change |
|------|------|--------|
| `plugins/yf/scripts/plan-chronicle.sh` | New | Deterministic plan boundary chronicle creation |
| `plugins/yf/scripts/chronicle-validate.sh` | New | Post-completion validation and fallback creation |
| `plugins/yf/hooks/exit-plan-gate.sh` | Edit | Add `plan-chronicle.sh save` call |
| `plugins/yf/skills/plan_intake/SKILL.md` | Edit | Step 4 → bash command + optional enrichment |
| `plugins/yf/skills/plan_execute/SKILL.md` | Edit | Step 4.1 → validate + fallback pattern |
| `plugins/yf/scripts/plan-exec.sh` | Edit | Add `chronicle-validate.sh` on completion |
| `plugins/yf/rules/plan-transition-chronicle.md` | Edit | "Create" → "enrich existing stub" |
| `plugins/yf/rules/auto-chain-plan.md` | Edit | Remove chronicle creation, add enrichment note |
| `tests/scenarios/unit-plan-chronicle.yaml` | New | Test deterministic chronicle and validation |

## Implementation Sequence

1. Create `plan-chronicle.sh` (core mechanism, no dependencies)
2. Create `chronicle-validate.sh` (uses bd only)
3. Edit `exit-plan-gate.sh` to call `plan-chronicle.sh save`
4. Edit `plan_intake/SKILL.md` Step 4
5. Edit `plan_execute/SKILL.md` Step 4.1
6. Edit `plan-exec.sh` to call `chronicle-validate.sh`
7. Edit rules (plan-transition-chronicle, auto-chain-plan)
8. Create tests
9. Run `bash tests/run-tests.sh --unit-only`

## Verification

```bash
bash tests/run-tests.sh --unit-only
```

Manual verification:
1. Enter plan mode, exit → verify chronicle bead created automatically
2. Run `/yf:plan_intake` on a pasted plan → verify chronicle stub exists
3. Complete a plan → verify `chronicle-validate.sh` reports full coverage
