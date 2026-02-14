# Rule: Plan Lifecycle Triggers

**Applies:** Always (different triggers for different states)

When the user says plan lifecycle phrases, invoke the appropriate action via `/yf:plan_engage`.

## Note

The Draft transition is now handled automatically by ExitPlanMode. When the user exits plan mode, the `exit-plan-gate.sh` hook saves the plan and the `auto-chain-plan.md` rule drives the full lifecycle (plan_to_beads → execute). The phrases below are for manual overrides and non-Draft transitions.

## Trigger Phrases

### Ready (Manual Override)
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

Invoke: `/yf:plan_engage` with the detected action context.
