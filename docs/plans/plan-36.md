# Plan 36: Fix formula-labeled tasks bypass swarm dispatch

**Status:** Completed
**Date:** 2026-02-14

## Context

In the epx project, plan tasks had `formula:` labels assigned (e.g., `formula:feature-build`, `formula:code-implement`), but during execution the pump dispatched them as bare `Task(subagent_type=...)` calls instead of routing through `/yf:swarm_run`. This bypassed multi-agent workflows (research → implement → review), structured bead comments, reactive bugfix, and chronicle capture.

The work completed correctly, but skipped all swarm guardrails.

## Root Causes

1. **plan_execute Step 3a contradicts plan_pump** — The abbreviated pump summary says "Groups remaining beads by `agent:<name>` label" with no mention of formula classification. Claude follows this simplified description during execution.

2. **Opening descriptions omit formula track** — Both plan_execute (line 15) and plan_pump (line 12) say "groups them by assigned agent", priming Claude on agent-only dispatch.

3. **Advisory language in swarm-formula-dispatch rule** — Says "should be dispatched" instead of MUST. Claude deprioritizes "should" during complex multi-task execution.

4. **No enforcement mechanism** — Nothing validates that formula-labeled tasks actually went through swarm_run.

## Fixes (6 edits across 3 files)

### File 1: `plugins/yf/skills/plan_execute/SKILL.md`

**Edit A — Opening description (line 15):**
Replace "groups them by assigned agent, and dispatches them as parallel Task tool calls" with text that names both formula and agent tracks with their dispatch methods.

**Edit B — Step 3a pump summary (lines 63-66):**
Replace the 4-item pump summary. Item 3 currently says "Groups remaining beads by `agent:<name>` label" — change to describe two-track classification (formula → swarm, agent → Task). Item 4 currently says "Returns the grouped beads for dispatch" — change to "Returns two groups: formula beads (for swarm dispatch) and agent beads (for bare Task dispatch)".

**Edit C — Insert critical callout before Step 3c (after line 76):**
Add a `> **CRITICAL: Dispatch Routing**` callout block immediately before the `#### 3c. Dispatch in Parallel` heading. States that formula-labeled beads MUST use `/yf:swarm_run` and bare Task dispatch of formula beads is a bug, listing what gets bypassed.

### File 2: `plugins/yf/skills/plan_pump/SKILL.md`

**Edit D — Opening description (line 12):**
Replace "groups them by assigned agent, and dispatches them as parallel Task tool calls" with text naming both tracks (formula via swarm, agent via Task tool).

**Edit E — Step 4 heading (line 61):**
Append `(CRITICAL — formula labels take priority)` to the heading.

### File 3: `plugins/yf/rules/swarm-formula-dispatch.md`

**Edit F — Strengthen language and add validation (line 13 + new section):**
Change "should be dispatched" to "MUST be dispatched" with explicit statement that bare dispatch is a bug. Insert a `## Validation` section before `## Non-Triggers` with a 3-step pre-dispatch checklist.

## Test Impact

All 7 existing test cases in `tests/scenarios/unit-formula-dispatch.yaml` pass unchanged:
- Cases grep for `formula:<`, `formula track`, `agent track`, `formula label takes priority`, `swarm_run`, `Formula dispatch`, `Agent dispatch`, pump references, and dispatch args — all still present after edits.

## Verification

```bash
bash tests/run-tests.sh --unit-only
```

All text/instruction edits only — no script or code changes.
