---
name: yf:engineer_reconcile
description: Reconcile a plan against specification documents (PRD, EDD, IG)
arguments:
  - name: plan_file
    description: "Path to the plan file to reconcile"
    required: false
  - name: plan_idx
    description: "Plan index (e.g., 0034-m8q2r)"
    required: false
  - name: mode
    description: "Mode: gate (interactive, blocks on conflict) or check (report only). Default: gate"
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


# Engineer: Reconcile Plan Against Specifications

Check a plan for compliance with existing specification documents. Flags conflicts, untraced functionality, and features that may need IG updates.

## Behavior

### Step 0: Configuration Check

```bash
RECON_MODE=$(jq -r '.config.engineer.reconciliation_mode // "blocking"' .yoshiko-flow/config.json 2>/dev/null || echo "blocking")
```

If `RECON_MODE` is `"disabled"`, exit silently with success.

### Step 1: Locate Specification Files

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

Check for spec files:
```bash
HAS_PRD=false; [ -f "$SPEC_DIR/PRD.md" ] && HAS_PRD=true
HAS_EDD=false; [ -f "$SPEC_DIR/EDD/CORE.md" ] && HAS_EDD=true
HAS_IG=false; ls "$SPEC_DIR/IG/"*.md >/dev/null 2>&1 && HAS_IG=true
```

**If no spec files exist**: Return success silently. No enforcement without specs.

### Step 2: Locate Plan

If `plan_file` specified, use it directly. Otherwise, find by `plan_idx`:
```bash
PLAN_FILE="docs/plans/plan-${plan_idx}.md"
```

If neither specified, find the most recent plan:
```bash
ls -t docs/plans/plan-*.md | head -1
```

Read the plan file content.

### Step 3: PRD Reconciliation

If PRD exists, compare plan tasks against requirements:

1. **Extract REQ-xxx entries** from `$SPEC_DIR/PRD.md`
2. **Parse plan tasks** from the plan file
3. **Check traceability**: Do plan tasks map to existing requirements?
   - Tasks that introduce new functionality without a REQ → flag as `UNTRACED`
   - Tasks that contradict an existing REQ → flag as `CONTRADICTION`
4. **Verdict**: `PRD:COMPLIANT` or `PRD:CONFLICT` (with details)

### Step 4: EDD Reconciliation

If EDD exists, compare plan approach against design decisions:

1. **Extract DD-xxx and NFR-xxx entries** from `$SPEC_DIR/EDD/CORE.md` and subsystem files
2. **Parse plan implementation approach** — technology choices, patterns, architecture
3. **Check alignment**:
   - Plan uses technology that conflicts with a DD → flag as `TECHNOLOGY_CONFLICT`
   - Plan approach violates an NFR → flag as `NFR_VIOLATION`
   - Plan introduces new architecture not covered by existing DDs → flag as `NEW_ARCHITECTURE`
4. **Verdict**: `EDD:COMPLIANT` or `EDD:CONFLICT` (with details)

### Step 5: IG Reconciliation

If IG files exist, check which features may be affected:

1. **List existing IG feature files** in `$SPEC_DIR/IG/`
2. **Parse plan tasks** for references to documented features
3. **Check impact**:
   - Plan modifies a feature that has an IG → flag as `NEEDS_UPDATE`
   - Plan adds new feature that should have an IG → flag as `NEW_FEATURE`
4. **Verdict**: `IG:COMPLIANT` or `IG:NEEDS-UPDATE` (with details)

### Step 6: Overall Verdict

Combine individual verdicts:
- All COMPLIANT → `PASS`
- Any CONFLICT or NEEDS-UPDATE → `NEEDS-RECONCILIATION`

### Step 7.5: Chronicle on NEEDS-RECONCILIATION

If the overall verdict from Step 6 is `NEEDS-RECONCILIATION`, create a chronicle bead capturing the reconciliation context. Skip on `PASS` (routine compliance is not chronicle-worthy).

```bash
# Only chronicle on conflict — routine PASS is not chronicle-worthy
if [ "$VERDICT" = "NEEDS-RECONCILIATION" ]; then
  PLAN_LABEL=$(bd label list <epic-id> --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1)
  LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:engineer"
  [ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

  bd create --type task \
    --title "Chronicle: engineer_reconcile — NEEDS-RECONCILIATION" \
    -l "$LABELS" \
    --description "Reconciliation verdict: NEEDS-RECONCILIATION
PRD: $PRD_VERDICT
EDD: $EDD_VERDICT
IG: $IG_VERDICT
Conflicts: <specific conflicts found>
Operator decision: <update specs / modify plan / acknowledge>" \
    --silent
fi
```

### Step 7: Report and Gate

#### In `check` mode:
Output the reconciliation report and return. No interaction.

#### In `gate` mode:

If `PASS`: Proceed silently.

If `NEEDS-RECONCILIATION`:

**When `reconciliation_mode` is `"blocking"`**: Present conflicts to operator via AskUserQuestion:

```
Specification Reconciliation: NEEDS-RECONCILIATION

PRD: CONFLICT
  - Task "Add OAuth support" introduces new functionality not traced to any REQ
  - Task "Remove email login" contradicts REQ-003 (email authentication required)

EDD: COMPLIANT

IG: NEEDS-UPDATE
  - Feature "authentication" (specifications/IG/authentication.md) affected by plan tasks
```

Options:
- **(a) Update specs** — "I'll update the specifications to match this plan" → Proceed, operator will update specs after
- **(b) Modify plan** — "I need to adjust the plan to match specs" → Abort auto-chain, return to planning
- **(c) Acknowledge and proceed** — "I understand the conflicts, proceed anyway" → Continue with warning logged

**When `reconciliation_mode` is `"advisory"`**: Output the report as a note, then proceed automatically.

## Output Format

Report includes: plan reference, per-spec verdicts (PRD/EDD/IG with COMPLIANT or CONFLICT details), and overall verdict (PASS or NEEDS-RECONCILIATION).

## Labels

When reconciliation runs during plan execution, create a label on the plan epic:
```bash
bd label add <epic-id> ys:engineer:reconciliation
```

## Error Handling

- Plan file not found → Report error
- Spec files partially present → Reconcile only against available specs
- Config not found → Default to `blocking` mode
