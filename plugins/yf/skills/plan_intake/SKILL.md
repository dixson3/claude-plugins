---
name: yf:plan_intake
description: Run plan intake checklist — save plan, create beads, start execution
user_invocable: true
arguments:
  - name: plan
    description: "Path to plan file or plan index (e.g., docs/plans/plan-15.md or 15)"
    required: false
---

# Plan Intake Checklist

Run the 5-step intake checklist to ensure a plan goes through the proper lifecycle before implementation begins. Idempotent — safe to re-run if partially completed.

## Steps

Execute these steps in order, skipping any that are already satisfied:

### Step 1: Ensure Plan File Exists

Check if a plan file exists in `docs/plans/` for this plan:

```bash
ls docs/plans/plan-*.md
```

- **If the `plan` argument is a file path**: Use that file directly. Determine the plan index from the filename.
- **If the `plan` argument is a number**: Look for `docs/plans/plan-<number>.md`.
- **If no argument and plan content was provided inline**: Determine the next index and save to `docs/plans/plan-<next-idx>.md` using the standard format:

  ```markdown
  # Plan <idx>: <Title>

  **Status:** Draft
  **Date:** YYYY-MM-DD

  ## Overview
  <plan content>

  ## Implementation Sequence
  <ordered steps>

  ## Completion Criteria
  - [ ] Criterion 1
  ```

- **If plan file already exists**: Use the existing file.

### Step 2: Ensure Beads Exist

Check if beads have been created for this plan:

```bash
bd list -l plan:<idx> --type=epic
```

- **If no beads exist**: Invoke `/yf:plan_create_beads docs/plans/plan-<idx>.md` to create the structured hierarchy (epic, tasks, gates, dependencies).
- **If beads already exist**: Skip this step.

### Step 3: Ensure Plan is Executing

Check if the plan is in Executing state:

```bash
test -f .yoshiko-flow/plan-gate && echo "gate exists" || echo "no gate"
```

- **If gate exists** (plan is Draft/Ready, not yet Executing):
  ```bash
  ROOT_EPIC=$(bd list -l plan:<idx> --type=epic --status=open --limit=1 --json 2>/dev/null \
    | jq -r '.[0].id // empty')
  bash plugins/yf/scripts/plan-exec.sh start "$ROOT_EPIC"
  ```
- **If no gate**: Plan is already in Executing state (or was never gated). Proceed.

### Step 4: Capture Planning Context

If this is the start of implementation and there was planning discussion in the conversation (design rationale, alternatives considered, architectural decisions):
- Invoke `/yf:chronicle_capture topic:planning` to preserve the planning context as a chronicle bead.
- Skip if the planning discussion was trivial (less than a few exchanges).

### Step 5: Dispatch via Task Pump

Invoke `/yf:plan_execute` to begin structured dispatch via the task pump.

## On Success

Create the intake marker to suppress the code-gate warning:

```bash
touch "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-intake-ok"
```

## Important

- This skill is **idempotent** — each step checks whether it's already been done before acting.
- If any step fails, report the error. The user can re-run `/yf:plan_intake` to retry.
- The marker file (`.yoshiko-flow/plan-intake-ok`) is ephemeral session state — it prevents the code-gate hook from warning repeatedly.
