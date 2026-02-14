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

# Engineer: Update Specification

Add, update, or deprecate individual entries in specification documents.

## When to Invoke

- `/yf:engineer_update type:prd` — Add a new requirement to the PRD
- `/yf:engineer_update type:edd action:update id:DD-003` — Update a design decision
- `/yf:engineer_update type:ig feature:authentication action:add` — Add a use case to the authentication IG
- `/yf:engineer_update type:todo action:deprecate id:TODO-002` — Deprecate a TODO item

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

Read the spec file and extract the highest existing ID for the relevant type:
- PRD: Find highest `REQ-NNN`
- EDD: Find highest `DD-NNN` or `NFR-NNN` (depending on which section)
- IG: Find highest `UC-NNN`
- TODO: Find highest `TODO-NNN`

### Step 3: Execute Action

#### Add (default)

1. Generate next sequential ID
2. Gather context from the current conversation
3. Create the new entry following the spec format
4. Insert at the appropriate location in the file
5. Report: "Added REQ-007: [description]"

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

### Step 4: Cross-Reference Check

After modifying a spec, check for cross-reference implications:

- **PRD change** → Suggest: "This requirement change may affect EDD design decisions. Review DD-xxx entries for alignment."
- **EDD change** → Suggest: "This design decision may affect PRD requirements. Review REQ-xxx entries for alignment."
- **IG change** → Suggest: "This use case change may affect PRD requirements or EDD patterns."

Cross-reference suggestions are advisory — the operator decides whether to act.

## Expected Output

```
Engineer: Update
=================
Action: add
Type: prd
File: docs/specifications/PRD.md

Added REQ-007: User must be able to export data in CSV format
  Priority: Medium
  Status: Active
  Code Reference: (none yet)

Cross-reference note: This new requirement may need a DD-xxx entry
in the EDD if it requires architectural decisions. Consider running
/yf:engineer_update type:edd to add a related design decision.
```

## Error Handling

- Missing spec file → Direct to `engineer_analyze_project`
- Missing `id` for update/deprecate → Report error with usage example
- Duplicate ID → Report error, do not create
- Missing `feature` for IG type → Report error, list existing IG files
