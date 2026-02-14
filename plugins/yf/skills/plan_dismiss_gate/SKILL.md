---
name: yf:plan_dismiss_gate
description: Remove the plan gate to allow free editing (abandons the plan lifecycle for this plan)
arguments: []
---

# Dismiss Gate Skill

Escape hatch for abandoning a plan without implementing it. Removes the plan gate so edits are unblocked, and marks the associated plan as Abandoned.

## Workflow

1. **Check for active gate**: Look for `.yoshiko-flow/plan-gate`
   - If the file does not exist, report "No plan gate is active" and stop

2. **Read gate metadata**: Parse the `.yoshiko-flow/plan-gate` JSON to extract `plan_idx` and `plan_file`

3. **Remove the gate file**: Delete `.yoshiko-flow/plan-gate`

4. **Update plan status**: If `plan_file` exists in `docs/plans/`:
   - Change the `**Status:**` line from "Ready" or "Draft" to "Abandoned"

5. **Report result**:

```
Plan gate dismissed.
Plan <idx> (<plan_file>) status -> Abandoned
Code edits are now unblocked.
```

## Guidelines

- This is a destructive action relative to the plan lifecycle -- the plan will not be executed
- If the user wants to resume the plan later, they should create a new plan rather than un-abandon
- Do NOT delete any beads that may have been created; they serve as historical record
- Do NOT delete the plan file itself; only update its status
