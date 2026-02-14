# Plan 31: Harden Lifecycle Rule Enforcement

**Status:** Completed
**Date:** 2026-02-13

## Context

During the beads database pruning (Plan 30), two lifecycle rules were violated:

1. **plan-intake rule skipped** — The agent received "Implement the following plan:" with structured plan content but chose not to invoke `/yf:plan_intake`, overriding the behavioral rule with a judgment call ("creating beads to track bead deletion is circular").
2. **chronicle not captured** — Significant work (278 bead deletions) completed without a chronicle suggestion or capture.

**Root cause:** Both rules are purely behavioral — the agent reads markdown and decides whether to follow them. There is no hook-backed enforcement. The agent's judgment call overrode the rule without any safety net catching it.

**The gap:** The code-gate.sh hook (which has beads safety nets) only fires on Edit/Write tool calls. The pruning plan was executed entirely through Bash (`bd` commands), so code-gate.sh never fired.

## Overview

Add hook-backed enforcement to catch the two failure modes:
1. Destructive `bd` operations without plan lifecycle
2. Significant `bd` operations without chronicle capture

Plus harden the behavioral rules to be explicit about no-exception policies.

## Implementation Sequence

### 1. Add PreToolUse hook on `Bash(bd delete*)`

**File:** `plugins/yf/hooks/bd-safety-net.sh` (new)

A lightweight hook that fires before any `bd delete` command. Checks:
- If a plan file exists in `docs/plans/` that is not Status: Completed and has no beads → warn about missing plan-intake
- If no open chronicle exists and the delete targets >5 beads → warn about missing chronicle

Non-blocking (exit 0 always) — mirrors the advisory pattern of code-gate.sh's safety nets. Outputs warnings that the agent sees before proceeding.

### 2. Register the hook in plugin.json

**File:** `plugins/yf/.claude-plugin/plugin.json`

Add a new PreToolUse entry:
```json
{
  "matcher": "Bash(bd delete*)",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/bd-safety-net.sh"
    }
  ]
}
```

### 3. Harden plan-intake.md rule

**File:** `plugins/yf/rules/plan-intake.md`

Add explicit no-exception language:

> **No Exceptions:** This rule has NO override for agent judgment. Even if the plan content appears to conflict with the beads system (e.g., pruning beads, modifying the orchestration layer), the lifecycle still applies. The plan-intake skill handles plans of any type — operational, infrastructure, code, or meta-system changes. If in doubt, run plan-intake; it is idempotent and safe to re-run.

### 4. Harden watch-for-chronicle-worthiness.md rule

**File:** `plugins/yf/rules/watch-for-chronicle-worthiness.md`

Add database/infrastructure operations to the capture triggers:

> **6. Database or Infrastructure Operations**
>    - Bulk bead deletions or modifications
>    - Database migrations or schema changes
>    - Configuration changes affecting system behavior

### 5. Enhance session-recall.sh to check plan state

**File:** `plugins/yf/scripts/session-recall.sh`

Add a check: if the latest plan file in `docs/plans/` is not completed AND has no beads, output a warning at session start. This catches the case where a previous session created a plan file but never ran intake.

### 6. Add preflight declaration for new hook

**File:** `plugins/yf/.claude-plugin/preflight.json`

Add `bd-safety-net.sh` to the hooks section.

### 7. Add tests

**File:** `tests/scenarios/unit-bd-safety-net.yaml`

Test scenarios:
- Hook exits 0 when no plan files exist
- Hook warns when plan exists without beads and delete targets >5 beads
- Hook silent when plan is completed
- Hook warns about missing chronicle on bulk delete
- Hook always exits 0 (non-blocking)

### 8. Version bump to 2.14.1

**Files:** `plugins/yf/.claude-plugin/plugin.json`, `CHANGELOG.md`

Patch version bump for the enforcement hardening.

## Critical Files

- `plugins/yf/hooks/bd-safety-net.sh` — new hook (create)
- `plugins/yf/hooks/code-gate.sh` — reference for safety net pattern (read only)
- `plugins/yf/.claude-plugin/plugin.json` — register new hook
- `plugins/yf/.claude-plugin/preflight.json` — declare new artifact
- `plugins/yf/rules/plan-intake.md` — harden language
- `plugins/yf/rules/watch-for-chronicle-worthiness.md` — add infra triggers
- `plugins/yf/scripts/session-recall.sh` — add plan state check
- `tests/scenarios/unit-bd-safety-net.yaml` — new tests

## Completion Criteria

- [ ] `bd delete` with >5 targets and no plan lifecycle → warning output
- [ ] `bd delete` with >5 targets and no chronicle → warning output
- [ ] plan-intake.md has explicit no-exception language
- [ ] watch-for-chronicle-worthiness.md has infrastructure triggers
- [ ] session-recall.sh warns about plans without beads
- [ ] All existing + new tests pass
- [ ] Plugin version bumped to 2.14.1

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass
2. Manual test: create a plan file, attempt `bd delete` without intake → verify warning appears
3. `bd sync` clean
