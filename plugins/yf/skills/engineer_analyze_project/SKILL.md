---
name: yf:engineer_analyze_project
description: Synthesize specification artifacts (PRD, EDD, IG, TODO) from existing project context
arguments:
  - name: scope
    description: "Which specs to generate: all, prd, edd, ig, or todo (default: all)"
    required: false
  - name: force
    description: "Set to regenerate existing specs (shows diff of changes)"
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


# Engineer: Analyze Project

Synthesize specification artifacts from existing project context — plans, diary entries, research, decisions, and codebase structure.

## Behavior

### Step 1: Determine Artifact Directory

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

### Step 2: Check Existing Specs

Check which specs exist (`PRD.md`, `EDD/CORE.md`, `TODO.md`, `IG/*.md`). If all requested specs exist and `force` is not set, report what exists and exit.

### Step 3: Gather Project Context

Launch the `yf_engineer_synthesizer` agent via the Task tool to analyze the project:

```
Task(
  subagent_type = "yf:yf_engineer_synthesizer",
  prompt = "Analyze this project and synthesize specification content.

  Scope: <scope or 'all'>
  Force: <true/false>

  Scan these sources for context:
  - docs/plans/*.md — Plan documents with implementation details
  - docs/diary/*.md — Diary entries with rationale and context
  - docs/research/ — Archived research findings
  - docs/decisions/ — Archived design decisions
  - CLAUDE.md, DEVELOPERS.md, README.md — Project documentation
  - Source code structure — Key directories, patterns, conventions

  For each requested spec type, return JSON with the synthesized content.
  Follow the templates defined below."
)
```

### Step 4: Write Specification Files

For each spec type in scope where content was synthesized:

**If file does not exist**: Write the file using the template.

**If file exists and `force` is set**: Generate the new content, show a diff to the operator, and ask whether to apply changes.

**If file exists and `force` is not set**: Skip with a message.

### Step 5: Report

```
Engineer: Analyze Project Complete
===================================
Generated:
  - docs/specifications/PRD.md (N requirements)
  - docs/specifications/EDD/CORE.md (N design decisions, N NFRs)
  - docs/specifications/TODO.md (N items)

Skipped (already exist):
  - docs/specifications/IG/authentication.md

Run /yf:engineer_update to add or modify individual entries.
```

## Templates

Each template follows a standard section structure. The model synthesizes content from project context.

- **PRD** (`specifications/PRD.md`): Purpose & Goals, Technical Constraints, Requirement Traceability Matrix (REQ-NNN table), Functional Specifications
- **EDD** (`specifications/EDD/CORE.md`): Overview, Non-Functional Requirements (NFR-NNN table), Design Decisions (DD-NNN with Context/Decision/Rationale/Consequences)
- **IG** (`specifications/IG/<feature>.md`): Overview, Use Cases (UC-NNN with Actor/Preconditions/Flow/Postconditions), Implementation Notes
- **TODO** (`specifications/TODO.md`): Register table (ID, Description, Priority, Source, Status)

## Idempotency

- Does NOT overwrite existing specs unless `force` is set
- When `force` is set, shows diff and asks before applying
- Safe to run multiple times
