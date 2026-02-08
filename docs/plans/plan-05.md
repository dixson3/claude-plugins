# Plan 05: Plan Lifecycle Enforcement via Gates

**Status:** Ready
**Date:** 2026-02-07

## Context

When the LLM exits plan mode (ExitPlanMode), nothing mechanical prevents it from skipping the plan lifecycle and coding directly. The existing system has advisory rules that tell the LLM what to do (engage-the-plan, plan-to-beads, breakdown-the-work) and mechanical enforcement only at the task level (plan-exec-guard.sh blocks `bd update`/`bd close` when plan isn't Executing). The gap: between plan approval and task-level work, the LLM can bypass the entire lifecycle — skipping plan save, beads creation, and the execution loop.

## Design: Two-Layer Gate System

### Layer 1: Gate Creation (hybrid trigger)

The `.claude/.plan-gate` file is a marker that blocks code edits. It gets created by two complementary mechanisms:

**Primary: ExitPlanMode hook** — A PreToolUse hook on `ExitPlanMode` that saves the plan to `docs/plans/` and creates the gate. If `ExitPlanMode` isn't a valid matcher, this hook silently doesn't fire.

**Backup: engage_plan skill** — The existing `/workflows:engage_plan` Draft transition also creates the gate after saving the plan. A new rule enforces calling engage_plan before ExitPlanMode.

Either path creates the gate. Both paths are idempotent — if the gate already exists, skip creation.

### Layer 2: Gate Enforcement (code-gate.sh)

A PreToolUse hook on `Edit` and `Write` that:
1. Fast-path: if no `.plan-gate` file, exit 0 (zero overhead when no plan active)
2. Check target file path — exempt lifecycle files (docs/plans/, .claude/, etc.)
3. Block non-exempt files with instructions to complete the lifecycle

### Gate Removal

The gate is removed by `plan-exec.sh start` (Ready/Paused → Executing transition). This ensures the **full lifecycle** is followed before any code edits:

```
ExitPlanMode ──hook──► plan saved + .plan-gate created
                       │
Edit/Write ───────────► BLOCKED by code-gate.sh
                       │
plan_to_beads ────────► beads + exec gate created (bd commands not blocked)
                       │
"execute the plan" ───► plan-exec.sh start → .plan-gate removed + exec gate resolved
                       │
Edit/Write ───────────► ALLOWED (gate cleared)
bd update/close ──────► ALLOWED by plan-exec-guard.sh (plan is Executing)
                       │
execute_plan loop ────► dispatches tasks with dependency ordering
```

## Implementation Sequence

### Phase 1: New hooks (independent, parallelizable)
1. Create `plugins/workflows/hooks/code-gate.sh` — Edit/Write gate enforcement
2. Create `plugins/workflows/hooks/exit-plan-gate.sh` — ExitPlanMode plan save + gate creation

### Phase 2: New skill + rule (independent, parallelizable)
3. Create `plugins/workflows/skills/dismiss_gate/SKILL.md` — escape hatch
4. Create `plugins/workflows/rules/exit-plan-gate.md` — advisory backup rule

### Phase 3: Modify existing (sequential dependencies)
5. Modify `plugins/workflows/skills/engage_plan/SKILL.md` — add gate creation to Draft transition
6. Modify `plugins/workflows/scripts/plan-exec.sh` — add gate removal to `start` command
7. Modify `plugins/workflows/.claude-plugin/plugin.json` — register hooks + version bump
8. Modify `plugins/workflows/skills/init/SKILL.md` — add new hooks to install steps

### Phase 4: Metadata + docs (parallelizable)
9. Modify `.claude-plugin/marketplace.json` — version bumps
10. Modify `CLAUDE.md` — update workflows version
11. Modify `CHANGELOG.md` — add [1.4.0] entry

## Completion Criteria

- [ ] code-gate.sh blocks Edit/Write when .plan-gate exists (non-exempt files)
- [ ] code-gate.sh allows exempt files (docs/plans/, .claude/, README.md, etc.)
- [ ] exit-plan-gate.sh saves plan and creates gate on ExitPlanMode
- [ ] engage_plan skill creates gate on Draft transition
- [ ] plan-exec.sh start removes .plan-gate
- [ ] dismiss_gate skill removes gate manually
- [ ] All shell scripts pass syntax check
- [ ] All JSON manifests validate
- [ ] Plugin loads without error

## Exempt Files (code-gate.sh allows these even with active gate)

| Pattern | Rationale |
|---------|-----------|
| `*/docs/plans/*` | Plan files are lifecycle artifacts |
| `*/.claude/*` | Config, rules, settings, plans |
| `*/CHANGELOG.md` | Documentation during transitions |
| `*/MEMORY.md` | Session context always editable |
| `*/.claude-plugin/*.json` | Plugin manifest updates |
| `*/README.md` | Documentation, not implementation |
| `*/.beads/*` | Beads internal state |
