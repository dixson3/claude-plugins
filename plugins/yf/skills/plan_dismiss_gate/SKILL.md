---
name: yf:plan_dismiss_gate
description: Remove the plan gate to allow free editing (abandons the plan lifecycle for this plan)
arguments: []
---

## Activation Guard

Before proceeding, check that yf is active:

```bash
ACTIVATION=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-activation-check.sh")
IS_ACTIVE=$(echo "$ACTIVATION" | jq -r '.active')
```

If `IS_ACTIVE` is not `true`, read the `reason` and `action` fields from `$ACTIVATION` and tell the user:

> Yoshiko Flow is not active: {reason}. {action}

Then stop. Do not execute the remaining steps.


# Dismiss Gate Skill

Escape hatch for abandoning a plan without implementing it. Removes the plan gate so edits are unblocked, and marks the associated plan as Abandoned.

## Workflow

> **Guard:** Do NOT use this skill to work around a code-gate block during auto-chain. If auto-chain is in progress, wait for it to complete or diagnose the failure. This skill is for deliberately abandoning a plan you do not intend to implement.

1. **Check for active gate**: Look for `.yoshiko-flow/plan-gate`
   - If the file does not exist, report "No plan gate is active" and stop

2. **Read gate metadata**: Parse the `.yoshiko-flow/plan-gate` JSON to extract `plan_idx` and `plan_file`

3. **Remove the gate file**: Delete `.yoshiko-flow/plan-gate`

3.5. **Create skip marker**: Create `.yoshiko-flow/plan-intake-skip` so the code-gate does not re-block:
   ```bash
   touch "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-intake-skip"
   ```

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
