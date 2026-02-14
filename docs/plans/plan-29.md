# Plan 29: Implicit Swarm Formula Triggering

**Status:** Draft
**Date:** 2026-02-13

## Context

The yf plugin (v2.13.0) ships five swarm formulas but they only fire through two mechanisms: manual invocation (`/yf:swarm_run formula:X`) or explicit `formula:<name>` labels on beads (detected by the `swarm-formula-dispatch` rule during plan pump). There is no contextual or automatic formula selection — someone must manually label each bead or invoke each formula by name.

The goal is to make swarm formulas fire **implicitly** based on lifecycle events, task semantics, and runtime signals. A plan task that says "implement user authentication" should automatically get the `feature-build` formula without anyone adding a label. A test failure should spawn a `bugfix` swarm. A plan completion should require a `code-review` qualification gate.

## Overview — Five Triggers

| # | Trigger | Signal | Formula | Phase |
|---|---------|--------|---------|-------|
| T1 | Plan bead creation | Task semantics (title/type) | Auto-select best formula | Plan setup |
| T2 | Feature-build implement step | `compose` field in formula JSON | build-test sub-swarm | Execution |
| T3 | REVIEW:BLOCK or test failure | Comment content on parent bead | bugfix reactive spawn | Execution |
| T4 | Plan/feature nearing completion | All tasks closed, gate open | code-review qualification | Completion |
| T5 | Research activity during planning | Web searches, external docs | research-spike | Planning |

## Implementation

### T1 — Automatic Formula Selection at Bead Creation

**Hook point:** `/yf:plan_create_beads` Step 8 (Agent Selection)

**What:** After agent selection, evaluate each task for formula assignment. Add a new Step 8b that applies `formula:<name>` labels based on task semantics.

**New skill: `/yf:swarm_select_formula`**
- File: `plugins/yf/skills/swarm_select_formula/SKILL.md`
- Reads task title, description, type, and labels
- Applies heuristic matching:
  - Implementation tasks (create, add, build, implement) -> `formula:feature-build`
  - Bug-fix tasks (fix, resolve, debug, repair) -> `formula:bugfix`
  - Research tasks (research, investigate, evaluate, spike) -> `formula:research-spike`
  - Review tasks (review, audit) -> `formula:code-review`
  - Test-focused tasks -> `formula:build-test`
  - Atomic/trivial tasks (single file, single concern) -> **no formula** (bare agent dispatch)
- Checks for existing `formula:*` label before adding (idempotent)
- Respects explicit `formula:X` in plan text (author override)

**New rule: `swarm-formula-select.md`**
- File: `plugins/yf/rules/swarm-formula-select.md`
- Documents heuristic guidance for the agent
- States that atomic tasks should NOT get formulas

**Modify:** `plugins/yf/skills/plan_create_beads/SKILL.md` — add Step 8b after Step 8

**No changes to pump or dispatch** — the existing `swarm-formula-dispatch` rule already reads `formula:<name>` labels.

### T2 — Nested Formula Composition (`compose` field)

**Hook point:** `/yf:swarm_dispatch` Step 3-4 (Parse annotations, Dispatch steps)

**What:** Add a `compose` field to formula step definitions. When the dispatch loop encounters a step with `compose: "<formula-name>"`, it invokes `/yf:swarm_run` for that sub-formula instead of launching a bare Task call.

**Formula schema extension:**
```json
{
  "id": "implement",
  "title": "Implement {{feature}}",
  "description": "...",
  "needs": ["research"],
  "compose": "build-test"
}
```

**Depth tracking:**
- Add `depth` parameter to `/yf:swarm_run` (default: 0)
- Each nested invocation passes `depth+1`
- Hard limit: depth 2. At depth 2, `compose` is ignored and step dispatches as bare Task
- Prevents infinite recursion

**Nested state tracking:**
- Prefix convention in `swarm-state.sh`: `<parent-mol-id>/<step-id>` for nested steps
- New `--scope <mol-id>` flag on `clear` to clean only a sub-swarm's state

**Context flow:**
- Sub-swarm receives upstream FINDINGS from parent formula's earlier steps as `context`
- Sub-swarm posts CHANGES/TESTS/REVIEW on the **outermost** parent bead (maintains single audit trail)

**Modify:**
- `plugins/yf/skills/swarm_dispatch/SKILL.md` — add compose detection in Step 3, compose dispatch in Step 4
- `plugins/yf/skills/swarm_run/SKILL.md` — add `depth` parameter
- `plugins/yf/scripts/swarm-state.sh` — add scope prefix support
- `plugins/yf/formulas/feature-build.formula.json` — add `"compose": "build-test"` to implement step

**New rule: `swarm-nesting.md`**
- File: `plugins/yf/rules/swarm-nesting.md`
- Documents max depth 2, context flow, comment routing

### T3 — Reactive Bugfix on Test/Review Failure

**Hook point:** `/yf:swarm_dispatch` Step 6 (Wait and Process Returns)

**What:** After a step completes, read its comment. If `REVIEW:BLOCK` or `TESTS:` with failures, spawn a bugfix formula targeting the failure. Then retry the failed step.

**New skill: `/yf:swarm_react`**
- File: `plugins/yf/skills/swarm_react/SKILL.md`
- Takes parent bead ID and verdict type (BLOCK or FAIL)
- Reads the comment, extracts failure context
- Invokes `/yf:swarm_run formula:bugfix feature:"<failure summary>" parent_bead:<parent> context:"<failure details>"`
- Checks `ys:bugfix-attempt` label to prevent multiple reactive spawns per step

**Retry mechanism:**
- Step-level `max_retries` field in formula JSON (default: 1)
- After bugfix completes, re-dispatch the original failed step via `swarm-state.sh mark-retrying <step-id>`
- If retry fails again, the block stands — parent bead stays open for manual intervention

**Guard rails:**
- Reactive bugfix runs at `depth+1` — cannot itself trigger reactive bugfixes (depth limit)
- Design-level BLOCKs ("wrong approach", "needs redesign") are NOT eligible for reactive bugfix — the agent distinguishes bug BLOCKs from design BLOCKs using the REVIEW comment content
- Config: `reactive_bugfix: true|false` in `.yoshiko-flow/config.json` (escape hatch)

**Modify:**
- `plugins/yf/skills/swarm_dispatch/SKILL.md` — add Step 6b (reactive check after processing returns)
- `plugins/yf/scripts/swarm-state.sh` — add `mark-retrying` command

**New rule: `swarm-reactive.md`**
- File: `plugins/yf/rules/swarm-reactive.md`
- Documents when reactive bugfix fires, retry budget, design-BLOCK exclusion

### T4 — Code Review Qualification Gate

**Hook point:** `/yf:plan_execute` Step 4 (Completion sequence) and `/yf:plan_create_beads` Step 9

**What:** Before a plan is marked complete, run `code-review` formula as a mandatory qualification. Block completion on REVIEW:BLOCK.

**Qualification gate bead:**
- Created during `plan_create_beads` Step 9c (new):
  ```bash
  bd create --type=gate \
    --title="Qualification review for plan-<idx>" \
    --parent=<root-epic-id> \
    -l ys:qualification-gate,plan:<idx> \
    --silent
  ```

**Completion interception:**
- In `plan_execute` Step 4, before marking plan complete:
  1. Check for open qualification gate: `bd list -l ys:qualification-gate,plan:<idx> --status=open`
  2. If open -> invoke `/yf:swarm_run formula:code-review feature:"Plan <idx> qualification" parent_bead:<gate-id>`
  3. code-review analyzes changes (git diff from plan start commit to HEAD)
  4. REVIEW:PASS -> close gate, proceed with plan completion
  5. REVIEW:BLOCK -> leave gate open, report block. User fixes issues and re-runs

**New skill: `/yf:swarm_qualify`**
- File: `plugins/yf/skills/swarm_qualify/SKILL.md`
- Takes plan index or root epic ID
- Determines review scope via git diff
- Invokes code-review formula
- Reports verdict

**Config:** `qualification_gate: "blocking"|"advisory"|"disabled"` in `.yoshiko-flow/config.json`
- `blocking` (default): BLOCK prevents completion
- `advisory`: BLOCK is noted in completion report but doesn't prevent closing
- `disabled`: No gate created

**Starting commit tracking:**
- `plan-exec.sh start` records the current HEAD SHA as a label on the root epic: `start-sha:<hash>`
- Qualification reviews diff from this SHA

**Modify:**
- `plugins/yf/skills/plan_create_beads/SKILL.md` — add Step 9c (qualification gate)
- `plugins/yf/skills/plan_execute/SKILL.md` — add qualification check before completion
- `plugins/yf/scripts/plan-exec.sh` — add `qualifying` status, start-commit recording
- `plugins/yf/rules/plan-completion-report.md` — add Qualification section

### T5 — Research Spike During Planning (Advisory)

**Hook point:** Agent behavior during plan mode

**What:** When the agent performs significant research during plan mode (3+ web searches, library comparisons, API doc reading), suggest running a research-spike formula to formalize the investigation.

**New rule: `swarm-planning-research.md`**
- File: `plugins/yf/rules/swarm-planning-research.md`
- Advisory only — suggests, does not auto-invoke
- Threshold: 3+ web searches, or explicit alternative comparison
- Checks for existing archive beads before suggesting (avoids duplicating `/yf:archive_capture`)
- Suggests: "This research could benefit from `/yf:swarm_run formula:research-spike feature:"<topic>"`"

**Formula annotation:**
- Add `"planning_safe": true` to `research-spike.formula.json`
- All its steps are read-only or bead-only (no file writes) — plan gate doesn't interfere

**Integration with existing rules:**
- `plan-transition-archive.md` already fires between plan save and beads creation
- Extend: if research scope was large, suggest research-spike instead of bare `archive_capture`
- `watch-for-archive-worthiness.md` continues to handle lightweight research

**Modify:**
- `plugins/yf/formulas/research-spike.formula.json` — add `planning_safe: true`

## New Artifacts Summary

**Skills (3 new):**
| Skill | Path | Purpose |
|-------|------|---------|
| `/yf:swarm_select_formula` | `plugins/yf/skills/swarm_select_formula/SKILL.md` | Auto-assign formula labels to beads |
| `/yf:swarm_react` | `plugins/yf/skills/swarm_react/SKILL.md` | Reactive bugfix from BLOCK/FAIL verdicts |
| `/yf:swarm_qualify` | `plugins/yf/skills/swarm_qualify/SKILL.md` | Run code-review qualification gate |

**Rules (4 new):**
| Rule | Path | Purpose |
|------|------|---------|
| `swarm-formula-select.md` | `plugins/yf/rules/swarm-formula-select.md` | Heuristics for formula assignment |
| `swarm-nesting.md` | `plugins/yf/rules/swarm-nesting.md` | Nesting protocol and depth limits |
| `swarm-reactive.md` | `plugins/yf/rules/swarm-reactive.md` | Reactive bugfix spawning behavior |
| `swarm-planning-research.md` | `plugins/yf/rules/swarm-planning-research.md` | Advisory for research-spike during planning |

**Modified files:**
| File | Changes |
|------|---------|
| `plugins/yf/skills/plan_create_beads/SKILL.md` | Add Step 8b (formula selection) and Step 9c (qualification gate) |
| `plugins/yf/skills/swarm_dispatch/SKILL.md` | Add compose dispatch, reactive check (Step 6b), retry logic |
| `plugins/yf/skills/swarm_run/SKILL.md` | Add `depth` parameter |
| `plugins/yf/skills/plan_execute/SKILL.md` | Add qualification gate check before completion |
| `plugins/yf/scripts/swarm-state.sh` | Add scope prefix, `mark-retrying` command |
| `plugins/yf/scripts/plan-exec.sh` | Add `qualifying` status, start-commit recording |
| `plugins/yf/formulas/feature-build.formula.json` | Add `compose: "build-test"` on implement step |
| `plugins/yf/formulas/research-spike.formula.json` | Add `planning_safe: true` |
| `plugins/yf/rules/plan-completion-report.md` | Add Qualification section |
| `plugins/yf/.claude-plugin/preflight.json` | Register 4 new rules |
| `plugins/yf/.claude-plugin/plugin.json` | Version bump to 2.14.0 |
| `plugins/yf/README.md` | Document implicit triggers in Swarm section |
| `plugins/yf/DEVELOPERS.md` | Update capability table |
| `CHANGELOG.md` | Version entry |

## Implementation Sequence

```
T1 (formula select) --> T2 (nesting) --> T3 (reactive) --+
                                                          +--> Update docs, bump version
T5 (planning research) -----------------> T4 (qualification) +
```

T1 and T5 are independent — start in parallel. T2 depends on T1 (beads need formula labels). T3 depends on T2 (needs dispatch loop changes). T4 is independent of T2/T3 but logically last.

## Completion Criteria

- [ ] T1: `swarm_select_formula` skill assigns formula labels during `plan_create_beads`
- [ ] T2: `compose` field in formulas spawns nested sub-swarms with depth tracking
- [ ] T3: `swarm_react` skill spawns bugfix on BLOCK/FAIL with retry mechanism
- [ ] T4: `swarm_qualify` skill runs code-review gate before plan completion
- [ ] T5: Advisory rule suggests research-spike during heavy planning research
- [ ] All new rules registered in preflight.json
- [ ] Plugin version bumped to 2.14.0
- [ ] README and DEVELOPERS.md updated
- [ ] CHANGELOG entry added
- [ ] All tests pass (`bash tests/run-tests.sh --unit-only`)
