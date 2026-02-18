---
name: yf:swarm_qualify
description: Run code-review qualification gate before plan completion
arguments:
  - name: plan_idx
    description: "Plan index (e.g., 29)"
    required: false
  - name: root_epic
    description: "Root epic ID (alternative to plan_idx)"
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


# Swarm Qualification Gate

Runs a `code-review` formula as a mandatory qualification step before a plan is marked complete. Blocks completion on REVIEW:BLOCK.

## When to Invoke

- Called by `/yf:plan_execute` before Step 4 completion sequence
- Can be invoked directly: `/yf:swarm_qualify plan_idx:29`

## Behavior

### Step 1: Resolve Plan

If `root_epic` provided, use it directly. Otherwise, find the root epic from `plan_idx`:
```bash
ROOT_EPIC=$(bd list -l plan:<idx> --type=epic --status=open --limit=1 --json 2>/dev/null | jq -r '.[0].id // empty')
```

Also determine `plan_idx` from the root epic's labels if not provided.

### Step 2: Check Config

Read `qualification_gate` from `.yoshiko-flow/config.json` (default: `"blocking"`):

| Value | Behavior |
|-------|----------|
| `blocking` | REVIEW:BLOCK prevents plan completion |
| `advisory` | REVIEW:BLOCK is noted in report but doesn't prevent completion |
| `disabled` | Skip qualification entirely |

If `disabled`, report "Qualification gate disabled" and return success.

### Step 3: Find Qualification Gate Bead

```bash
GATE_ID=$(bd list -l ys:qualification-gate,plan:<idx> --status=open --limit=1 --json 2>/dev/null | jq -r '.[0].id // empty')
```

If no gate bead exists, create one:
```bash
GATE_ID=$(bd create --type=task \
  --title="Qualification review for plan-<idx>" \
  --parent=<root-epic-id> \
  --description="Code review qualification gate. Must pass before plan completion." \
  -l ys:qualification-gate,plan:<idx> \
  --silent)
```

### Step 4: Determine Review Scope

Get the starting commit SHA from the root epic:
```bash
START_SHA=$(bd label list <root-epic-id> --json 2>/dev/null | jq -r '.[] | select(startswith("start-sha:")) | sub("start-sha:";"")' )
```

If no start SHA is recorded, use the diff against the base branch:
```bash
START_SHA=$(git merge-base HEAD main 2>/dev/null || echo "HEAD~20")
```

The review scope is `git diff $START_SHA..HEAD`.

### Step 5: Run Code Review Formula

```bash
/yf:swarm_run formula:code-review feature:"Plan <idx> qualification review" parent_bead:<gate-id> context:"Review scope: git diff $START_SHA..HEAD. Focus on correctness, style, and edge cases across all plan changes."
```

### Step 6: Process Verdict

Read the REVIEW comment from the gate bead:
```bash
bd show <gate-id> --comments
```

**REVIEW:PASS**:
- Close the qualification gate bead
- Return success — plan completion proceeds

**REVIEW:BLOCK** (blocking mode):
- Leave gate bead open
- Report the block with details
- Return failure — plan completion is halted

**REVIEW:BLOCK** (advisory mode):
- Close the qualification gate bead with a note
- Report the advisory block in the completion report
- Return success — plan completion proceeds with warning

### Step 6.5: Chronicle Qualification Verdict

After processing the verdict (PASS or BLOCK), create a chronicle bead. Both verdicts are chronicle-worthy — PASS captures the quality checkpoint, BLOCK captures what needs fixing.

```bash
LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:qualification"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,plan:$PLAN_IDX"

bd create --type task \
  --title "Chronicle: swarm_qualify — REVIEW:$VERDICT for plan-$PLAN_IDX" \
  -l "$LABELS" \
  --description "Qualification verdict: REVIEW:$VERDICT
Config mode: $QUAL_MODE
Review scope: $START_SHA..HEAD
Gate bead: $GATE_ID
Issues found: <summary of issues or 'none'>" \
  --silent
```

## Output

```
Qualification Gate: plan-<idx>
  Config: <blocking|advisory|disabled>
  Gate bead: <gate-id>
  Review scope: <start-sha>..<HEAD>
  Verdict: REVIEW:<PASS|BLOCK>
  Result: <PASS — completion proceeds | BLOCK — manual intervention required>
```

## Important

- The gate bead is created during `plan_create_beads` Step 9c and stays open until qualification passes
- Start SHA is recorded by `plan-exec.sh start` as a `start-sha:<hash>` label on the root epic
- The code-review formula runs as a standard swarm (analyze → report) with the diff scope as context
- In `advisory` mode, the block is noted in the plan completion report but doesn't prevent closing
