# Plan 22: Automatic Session Boundary Hooks for Chronicler

**Status:** Completed
**Date:** 2026-02-09

## Overview

Cairn-MCP review revealed a reliability gap in the chronicler: session boundaries are manual. The agent must remember to run `/yf:chronicle_recall` at session start and "land the plane" at session end. If it forgets — or the user closes the terminal — chronicle context is orphaned.

This plan adds automatic context recovery at session start and automatic draft preservation at session end, using three new hooks. Phase 3 (PostToolUse ambient logging) is deferred to a bead.

**Phase 1 — SessionStart auto-recall**: New hook outputs open chronicle summaries to stdout on session start. Since SessionStart stdout is injected into the agent's context, the agent starts every session with recovered context — no manual `/yf:chronicle_recall` needed.

**Phase 2 — SessionEnd auto-draft + pending-diary marker**: New hooks on `SessionEnd` and `PreCompact` run `chronicle-check.sh` to capture significant work as draft beads, then write a `.beads/.pending-diary` marker if open chronicles exist. The Phase 1 SessionStart hook detects this marker and surfaces an urgent "deferred diary" notice on next session start.

## Implementation Sequence

### Phase 1: SessionStart Auto-Recall

**New script**: `plugins/yf/scripts/session-recall.sh`

1. Source yf-config.sh
2. Guard: exit 0 if yf disabled OR chronicler disabled OR bd missing
3. Query: bd list --label=ys:chronicle --status=open --format=json
4. If no results: exit 0 (silent)
5. Check for .beads/.pending-diary marker
   - If found: output "DEFERRED DIARY" header (from previous session)
   - Delete the marker
6. Format and output to stdout:
   - "CHRONICLER: N open chronicle(s) detected"
   - List each bead: ID, title, age
   - If pending-diary was found: "Run /yf:chronicle_diary to process pending entries"
   - Otherwise: "Run /yf:chronicle_recall for full context recovery"
7. Exit 0

**Hook registration**: Add to `plugin.json` SessionStart hooks array (after preflight-wrapper.sh).

### Phase 2: SessionEnd + PreCompact Auto-Draft

**New hook**: `plugins/yf/hooks/session-end.sh`

1. Source yf-config.sh
2. Guard: exit 0 if yf disabled OR chronicler disabled OR bd/jq missing
3. Run: chronicle-check.sh check (creates draft beads from git activity)
4. Query: bd list --label=ys:chronicle --status=open --format=json
5. Count open chronicles
6. If count > 0: Write .beads/.pending-diary marker (JSON: timestamp, count, reason)
7. Exit 0 (always non-blocking)

**New hook**: `plugins/yf/hooks/pre-compact.sh`

1. Source yf-config.sh
2. Guard: exit 0 if yf disabled OR chronicler disabled OR bd missing
3. Run: chronicle-check.sh check (capture work before context erased)
4. Exit 0 (always non-blocking)

**Hook registration** in `plugin.json`: SessionEnd and PreCompact event arrays.

**Pending-diary marker format** (`.beads/.pending-diary`):

```json
{
  "created": "2026-02-09T14:30:00Z",
  "reason": "session_end",
  "chronicle_count": 3,
  "draft_created": true
}
```

Consumed and deleted by `session-recall.sh` on next SessionStart.

### Phase 3 (Deferred)

PostToolUse ambient session log — create bead to track as future feature.

## Completion Criteria

- [ ] `session-recall.sh` outputs chronicle summary on SessionStart when open chronicles exist
- [ ] `session-recall.sh` detects and consumes `.beads/.pending-diary` marker
- [ ] `session-recall.sh` is silent when no chronicles and no marker
- [ ] `session-end.sh` creates draft beads via chronicle-check.sh
- [ ] `session-end.sh` writes pending-diary marker when open chronicles exist
- [ ] `pre-compact.sh` creates draft beads via chronicle-check.sh
- [ ] All three hooks are fail-open (exit 0 always)
- [ ] All three hooks respect yf enabled + chronicler enabled guards
- [ ] plugin.json registers all hooks correctly
- [ ] Unit tests pass for all three scripts
- [ ] `bash tests/run-tests.sh --unit-only` passes
- [ ] README and DEVELOPERS.md updated
- [ ] CHANGELOG updated with v2.9.0
