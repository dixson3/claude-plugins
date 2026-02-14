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

# Engineer: Analyze Project

Synthesize specification artifacts from existing project context — plans, diary entries, research, decisions, and codebase structure.

## When to Invoke

- `/yf:engineer_analyze_project` — Generate all missing specification documents
- `/yf:engineer_analyze_project scope:prd` — Generate only the PRD
- `/yf:engineer_analyze_project force` — Regenerate all specs, showing diffs for existing files

## Behavior

### Step 1: Determine Artifact Directory

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

### Step 2: Check Existing Specs

Check which specification files already exist:

```bash
PRD_EXISTS=false; [ -f "$SPEC_DIR/PRD.md" ] && PRD_EXISTS=true
EDD_EXISTS=false; [ -f "$SPEC_DIR/EDD/CORE.md" ] && EDD_EXISTS=true
TODO_EXISTS=false; [ -f "$SPEC_DIR/TODO.md" ] && TODO_EXISTS=true
# IG docs: check for any .md files in IG/
IG_EXISTS=false; ls "$SPEC_DIR/IG/"*.md >/dev/null 2>&1 && IG_EXISTS=true
```

If all requested specs exist and `force` is not set, report what exists and exit:
```
All specification documents already exist:
  - PRD: docs/specifications/PRD.md
  - EDD: docs/specifications/EDD/CORE.md
  - TODO: docs/specifications/TODO.md
  - IG: docs/specifications/IG/ (N files)

Run with `force` to regenerate (will show diffs).
```

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

### PRD Template (`specifications/PRD.md`)

```markdown
# Product Requirements Document (PRD)

## 1. Purpose & Goals

[Synthesized from plans, README, and project documentation]

## 2. Technical Constraints

- Runtime/Language: [detected from project]
- Infrastructure: [detected from project]
- Dependencies: [key dependencies]

## 3. Requirement Traceability Matrix

| ID | Requirement Description | Priority | Status | Code Reference |
|:---|:---|:---|:---|:---|
| REQ-001 | [requirement] | High | Active | `path/to/file` |

## 4. Functional Specifications

### [Feature Name]
- **Logic:** [business logic from plans/diary]
- **Validation:** [input/output constraints]
- **Related:** [DD-xxx, NFR-xxx references]
```

### EDD Template (`specifications/EDD/CORE.md`)

```markdown
# Engineering Design Document

## Overview

[Architectural overview synthesized from plans, decisions, and code structure]

## Non-Functional Requirements

| ID | Requirement | Criteria | Status |
|:---|:---|:---|:---|
| NFR-001 | [requirement] | [measurable criteria] | Active |

## Design Decisions

### DD-001: [Decision Title]
- **Context:** [from archived decisions or plan rationale]
- **Decision:** [what was decided]
- **Rationale:** [why this approach]
- **Consequences:** [trade-offs]
- **Related:** [REQ-xxx, NFR-xxx]
```

### IG Template (`specifications/IG/<feature>.md`)

```markdown
# Implementation Guide: [Feature Name]

## Overview

[Feature purpose and scope]

## Use Cases

### UC-001: [Use Case Name]
- **Actor:** [who triggers this]
- **Preconditions:** [what must be true]
- **Flow:**
  1. [step]
  2. [step]
- **Postconditions:** [what is true after]
- **Related:** [REQ-xxx, DD-xxx]

## Implementation Notes

[Key patterns, conventions, edge cases]
```

### TODO Template (`specifications/TODO.md`)

```markdown
# TODO Register

Lightweight deferred items — ideas, improvements, and follow-ups that don't warrant full beads tracking.

| ID | Description | Priority | Source | Status |
|:---|:---|:---|:---|:---|
| TODO-001 | [item] | Low | [plan/diary/session] | Open |
```

## Idempotency

- Does NOT overwrite existing specs unless `force` is set
- When `force` is set, shows diff and asks before applying
- Safe to run multiple times
