---
name: yf:swarm_run
description: Run a full swarm lifecycle — instantiate formula as wisp, dispatch steps, squash on completion
arguments:
  - name: formula
    description: "Formula name (e.g., feature-build) or path to .formula.json file"
    required: true
  - name: feature
    description: "Feature description — passed as the 'feature' variable to the formula"
    required: true
  - name: context
    description: "Additional context passed to the formula"
    required: false
  - name: parent_task
    description: "Parent task ID (if running under a plan task)"
    required: false
  - name: depth
    description: "Nesting depth for composed formulas (default: 0, max: 2)"
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

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

# Swarm Run

Full swarm lifecycle entry point. Instantiates a formula as a wisp, dispatches all steps through agents, and squashes the wisp on completion.

## Behavior

### Step 1: Resolve Formula

If `formula` is a name (no path separator):
```bash
FORMULA_PATH="plugins/yf/formulas/${formula}.formula.json"
```

If `formula` is a path, use it directly.

Verify the formula exists:
```bash
test -f "$FORMULA_PATH" || echo "Formula not found: $FORMULA_PATH"
```

### Step 2: Instantiate as Wisp

```bash
bash "$YFT" mol wisp "$FORMULA_PATH" --var feature="<feature>" --var context="<context>"
```

Capture the molecule ID from the output. If `parent_task` is specified, tag the wisp:
```bash
bash "$YFT" update <mol-id> -l ys:swarm,parent:<parent_task>
```

### Step 3: Dispatch Steps

Invoke `/yf:swarm_dispatch` with the wisp molecule ID and parent task:

```
/yf:swarm_dispatch mol_id:<mol-id> parent_task:<parent_task or mol-id>
```

If no `parent_task` was provided, use the molecule ID itself as the comment target.

This runs the full dispatch loop until all steps are complete.

### Step 4: Completion

After all steps complete:

#### 4a. Synthesize Results

Collect all comments from the parent task (FINDINGS, CHANGES, REVIEW, TESTS) and create a synthesis:

```
Swarm Complete: <formula name>
Feature: <feature>

Step Results:
- research: <summary of FINDINGS>
- implement: <summary of CHANGES>
- review: <REVIEW verdict>

Overall: <PASS/BLOCK based on review verdict>
```

#### 4b. Squash Wisp

```bash
bash "$YFT" mol squash <mol-id> --summary "<synthesized results>"
```

This creates a digest and cleans up ephemeral step tasks.

#### 4c. Auto-Chronicle (E1)

Create a chronicle task with labels `ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto` (plus any `plan:*` label from parent task). Description includes: formula, feature, step count, retries, BLOCK verdicts, final outcome, per-step results, key findings, and key changes.

#### 4d. Close Parent Task (if applicable)

If `parent_task` was provided (running under a plan task) and the review passed:
```bash
bash "$YFT" close <parent_task>
```

If the review blocked, leave the parent task open and report the block.

### Step 5: Clear Dispatch State

For top-level swarms (depth 0):
```bash
bash plugins/yf/scripts/dispatch-state.sh swarm clear
```

For nested swarms (depth > 0), use scoped clear to only remove sub-swarm state:
```bash
bash plugins/yf/scripts/dispatch-state.sh swarm clear --scope <mol-id>
```

### Step 6: Report

Report: formula, feature, wisp ID, steps completed, chronicle task ID, per-step summaries, overall PASS/BLOCK.

## Depth Tracking

Default depth: 0. Max: 2 — at depth 2, `compose` fields are ignored (steps dispatch as bare Tasks). Each nested invocation passes `depth+1`.

## Error Handling

- Formula/wisp failure: report and exit
- Dispatch failure: report partial results, do NOT squash (preserve state)
- Squash failure: still create chronicle
