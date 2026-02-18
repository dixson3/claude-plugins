# Plan: Memory Reconciliation Skill

## Context

The operator manually performed memory hygiene: reading MEMORY.md, comparing against specs and CLAUDE.md, finding contradictions, gaps, and duplicates, promoting gaps to specs, and cleaning memory. This process should be a skill so it runs consistently at every session close. The skill will be integrated into Rule 4.2 "Landing the Plane" as a pre-commit step.

## Files to Modify

| File | Change |
|------|--------|
| **Specifications** | |
| `docs/specifications/PRD.md` | Add REQ-037, FS-042 |
| `docs/specifications/IG/chronicler.md` | Add UC-037 (memory reconciliation) |
| `docs/specifications/test-coverage.md` | Add REQ-037 and UC-037 rows, update counts |
| `docs/specifications/TODO.md` | Add TODO-029 |
| **Implementation** | |
| `plugins/yf/skills/memory_reconcile/SKILL.md` | **New** — the skill |
| `plugins/yf/rules/yf-rules.md` | Add step 4.5 to Rule 4.2 |
| **Tests** | |
| `tests/scenarios/unit-memory-reconcile.yaml` | **New** — existence checks (7 cases) |
| **Documentation** | |
| `plugins/yf/DEVELOPERS.md` | Add memory capability row |
| `plugins/yf/README.md` | Add Memory section |
| `CHANGELOG.md` | Append to v2.21.0 |

## Implementation

### Step 0: Specification additions

**PRD.md** — Add after REQ-036:

```
| REQ-037 | MEMORY.md must be reconcilable against specifications and CLAUDE.md. Contradictions resolved in favor of specs, gaps promoted to specs with operator approval, ephemeral duplicates removed. | P2 | Memory | Plan 43 | `plugins/yf/skills/memory_reconcile/SKILL.md` |
```

Add after FS-041:

```
- FS-042: Memory reconciliation classifies MEMORY.md items as contradictions (spec wins), gaps (promote to specs), or ephemeral duplicates (remove). Agent-interpreted — the LLM reads both documents and reasons semantically. Operator approval required for all spec changes per Rule 1.4. Idempotent — clean memory is a no-op.
```

**IG/chronicler.md** — Add UC-037 after UC-013. Chronicler is the right home because memory reconciliation is session-boundary work (runs alongside chronicle capture and diary generation in Rule 4.2).

```markdown
### UC-037: Memory Reconciliation

**Actor**: Operator or System (Rule 4.2 step 4.5)

**Preconditions**: yf is enabled. MEMORY.md exists with content beyond the "no active items" sentinel. Specification files and/or CLAUDE.md exist.

**Flow**:
1. Operator invokes `/yf:memory_reconcile` (or system runs it at session close per Rule 4.2)
2. Skill reads MEMORY.md
3. Skill reads CLAUDE.md and specification files (PRD.md, EDD/CORE.md, IG/*.md, TODO.md)
4. Skill classifies each memory item: contradiction, gap, or ephemeral/duplicate
5. Skill presents structured report with proposed actions
6. In gate mode: operator approves changes via AskUserQuestion; spec changes require individual approval per Rule 1.4
7. In check mode: report only, no modifications
8. Skill executes approved changes: corrects contradictions, promotes gaps via `/yf:engineer_update`, removes ephemeral items
9. Skill writes cleaned MEMORY.md

**Postconditions**: MEMORY.md contains only items that genuinely belong there. Gaps promoted to appropriate spec files.

**Key Files**:
- `plugins/yf/skills/memory_reconcile/SKILL.md`
```

**test-coverage.md** — Add rows:
- REQ table: `| REQ-037 | Memory reconciliation | unit-memory-reconcile.yaml | existence-only |`
- UC table: `| UC-037 | Memory reconciliation | chronicler | unit-memory-reconcile.yaml | existence-only |`
- Update summary: REQ 36→37, UC 36→37, total 95→97

**TODO.md** — Add:
```
| TODO-029 | E2E validation of memory reconciliation with real MEMORY.md and spec files | P2 | Plan 43 (memory reconcile) | Open |
```

### Step 1: Skill file

**New: `plugins/yf/skills/memory_reconcile/SKILL.md`**

Standard pattern: YAML frontmatter, activation guard, behavioral steps.

- **Arguments**: `mode` (gate/check, default gate)
- **Step 1**: Read MEMORY.md. If empty or sentinel ("No active memory items"), report clean and exit.
- **Step 2**: Read comparison sources — CLAUDE.md and all spec files under `$ARTIFACT_DIR/specifications/`.
- **Step 3**: Classify each memory item into: contradiction (spec wins), gap (important info not in specs), ephemeral/duplicate (version numbers, commands that duplicate CLAUDE.md).
- **Step 4**: Present structured report (contradictions, gaps, ephemeral items with proposed actions).
- **Step 5**: In gate mode, use AskUserQuestion for operator approval. Spec changes require individual approval per Rule 1.4.
- **Step 6**: Execute approved changes. For gaps, use `/yf:engineer_update` to promote to specs, then remove from memory.
- **Step 7**: Write cleaned MEMORY.md. If all items resolved, write the sentinel.
- **Step 8**: Output summary (resolved counts, remaining items, files modified).

### Step 2: Rule 4.2 update

In `yf-rules.md` section 4.2 "Landing the Plane", insert step 4.5 between current steps 4 and 5:

```
4.5. Memory reconciliation (if specs exist): `/yf:memory_reconcile`
```

Placement rationale: after quality gates (code stable), before commit (spec changes included).

### Step 3: Tests

**New: `tests/scenarios/unit-memory-reconcile.yaml`** — 7 existence-check cases:
1. Skill file exists
2. Correct name in frontmatter
3. Has activation guard
4. References MEMORY.md
5. References AskUserQuestion (operator approval)
6. References engineer_update (gap promotion)
7. Rule 4.2 references memory_reconcile

### Step 4: Documentation

- **DEVELOPERS.md**: Add row `| Memory | memory | memory_reconcile | — |` to capability table
- **README.md**: Add compact Memory section (why, how, skill, Rule 4.2 integration)
- **CHANGELOG.md**: Append to v2.21.0 Added/Changed sections

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass including new memory-reconcile tests
2. `bash plugins/yf/scripts/spec-sanity-check.sh all` — 6/6 pass (counts updated)
3. Manual: invoke `/yf:memory_reconcile` on current (clean) MEMORY.md — should report no-op

## Execution Order

1. Step 0 — Specs first (anchor before code)
2. Step 1 — Skill file
3. Step 2 — Rule update
4. Step 3 — Tests
5. Step 4 — Documentation
