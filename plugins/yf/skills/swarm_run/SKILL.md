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
  - name: parent_bead
    description: "Parent bead ID (if running under a plan task)"
    required: false
  - name: depth
    description: "Nesting depth for composed formulas (default: 0, max: 2)"
    required: false
---

# Swarm Run

Full swarm lifecycle entry point. Instantiates a formula as a wisp, dispatches all steps through agents, and squashes the wisp on completion.

## When to Invoke

- Directly by the user: `/yf:swarm_run formula:feature-build feature:"add dark mode"`
- By the plan pump when a task has a `formula:<name>` label
- By `/yf:swarm_dispatch` when a step has a `compose` field (nested invocation)
- Programmatically from other skills

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
bd mol wisp "$FORMULA_PATH" --var feature="<feature>" --var context="<context>"
```

Capture the molecule ID from the output. If `parent_bead` is specified, tag the wisp:
```bash
bd update <mol-id> -l ys:swarm,parent:<parent_bead>
```

### Step 3: Dispatch Steps

Invoke `/yf:swarm_dispatch` with the wisp molecule ID and parent bead:

```
/yf:swarm_dispatch mol_id:<mol-id> parent_bead:<parent_bead or mol-id>
```

If no `parent_bead` was provided, use the molecule ID itself as the comment target.

This runs the full dispatch loop until all steps are complete.

### Step 4: Completion

After all steps complete:

#### 4a. Synthesize Results

Collect all comments from the parent bead (FINDINGS, CHANGES, REVIEW, TESTS) and create a synthesis:

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
bd mol squash <mol-id> --summary "<synthesized results>"
```

This creates a digest and cleans up ephemeral step beads.

#### 4c. Auto-Chronicle (E1)

Capture a structured execution narrative as a chronicle bead:

```bash
PLAN_LABEL=$(bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
LABELS="ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

bd create --title "Chronicle: Swarm <formula> — <feature>" \
  -l "$LABELS" \
  --description "Swarm Execution: <formula>
Feature: <feature>
Steps: <completed>/<total>
Retries: <retry count or 0>
BLOCK verdicts: <list of steps that BLOCKed, or none>
Final outcome: <PASS or BLOCK>

Step Results:
- <step-id>: <verdict/summary> (<agent type>)
- <step-id>: <verdict/summary> (<agent type>)

Key Findings: <condensed FINDINGS from research steps>
Key Changes: <condensed CHANGES from implementation steps>"
```

This structured narrative replaces the bare squash summary to give the diary agent richer context for generating diary entries.

#### 4d. Close Parent Bead (if applicable)

If `parent_bead` was provided (running under a plan task) and the review passed:
```bash
bd close <parent_bead>
```

If the review blocked, leave the parent bead open and report the block.

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

```
Swarm Execution Complete
========================
Formula: <name>
Feature: <feature>
Wisp: <mol-id> (squashed)

Steps: <completed>/<total>
Chronicle: <chronicle-bead-id>

Results:
  <step summaries>

Overall: PASS/BLOCK
```

## Usage Examples

```bash
# Run a feature build swarm
/yf:swarm_run formula:feature-build feature:"add user authentication"

# Run a research spike
/yf:swarm_run formula:research-spike feature:"evaluate GraphQL libraries"

# Run under a plan task (auto-closes parent on success)
/yf:swarm_run formula:feature-build feature:"implement dark mode" parent_bead:marketplace-abc
```

## Depth Tracking (Nesting)

The `depth` parameter tracks nesting level for composed formulas:

- **Default**: 0 (top-level invocation)
- **Max**: 2. If depth >= 2, the swarm runs but `compose` fields in steps are ignored (steps dispatch as bare Tasks instead)
- Each nested invocation passes `depth+1` to the child swarm

This prevents infinite recursion when formulas compose other formulas. See the `swarm-nesting` rule for details.

## Error Handling

- If formula not found: report error and exit
- If wisp instantiation fails: report error and exit
- If dispatch fails mid-way: report partial results, do NOT squash (preserve state for debugging)
- If squash fails: report error but still create chronicle
- If parent_bead close fails: report warning (bead may already be closed)
