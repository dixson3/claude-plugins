# Plan 38: Rule consolidation, migration pruning, and plan-intake enforcement

**Status:** Completed
**Date:** 2026-02-14

## Context

GitHub issue #11: The agent bypasses `plan-intake` when the user says "Implement the following plan." Root cause analysis reveals two compounding factors:

1. **Rule dilution** — 24 separate rule files all loaded unconditionally compete for agent attention. The critical `plan-intake` rule is one voice among 23 others.
2. **No hook enforcement** — `code-gate.sh` has an advisory-only check for "plan exists but no beads" that exits 0 and fires once per session. The agent can ignore it.

The original plugin design used small, focused rule files for role-based conditional loading. That design is obsolete — all features (chronicler, archivist, engineer, swarm) are always-on. The fragmentation now hurts more than it helps.

## Overview

Three coordinated changes:

1. **Consolidate 24 rule files into 1** with clear event-driven checklists
2. **Prune all migration/upgrade logic** from `plugin-preflight.sh` (no backward compat needed)
3. **Consolidate duplicate scripts** (`pump-state.sh` + `swarm-state.sh` into `dispatch-state.sh`)
4. **Upgrade `code-gate.sh`** beads-safety-net from advisory to blocking (issue #11 fix)

## Implementation Sequence

### Phase 1: Consolidate rules (24 into 1)

**Create:** `plugins/yf/rules/yf-rules.md`
**Delete:** All 24 existing rule files in `plugins/yf/rules/`
**Update:** `plugins/yf/.claude-plugin/preflight.json` — replace 24 rule entries with 1

Structure of the consolidated file (priority order, top-to-bottom):

```
# Yoshiko Flow — Agent Rules

## 1. HARD ENFORCEMENT
  1.1 Beads Are the Source of Truth
      (from: beads-drive-tasks.md, plan-to-beads.md)
  1.2 Plan Intake: No Implementation Without Lifecycle
      (from: plan-intake.md) — CRITICAL, with self-check protocol
  1.3 Formula-Labeled Beads Route Through Swarm
      (from: swarm-formula-dispatch.md)

## 2. PLAN LIFECYCLE
  2.1 Auto-Chain After ExitPlanMode
      (from: auto-chain-plan.md, plan-transition-chronicle.md,
       plan-transition-archive.md, engineer-reconcile-on-plan.md)
  2.2 Plan Lifecycle Phrase Triggers
      (from: engage-the-plan.md)
  2.3 Breakdown Before Building
      (from: breakdown-the-work.md)
  2.4 Plan Completion Report
      (from: plan-completion-report.md, engineer-suggest-on-completion.md)

## 3. SWARM EXECUTION
  3.1 Comment Protocol (FINDINGS/CHANGES/REVIEW/TESTS)
      (from: swarm-comment-protocol.md — compressed, full templates in skill)
  3.2 Nesting Depth Limit (max 2)
      (from: swarm-nesting.md — one-liner, detail in skill)
  3.3 Reactive Bugfix
      (from: swarm-reactive.md — delegation to /yf:swarm_react)

## 4. SESSION PROTOCOL
  4.1 Beads Quick Reference + Landing the Plane
      (from: beads.md)

## 5. ADVISORY MONITORING (lowest priority)
  5.1 Swarm Completion Bridges
      (from: swarm-archive-bridge.md, swarm-chronicle-bridge.md, swarm-spec-bridge.md)
  5.2 Research Spike During Planning
      (from: swarm-planning-research.md)
  5.3 Chronicle Worthiness
      (from: watch-for-chronicle-worthiness.md)
  5.4 Archive Worthiness
      (from: watch-for-archive-worthiness.md)
  5.5 Specification Drift
      (from: watch-for-spec-drift.md)
```

**Dropped entirely** (content already lives in skills):
- `swarm-formula-select.md` — self-describes as "informational, logic in skill"

**Compression techniques:**
- Remove all "When This Does NOT Fire" / "Non-Triggers" sections (~15 files have them)
- Remove all "Why" persuasion paragraphs (agents need rules, not reasons)
- Remove "Example Suggestions" blocks from advisory rules
- Remove cross-references between rules (single-file, no longer needed)
- Compress format templates to protocol names + verdict requirements (full templates stay in swarm_dispatch skill)
- Remove duplicate spec-check boilerplate (one check, referenced by all spec-aware sections)

**Estimated size:** ~300 lines (down from ~1400 across 24 files)

**Stale symlink cleanup:** Preflight already handles this (lines 437-452 of `plugin-preflight.sh`). When `preflight.json` changes from 24 entries to 1, the next run auto-removes the 23 old symlinks from `.claude/rules/yf/`. No migration code needed.

### Phase 2: Upgrade code-gate.sh (issue #11 fix)

**File:** `plugins/yf/hooks/code-gate.sh`

Change the beads-safety-net (lines 63-83) from advisory to blocking:

- Remove the `plan-intake-ok` marker guard — check on every Edit/Write
- When a non-completed plan file exists with no beads: output blocking JSON `{"decision":"block","reason":"..."}` and exit 2
- Add a 60-second TTL cache (`.yoshiko-flow/.beads-check-cache`) to avoid `bd list` on every edit
- Add escape hatch: if `.yoshiko-flow/plan-intake-skip` exists, bypass the block
- Keep the same exempt file patterns as the plan-gate block (docs/plans/*, .claude/*, etc.)
- Remove the `plan-intake-ok` marker file logic entirely (no longer needed)
- Keep the `plan-chronicle-ok` advisory check as-is

### Phase 3: Prune migration logic from plugin-preflight.sh

**File:** `plugins/yf/scripts/plugin-preflight.sh`

Remove these migration blocks (no backward compat needed):

1. **`yf.json` to `config.json` rename** (lines 55-62, ~7 lines)
2. **`.claude/` to `.yoshiko-flow/` migration** (lines 74-100, ~27 lines)
3. **`chronicler_enabled`/`archivist_enabled` field pruning** (lines 131-144, ~14 lines)
4. **Beads git workflow migration** (lines 335-375, ~38 lines)
5. **Legacy flat `yf-*.md` rule cleanup** (lines 454-460, ~7 lines)

Total: ~93 lines removed.

Also inline `install-beads-push-hook.sh` (77 lines, single caller) into `plugin-preflight.sh` as a function, then delete the standalone script.

### Phase 4: Consolidate dispatch state scripts

**Merge:** `plugins/yf/scripts/pump-state.sh` + `plugins/yf/scripts/swarm-state.sh`
**Into:** `plugins/yf/scripts/dispatch-state.sh`

Interface: `dispatch-state.sh <store> <command> [args]`
- `<store>` is `pump` or `swarm` (determines JSON file path)
- `<command>` is `is-dispatched`, `mark-dispatched`, `mark-done`, `mark-retrying`, `pending`, `clear`
- `mark-retrying` and `clear --scope` only apply to swarm store (no-op for pump)

**Update callers:**
- `skills/plan_execute/SKILL.md` — `pump-state.sh` to `dispatch-state.sh pump`
- `skills/plan_pump/SKILL.md` — `pump-state.sh` to `dispatch-state.sh pump`
- `skills/swarm_dispatch/SKILL.md` — `swarm-state.sh` to `dispatch-state.sh swarm`
- `skills/swarm_run/SKILL.md` — `swarm-state.sh` to `dispatch-state.sh swarm`
- `skills/swarm_react/SKILL.md` — `swarm-state.sh` to `dispatch-state.sh swarm`
- `skills/swarm_status/SKILL.md` — `swarm-state.sh` to `dispatch-state.sh swarm`

**Delete:** `pump-state.sh`, `swarm-state.sh`

### Phase 5: Prune setup-project.sh cleanup_agents

**File:** `plugins/yf/scripts/setup-project.sh`

Remove the `cleanup_agents` function and its call. This is migration/cleanup logic that removes `bd init`/`bd onboard` generated boilerplate from `AGENTS.md`. Keep only the `setup_gitignore` function.

### Phase 6: Update tests

**Delete:** `tests/scenarios/unit-migration.yaml` — tests migration paths we're removing

**Update:** `tests/scenarios/unit-code-gate-intake.yaml`:
- Case 3: change expected exit code from 0 to 2 (now blocks, not warns)
- Case 3: change expected output from "WARNING" to "BLOCKED" / `{"decision":"block"}`
- Case 5: remove (marker file no longer exists)
- Add: escape hatch test (plan-intake-skip bypasses block)
- Add: cache TTL test (second check within 60s doesn't re-query bd)
- Add: exempt file test (docs/plans/* allowed even when blocking)

**Update:** `tests/scenarios/unit-preflight-symlinks.yaml`:
- Update Case 4/5 assertions for single rule file name (`yf-rules.md` instead of `beads.md`)

**Update:** `tests/scenarios/unit-pump-state.yaml` to rename to `unit-dispatch-state.yaml`, update script path references

**Update:** `tests/scenarios/unit-swarm-state.yaml` to merge into `unit-dispatch-state.yaml`

**Run:** `bash tests/run-tests.sh --unit-only` — all tests must pass

### Phase 7: Version bump and changelog

- Bump to `2.19.0` in `plugins/yf/.claude-plugin/plugin.json`
- Add CHANGELOG.md entry covering all changes

## Critical Files

| File | Action |
|------|--------|
| `plugins/yf/rules/yf-rules.md` | CREATE — consolidated rule file |
| `plugins/yf/rules/*.md` (24 files) | DELETE |
| `plugins/yf/.claude-plugin/preflight.json` | UPDATE — 24 entries to 1 |
| `plugins/yf/hooks/code-gate.sh` | UPDATE — advisory to blocking |
| `plugins/yf/scripts/plugin-preflight.sh` | UPDATE — prune migrations, inline beads push hook |
| `plugins/yf/scripts/dispatch-state.sh` | CREATE — merged pump+swarm state |
| `plugins/yf/scripts/pump-state.sh` | DELETE |
| `plugins/yf/scripts/swarm-state.sh` | DELETE |
| `plugins/yf/scripts/install-beads-push-hook.sh` | DELETE (inlined) |
| `plugins/yf/scripts/setup-project.sh` | UPDATE — remove cleanup_agents |
| `plugins/yf/.claude-plugin/plugin.json` | UPDATE — version bump |
| `CHANGELOG.md` | UPDATE |
| 6 skill SKILL.md files | UPDATE — dispatch-state.sh caller refs |
| `tests/scenarios/unit-migration.yaml` | DELETE |
| `tests/scenarios/unit-code-gate-intake.yaml` | UPDATE |
| `tests/scenarios/unit-preflight-symlinks.yaml` | UPDATE |
| `tests/scenarios/unit-pump-state.yaml` | RENAME+UPDATE to unit-dispatch-state.yaml |
| `tests/scenarios/unit-swarm-state.yaml` | DELETE (merged) |

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass
2. `claude --plugin-dir ./plugins/yf` — plugin loads, single rule symlink created in `.claude/rules/yf/`
3. Manual: create a plan file in `docs/plans/` without beads, attempt Edit — should be BLOCKED
4. Manual: create `.yoshiko-flow/plan-intake-skip` — Edit should be allowed
5. Verify old symlinks are cleaned up by preflight on first run after upgrade

## Completion Criteria

- [ ] 24 rule files consolidated into 1 (`yf-rules.md`) at ~300 lines
- [ ] `code-gate.sh` blocks Edit/Write when plan file exists with no beads
- [ ] Escape hatch (plan-intake-skip) bypasses the block
- [ ] 60-second cache prevents repeated `bd list` queries on every edit
- [ ] Exempt files still pass through when blocked
- [ ] ~93 lines of migration logic removed from plugin-preflight.sh
- [ ] `install-beads-push-hook.sh` inlined and deleted
- [ ] `pump-state.sh` + `swarm-state.sh` merged into `dispatch-state.sh`
- [ ] All 6 skill callers updated
- [ ] `setup-project.sh` cleanup_agents removed
- [ ] All tests pass (`bash tests/run-tests.sh --unit-only`)
- [ ] Version bumped to 2.19.0
- [ ] CHANGELOG.md updated
