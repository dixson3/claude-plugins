# Plan 40: Specification Integrity Gates

**Status:** Completed
**Date:** 2026-02-16

## Context

Specifications are anchor documents. No implementation plan should contract the spec. All tests should be written against the spec first, implementation second. If a plan adds capability not addressed in a specification, new spec content must be written as part of that plan.

A manual review of `docs/specifications/` found systemic drift that went uncaught: stale counts, broken cross-references, removed artifacts still described, new capabilities never added to coverage. The root cause: no gates enforce spec integrity at lifecycle boundaries. This plan adds two gatekeeping checklists — one at plan intake, one at plan completion — that make the specification the authority over plans, tests, and implementation.

## Overview

Two checklists, codified as behavioral steps in skills and rules. Backed by a mechanical consistency script for the structural checks. All operator-facing — contradictions and spec changes require explicit approval.

## Implementation Sequence

### Phase 1: Mechanical consistency script — `plugins/yf/scripts/spec-sanity-check.sh`

~250 lines. Subcommand model following `plan-prune.sh`. Sources `yf-config.sh`. Exit 0 always (fail-open). This script handles structural/mechanical checks only — the analytical checks are handled by skill instructions.

**Subcommands:** `all | counts | contiguity | arithmetic | uc-ranges | test-refs | formulas`

**Guards:** No jq → SKIP. yf disabled → exit 0. No `$SPEC_DIR` → SKIP.

**Checks:**
1. **Count parity** — REQ count in PRD == rows in test-coverage == Coverage Summary total. Same for DD, NFR, UC.
2. **ID contiguity** — No gaps in REQ-001..N, DD-001..N, NFR-001..N, UC-001..N sequences.
3. **Coverage arithmetic** — Total = Tested + Existence-Only + Untested per category. Grand total = sum of categories.
4. **UC range alignment** — UC IDs in each IG file match declared ranges in test-coverage.md header.
5. **Test file existence** — Every `unit-*.yaml` referenced in test-coverage.md exists in `tests/scenarios/`.
6. **Formula count** — Formula names in PRD FS-011 match actual `.formula.json` files on disk.

**Output:** Structured report with `[PASS]`/`[FAIL]` per check, trailing `SANITY_ISSUES=N` for machine parsing.

### Phase 2: Config helper — `plugins/yf/scripts/yf-config.sh`

Add `yf_sanity_check_mode()` (after line 64):

```bash
yf_sanity_check_mode() {
  local mode
  mode=$(yf_read_field '.config.engineer.sanity_check_mode' 2>/dev/null)
  if [ -z "$mode" ] || [ "$mode" = "null" ]; then
    echo "blocking"
  else
    echo "$mode"
  fi
}
```

Default: `blocking` — specs are anchor documents, so integrity violations block by default. Consistent with `reconciliation_mode` default.

### Phase 3: Test scenarios — `tests/scenarios/unit-spec-sanity.yaml`

~300 lines, 14 test steps with synthetic spec files. Key cases:
- No specs → SKIP (exit 0)
- Count parity pass/fail
- Contiguity pass/fail (gap detection)
- Arithmetic pass/fail
- Test file refs pass/fail (missing file detection)
- Formula count pass/fail
- `all` subcommand with full consistent set
- Always exits 0 regardless of failures

### Phase 4: Codify plan intake checklist — `plugins/yf/skills/plan_intake/SKILL.md`

Insert new **Step 1.5: Specification Integrity Gate** between Step 1 (plan file exists) and Step 2 (ensure beads). Six-part checklist: contradiction check, new capability check, test-spec alignment, test deprecation, chronicle changes, structural consistency. All spec changes require explicit operator approval.

### Phase 5: Codify plan completion checklist — `plugins/yf/skills/plan_execute/SKILL.md`

Replace current Step 2-3.5 block with structured completion checklist: diary generation, archive processing, structural staleness check (Step 3.25), spec self-reconciliation (Step 3.5), deprecated artifact pruning (Step 3.75).

### Phase 6: Update rules — `plugins/yf/rules/yf-rules.md`

- New Rule 1.4: Specifications Are Anchor Documents (hard enforcement)
- Section 2.1: Insert step 1.5 for spec integrity gate before reconciliation
- Section 2.4: Expand spec status and add deprecated artifacts to completion report

### Phase 7: Update specifications

- PRD.md: REQ-033, FS-038, FS-039
- EDD/CORE.md: DD-014
- IG/engineer.md: UC-033, UC-034
- test-coverage.md: New rows + updated totals
- TODO.md: TODO-026

### Phase 8: Version bump

- `plugins/yf/.claude-plugin/plugin.json` → 2.20.0
- `CHANGELOG.md` → v2.20.0 entry

## Files Modified

| File | Change |
|------|--------|
| `plugins/yf/scripts/spec-sanity-check.sh` | **New** — mechanical consistency script |
| `plugins/yf/scripts/yf-config.sh` | Add `yf_sanity_check_mode()` |
| `tests/scenarios/unit-spec-sanity.yaml` | **New** — test scenarios for mechanical checks |
| `plugins/yf/skills/plan_intake/SKILL.md` | Add Step 1.5 (6-part integrity gate) |
| `plugins/yf/skills/plan_execute/SKILL.md` | Add Steps 3.25, 3.5, 3.75 (completion checklist) |
| `plugins/yf/rules/yf-rules.md` | Rule 1.4 + Sections 2.1, 2.4 updates |
| `docs/specifications/PRD.md` | REQ-033, FS-038, FS-039 |
| `docs/specifications/EDD/CORE.md` | DD-014 |
| `docs/specifications/IG/engineer.md` | UC-033, UC-034 |
| `docs/specifications/test-coverage.md` | New rows + updated totals |
| `docs/specifications/TODO.md` | TODO-026 |
| `plugins/yf/.claude-plugin/plugin.json` | Version 2.20.0 |
| `CHANGELOG.md` | v2.20.0 entry |

## Completion Criteria

- [ ] `spec-sanity-check.sh all` passes against real specs (6/6 checks)
- [ ] `bash tests/run-tests.sh --unit-only` passes (all existing + new tests)
- [ ] `plan_intake/SKILL.md` Step 1.5 encodes full 6-part intake checklist with operator approval gates
- [ ] `plan_execute/SKILL.md` encodes completion checklist: diary, staleness, self-reconciliation, deprecated artifact verification
- [ ] `yf-rules.md` Rule 1.4 establishes "Specifications Are Anchor Documents" as hard enforcement
- [ ] `yf-rules.md` Section 2.1 references intake integrity gate (Rule 1.4); Section 2.4 includes spec status and deprecated artifacts
- [ ] DD-014 establishes "specs as anchor documents" as a design decision
- [ ] All new spec entries (REQ-033, DD-014, UC-033, UC-034, FS-038, FS-039) present and traced in test-coverage.md
- [ ] Version bumped to 2.20.0 with CHANGELOG entry
