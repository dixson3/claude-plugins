---
name: yf:formula_execute
description: Execute a formula's steps as sequential Task subagent calls respecting dependencies
arguments:
  - name: task_id
    description: "Parent plan task ID"
    required: true
  - name: formula
    description: "Formula name (e.g., feature-build) or path to .formula.json file"
    required: true
  - name: context
    description: "Additional context passed to the formula"
    required: false
  - name: depth
    description: "Nesting depth for reactive bugfix (default: 0, max: 2)"
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

# Formula Execute

Full formula lifecycle: instantiate wisp, dispatch all steps through agents, handle failures with inline reactive bugfix, and squash on completion.

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
bash "$YFT" mol wisp "$FORMULA_PATH" --var feature="<task title from task_id>" --var context="<context>"
```

Capture the molecule ID from the output. Tag the wisp:
```bash
bash "$YFT" update <mol-id> -l ys:formula,parent:<task_id>
```

### Step 3: Dispatch Loop

Repeat until all steps are closed:

#### 3a. Read Molecule State

```bash
bash "$YFT" mol show <mol_id> --json 2>/dev/null
```

Parse all steps with their ID, title, description, status (open/closed), and dependencies (`needs` array).

#### 3b. Identify Ready Steps

A step is ready when:
1. Its status is `open`
2. All steps in its `needs` array are `closed`
3. It has NOT been dispatched:
   ```bash
   bash plugins/yf/scripts/dispatch-state.sh formula is-dispatched <step-id>
   ```

#### 3c. Parse Step Annotations

For each ready step, extract:

**Agent annotation** — `SUBAGENT:<type>` from the description:
```
SUBAGENT:Explore           → subagent_type = "Explore"
SUBAGENT:general-purpose   → subagent_type = "general-purpose"
SUBAGENT:yf:yf_formula_researcher → subagent_type = "yf:yf_formula_researcher"
```
If no `SUBAGENT:` annotation, default to `general-purpose`.

**Compose field** — If a step has a `compose` field, ignore it (treat as a normal step).

#### 3d. Determine Isolation Mode

| Agent Type | Isolation |
|---|---|
| `Explore` | None (read-only) |
| `yf:yf_formula_researcher` | None (read-only) |
| `yf:yf_formula_reviewer` | None (read-only) |
| `yf:yf_code_researcher` | None (read-only) |
| `yf:yf_code_reviewer` | None (read-only) |
| `general-purpose` | `isolation: "worktree"` |
| `yf:yf_code_writer` | `isolation: "worktree"` |
| `yf:yf_formula_tester` | `isolation: "worktree"` |
| `yf:yf_code_tester` | `isolation: "worktree"` |
| (no annotation / default) | `isolation: "worktree"` (safe default) |

#### 3e. Dispatch Ready Steps

For each ready step, launch a Task tool call:

```
Task(
  subagent_type = "<parsed agent type>",
  description = "Formula step: <step title>",
  isolation = "worktree",  // only for write-capable agents per Step 3d
  prompt = "You are working on a formula step.

Molecule: <mol_id>
Step: <step_id> — <step_title>
Parent task: <task_id> (post comments here)

## Instructions
<step description (with SUBAGENT: annotation stripped)>

## Upstream Context
<Read FINDINGS:/CHANGES: comments from parent task for context from prior steps>

## Comment Protocol
When you finish, post your results as a comment on the parent task:
  bash "$YFT" comment <task_id> \"<PROTOCOL_PREFIX>: <your structured output>\"

Protocol prefixes by role:
- Research/analysis steps: FINDINGS:
- Implementation steps: CHANGES:
- Review steps: REVIEW: (with REVIEW:PASS or REVIEW:BLOCK verdict)
- Test steps: TESTS:

## Completion
After posting your comment, close this step:
  bash "$YFT" close <step_task_id>"
)
```

Launch **all ready steps in parallel** (multiple Task calls in one message).

#### 3f. Mark Dispatched

After launching each Task call:
```bash
bash plugins/yf/scripts/dispatch-state.sh formula mark-dispatched <step-id>
```

#### 3g. Process Returns

When Task calls return:
1. Verify the agent posted a comment on the parent task
2. Mark done: `bash plugins/yf/scripts/dispatch-state.sh formula mark-done <step-id>`
3. Check if the step task was closed by the agent; if not, close it

#### 3h. Merge-Back Worktree-Isolated Agents

Process returns **sequentially** (one merge at a time):

1. **If the agent made changes** (Task tool returns worktree path and branch):
   ```bash
   RESULT=$(bash plugins/yf/scripts/formula-worktree.sh merge <worktree-path>)
   STATUS=$(echo "$RESULT" | jq -r '.status')
   ```

   - **`ok`**: Changes merged. Clean up:
     ```bash
     bash plugins/yf/scripts/formula-worktree.sh cleanup <worktree-path>
     ```

   - **`conflict`**: Escalate through resolution levels:

     | Level | Strategy | When |
     |-------|----------|------|
     | 1 | `-X theirs` (already attempted by merge) | First attempt |
     | 2 | Claude-driven resolution | Read conflict markers, resolve with Read+Edit |
     | 3 | Abort + re-dispatch | `git rebase --abort`, mark step for retry |
     | 4 | Human escalation | Leave branch intact, mark step as `conflict` |

   - **`error`**: Log warning, clean up worktree, continue.

2. **If no changes**: Worktree was auto-cleaned — no action needed.

3. Each subsequent merge rebases onto the updated HEAD.

#### 3i. Reactive Bugfix (Inline)

After processing each step's return, check for failure signals:

1. Read the comment on the parent task for this step
2. Check for `REVIEW:BLOCK` or `TESTS:` with `FAIL:` count > 0

If failure detected, evaluate eligibility:
- **Depth check**: `depth >= 2` → skip (at max nesting depth)
- **Dedup check**: `ys:bugfix-attempt` label on parent task → skip
- **Config check**: `reactive_bugfix` in `.yoshiko-flow/config.json` is `false` → skip
- **Design BLOCK**: Content indicates "wrong approach", "needs redesign", "architectural concern" → skip

If eligible:
```bash
bash "$YFT" label add <task_id> ys:bugfix-attempt
```

Invoke bugfix formula:
```
/yf:formula_execute task_id:<task_id> formula:bugfix depth:<depth+1> context:"<failure details>"
```

Create a chronicle task for the reactive bugfix:
```bash
PLAN_LABEL=$(bash "$YFT" label list <task_id> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
LABELS="ys:chronicle,ys:topic:formula,ys:formula,ys:chronicle:auto"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

bash "$YFT" create --type=task \
  --title="Chronicle (Auto): Reactive bugfix — <failure summary>" \
  --description="Reactive bugfix triggered on <task_id>.
Verdict: <verdict>
Failed step: <step_id>
Failure details: <extracted failure context>" \
  -l "$LABELS" \
  --silent
```

After bugfix completes, mark step for retry:
```bash
bash plugins/yf/scripts/dispatch-state.sh formula mark-retrying <step_id>
```

Budget: 1 retry per step (configurable via `max_retries`). If retry fails again, the block stands permanently.

If no failure detected, proceed normally.

#### 3j. Auto-Capture Chronicle (Step 4.5 equivalent — fires automatically, NOT advisory)

After a step completes, check two triggers:

**Trigger 1 — Formula flag**: If the step JSON has `"chronicle": true`, create a chronicle task with labels `ys:chronicle,ys:topic:formula,ys:formula,ys:chronicle:auto` (plus any `plan:*` label) and description containing the step's comment content.

**Trigger 2 — CHRONICLE-SIGNAL**: If the step's comment contains a `CHRONICLE-SIGNAL:` line, extract the signal text and create a chronicle task with the same label pattern.

#### 3k. Archive Findings (Opt-In)

If the step JSON has `"archive_findings": true` and the step's `FINDINGS:` comment contains external sources, create an archive task with labels `ys:archive,ys:archive:research,ys:formula` (plus any `plan:*` label) and the FINDINGS content as description.

#### 3l. Re-dispatch Loop

After processing returns, loop back to Step 3a. New steps may now be ready. Continue until all steps are closed.

### Step 4: Synthesize Results

Collect all comments from the parent task (FINDINGS, CHANGES, REVIEW, TESTS) and create a synthesis:

```
Formula Complete: <formula name>
Feature: <task title>

Step Results:
- research: <summary of FINDINGS>
- implement: <summary of CHANGES>
- review: <REVIEW verdict>

Overall: <PASS/BLOCK based on review verdict>
```

### Step 5: Squash Wisp

```bash
bash "$YFT" mol squash <mol-id> --summary "<synthesized results>"
```

### Step 6: Auto-Chronicle

Create a chronicle task with labels `ys:chronicle,ys:topic:formula,ys:formula,ys:chronicle:auto` (plus any `plan:*` label from parent task). Description includes: formula, feature, step count, retries, BLOCK verdicts, final outcome, per-step results, key findings, and key changes.

### Step 7: Close Parent Task

If the review passed:
```bash
bash "$YFT" close <task_id>
```

If the review blocked, leave the parent task open and report the block.

### Step 8: Clear Dispatch State

For top-level executions (depth 0):
```bash
bash plugins/yf/scripts/dispatch-state.sh formula clear
```

For nested executions (depth > 0), use scoped clear:
```bash
bash plugins/yf/scripts/dispatch-state.sh formula clear --scope <mol-id>
```

### Step 9: Report

Report: formula, feature, wisp ID, steps completed, chronicle task ID, per-step summaries, overall PASS/BLOCK.

## Depth Tracking

Default depth: 0. Max: 2. Each reactive bugfix invocation passes `depth+1`. At depth 2, reactive bugfix is ineligible.

## Error Handling

- Formula/wisp failure: report and exit
- Dispatch failure: report partial results, do NOT squash (preserve state)
- Squash failure: still create chronicle
- Task call failure: report error, mark step as done, continue with other steps
- Agent doesn't post comment: note the gap but continue
- dispatch-state.sh failure: log warning, continue
