---
name: yf:swarm_dispatch
description: Core swarm dispatch loop — drives agents through molecule steps respecting dependencies
arguments:
  - name: mol_id
    description: "Molecule (wisp) ID to dispatch steps for"
    required: true
  - name: parent_bead
    description: "Parent bead ID for comment protocol"
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


# Swarm Dispatch

The core dispatch loop that drives agents through molecule steps. Reads the molecule state, identifies ready steps, parses agent annotations, and dispatches parallel Task tool calls.

## When to Invoke

- Called by `/yf:swarm_run` after wisp instantiation
- Can be invoked directly for manual dispatch control

## Behavior

### Step 1: Read Molecule State

```bash
bd mol show <mol_id> --json 2>/dev/null
```

Parse the molecule to get all steps with their:
- ID
- Title
- Description
- Status (open/closed)
- Dependencies (`needs` array)

### Step 2: Identify Ready Steps

A step is ready when:
1. Its status is `open`
2. All steps in its `needs` array are `closed`
3. It has NOT been dispatched (check dispatch-state.sh)

```bash
bash plugins/yf/scripts/dispatch-state.sh swarm is-dispatched <step-id>
```

### Step 3: Parse Step Annotations

For each ready step, extract annotations:

**Agent annotation** — `SUBAGENT:<type>` from the description:
```
SUBAGENT:Explore      → subagent_type = "Explore"
SUBAGENT:general-purpose → subagent_type = "general-purpose"
```
If no `SUBAGENT:` annotation, default to `general-purpose`.

**Compose annotation** — Check the step's JSON for a `compose` field:
```json
{ "id": "implement", "compose": "build-test", ... }
```
If `compose` is present and the current swarm `depth < 2`, this step will be dispatched as a nested swarm instead of a bare Task call.

### Step 4: Dispatch Ready Steps

For each ready step, launch a Task tool call:

```
Task(
  subagent_type = "<parsed agent type>",
  description = "Swarm step: <step title>",
  prompt = "You are working on a swarm step.

Molecule: <mol_id>
Step: <step_id> — <step_title>
Parent bead: <parent_bead> (post comments here)

## Instructions
<step description (with SUBAGENT: annotation stripped)>

## Upstream Context
<Read FINDINGS:/CHANGES: comments from parent bead for context from prior steps>

## Comment Protocol
When you finish, post your results as a comment on the parent bead:
  bd comment <parent_bead> \"<PROTOCOL_PREFIX>: <your structured output>\"

Protocol prefixes by role:
- Research/analysis steps: FINDINGS:
- Implementation steps: CHANGES:
- Review steps: REVIEW: (with REVIEW:PASS or REVIEW:BLOCK verdict)
- Test steps: TESTS:

## Completion
After posting your comment, close this step:
  bd close <step_bead_id>"
)
```

Launch **all ready steps in parallel** (multiple Task calls in one message).

**Compose dispatch** — If a step has a `compose` field and `depth < 2`:

Instead of a bare Task call, invoke the nested formula:
```
/yf:swarm_run formula:<compose-value> feature:"<step title>" parent_bead:<parent_bead> depth:<current_depth+1> context:"<upstream FINDINGS from parent formula>"
```

The nested swarm:
- Receives upstream FINDINGS from the parent formula's earlier steps as context
- Posts CHANGES/TESTS/REVIEW comments on the **outermost** parent bead (single audit trail)
- Uses scoped state tracking: `<parent-mol-id>/<step-id>` prefix in dispatch-state.sh

If `depth >= 2`, ignore the `compose` field and dispatch as a normal bare Task call.

### Step 5: Mark Dispatched

After launching each Task call:
```bash
bash plugins/yf/scripts/dispatch-state.sh swarm mark-dispatched <step-id>
```

### Step 6: Wait and Process Returns

When Task calls return:
1. Verify the agent posted a comment on the parent bead
2. Mark done in swarm state: `bash plugins/yf/scripts/dispatch-state.sh swarm mark-done <step-id>`
3. Check if the step bead was closed by the agent; if not, close it

### Step 6b: Reactive Failure Check

After processing each step's return, check for failure signals in the posted comment:

1. **Read the comment** on the parent bead for this step
2. **Check for REVIEW:BLOCK**: If the step posted a `REVIEW:BLOCK` comment, this is a failure
3. **Check for TESTS with failures**: If the step posted a `TESTS:` comment containing `FAIL:` with a count > 0, this is a failure

If a failure is detected, invoke `/yf:swarm_react`:
```
/yf:swarm_react parent_bead:<parent_bead> verdict:<BLOCK|FAIL> step_id:<step-id> depth:<current_depth>
```

The reactive skill handles eligibility checks (depth, dedup, config), spawns a bugfix formula if appropriate, and marks the step for retry. The dispatch loop will pick up the retried step on its next iteration (Step 7).

If no failure is detected, proceed normally.

### Step 6c: Progressive Chronicle (Opt-In + Signal)

After a step completes, check two chronicle triggers:

**Trigger 1 — Formula flag**: If the step JSON has `"chronicle": true`:

```bash
# Check step definition for chronicle flag
CHRONICLE=$(jq -r '.chronicle // false' <<< "$STEP_JSON")
if [ "$CHRONICLE" = "true" ]; then
  PLAN_LABEL=$(bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
  LABELS="ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto"
  [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

  bd create --title "Chronicle (Auto): Swarm step <step-id> — <step title>" \
    -l "$LABELS" \
    --description "<step comment content (FINDINGS/CHANGES/REVIEW/TESTS)>" \
    --silent
fi
```

**Trigger 2 — CHRONICLE-SIGNAL**: If the step's comment on the parent bead contains a `CHRONICLE-SIGNAL:` line (used by read-only agents that cannot create beads directly):

```bash
COMMENT=$(bd show <parent_bead> --comments | grep -A 1 "CHRONICLE-SIGNAL:")
if [ -n "$COMMENT" ]; then
  SIGNAL_TEXT=$(echo "$COMMENT" | grep "CHRONICLE-SIGNAL:" | sed 's/CHRONICLE-SIGNAL: *//')
  PLAN_LABEL=$(bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
  LABELS="ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto"
  [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

  bd create --title "Chronicle (Signal): $SIGNAL_TEXT" \
    -l "$LABELS" \
    --description "Signaled by step <step-id> (<step title>)
Agent type: <read-only>
Signal: $SIGNAL_TEXT
Full comment: <step comment content>" \
    --silent
fi
```

This is **opt-in per step** (formula flag) or **opt-in per agent** (CHRONICLE-SIGNAL). Both give agents a path to trigger chronicles — write-capable agents can also create beads directly via their Chronicle Protocol.

### Step 6d: Archive Findings (Opt-In)

After a step completes, if the step JSON has `"archive_findings": true` and the step posted a `FINDINGS:` comment containing external sources (URLs, doc references):

```bash
ARCHIVE=$(jq -r '.archive_findings // false' <<< "$STEP_JSON")
if [ "$ARCHIVE" = "true" ]; then
  # Check if FINDINGS contains external sources
  COMMENT=$(bd show <parent_bead> --comments | grep -A 50 "FINDINGS:" | head -50)
  if echo "$COMMENT" | grep -qiE 'http|docs/|external|reference|api|library'; then
    PLAN_LABEL=$(bd label list <parent_bead> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
    LABELS="ys:archive,ys:archive:research,ys:swarm"
    [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

    bd create --title "Archive: Research from swarm step <step-id>" \
      -l "$LABELS" \
      --description "<FINDINGS content with external sources>" \
      --silent
  fi
fi
```

This is **opt-in per step** — extends archival beyond research-spike to any formula step that produces findings with external sources.

### Step 7: Re-dispatch Loop

After processing returns, loop back to Step 1:
- New steps may now be ready (their dependencies just closed)
- Continue until all steps are closed

### Step 8: Return Summary

When all steps are closed, collect all comments from the parent bead and return a summary:

```
Swarm Dispatch Complete
=======================
Molecule: <mol_id>
Steps completed: <count>/<total>

Results:
  research: FINDINGS posted
  implement: CHANGES posted
  review: REVIEW:PASS

All steps closed.
```

## Error Handling

- If a Task call fails: report error, mark step as done (not re-dispatched), continue with other steps
- If an agent doesn't post a comment: note the gap but continue
- If dispatch-state.sh fails: log warning, continue (risk double-dispatch vs missing dispatch)
- If molecule not found: report error and exit

## Important

- Parse `SUBAGENT:` from step descriptions — this determines which agent type handles each step
- Strip `SUBAGENT:` annotations from the prompt sent to agents (they don't need to see routing metadata)
- Read upstream comments from the parent bead to provide context to downstream steps
- The dispatch loop is synchronous within each wave but parallel within a wave (steps with satisfied deps run concurrently)
