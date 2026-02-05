---
name: engage-plan
description: Formalize and save a plan discussion to docs/plans/ with optional factoring into parts
---

# Engage Plan Command

Formalize the current plan discussion into structured documentation ready for implementation.

## Workflow

### Step 1: Determine Plan Index

1. Check existing plans in `docs/plans/`
2. Find the highest existing index
3. Use next index (zero-padded: 01, 02, 03...)

### Step 2: Save the Master Plan

Create `docs/plans/plan-<idx>.md`:

```markdown
# Plan <idx>: <Title>

**Status:** Pending
**Date:** YYYY-MM-DD

## Overview
<consolidated plan content from discussion>

## Implementation Sequence
<ordered list of phases/steps>

## Completion Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

### Step 3: Factor into Parts (if complex)

If the plan has multiple distinct phases or components:

1. Create part files: `plan-<idx>-part<N>-<name>.md`
2. Each part includes:
   ```markdown
   # Plan <idx> - Part <N>: <Name>

   **Status:** Pending
   **Parent:** plan-<idx>.md
   **Dependencies:** <list dependent part files>

   ## Overview
   <part-specific content>

   ## Files to Create
   <detailed file list with content>

   ## Completion Criteria
   - [ ] Specific criteria
   ```
3. Update master plan to reference parts with execution order

### Step 4: Update Memory

Add to MEMORY.md under "Current Plans":

```markdown
- `plan-<idx>.md` - <brief description>
  - `plan-<idx>-part1-<name>.md` - <part description>
```

### Step 5: Offer Context Clear

Present summary and options:

```
Plan saved to `docs/plans/plan-<idx>.md`

Parts created:
1. `plan-<idx>-part1-<name>.md` - <description>
2. `plan-<idx>-part2-<name>.md` - <description>

**Ready to implement?**
- Clear context and start with Part 1?
- Continue in current session?
```

## Plan File Conventions

### Naming
| Type | Format | Example |
|------|--------|---------|
| Master | `plan-<idx>.md` | `plan-02.md` |
| Part | `plan-<idx>-part<N>-<name>.md` | `plan-02-part1-roles.md` |

### Status Values
- `Pending` - Not started
- `In Progress` - Being implemented
- `Completed` - All criteria met
- `Abandoned` - Will not implement

### Progress Tracking
- Checkbox lists for completion criteria
- Update status field when starting/completing
- Mark checkboxes as work progresses

## Guidelines

- Create `docs/plans/` if it doesn't exist
- Include enough detail for implementation without original conversation
- Reference specific file paths and code patterns
- List dependencies between parts
- Implement parts in dependency order
