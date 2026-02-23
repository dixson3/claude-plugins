---
name: yf:engineer_suggest_updates
description: Suggest specification updates based on completed plan work
arguments:
  - name: plan_idx
    description: "Plan index to analyze (e.g., 0034-m8q2r)"
    required: false
  - name: scope
    description: "Which specs to check: all, prd, edd, ig, or todo (default: all)"
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


# Engineer: Suggest Specification Updates

Analyze completed plan work and suggest updates to specification documents. Advisory only — does not auto-update.

## Behavior

### Step 1: Identify Plan

If `plan_idx` not specified, find the most recently completed plan:
```bash
bd list -l ys:plan --type=epic --status=closed --sort=created --reverse --limit=1 --json 2>/dev/null
```

### Step 2: Gather Completed Work

Read plan beads and their comments:
```bash
# List all closed tasks for the plan
bd list -l plan:<idx> --type=task --status=closed --limit=0 --json 2>/dev/null

# For each task, read CHANGES/FINDINGS/REVIEW comments
bd show <task-id> --comments 2>/dev/null
```

### Step 3: Read Current Specs

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

Read all existing spec files. If no specs exist, exit with: "No specification documents found. Run `/yf:engineer_analyze_project` to create them."

### Step 4: Compare and Suggest

For each spec type in scope:

#### PRD Suggestions
- New functionality implemented → suggest new REQ entry
- Existing REQ addressed → suggest status update to "Implemented"
- Code references changed → suggest updating Code Reference column

#### EDD Suggestions
- New architecture introduced → suggest new DD entry
- Technology changes → suggest updating existing DD entries
- Performance characteristics changed → suggest NFR updates

#### IG Suggestions
- Feature modified → suggest updating existing IG use cases
- New feature implemented → suggest new IG file
- Use case flow changed → suggest UC updates

#### TODO Suggestions
- Plan "Future Work" items → suggest new TODO entries
- Deferred items from plan → suggest TODO entries
- Completed TODO items → suggest closing

### Step 5: Output Suggestions

Report includes: plan reference, per-spec-type suggestions (PRD/EDD/IG/TODO) with action (ADD/UPDATE), entry ID, description, and source reference. Ends with pointer to `/yf:engineer_update` for applying suggestions.

## Important

- This skill is **advisory only** — it suggests, the operator decides
- Suggestions reference their source (plan task, comment, section)
- Does NOT modify specification files
- Produces actionable output that can be applied via `/yf:engineer_update`
