# Plan: Land-the-Plane Enforcement & Plan Foreshadowing

## Context

With the migration to Dolt-backed beads, `bd sync` is a no-op and has been removed from yf (Plan 45). But the landing protocol (Rule 4.2) remains a behavioral rule with no mechanical enforcement — agents can skip commits, forget to push, or start plans with uncommitted changes. The beads `bd prime` SESSION CLOSE PROTOCOL still references `bd sync`, creating confusion about which protocol to follow.

This plan adds:
- **Pre-push enforcement**: a blocking hook that ensures the working tree is clean before allowing push
- **Plan foreshadowing**: auto-classification and commit of uncommitted changes when a plan starts
- **`/yf:session_land` skill**: an orchestrator that runs the full close-out checklist including push with operator confirmation
- **Cross-session dirty-tree awareness**: markers that warn the next session about uncommitted changes

Release tagging is deferred to a future plan.

---

## 1. Create `/yf:session_land` skill

**File**: `plugins/yf/skills/session_land/SKILL.md`

Orchestrates the full session close-out sequence. Steps:

1. **Check dirty tree** — `git status --porcelain`. Report changed files.
2. **File remaining work** — `bd list --status=in_progress`. For each: ask operator to close, leave open, or create followup.
3. **Capture context** (conditional) — If significant work since last chronicle, invoke `/yf:chronicle_capture topic:session-close`.
4. **Generate diary** (conditional) — If open chronicles exist, invoke `/yf:chronicle_diary`.
5. **Quality gates** (conditional) — If code changed, run project quality checks.
6. **Memory reconciliation** (conditional) — If specs exist, invoke `/yf:memory_reconcile mode:check`.
7. **Update issue status** — Close finished beads.
8. **Session prune** — `bash plugins/yf/scripts/session-prune.sh all`.
9. **Commit** — Stage changes, present diff summary, commit with conventional message.
10. **Push with operator confirmation** — Use `AskUserQuestion`: "Push to remote?" If yes, `git push`. If no, note for next session.
11. **Hand off** — Summarize what was done, what remains, key context.

Pattern: follows `memory_reconcile/SKILL.md` structure (activation guard, stepped behavior, arguments).

---

## 2. Create `pre-push-land.sh` blocking hook

**File**: `plugins/yf/hooks/pre-push-land.sh`

PreToolUse hook on `Bash(git push*)`. **Blocking** (exit 2) when conditions aren't met.

Checks:
1. **Uncommitted changes** — `git status --porcelain`. If dirty tree, block with structured checklist output showing what files need to be committed.
2. **In-progress beads** — `bd list --status=in_progress --json`. If any in-progress beads exist, block with advisory to close or update them first.

Output format when blocking:
```
LAND-THE-PLANE: Push blocked — prerequisites not met

[ ] Uncommitted changes: N file(s)
    <file list, max 10>
    Action: Commit changes before pushing

[ ] In-progress beads: N issue(s)
    <bead list>
    Action: Close or update status before pushing

Run /yf:session_land to complete the checklist, then retry push.
```

When all conditions pass: exit 0 (allow push). The existing `pre-push-diary.sh` (advisory chronicles/archives check) fires after this hook passes.

Guards: standard `yf_is_enabled || exit 0`, `command -v bd || exit 0`, `command -v jq || exit 0`.

---

## 3. Update `plugin.json` hook declarations

**File**: `plugins/yf/.claude-plugin/plugin.json`

Replace the current single `Bash(git push*)` PreToolUse entry (lines 112-120) with two hooks in sequence:

```json
{
  "matcher": "Bash(git push*)",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-push-land.sh"
    },
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-push-diary.sh"
    }
  ]
}
```

`pre-push-land.sh` fires first (blocking). If it blocks, `pre-push-diary.sh` never fires. If it passes, `pre-push-diary.sh` runs its advisory checks.

---

## 4. Add plan foreshadowing to `plan_intake`

**File**: `plugins/yf/skills/plan_intake/SKILL.md`

Add **Step 0: Foreshadowing Check** before Step 1 (Ensure Plan File Exists):

```
### Step 0: Foreshadowing Check

Before beginning intake, check for uncommitted changes:

    git status --porcelain

If the working tree is clean, skip to Step 1.

If dirty, auto-classify each changed file:

1. Parse the plan content (from argument, inline, or most recent plan file)
   to identify the plan's target scope — file paths, directories, modules
   mentioned in the plan.
2. For each uncommitted file, check overlap with plan scope:
   - **Foreshadowing**: File path overlaps with plan targets (same directory,
     same module, same component). These are proto-plan changes.
   - **Unrelated**: File path has no overlap with plan scope.
3. Commit unrelated changes first with message:
   "Pre-plan commit: unrelated changes before plan-<idx>"
4. Commit foreshadowing changes with message:
   "Plan foreshadowing (plan-<idx>): <summary of changes>"
5. Report what was classified and committed.

Both commits happen automatically — no operator prompt needed. The
classification is logged in the commit messages for traceability.
```

---

## 5. Add dirty-tree markers for cross-session awareness

### 5a. `session-end.sh` — write marker

**File**: `plugins/yf/hooks/session-end.sh`

After the existing `.pending-diary` logic (line 62), add:

```bash
# --- Write dirty-tree marker if uncommitted changes exist ---
DIRTY_COUNT=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_COUNT" -gt 0 ]; then
  mkdir -p "$BEADS_DIR" 2>/dev/null || true
  cat > "$BEADS_DIR/.dirty-tree" <<MARKER
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "session_end",
  "dirty_count": $DIRTY_COUNT
}
MARKER
fi
```

### 5b. `session-recall.sh` — consume marker

**File**: `plugins/yf/scripts/session-recall.sh`

After the pending-diary marker check (line 47), add dirty-tree marker consumption:

```bash
# --- Check for dirty-tree marker from previous session ---
DIRTY_MARKER="$BEADS_DIR/.dirty-tree"
HAS_DIRTY=false
DIRTY_FILE_COUNT=0
if [ -f "$DIRTY_MARKER" ]; then
  HAS_DIRTY=true
  DIRTY_FILE_COUNT=$(jq -r '.dirty_count // 0' "$DIRTY_MARKER" 2>/dev/null || echo "0")
  rm -f "$DIRTY_MARKER"
fi
```

Update the "exit silently" guard and output section to include dirty-tree warnings.

---

## 6. Update Rule 4.2

**File**: `plugins/yf/rules/yf-rules.md` (lines 189-202)

Replace current text with:

```markdown
### 4.2 Landing the Plane

When ending a work session, invoke `/yf:session_land`. This skill orchestrates
the full close-out sequence with operator confirmation at key steps.

The pre-push hook (`pre-push-land.sh`) enforces clean-tree and closed-beads
prerequisites. If you attempt `git push` without completing the checklist,
the push is blocked with actionable guidance.

**Dolt-backend note:** This protocol supersedes the `bd prime` SESSION CLOSE
PROTOCOL. The `bd sync` steps in that protocol are no-ops with the Dolt backend
and should be ignored. yf manages the full git commit/push workflow.

**Checklist** (orchestrated by `/yf:session_land`):
1. File issues for remaining work
2. Capture context (if significant): `/yf:chronicle_capture topic:session-close`
3. Generate diary (if open chronicles): `/yf:chronicle_diary`
4. Run quality gates (if code changed)
5. Memory reconciliation (if specs exist): `/yf:memory_reconcile`
6. Update issue status — close finished work
7. Session prune
8. Commit code changes
9. Push (operator confirmation via AskUserQuestion)
10. Hand off context for next session
```

---

## 7. Documentation updates

### 7a. DEVELOPERS.md capability table
**File**: `plugins/yf/DEVELOPERS.md`
Add `session` capability row: `| Session | session | session_land | — |`

### 7b. README.md
**File**: `plugins/yf/README.md`
Add session close capability section following existing pattern (Why / How It Works / Artifacts / Skills).

### 7c. CHANGELOG.md
**File**: `CHANGELOG.md`
Document all changes under new version entry.

### 7d. Version bump
**File**: `plugins/yf/.claude-plugin/plugin.json`
Bump version `2.22.0` → `2.23.0`.

---

## 8. Test scenarios

### New: `tests/scenarios/unit-session-land.yaml`
- Skill file exists with correct frontmatter
- References activation guard
- References AskUserQuestion (push confirmation)
- References chronicle_capture, chronicle_diary, memory_reconcile

### New: `tests/scenarios/unit-pre-push-land.yaml`
- Exits 0 when yf disabled (standard guard)
- Exits 0 when tree is clean and no in-progress beads
- Exits 2 (blocks) when uncommitted changes exist
- Exits 2 (blocks) when in-progress beads exist
- Output contains structured checklist format
- Non-blocking when bd is not installed

### Updates to existing tests
- `unit-session-end.yaml`: dirty-tree marker written when tree dirty, not written when clean
- `unit-session-recall.yaml`: dirty-tree marker consumed and warning displayed

---

## Files changed (summary)

| Action | File |
|--------|------|
| Create | `plugins/yf/skills/session_land/SKILL.md` |
| Create | `plugins/yf/hooks/pre-push-land.sh` |
| Create | `tests/scenarios/unit-session-land.yaml` |
| Create | `tests/scenarios/unit-pre-push-land.yaml` |
| Modify | `plugins/yf/rules/yf-rules.md` |
| Modify | `plugins/yf/skills/plan_intake/SKILL.md` |
| Modify | `plugins/yf/hooks/session-end.sh` |
| Modify | `plugins/yf/scripts/session-recall.sh` |
| Modify | `plugins/yf/.claude-plugin/plugin.json` |
| Modify | `plugins/yf/DEVELOPERS.md` |
| Modify | `plugins/yf/README.md` |
| Modify | `CHANGELOG.md` |

---

## Verification

1. **Pre-push blocking**: Make a change, don't commit, run `git push` — hook should block with checklist output
2. **Pre-push pass**: Commit all changes, close in-progress beads, run `git push` — hook should allow
3. **Session land skill**: Invoke `/yf:session_land` — should orchestrate full checklist with AskUserQuestion for push
4. **Plan foreshadowing**: Start with uncommitted changes, invoke `/yf:plan_intake` — should auto-classify and commit
5. **Dirty-tree markers**: End session with dirty tree, start new session — should see warning
6. **Tests**: `bash tests/run-tests.sh --unit-only` — all scenarios pass
