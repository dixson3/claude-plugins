# Rule: Plan Lifecycle Triggers

**Applies:** Always (different triggers for different states)

When the user says plan lifecycle phrases, invoke the appropriate action via `/workflows:engage_plan`.

## Trigger Phrases

### Draft (Plan Mode Only)
- "engage the plan" → Save plan to `docs/plans/`, transition to Draft
- "engage plan"
- "finalize the plan"
- "lock in the plan"

### Ready
- "the plan is ready" → Create beads hierarchy, transition to Ready
- "activate the plan"

### Executing
- "execute the plan" → Resolve gate, undefer tasks, begin dispatch
- "start the plan"
- "run the plan"

### Paused
- "pause the plan" → Create gate, defer pending tasks
- "stop the plan"

### Resume
- "resume the plan" → Same as Executing (from Paused state)

### Complete (Manual Override)
- "mark plan complete" → Force completion

## Action

Invoke: `/workflows:engage_plan` with the detected action context.

**Important:** `/workflows:engage_plan` does NOT imply `ExitPlanMode`. They are independent.
