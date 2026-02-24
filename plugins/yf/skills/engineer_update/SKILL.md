---
name: yf:engineer_update
description: Add, update, or deprecate entries in specification documents (PRD, EDD, IG, TODO)
arguments:
  - name: type
    description: "Spec type: prd, edd, ig, or todo (required)"
    required: true
  - name: action
    description: "Action: add, update, or deprecate (default: add)"
    required: false
  - name: id
    description: "Specific entry ID to update (e.g., REQ-003, DD-001, NFR-002, UC-001, TODO-005)"
    required: false
  - name: subsystem
    description: "EDD subsystem name (for EDD type, creates/updates specifications/EDD/<subsystem>.md)"
    required: false
  - name: feature
    description: "Feature name (for IG type, creates/updates specifications/IG/<feature>.md)"
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

# Engineer: Update Specification

Add, update, or deprecate individual entries in specification documents.

## Behavior

### Step 1: Locate Spec File

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

Determine the target file based on `type`:
- `prd` → `$SPEC_DIR/PRD.md`
- `edd` → `$SPEC_DIR/EDD/CORE.md` (or `$SPEC_DIR/EDD/<subsystem>.md` if subsystem specified)
- `ig` → `$SPEC_DIR/IG/<feature>.md` (feature required for IG)
- `todo` → `$SPEC_DIR/TODO.md`

If the file does not exist, report: "No spec file found. Run `/yf:engineer_analyze_project scope:<type>` to create it first."

### Step 2: Parse Existing Entries

Read the spec file and extract existing IDs for the relevant type to check for collisions:
- PRD: Existing `REQ-NNNN-xxxxx` IDs
- EDD: Existing `DD-NNNN-xxxxx` or `NFR-NNNN-xxxxx` IDs (depending on which section)
- IG: Existing `UC-NNNN-xxxxx` IDs
- TODO: Existing `TODO-NNNN-xxxxx` IDs

### Step 3: Execute Action

#### Add (default)

1. Generate a hybrid idx-hash ID by passing the scope file:
   ```bash
   . "${CLAUDE_PLUGIN_ROOT}/scripts/yf-id.sh"
   # PRD:  yf_generate_id "REQ" "$SPEC_DIR/PRD.md"
   # EDD:  yf_generate_id "DD" "$SPEC_DIR/EDD/CORE.md"    (or subsystem file)
   # EDD:  yf_generate_id "NFR" "$SPEC_DIR/EDD/CORE.md"
   # IG:   yf_generate_id "UC" "$SPEC_DIR/IG/"             (directory scope)
   # TODO: yf_generate_id "TODO" "$SPEC_DIR/TODO.md"
   ```
   The scope argument ensures sequential indexing. Hash suffix ensures uniqueness.
2. Gather context from the current conversation
3. Create the new entry following the spec format
4. Insert at the appropriate location in the file
5. Report: "Added REQ-0005-k4m9q: [description]"

#### Update

1. Require `id` parameter — report error if missing
2. Find the entry in the file
3. Update the specified fields based on conversation context
4. Report: "Updated DD-003: [what changed]"

#### Deprecate

1. Require `id` parameter — report error if missing
2. Find the entry and change its Status to `Deprecated`
3. Add deprecation note with date and reason
4. Report: "Deprecated TODO-002: [reason]"

### Step 3.5: Chronicle Spec Mutation

After executing the action (add/update/deprecate), create a chronicle task. Every spec mutation is a contract change worth recording.

```bash
PLAN_LABEL=$(bash "$YFT" list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null | jq -r '.[0].labels[]? | select(startswith("plan:"))' | head -1)
LABELS="ys:chronicle,ys:chronicle:auto,ys:topic:engineer"
[ -n "$PLAN_LABEL" ] && LABELS="$LABELS,$PLAN_LABEL"

bash "$YFT" create --type task \
  --title "Chronicle: engineer_update — $ACTION $ENTRY_ID" \
  -l "$LABELS" \
  --description "Spec mutation: $ACTION
Entry: $ENTRY_ID
File: $TARGET_FILE
Rationale: <why this change was made>" \
  --silent
```

### Step 4: Cross-Reference Check

After modifying a spec, check for cross-reference implications:

- **PRD change** → Suggest: "This requirement change may affect EDD design decisions. Review DD-xxx entries for alignment."
- **EDD change** → Suggest: "This design decision may affect PRD requirements. Review REQ-xxx entries for alignment."
- **IG change** → Suggest: "This use case change may affect PRD requirements or EDD patterns."

Cross-reference suggestions are advisory — the operator decides whether to act.

## Expected Output

Report includes: action performed, spec type, target file, entry ID with description, and cross-reference advisory note if applicable.

## Error Handling

- Missing spec file → Direct to `engineer_analyze_project`
- Missing `id` for update/deprecate → Report error with usage example
- Duplicate ID → Report error, do not create
- Missing `feature` for IG type → Report error, list existing IG files
