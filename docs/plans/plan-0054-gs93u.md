# Plan: Operator Attribution and Narrative Diary Style

**Status: Completed**

## Context

The yf plugin tracks *what* was done and *when*, but not *who directed it*. Diary entries, plan indexes, and archive records lack operator attribution. Additionally, diary entries read as factual changelogs rather than human-friendly narratives — they list what happened without connecting to the arc of the project. This plan adds operator identity throughout the lifecycle and rewrites the diary agent's voice to tell stories, not list facts. Three restyled diary entries demonstrate the new voice for approval.

## Changes

### 1. Operator resolution function in `yf-config.sh`

**File**: `plugins/yf/scripts/yf-config.sh` (after `yf_tracker_tool()` at line 173)

Add `yf_operator_name()` with fallback cascade:
1. `.yoshiko-flow/config.json` → `.config.operator`
2. `plugin.json` → `.author.name` (via `CLAUDE_PLUGIN_ROOT` or `SCRIPT_DIR`)
3. `git config user.name`
4. `"Unknown"`

This is the single source of truth — all other files call this function or follow the same cascade.

### 2. Seed operator in config during setup

**File**: `plugins/yf/skills/plugin_setup/SKILL.md`

- On new config creation (line 45): auto-detect operator from `git config user.name` → `plugin.json .author.name`, write into `config.operator`
- On existing config update (line 42-43): inject operator only if `.config.operator` is not already set
- Preserves zero-question setup — no prompting

### 3. Add operator to this project's config

**File**: `.yoshiko-flow/config.json`

```json
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs",
    "operator": "James Dixson"
  }
}
```

### 4. Operator in plan lifecycle

**File**: `plugins/yf/hooks/exit-plan-gate.sh`

- After sourcing `yf-id.sh` (line 41): resolve `OPERATOR=$(yf_operator_name)`
- `_index.md` header template (line 59-64): add `Operator` column between Date and Status
- `printf` for new entries (line 69-70): include `$OPERATOR`
- Gate JSON (line 75-76): add `"operator":"$OPERATOR"`

**File**: `docs/plans/_index.md`

- Add `Operator` column to header
- Backfill all 55 existing rows with `James Dixson`

### 5. Operator in archive templates

**File**: `plugins/yf/skills/archive_capture/SKILL.md`

- Add "Operator Resolution" subsection before the templates explaining the cascade
- Add `Operator: [resolved name]` field to both research and decision bead body templates (after `Status:` line)

**File**: `plugins/yf/agents/yf_archive_process.md`

- Add `Operator` to research SUMMARY.md section list (line 55)
- Add `Operator` to decision SUMMARY.md section list (line 66)

### 6. Narrative diary style + operator field

**File**: `plugins/yf/agents/yf_chronicle_diary.md`

- Step 4 sections list (line 48): add `Operator` field, change Summary description to "narrative journal entry"
- Add operator resolution instructions (same cascade)
- Replace Writing Guidelines (lines 62-63) with narrative guidance:
  - First-person plural ("we"), past tense
  - Open with context/motivation, connect to prior work, describe the arc, close with forward momentum
  - "Tell a story, not a changelog" — weave file paths and technical details into narrative
  - Mention operator by name when describing direction or decisions
  - Reference prior diary entries or plan numbers when building on past work
  - 150-400 words, substance over length
  - Include a short inline example contrasting factual vs narrative style

**File**: `plugins/yf/skills/chronicle_diary/SKILL.md`

- Diary entry format (lines 70-90): add `**Operator**: <name>` line after Date
- Update summary placeholder to say "Narrative journal entry describing the arc of work"

### 7. Restyle last 3 diary entries as samples

Rewrite the content (not filenames) of:
- `docs/diary/26-02-22.19-10.xref-gate-version-testing.md`
- `docs/diary/26-02-22.session.hybrid-idx-hash-ids.md`
- `docs/diary/26-02-22.17-22.worktree-hooks-v2-29.md`

Each gets the `**Operator**: James Dixson` field and a narrative rewrite of the Summary section. Decisions and Next Steps stay as-is (they're already good). The narrative style:
- Opens with what motivated the work
- Connects to prior versions/plans that led here
- Tells the story of what happened, not just what changed
- Names the operator when describing direction

### 8. Tests

**File**: `tests/scenarios/unit-exit-plan-gate.yaml`
- Existing gate JSON test: add assertion for `operator` key
- New case: verify `_index.md` header includes `Operator` column

**File**: `tests/scenarios/unit-yf-config.yaml` (new cases or new file)
- `yf_operator_name` returns config value when set
- `yf_operator_name` falls back to non-empty value when config field missing

## Critical Files

| File | Action |
|------|--------|
| `plugins/yf/scripts/yf-config.sh` | Edit (add `yf_operator_name()`) |
| `plugins/yf/skills/plugin_setup/SKILL.md` | Edit (seed operator) |
| `.yoshiko-flow/config.json` | Edit (add operator) |
| `plugins/yf/hooks/exit-plan-gate.sh` | Edit (operator in gate/index) |
| `docs/plans/_index.md` | Edit (add column, backfill rows) |
| `plugins/yf/skills/archive_capture/SKILL.md` | Edit (operator in templates) |
| `plugins/yf/agents/yf_archive_process.md` | Edit (operator in output) |
| `plugins/yf/agents/yf_chronicle_diary.md` | Edit (narrative guidelines + operator) |
| `plugins/yf/skills/chronicle_diary/SKILL.md` | Edit (operator in format) |
| `docs/diary/26-02-22.19-10.xref-gate-version-testing.md` | Edit (narrative restyle) |
| `docs/diary/26-02-22.session.hybrid-idx-hash-ids.md` | Edit (narrative restyle) |
| `docs/diary/26-02-22.17-22.worktree-hooks-v2-29.md` | Edit (narrative restyle) |
| `tests/scenarios/unit-exit-plan-gate.yaml` | Edit (operator assertions) |

## Verification

1. `bash tests/run-tests.sh --unit-only --changed` — new/modified test scenarios pass
2. Verify `.yoshiko-flow/config.json` has `operator` field
3. Review the 3 restyled diary entries for narrative voice and operator attribution
4. Verify `_index.md` header and a sample row include the Operator column
5. `bash tests/run-tests.sh --unit-only` — full suite passes
