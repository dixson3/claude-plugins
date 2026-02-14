# Plan 35: Swarm Integration, Chronicle Aggressiveness, Spec-Test Reconciliation, Capability Improvements, and Coder Capability

**Status:** Completed
**Date:** 2026-02-14
**Version Target:** 2.18.0

## Context

Swarms are never triggered from plan execution despite the infrastructure being in place. The `swarm_select_formula` skill correctly assigns `formula:<name>` labels during `plan_create_beads`, but `plan_pump` and `plan_execute` never check these labels — all tasks dispatch as bare agent calls. Additionally, chronicles are not aggressive enough to capture implementation adjustments, spec-test coverage has gaps, and the capabilities (chronicler, archivist, researcher, engineer) don't fully leverage swarm execution. A new "coder" capability is needed for structured code generation workflows.

## Overview

Five work areas, implemented as five sequential phases:

| Phase | Area | Impact | Risk |
|-------|------|--------|------|
| 1 | Fix swarm triggering from plans | Critical — unlocks swarm execution | Low |
| 2 | More aggressive chronicles | Medium — captures rework context | Low |
| 3 | Spec-test reconciliation | Medium — identifies coverage gaps | None (docs/tests only) |
| 4 | Capability improvements for swarms | Medium — deeper integration | Low (additive) |
| 5 | New coder capability | High — structured code workflows | Medium |

## Phase 1: Fix Swarm Triggering from Plans

**Problem:** `plan_pump/SKILL.md` Step 4 groups beads only by `agent:<name>` labels. `plan_execute/SKILL.md` Step 3c dispatches all beads as bare Task calls. Neither checks `formula:<name>` labels. The IG (UC-003) and rule (`swarm-formula-dispatch.md`) describe the intended behavior but it was never implemented.

### Changes

**1a. `plugins/yf/skills/plan_pump/SKILL.md`** — Modify Step 4 ("Group by Agent")
- After reading `agent:<name>` labels, also read `formula:<name>` labels
- Annotate each bead with its dispatch track: `formula` or `agent`
- Output both tracks so `plan_execute` can route correctly

**1b. `plugins/yf/skills/plan_execute/SKILL.md`** — Modify Step 3c ("Dispatch in Parallel")
- Add formula dispatch path before existing agent dispatch:
  - For beads with `formula:<name>`: invoke `/yf:swarm_run formula:<name> feature:"<title>" parent_bead:<id>`
  - For beads without formula label: existing bare Task dispatch (unchanged)

**1c. `tests/scenarios/unit-formula-dispatch.yaml`** — New test file
- Verify plan_pump documents formula detection
- Verify plan_execute documents swarm_run dispatch path
- Verify swarm-formula-dispatch rule references the pump

### Why This Works
The pump remains a pure query/grouping tool. The execute skill makes the dispatch routing decision. Formula-labeled beads get full swarm lifecycle (wisp, dispatch, squash, chronicle). Non-formula beads dispatch as before.

---

## Phase 2: More Aggressive Chronicles

**Problem:** Chronicles only trigger on major milestones and decisions. Implementation adjustments to comply with requirements, plan constraints, or review feedback are not captured — these are high-context moments worth preserving.

### Changes

**2a. `plugins/yf/rules/watch-for-chronicle-worthiness.md`** — Add 3 trigger categories

7. **Implementation Adjustments** — code modified to comply with REQ-xxx, plan constraints, spec alignment, or rework after review feedback
8. **Swarm Execution Events** — reactive bugfix triggered, test failures requiring adjustments, formula step retried, swarm completed with mixed results
9. **Plan Compliance Adjustments** — implementation deviating from plan, dependency ordering changed, task scope expanded/split during execution

- Reduce frequency threshold to 10-15 minutes for categories 7-9
- Update non-triggers to clarify boundary (routine test runs excluded unless they fail and trigger rework)

**2b. `plugins/yf/rules/swarm-chronicle-bridge.md`** — New rule
- Auto-capture chronicle when reactive bugfix triggers (not advisory — fires automatically)
- Fires after `swarm_react` spawns bugfix and after retry result is known
- Preserves mid-swarm context that would otherwise be lost on wisp squashing

**2c. `plugins/yf/skills/swarm_react/SKILL.md`** — Add Step 4.5
- Between spawn bugfix (Step 4) and retry (Step 5), auto-create chronicle bead
- Labels: `ys:chronicle,ys:topic:swarm,ys:swarm`
- Content: failure details, bugfix formula ID, step being retried

**2d. `plugins/yf/.claude-plugin/preflight.json`** — Add swarm-chronicle-bridge rule

**2e. Tests** — Add cases to `unit-chronicle-check.yaml` verifying new trigger categories

---

## Phase 3: Specification-Test Reconciliation

**Problem:** 76% overall spec coverage. Key gaps in swarm integration, engineer, and archivist behavioral testing. Several tests only verify file existence rather than behavior.

### Gap Summary

| Category | Items | Tested | Existence-Only | Untested |
|----------|-------|--------|----------------|----------|
| REQ-xxx | 31 | 12 | 15 | 4 |
| DD-xxx | 12 | 8 | 4 | 0 |
| NFR-xxx | 7 | 0 | 7 | 0 |
| UC-xxx | 28 | 8 | 16 | 4 |

**Critical untested areas:**
- Formula dispatch integration (UC-003 Step 4) — addressed by Phase 1
- Full swarm lifecycle (UC-006) — requires wisp support, deferred
- Reactive bugfix eligibility (UC-008) — behavioral test needed
- Engineer synthesis/reconciliation (UC-018-021) — behavioral tests needed
- Archivist capture/process cycle (UC-014-017) — behavioral tests needed

### Changes

**3a. `tests/scenarios/unit-swarm-comment-protocol.yaml`** — New test file
- Verify all 5 formula files include correct SUBAGENT annotations
- Verify all formulas reference the correct comment protocol prefixes
- Verify step dependencies are correctly declared

**3b. `docs/specifications/test-coverage.md`** — New traceability matrix
- Maps each REQ, DD, NFR, UC to test scenario file and case names
- Tags coverage status: `tested` / `existence-only` / `untested`

**3c. `docs/specifications/TODO.md`** — Update with new gap items
- UC-008 behavioral test (reactive bugfix eligibility logic)
- UC-018-021 engineer behavioral tests
- UC-014-017 archivist behavioral tests
- Integration test maintenance (TODO-014 refresh)

**3d. Priority test scenarios** — Add behavioral tests where feasible:
- `unit-swarm-reactive.yaml` — Add cases testing `swarm-state.sh mark-retrying` with guard rails (depth check, label check)
- `unit-engineer.yaml` — Add cases testing spec directory structure and reconciliation config
- `unit-archive-suggest.yaml` — Add cases testing keyword detection patterns

---

## Phase 4: Capability Improvements for Swarm Execution

**Problem:** Chronicler, archivist, researcher, and engineer capabilities are underutilized during swarm execution. Chronicles only capture post-completion snapshots. Only research-spike archives findings. Researcher has no archive integration. Engineer is completely disconnected from swarms.

### Changes

#### Chronicler
**4a. `plugins/yf/skills/swarm_run/SKILL.md`** — Enhance E1 chronicle (Step 4c)
- Include formula name, step count, retry attempts, BLOCK verdicts, final outcome
- Currently just squash summary; make it a structured execution narrative

**4b. `plugins/yf/skills/swarm_dispatch/SKILL.md`** — Add Step 6c (Progressive Chronicle)
- After a step completes, if step JSON has `"chronicle": true`, auto-create chronicle bead
- Opt-in per step; no existing formulas affected unless explicitly updated

#### Archivist
**4c. `plugins/yf/skills/swarm_dispatch/SKILL.md`** — Add Step 6d (Archive Findings)
- After a step completes, if step JSON has `"archive_findings": true` and FINDINGS contains external sources, auto-create archive bead
- Opt-in per step; extends archival beyond research-spike

**4d. `plugins/yf/rules/swarm-archive-bridge.md`** — Broaden scope
- Currently fires only after swarm_run Step 4b; extend to fire after any formula completion
- Detection markers already correct; just widen the "When This Fires" scope

#### Researcher
**4e. `plugins/yf/agents/yf_swarm_researcher.md`** — Structured sources in FINDINGS
- Add `### External` subsection within Sources for URLs/doc references
- Makes archive bridge detection more reliable

#### Engineer
**4f. `plugins/yf/rules/swarm-spec-bridge.md`** — New rule
- After feature-build or build-test swarm completes with REVIEW:PASS, suggest spec updates if `docs/specifications/` exists
- Advisory only, one suggestion per swarm completion

**4g. `plugins/yf/agents/yf_swarm_reviewer.md`** — Add IG reference
- If `docs/specifications/IG/` contains a relevant IG for the feature under review, reference it
- Note divergence in REVIEW comment

**4h. `plugins/yf/.claude-plugin/preflight.json`** — Add swarm-spec-bridge rule

**4i. Tests** — Add cases verifying new rule files and dispatch steps

---

## Phase 5: Coder Capability

**Problem:** No structured code generation workflow exists. Implementation tasks are handled by generic agents without technology-specific standards, dedicated review criteria, or test feedback loops.

### Design

Four specialized agents working through a `code-implement` formula:

```
research-standards (yf_code_researcher) → implement (yf_code_writer) → test (yf_code_tester) → review (yf_code_reviewer)
```

- **code-researcher**: Checks for existing coding standards IG; if none exists for the target technology, researches best practices and posts FINDINGS with proposed standards
- **code-writer**: Reads upstream FINDINGS for standards, reads relevant IGs, implements the feature following patterns. Posts CHANGES
- **code-tester**: Reads CHANGES, writes unit/integration tests, runs them. Posts TESTS. Failures trigger reactive bugfix loop with code-writer
- **code-reviewer**: Reads all upstream comments, reviews against standards IG + global review criteria + any feature-specific IG. Posts REVIEW:PASS or REVIEW:BLOCK

### New Files

| File | Type | Purpose |
|------|------|---------|
| `plugins/yf/agents/yf_code_researcher.md` | Agent | Read-only; researches technology standards |
| `plugins/yf/agents/yf_code_writer.md` | Agent | Full-capability; implements code following standards |
| `plugins/yf/agents/yf_code_reviewer.md` | Agent | Read-only; reviews against IGs and standards |
| `plugins/yf/agents/yf_code_tester.md` | Agent | Limited-write; creates/runs tests |
| `plugins/yf/formulas/code-implement.formula.json` | Formula | 4-step code workflow |
| `tests/scenarios/unit-code-implement.yaml` | Test | Validates structure and integration |

### Modified Files

| File | Change |
|------|--------|
| `plugins/yf/skills/swarm_select_formula/SKILL.md` | Add `code-implement` to heuristic table: matches `code`, `write`, `program`, `develop` when technology/language context present |
| `plugins/yf/rules/swarm-formula-select.md` | Add `code-implement` row to heuristic table |
| `plugins/yf/skills/plan_select_agent/SKILL.md` | Add 4 new agents to agent registry |
| `plugins/yf/DEVELOPERS.md` | Add `code` capability row to capability table |
| `plugins/yf/README.md` | Add Coder capability section |
| `README.md` | Add coder narrative to plugin overview |
| `docs/specifications/PRD.md` | Add REQ-032 (coding standards workflow) |
| `docs/specifications/EDD/CORE.md` | Add DD-013 (code-implement formula design) |
| `docs/specifications/IG/coder.md` | New IG with UC-029 through UC-032 |
| `docs/specifications/TODO.md` | Add end-to-end testing items |
| `plugins/yf/.claude-plugin/plugin.json` | Bump to 2.18.0 |
| `marketplace/.claude-plugin/marketplace.json` | Bump to 2.18.0 |
| `CHANGELOG.md` | Add v2.18.0 entry |

### Formula Definition

```json
{
  "name": "code-implement",
  "description": "Standards-driven code implementation with research, coding, testing, and review",
  "steps": [
    { "id": "research-standards", "needs": [], "SUBAGENT": "yf_code_researcher" },
    { "id": "implement", "needs": ["research-standards"], "SUBAGENT": "yf_code_writer" },
    { "id": "test", "needs": ["implement"], "SUBAGENT": "yf_code_tester" },
    { "id": "review", "needs": ["test"], "SUBAGENT": "yf_code_reviewer" }
  ]
}
```

Reactive bugfix is inherited from existing swarm infrastructure — TESTS failures and REVIEW:BLOCK automatically trigger the bugfix formula via `swarm_react`.

### Differentiation from feature-build

| Aspect | feature-build | code-implement |
|--------|---------------|----------------|
| Research focus | Codebase patterns | Technology standards |
| Standards | None | IG-driven coding standards |
| Testing | Composed (build-test) | Dedicated tester agent |
| Review criteria | General code quality | Standards + IG compliance |
| Selection trigger | General implement verbs | Language/technology context |

---

## Implementation Sequence

1. **Phase 1** — Fix swarm triggering (2 skills, 1 test file)
2. **Phase 2** — Chronicle aggressiveness (1 rule update, 1 new rule, 1 skill update, preflight update, tests)
3. **Phase 3** — Spec-test reconciliation (2 new test files, 1 traceability doc, TODO update, existing test enhancements)
4. **Phase 4** — Capability improvements (2 skill updates, 2 agent updates, 1 rule update, 1 new rule, preflight update, tests)
5. **Phase 5** — Coder capability (4 agents, 1 formula, 1 test file, ~12 file updates for integration and specs)

## Completion Criteria

- [ ] Formula-labeled beads dispatch through swarm_run during plan execution (Phase 1)
- [ ] Implementation adjustment events trigger chronicle suggestions (Phase 2)
- [ ] Reactive bugfix auto-captures chronicle bead (Phase 2)
- [ ] Test-coverage traceability matrix exists mapping all spec items (Phase 3)
- [ ] Priority gap tests added for swarm, engineer, archivist (Phase 3)
- [ ] Swarm dispatch supports optional progressive chronicle and archive steps (Phase 4)
- [ ] Researcher FINDINGS include structured external sources section (Phase 4)
- [ ] Post-swarm spec suggestion rule exists (Phase 4)
- [ ] 4 code agents created with correct tool profiles (Phase 5)
- [ ] code-implement formula created with 4 steps (Phase 5)
- [ ] swarm_select_formula heuristic table includes code-implement (Phase 5)
- [ ] All specs updated (PRD, EDD, IG, TODO) (Phase 5)
- [ ] `bash tests/run-tests.sh --unit-only` passes after each phase
- [ ] Version bumped to 2.18.0
