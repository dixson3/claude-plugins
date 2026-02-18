---
name: yf:plan_intake
description: Run plan intake checklist — save plan, create beads, start execution
user_invocable: true
arguments:
  - name: plan
    description: "Path to plan file or plan index (e.g., docs/plans/plan-15.md or 15)"
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

### Step 1.5: Specification Integrity Gate

If specifications exist (`<artifact_dir>/specifications/`), run this checklist
before creating beads. All spec changes require explicit operator approval.

**1.5a. Contradiction check:**
Read the plan file and compare against PRD requirements (REQ-xxx),
EDD design decisions (DD-xxx), and IG use cases (UC-xxx). If the plan
contradicts any existing spec item, present the contradiction to the
operator via AskUserQuestion with options:
- "Revise the plan to resolve" (recommended)
- "Update the specification (explain why)"
- "Acknowledge and proceed"

If operator chooses spec update, draft the change and get explicit approval
before modifying the spec file.

**1.5b. New capability check:**
Identify any plan tasks that describe functionality not traced to existing
REQ/UC/DD entries. If found, present to operator:
- "Add specification entries for new capabilities" (recommended)
- "Proceed without spec coverage"

If adding specs: draft new REQ, UC, and/or DD entries. Get operator approval.
Write entries using `/yf:engineer_update`. Update test-coverage.md with
new rows (status: untested).

**1.5c. Test-spec alignment check:**
Review the plan's testing approach. Tests must reference specification
items (REQ-xxx, UC-xxx, DD-xxx) as their primary basis, not just
implementation details. If the plan describes tests only in implementation
terms, restructure the test plan to align with spec items first.

**1.5d. Test deprecation check:**
If the plan or any proposed spec change deprecates existing functionality,
identify test scenarios in test-coverage.md that would become invalid.
Plan their removal or update as part of the implementation.

**1.5e. Chronicle spec and functionality changes:**
For any specification additions, modifications, or deprecations identified
in steps 1.5a-d, create chronicle entries:
- `bash plugins/yf/scripts/plan-chronicle.sh intake "spec-change" "<summary>"`
For any deprecated or newly added functionality:
- `bash plugins/yf/scripts/plan-chronicle.sh intake "capability-change" "<summary>"`

**1.5f. Structural consistency:**
Run `bash plugins/yf/scripts/spec-sanity-check.sh all` to verify spec
files are internally consistent before reconciling the plan against them.
If issues found and mode is `blocking` (default): present to operator.
If issues found and mode is `advisory`: output report, proceed.

Then run spec reconciliation:
- Invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`

This closes the gap where manual intake previously had no spec checks at all.

**1.5g. Chronicle reconciliation verdict:**
If reconciliation ran in Step 1.5f and produced a result (skip if no specs exist),
create a chronicle bead capturing the intake reconciliation context:

```bash
LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:planning,plan:<idx>"

bd create --type task \
  --title "Chronicle: plan_intake — reconciliation for plan-<idx>" \
  -l "$LABELS" \
  --description "Intake reconciliation verdict: <PASS or NEEDS-RECONCILIATION>
Structural consistency: <sanity check result>
Spec changes approved: <list of changes from Steps 1.5a-d, or 'none'>
Contradictions found: <summary or 'none'>
New capabilities requiring spec coverage: <summary or 'none'>" \
  --silent
```

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

**Step 4a (DETERMINISTIC):** Run the shell command to create a guaranteed chronicle stub:

```bash
bash plugins/yf/scripts/plan-chronicle.sh intake "plan:<idx>" "docs/plans/plan-<idx>.md"
```

This creates a stub chronicle bead with the plan excerpt. It is deduped (safe to re-run) and fail-open.

**Step 4b (OPTIONAL):** If the planning discussion had significant design rationale beyond what the plan file captures (e.g., alternatives considered, architecture debates), invoke `/yf:chronicle_capture topic:planning` to create a richer chronicle. Skip if the plan file already contains all relevant context.

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
