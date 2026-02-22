# Plan: Hybrid `idx-hash` ID Generation

## Context

All yf-generated identifiers (plans, specifications, TODOs, decisions) currently use pure 5-char base36 hashes (`PREFIX-xxxxx`). These are collision-safe but lack human-readable ordering. The hybrid format `PREFIX-NN-xxxxx` adds a sequential index while preserving the hash for parallel safety — if two people create `REQ-05` simultaneously, the hashes differ so entries don't collide on merge.

Plans additionally get an `_index.md` registry tracking creation order.

## Changes

### 1. Update `yf_generate_id` in `plugins/yf/scripts/yf-id.sh`

Add optional second argument `scope` (file or directory path). When provided, count existing IDs to determine the next sequential index and produce `PREFIX-NN-xxxxx`. Without scope, produce legacy `PREFIX-xxxxx` for backward compatibility.

New helper `_yf_next_idx`:
- **Directory scope** (plans): count `plan-*.md` files (exclude part files)
- **File scope** (specs): count occurrences of `PREFIX-` pattern in the file
- **Directory scope** (IG UCs): count across all `.md` files in the directory
- Zero-padded 2 digits (`%02d`), auto-expands past 99

### 2. Update plan ID generation in `plugins/yf/hooks/exit-plan-gate.sh`

- Pass `$PLANS_DIR` as scope: `yf_generate_id "plan" "$PLANS_DIR"`
- `PLAN_ID` becomes `NN-xxxxx` (e.g., `54-8izyz`) instead of `xxxxx`
- After copying plan file, append entry to `docs/plans/_index.md` (create if missing)
- Plan file naming: `plan-54-8izyz.md` (was `plan-8izyz.md`)

`_index.md` format:
```markdown
# Plan Index

| Idx | ID | Title | Date | Status |
|-----|-----|-------|------|--------|
| 54 | plan-54-8izyz | Hybrid ID generation | 2026-02-22 | Active |
```

### 3. Fix plan-idx extraction sed in 3 hooks/scripts

The current pattern `sed -n 's/^plan-\([a-z0-9]*\).*/\1/p'` stops at the hyphen between idx and hash. Replace with `basename "$f" .md | sed 's/^plan-//'` in:

- `plugins/yf/hooks/code-gate.sh` (lines 97, 134)
- `plugins/yf/hooks/bd-safety-net.sh` (line 58)
- `plugins/yf/scripts/session-recall.sh` (line 70)

### 4. Update TODO ID generation in `plugins/yf/scripts/tracker-api.sh`

Simplify `_next_todo_id()` to pass scope:
```bash
id=$(yf_generate_id "TODO" "$TODO_FILE")
```
Remove the manual collision-check loop (hash ensures uniqueness).

### 5. Update spec ID uniqueness regex in `plugins/yf/scripts/spec-sanity-check.sh`

The uniqueness check patterns (`REQ-[a-z0-9]+`, etc.) stop at the hyphen in `REQ-01-k4m9q`, extracting only `REQ-01`. Change to include hyphens: `REQ-[a-z0-9-]+` (and same for DD, NFR, UC).

Lines to update: 192, 206, 220, 237. Count-check patterns (lines 117-166) already work since `REQ-[0-9]+` matches the leading digits in `REQ-01-k4m9q`.

### 6. Update engineer_update skill instructions

`plugins/yf/skills/engineer_update/SKILL.md` — Step 2 (line 62-65): update ID format examples to `REQ-NN-xxxxx`. Step 3 (line 73): pass scope file to `yf_generate_id`:
- PRD: `yf_generate_id "REQ" "$SPEC_DIR/PRD.md"`
- EDD: `yf_generate_id "DD" "$SPEC_DIR/EDD/CORE.md"` (or subsystem)
- IG: `yf_generate_id "UC" "$SPEC_DIR/IG/"` (directory scope)
- TODO: `yf_generate_id "TODO" "$SPEC_DIR/TODO.md"`

### 7. Update synthesizer agent instructions

`plugins/yf/agents/yf_engineer_synthesizer.md` — Lines 67-76: update generation guidelines to pass scope paths, update example output to show `REQ-01-xxxxx` format.

### 8. Update archive_capture DEC ID generation

`plugins/yf/skills/archive_capture/SKILL.md` — Lines 91-100: pass scope:
```bash
DEC_ID=$(yf_generate_id "DEC" "docs/decisions/_index.md")
```
Remove the manual collision-check while loop.

### 9. Update tests

**`tests/scenarios/unit-yf-id.yaml`** (new) — Test core library:
- Without scope: produces `PREFIX-xxxxx`
- With file scope: produces `PREFIX-NN-xxxxx`
- With directory scope: produces `plan-NN-xxxxx`
- Empty scope: idx starts at 01
- Counts correctly with existing IDs in file

**`tests/scenarios/unit-exit-plan-gate.yaml`** — Update Case 4 to verify `plan-NN-xxxxx.md` naming and `_index.md` creation.

**`tests/scenarios/unit-tracker-api.yaml`** — Line 51: change regex from `TODO-[a-z0-9]{5}` to `TODO-[0-9]+-[a-z0-9]{5}`.

**`tests/scenarios/unit-spec-sanity.yaml`** — Verify existing tests pass with updated regex (old-format IDs like `REQ-001` still match).

### 10. Version bump + documentation

- `plugins/yf/.claude-plugin/plugin.json`: version → 2.30.0, add "hybrid idx-hash IDs" to description
- `CLAUDE.md`: version reference
- `CHANGELOG.md`: v2.30.0 entry
- `plugins/yf/README.md`: update Worktree Isolation → Hash-Based IDs paragraph to describe hybrid format

## Critical Files

| File | Action |
|------|--------|
| `plugins/yf/scripts/yf-id.sh` | Edit (add `_yf_next_idx`, scope parameter) |
| `plugins/yf/hooks/exit-plan-gate.sh` | Edit (scope, `_index.md` creation) |
| `plugins/yf/hooks/code-gate.sh` | Edit (sed pattern, 2 locations) |
| `plugins/yf/hooks/bd-safety-net.sh` | Edit (sed pattern) |
| `plugins/yf/scripts/session-recall.sh` | Edit (sed pattern) |
| `plugins/yf/scripts/tracker-api.sh` | Edit (`_next_todo_id` simplification) |
| `plugins/yf/scripts/spec-sanity-check.sh` | Edit (uniqueness regex) |
| `plugins/yf/skills/engineer_update/SKILL.md` | Edit (scope instructions) |
| `plugins/yf/agents/yf_engineer_synthesizer.md` | Edit (scope instructions) |
| `plugins/yf/skills/archive_capture/SKILL.md` | Edit (DEC scope) |
| `tests/scenarios/unit-yf-id.yaml` | Create |
| `tests/scenarios/unit-exit-plan-gate.yaml` | Edit |
| `tests/scenarios/unit-tracker-api.yaml` | Edit |
| `plugins/yf/.claude-plugin/plugin.json` | Edit (version + description) |
| `CLAUDE.md` | Edit (version) |
| `CHANGELOG.md` | Edit (new entry) |
| `plugins/yf/README.md` | Edit (ID format docs) |

## Backward Compatibility

- Old IDs (`REQ-001`, `REQ-k4m9q`, `plan-8izyz`) remain valid everywhere
- Updated regex patterns match all three formats: sequential (`REQ-001`), hash-only (`REQ-k4m9q`), hybrid (`REQ-01-k4m9q`)
- `plan:<idx>` labels are derived from filenames — `plan:54-8izyz` works identically to `plan:8izyz` in all label consumers
- `_index.md` starts fresh from next plan; no retroactive backfill of plans 01-51

## Edge Cases

- **Parallel idx collision**: Two agents both see 53 REQs, both mint `REQ-54-xxx`. Hashes differ, both survive merge. Duplicate idx is cosmetic, full IDs are unique.
- **Part files**: `plan-54-8izyz-part1-api.md` — `_yf_next_idx` excludes part files when counting plans.
- **Empty scope**: If spec file doesn't exist yet, `_yf_next_idx` returns `01`.

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass including new `unit-yf-id.yaml`
2. Verify `yf_generate_id "REQ"` (no scope) still produces `REQ-xxxxx` (backward compat)
3. Verify `yf_generate_id "REQ" /path/to/PRD.md` produces `REQ-NN-xxxxx`
4. Verify `exit-plan-gate.sh` creates `plan-NN-xxxxx.md` and appends to `_index.md`
5. Verify `spec-sanity-check.sh` passes with both old and new ID formats
