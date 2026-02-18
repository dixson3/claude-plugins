---
name: yf:memory_reconcile
description: Reconcile MEMORY.md against specifications and CLAUDE.md
arguments:
  - name: mode
    description: "gate (interactive approval, default) or check (report only)"
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


# Memory Reconciliation Skill

Reconcile MEMORY.md against specifications and CLAUDE.md. Classifies memory items as contradictions, gaps, or ephemeral duplicates. Resolves with operator approval.

## Arguments

- `mode`: `gate` (default) — interactive, prompts for approval. `check` — report only, no modifications.

## Behavior

### Step 1: Read MEMORY.md

Locate the project's auto-memory file:

```bash
MEMORY_DIR=$(ls -d ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null | head -1)
```

If the file path is known from context (e.g., the current project's memory directory), use it directly.

Read the file contents. If the file is empty, missing, or contains only the sentinel text ("No active memory items"), report:

> Memory is clean. No reconciliation needed.

Then stop. This makes the skill idempotent on clean memory.

### Step 2: Read Comparison Sources

Gather the reference documents:

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

Read:
1. **CLAUDE.md** — project root and any global `~/.claude/CLAUDE.md`
2. **Specification files** (if `$SPEC_DIR` exists):
   - `$SPEC_DIR/PRD.md` — requirements and functional specs
   - `$SPEC_DIR/EDD/CORE.md` — design decisions and NFRs
   - `$SPEC_DIR/IG/*.md` — implementation guides and use cases
   - `$SPEC_DIR/TODO.md` — open items

If no specs exist and no CLAUDE.md exists, report:

> No comparison sources found. Nothing to reconcile against.

Then stop.

### Step 3: Classify Each Memory Item

Parse MEMORY.md into discrete items (each heading, bullet, or logical block). For each item, classify it as one of:

| Classification | Definition | Action |
|---------------|------------|--------|
| **Contradiction** | Memory states something that conflicts with a spec entry or CLAUDE.md | Correct memory to match spec (spec wins) |
| **Gap** | Memory contains valuable information not captured in any spec or CLAUDE.md | Promote to appropriate spec via `/yf:engineer_update` |
| **Ephemeral** | Memory duplicates info already in specs/CLAUDE.md, or contains session-specific state (version numbers, temp paths, in-progress notes) | Remove from memory |
| **Valid** | Memory contains info that belongs there (user preferences, workflow notes not suitable for specs) | Keep as-is |

Classification is agent-interpreted — read both documents and reason semantically about whether each memory item adds unique value.

### Step 4: Present Structured Report

Output the reconciliation report:

```
Memory Reconciliation Report
=============================

## Contradictions (spec wins)
- "<memory item>" contradicts <spec-id>: <explanation>
  Action: Correct in MEMORY.md

## Gaps (promote to specs)
- "<memory item>" not covered by any spec
  Action: Add to <target-spec> as <entry-type>

## Ephemeral/Duplicates (remove)
- "<memory item>" duplicates <source>
  Action: Remove from MEMORY.md

## Valid (keep)
- "<memory item>" — user preference, not spec material

Summary: X contradictions, Y gaps, Z ephemeral, W valid
```

If all items are valid or the report is empty, report:

> Memory is consistent. No changes needed.

Then stop (in both modes).

### Step 5: Operator Approval (gate mode only)

If `mode` is `check`, skip to output — no modifications.

If `mode` is `gate` and changes are proposed, use AskUserQuestion to get approval:

- For **contradictions**: "Correct these items in MEMORY.md to match specs?"
- For **gaps**: Present each gap individually — spec changes require individual approval per Rule 1.4. "Promote this to `<target-spec>` as `<entry-type>`?"
- For **ephemeral items**: "Remove these ephemeral/duplicate items from MEMORY.md?"

The operator can approve all, approve selectively, or skip.

### Step 6: Execute Approved Changes

For each approved change:

- **Contradictions**: Edit MEMORY.md to correct the item (align with spec).
- **Gaps**: Invoke `/yf:engineer_update type:<type>` to add the entry to the appropriate spec file, then remove the item from MEMORY.md.
- **Ephemeral items**: Remove from MEMORY.md.

### Step 7: Write Cleaned MEMORY.md

After all approved changes are applied, write the updated MEMORY.md.

If all items were resolved (nothing remains), write the sentinel:

```markdown
# Project Memory — <project-name>

No active memory items. All conventions and lessons are captured in specifications and CLAUDE.md.
```

### Step 8: Output Summary

```
Memory Reconciliation Complete
===============================
Contradictions resolved: X
Gaps promoted to specs: Y
Ephemeral items removed: Z
Items kept: W
Files modified: MEMORY.md[, PRD.md, ...]
```
