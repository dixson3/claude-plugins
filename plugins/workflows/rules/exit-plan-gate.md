# Rule: Save Plan Before Exiting Plan Mode

**Applies:** When in plan mode, before calling ExitPlanMode

Before calling ExitPlanMode, you MUST invoke `/workflows:engage_plan` to:
1. Save the plan to `docs/plans/plan-<idx>.md`
2. Create the `.claude/.plan-gate` marker

This ensures the plan is persisted and the lifecycle gate is active before implementation begins.

## Sequence

1. Design the plan (normal plan mode activity)
2. Invoke `/workflows:engage_plan` — saves plan, creates gate
3. Call ExitPlanMode — user approves
4. Gate blocks Edit/Write until lifecycle completes
5. Run `/workflows:plan_to_beads` to create beads hierarchy
6. Say "execute the plan" to start — removes gate, begins execution loop

## Why

Without the gate, the LLM can skip plan_to_beads and the execution loop, coding directly without tracked progress or dependency enforcement.
