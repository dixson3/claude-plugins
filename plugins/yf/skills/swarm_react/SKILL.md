---
name: yf:swarm_react
description: Reactive bugfix from BLOCK/FAIL verdicts — spawns bugfix formula and retries failed step
arguments:
  - name: parent_bead
    description: "Parent bead ID where the failure comment was posted"
    required: true
  - name: verdict
    description: "Verdict type: BLOCK (from REVIEW:BLOCK) or FAIL (from TESTS with failures)"
    required: true
  - name: step_id
    description: "ID of the failed step to retry after bugfix"
    required: true
  - name: depth
    description: "Current swarm nesting depth (reactive bugfix adds +1)"
    required: false
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


# Swarm React

Spawns a reactive bugfix formula when a swarm step reports a failure (REVIEW:BLOCK or TESTS with failures). After the bugfix completes, the failed step is retried.

## When to Invoke

- Called by `/yf:swarm_dispatch` Step 6b when processing a step return with a failure verdict
- Should NOT be invoked manually (use `/yf:swarm_run formula:bugfix` for manual bugfix runs)

## Behavior

### Step 1: Validate Eligibility

Check guard conditions:

1. **Depth check**: If current `depth >= 2`, skip reactive bugfix (at max nesting depth)
2. **Dedup check**: Check for `ys:bugfix-attempt` label on the parent bead:
   ```bash
   bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(. == "ys:bugfix-attempt")'
   ```
   If label exists, skip — only one reactive bugfix per step execution
3. **Config check**: Read `reactive_bugfix` from `.yoshiko-flow/config.json` (default: `true`). If `false`, skip.

### Step 2: Classify Failure

Read the failure comment from the parent bead:
```bash
bd show <parent_bead> --comments
```

**Bug BLOCKs** (eligible for reactive bugfix):
- Specific test failures
- Runtime errors
- Missing implementation
- Incorrect behavior

**Design BLOCKs** (NOT eligible — skip):
- "wrong approach", "needs redesign", "architectural concern"
- "should use X instead of Y"
- "scope too large", "needs to be split"

If the REVIEW:BLOCK content indicates a design-level concern rather than a bug, report:
```
Reactive bugfix skipped: design-level BLOCK detected.
Manual intervention needed — review the REVIEW:BLOCK comment for guidance.
```

### Step 3: Extract Failure Context

From the comment, extract:
- What failed (test names, error messages, incorrect behavior)
- What files are involved
- What the expected behavior should be

### Step 4: Spawn Bugfix Formula

```bash
bd label add <parent_bead> ys:bugfix-attempt
```

Invoke the bugfix formula:
```
/yf:swarm_run formula:bugfix feature:"Fix: <failure summary>" parent_bead:<parent_bead> depth:<current_depth+1> context:"<failure details from comment>"
```

### Step 4.5: Auto-Capture Chronicle

Create a chronicle bead to preserve the reactive bugfix context (per `swarm-chronicle-bridge` rule):

```bash
PLAN_LABEL=$(bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
LABELS="ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

bd create --type=task \
  --title="Chronicle (Auto): Reactive bugfix — <failure summary>" \
  --description="Reactive bugfix triggered on <parent_bead>.
Verdict: <verdict>
Failed step: <step_id>
Bugfix formula: <bugfix mol-id>
Failure details: <extracted failure context from Step 3>" \
  -l "$LABELS" \
  --silent
```

This fires automatically (not advisory) because mid-swarm context is lost after wisp squashing.

### Step 5: Retry Failed Step

After bugfix completes, mark the original failed step for retry:
```bash
bash plugins/yf/scripts/dispatch-state.sh swarm mark-retrying <step_id>
```

The dispatch loop will re-dispatch this step on its next iteration.

### Step 6: Retry Budget

Each step has a `max_retries` budget (default: 1, configurable per step in formula JSON).

If the retry fails again:
- The block stands
- The parent bead stays open for manual intervention
- Report: "Retry failed. Manual intervention required."

## Output

```
Reactive Bugfix: <parent_bead>
  Verdict: <BLOCK|FAIL>
  Failure: <summary>
  Bugfix swarm: <mol-id>
  Bugfix result: <PASS|BLOCK>
  Retry: <step_id> marked for retry
```

## Important

- Reactive bugfixes run at `depth+1` — they cannot themselves trigger further reactive bugfixes (depth limit prevents recursion)
- Only one reactive bugfix attempt per step per execution (`ys:bugfix-attempt` dedup label)
- Design-level BLOCKs are excluded — they require human judgment, not automated fixing
- Config escape hatch: set `reactive_bugfix: false` in `.yoshiko-flow/config.json` to disable
