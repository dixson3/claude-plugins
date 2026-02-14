# Plan 34: Engineer Capability for yf Plugin

**Status:** Completed
**Date:** 2026-02-14

## Overview

The yf plugin currently captures *rationale* (chronicler/archivist) and *execution state* (plans/swarm), but lacks *specification artifacts* — the living documents that define what the software should do, how it's built, and how features work. The Engineer capability fills this gap by synthesizing and maintaining PRD, EDD, Implementation Guides, and a TODO register. When specs exist, plans are reconciled against them before execution, creating a feedback loop between specification and implementation.

Templates are adapted from the reference rules at `/Users/james/workspace/spikes/code-manager/collection/requirements/PRD.md` and `EDD.md`, restructured to fit the yf artifact directory layout and naming conventions.

## Artifact Directory Structure

Under `<artifact_dir>/specifications/`:

```
specifications/
  PRD.md                    # Product requirements (REQ-xxx)
  EDD/
    CORE.md                 # Primary design doc (DD-xxx, NFR-xxx)
    <subsystem>.md          # Per-subsystem for complex projects
  IG/
    <feature>.md            # Per-feature use-case docs (UC-xxx)
  TODO.md                   # Lightweight deferred items (TODO-xxx)
```

## Implementation Sequence

### Phase 1: Core Skills & Agent (Foundation)

**1.1** Create `plugins/yf/skills/engineer_analyze_project/SKILL.md`
- Arguments: `scope` (optional: `all|prd|edd|ig|todo`), `force` (optional: regenerate with diff)
- Behavior: Check which specs exist; for missing ones, scan `docs/plans/`, `docs/diary/`, `docs/research/`, `docs/decisions/`, and codebase structure; launch `yf_engineer_synthesizer` agent; write generated files
- Idempotent: does not overwrite existing specs unless `force` — shows diff instead
- Templates: PRD with REQ-xxx matrix, EDD with DD-xxx/NFR-xxx ADR format, IG with UC-xxx use cases, TODO with TODO-xxx register

**1.2** Create `plugins/yf/agents/yf_engineer_synthesizer.md`
- Read-only agent (same tool profile as `yf_swarm_researcher`)
- Reads plans, archives, diary, codebase structure
- Returns JSON with spec content for each document type (follows `yf_archive_process` output pattern)
- Does NOT write files — the calling skill handles that

**1.3** Create `plugins/yf/skills/engineer_update/SKILL.md`
- Arguments: `type` (required: `prd|edd|ig|todo`), `action` (optional: `add|update|deprecate`), `id` (optional: specific REQ/DD/NFR/UC/TODO ID), `subsystem` (optional for EDD), `feature` (optional for IG)
- Auto-generates next sequential ID when adding
- Cross-references: suggests EDD update when PRD changes affect architecture, and vice versa

**1.4** Update `plugins/yf/.claude-plugin/preflight.json`
- Add to `artifacts.directories`: `"docs/specifications"`, `"docs/specifications/EDD"`, `"docs/specifications/IG"`

**1.5** Update `plugins/yf/hooks/code-gate.sh`
- Add exemption: `*/docs/specifications/*) exit 0 ;; # Engineer spec artifacts`

### Phase 2: Reconciliation Gate (Plan Lifecycle Integration)

**2.1** Create `plugins/yf/skills/engineer_reconcile/SKILL.md`
- Arguments: `plan_file` (optional), `plan_idx` (optional), `mode` (optional: `gate|check`, default: `gate`)
- Reads all spec files under `<artifact_dir>/specifications/`
- If no specs exist: returns success silently (no enforcement without specs)
- PRD check: plan tasks vs REQ-xxx IDs — flags new untraced functionality and contradictions
- EDD check: plan approach vs DD-xxx/NFR-xxx — flags technology/architecture conflicts, suggests migration
- IG check: plan tasks vs UC-xxx use cases — flags affected features
- Output: structured reconciliation report with `PRD:COMPLIANT|CONFLICT`, `EDD:COMPLIANT|CONFLICT`, `IG:COMPLIANT|NEEDS-UPDATE`, and overall `PASS|NEEDS-RECONCILIATION`
- In `gate` mode: presents conflicts to operator via AskUserQuestion with options: (a) update specs, (b) modify plan, (c) acknowledge and proceed
- Config-gated: `.yoshiko-flow/config.json` -> `config.engineer.reconciliation_mode`: `"blocking"` (default), `"advisory"`, `"disabled"`

**2.2** Create `plugins/yf/rules/engineer-reconcile-on-plan.md`
- Trigger: auto-chain — fires when "Plan saved to docs/plans/" appears AND spec files exist
- Behavior: invoke `/yf:engineer_reconcile plan_file:<path> mode:gate` between plan format and beads creation
- If no specs: skip silently
- If CONFLICT: present to operator, await decision before continuing auto-chain
- If COMPLIANT: proceed

**2.3** Update `plugins/yf/rules/auto-chain-plan.md`
- Insert step 1.5 between "Format the plan file" and "Update MEMORY.md"

**2.4** Update `plugins/yf/.claude-plugin/preflight.json`
- Add rule: `engineer-reconcile-on-plan.md`

### Phase 3: Advisory Monitoring (Watch Rule)

**3.1** Create `plugins/yf/rules/watch-for-spec-drift.md`
- Single advisory rule covering all spec types
- PRD triggers: new functionality, requirement contradictions
- EDD triggers: technology choices conflicting with DD-xxx, NFR violations
- IG triggers: feature changes affecting documented use cases
- Test triggers: suggest test suite validation against IG use cases; suggest system tests validate PRD requirements
- Frequency: at most once per 15-20 minutes
- Non-triggers: trivial changes, work on features without existing IG docs

**3.2** Update `plugins/yf/.claude-plugin/preflight.json`
- Add rule: `watch-for-spec-drift.md`

### Phase 4: Completion Integration

**4.1** Create `plugins/yf/skills/engineer_suggest_updates/SKILL.md`
- Arguments: `plan_idx` (optional), `scope` (optional: `all|prd|edd|ig|todo`)
- Reads plan beads, CHANGES/FINDINGS/REVIEW comments, completed work
- Compares against current specs
- Outputs advisory suggestions
- Does NOT auto-update

**4.2** Create `plugins/yf/rules/engineer-suggest-on-completion.md`
- Trigger: plan execution completes
- If specs exist: invoke `/yf:engineer_suggest_updates plan_idx:<idx>`
- Advisory only

**4.3** Update `plugins/yf/skills/plan_execute/SKILL.md`
- Add step 3.5 in completion sequence

**4.4** Update `plugins/yf/rules/plan-completion-report.md`
- Add Section 7 "Specification Status"

**4.5** Update `plugins/yf/.claude-plugin/preflight.json`
- Add rule: `engineer-suggest-on-completion.md`

### Phase 5: Documentation & Packaging

**5.1** Update `plugins/yf/DEVELOPERS.md` — Add Engineer to capability table
**5.2** Update `plugins/yf/README.md` — Add Engineer capability section
**5.3** Update root `README.md` — Add Engineer narrative
**5.4** Update `plugins/yf/.claude-plugin/plugin.json` — Version bump to 2.17.0
**5.5** Update `CHANGELOG.md` — Add v2.17.0 entry
**5.6** Update `CLAUDE.md` — Update version reference
**5.7** Write test scenarios in `tests/scenarios/`

## Key Design Decisions

1. **Advisory by default, configurable to blocking** — Reconciliation notifies operator of conflicts. Config `engineer.reconciliation_mode` controls behavior (`blocking`/`advisory`/`disabled`).
2. **No specs = no enforcement** — All engineer rules degrade to no-ops when specs don't exist. Zero-cost for projects that don't opt in.
3. **Idempotent synthesis** — `engineer_analyze_project` will not overwrite existing specs. Shows diff/suggestions for existing docs.
4. **Single watch rule** — One `watch-for-spec-drift.md` covers PRD, EDD, and IG monitoring.
5. **One agent, not four** — `yf_engineer_synthesizer` handles all spec types. Templates live in the skill, keeping the agent generic.
6. **Bead labels** — `ys:engineer`, `ys:engineer:reconciliation`.

## Completion Criteria

- [ ] All 4 skills invoke correctly and produce expected output
- [ ] Agent synthesizes specs from existing project context
- [ ] Reconciliation integrates into auto-chain between plan save and beads creation
- [ ] Advisory rule fires when changes may affect specs
- [ ] Plan completion report includes spec status
- [ ] Preflight creates specification directories
- [ ] Code-gate exempts specification files
- [ ] DEVELOPERS.md, README.md, CHANGELOG.md updated
- [ ] Existing tests still pass
