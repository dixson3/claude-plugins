---
name: yf:swarm_status
description: Show active swarm state including wisp status, step progress, and dispatch state
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


# Swarm Status

Shows the current state of active swarm executions.

## Behavior

### Step 1: Check Dispatch State

```bash
bash plugins/yf/scripts/dispatch-state.sh swarm pending
```

If no pending dispatches, report "No active swarm dispatches."

### Step 2: List Active Wisps

```bash
bd mol wisp list 2>/dev/null
```

If no active wisps, report "No active wisps."

### Step 3: For Each Active Wisp

Show molecule details:
```bash
bd mol show <mol-id> --json 2>/dev/null
```

Extract:
- Molecule ID
- Formula name (from title or labels)
- Step status (open/closed for each step)
- Dependencies between steps

### Step 4: Show Dispatch State

Cross-reference wisp steps with dispatch state:
- Which steps are dispatched (in-flight to agents)
- Which steps are done
- Which steps are pending (deps not satisfied)

### Step 5: Format Output

Report includes: active wisp count, per-wisp details (mol-id, formula, step status with closed/dispatched/pending), and dispatch state (pending count with timestamps). If no activity, reports "No active swarms."
