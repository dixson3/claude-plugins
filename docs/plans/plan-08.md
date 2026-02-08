# Plan 08: Simplify Exit-Plan-Mode with Auto-Chain Lifecycle

**Status:** Completed
**Date:** 2026-02-08

## Overview

The current plan lifecycle requires 4 manual steps after designing a plan. We collapse this so the user just exits plan mode and the system auto-chains the full lifecycle (save -> beads -> execute). Planning context is captured as chronicle beads via a composable chronicler rule (workflows does NOT depend on chronicler).

## Implementation Sequence

1. Update `exit-plan-gate.sh` hook output to signal auto-chain
2. Replace `exit-plan-gate.md` rule with `auto-chain-plan.md` (auto-chain sequence)
3. Update `engage-the-plan.md` rule (remove Draft triggers, keep Pause/Resume/Complete)
4. Annotate `engage_plan` skill Draft section as legacy fallback
5. Update `workflows:init` skill (add auto-chain rule install)
6. Create `plugins/chronicler/rules/plan-transition-chronicle.md` (chronicle capture during transitions)
7. Update `chronicler:init` skill (add rule install step)
8. Update unit tests for new hook output format

## Changes Detail

### 1. Hook output — `plugins/workflows/hooks/exit-plan-gate.sh`
Replace manual-step guidance (lines 85-91) with auto-chain signal including parseable `PLAN_IDX` and `PLAN_FILE` lines.

### 2. Rule replacement — `exit-plan-gate.md` -> `auto-chain-plan.md`
Delete old rule. New rule auto-chains after ExitPlanMode: format plan -> update MEMORY -> plan_to_beads -> plan-exec.sh start -> execute_plan. No user input between steps. Gate does not interfere (all ops use Bash or exempt paths).

### 3. Rule update — `engage-the-plan.md`
Remove Draft trigger phrases. Keep Ready (manual override), Executing, Paused, Resume, Complete triggers. Note that Draft is handled by ExitPlanMode auto-chain.

### 4. Skill annotation — `engage_plan/SKILL.md`
Mark Draft transition as legacy/fallback. Do not remove — still works if user explicitly says "engage the plan".

### 5. Init update — `workflows:init`
Add `auto-chain-plan.md` to rule install list.

### 6. Chronicler rule — `plan-transition-chronicle.md`
Fires when "Plan saved to docs/plans/" appears. Invokes `/chronicler:capture topic:planning` to capture design rationale before beads creation. Composable: if chronicler not installed, rule doesn't exist, auto-chain runs without it.

### 7. Chronicler init update
Add rule install step for `plan-transition-chronicle.md`.

### 8. Test updates — `unit-exit-plan-gate.yaml`
Verify new output format (Auto-chaining, PLAN_IDX=, PLAN_FILE=). Existing core tests unchanged.

## Files Modified

| File | Action |
|------|--------|
| `plugins/workflows/hooks/exit-plan-gate.sh` | Modify output |
| `plugins/workflows/rules/exit-plan-gate.md` | Delete |
| `plugins/workflows/rules/auto-chain-plan.md` | Create |
| `plugins/workflows/rules/engage-the-plan.md` | Modify |
| `.claude/rules/engage-the-plan.md` | Modify (installed copy) |
| `.claude/rules/auto-chain-plan.md` | Create (installed copy) |
| `plugins/workflows/skills/engage_plan/SKILL.md` | Modify |
| `plugins/workflows/skills/init/SKILL.md` | Modify |
| `plugins/chronicler/rules/plan-transition-chronicle.md` | Create |
| `plugins/chronicler/skills/init/SKILL.md` | Modify |
| `tests/scenarios/unit-exit-plan-gate.yaml` | Modify |

## Completion Criteria

- [ ] ExitPlanMode triggers auto-chain (save -> beads -> execute) with no manual steps
- [ ] "engage the plan" still works as legacy fallback without double-firing
- [ ] Pause/Resume/Complete lifecycle transitions unchanged
- [ ] dismiss_gate escape hatch unchanged
- [ ] Chronicle capture fires between plan save and beads creation (when chronicler installed)
- [ ] All unit tests pass
