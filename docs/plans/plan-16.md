# Plan 16: Enforce Plan Intake — Skill + Hook Safety Net

**Status:** Completed
**Date:** 2026-02-08

## Overview

Made the plan intake lifecycle easy (skill) and the wrong path hard (hook warning). Same pattern as the plan gate: skill for the happy path, code-gate.sh for enforcement.

## Implementation

### Part A: `yf:plan_intake` Skill
New skill at `plugins/yf/skills/plan_intake/SKILL.md` encapsulating the 5-step intake checklist (save plan, create beads, start execution, capture context, dispatch).

### Part B: Hook Safety Net
Extended `code-gate.sh` with a beads-check in the no-gate path. On first non-exempt Edit/Write, warns (not blocks) if an active plan has no beads. Uses `.claude/.plan-intake-ok` marker to prevent repeat warnings. Runs in a subshell with `set +e` for fail-open safety.

### Part C: Rule Simplification
Updated `yf-plan-intake.md` to reference `/yf:plan_intake` skill instead of listing 5 manual steps.

## Files Changed

| File | Action |
|------|--------|
| `plugins/yf/skills/plan_intake/SKILL.md` | NEW |
| `plugins/yf/hooks/code-gate.sh` | MODIFIED |
| `plugins/yf/rules/yf-plan-intake.md` | MODIFIED |
| `.gitignore` | MODIFIED |
| `plugins/yf/.claude-plugin/plugin.json` | MODIFIED (2.2.0 → 2.3.0) |
| `tests/scenarios/unit-code-gate-intake.yaml` | NEW (6 cases) |
| `tests/scenarios/unit-plan-intake.yaml` | MODIFIED (+3 cases) |
| `CHANGELOG.md` | MODIFIED |
| `docs/plans/plan-16.md` | NEW |

## Completion Criteria

- [x] `yf:plan_intake` skill exists and is user-invocable
- [x] `code-gate.sh` warns when plan exists without beads
- [x] Warning is one-shot (marker suppresses repeat)
- [x] Gate check still takes priority over intake check
- [x] Completed plans don't trigger warning
- [x] All 239 unit tests pass
