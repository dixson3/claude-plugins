# Plan 28: Swarm-Enhanced Plan Execution (v2.13.0)

**Status:** Draft
**Date:** 2026-02-13

## Context

The yf plugin (v2.12.0) executes plans sequentially through a task pump that dispatches beads one-at-a-time to agents. The beads CLI already supports **formulas** (reusable workflow templates), **wisps** (ephemeral molecules), **gates** (async wait conditions), and **molecules** (instantiated work templates) — but the yf plugin doesn't use any of these capabilities.

This plan adds a **swarm** capability that leverages these beads features to run structured, parallel agent workflows. The core pattern is: a formula defines a reusable swarm shape (e.g., research -> implement -> review), wisps keep orchestration ephemeral, and a dispatch loop drives agents through gated phases.

## Overview

Add formula-driven swarm execution to the yf plugin:
- **5 formulas** shipped with the plugin (not in `.beads/`) defining common work patterns
- **3 new agents** (researcher, reviewer, tester) for specialized swarm roles
- **4 new skills** for swarm lifecycle (run, dispatch, status, list-formulas)
- **1 new script** for swarm dispatch state tracking
- **3 new rules** for comment protocol, plan integration, and archive bridging
- **Chronicler enhancements** — swarm auto-chronicles, diary reads swarm comments, chronicle-check detects swarms
- **Archivist enhancements** — research-spike auto-archives, swarm-archive bridge rule, researcher output aligns with archivist format
- **Minimal changes** to existing plan system (additive, not breaking)

## Key Design Decisions

1. **Formulas live at `plugins/yf/formulas/`** — not in `.beads/formulas/`. The `bd cook` and `bd mol wisp` commands accept explicit file paths, so no deployment step needed.

2. **JSON format** — `bd cook` expects `.formula.json` files, not TOML. The reference document showed TOML conceptually, but the CLI implementation uses JSON.

3. **Wisps for orchestration** — Swarm steps are ephemeral (not exported to JSONL, not synced via git). Results persist as comments on the parent bead. On completion, `bd mol squash` creates a digest.

4. **Comment protocol** for inter-agent communication — Agents post structured comments (`FINDINGS:`, `CHANGES:`, `REVIEW:`, `TESTS:`) on the parent bead. This survives wisp squashing and provides a readable audit trail.

5. **`SUBAGENT:` annotations** parsed by the dispatch skill (not by `bd cook`) — keeps beads-generic and yf-specific concerns separated.

6. **Plan integration via label** — During plan execution, tasks labeled `formula:<name>` are dispatched through the swarm system instead of bare agent dispatch. This is additive to the existing pump.

## Chronicler & Archivist Integration

### Analysis: Comment Protocol vs Chronicler — COMPLEMENT

The swarm comment protocol (`FINDINGS:`, `CHANGES:`, `REVIEW:`, `TESTS:`) and the chronicler serve different layers:

| Aspect | Comment Protocol | Chronicler |
|--------|-----------------|------------|
| Purpose | Inter-agent communication within a swarm | Human-readable context across sessions |
| Scope | Single swarm execution | Entire work session |
| Persistence | On parent bead (survives squash) | In chronicle beads -> diary entries |
| Audience | Next agent in the pipeline | Future sessions / the developer |
| Content | Structured results (file lists, verdicts) | Narrative (what happened, why, what's next) |

### Enhancements

| ID | Enhancement | What Changes | Scope |
|----|-------------|-------------|-------|
| E1 | Swarm auto-chronicles | `swarm_run` skill: add chronicle capture at step 4 | New behavior in new skill |
| E2 | Diary reads swarm comments | `yf_chronicle_diary` agent: add swarm-aware instruction | Small addition to existing agent |
| E3 | Chronicle detects swarms | `chronicle-check.sh`: add wisp-squash detection | Small addition to existing script |
| E4 | Research-spike auto-archives | `research-spike.formula.json`: add archive step | New formula design |
| E5 | Swarm-archive bridge rule | New rule: `swarm-archive-bridge.md` | New rule file |
| E6 | Researcher aligns with archivist | `yf_swarm_researcher` agent: FINDINGS format matches archive template | Agent design choice |

## Implementation Sequence

### Phase 1: Foundation (scripts, formulas)

**1a. Create `plugins/yf/scripts/swarm-state.sh`**
- Copy from `plugins/yf/scripts/pump-state.sh` (75 lines)
- Change state file path: `.yoshiko-flow/swarm-state.json`
- Same interface: `is-dispatched`, `mark-dispatched`, `mark-done`, `pending`, `clear`

**1b. Create `plugins/yf/formulas/` with 5 formulas**

All `.formula.json` files. Each formula has `vars` (with `feature` required), `steps` (with `id`, `title`, `description`, `needs`), and `SUBAGENT:<type>` annotations in step descriptions.

| Formula | Pattern | Steps |
|---------|---------|-------|
| `feature-build.formula.json` | Research -> Implement -> Review | 3 steps + concept of gates via needs |
| `research-spike.formula.json` | Investigate -> Synthesize -> Archive | 3 steps, research with archive |
| `code-review.formula.json` | Analyze -> Report | 2 steps, read-only |
| `bugfix.formula.json` | Diagnose -> Fix -> Verify | 3 steps |
| `build-test.formula.json` | Implement -> Test -> Review | 3 steps |

### Phase 2: Agents

**2a. Create `plugins/yf/agents/yf_swarm_researcher.md`**
- Read-only research agent (Explore subagent_type)
- Posts `FINDINGS:` comments using archivist-compatible format (E6)

**2b. Create `plugins/yf/agents/yf_swarm_reviewer.md`**
- Read-only review agent
- Posts `REVIEW:` comments, can emit `REVIEW:BLOCK`

**2c. Create `plugins/yf/agents/yf_swarm_tester.md`**
- Test-writing agent (can edit test files)
- Posts `TESTS:` comments with pass/fail results

### Phase 3: Core Skills

**3a. `plugins/yf/skills/swarm_list_formulas/SKILL.md`** — list formulas
**3b. `plugins/yf/skills/swarm_status/SKILL.md`** — show swarm state
**3c. `plugins/yf/skills/swarm_dispatch/SKILL.md`** — core dispatch loop
**3d. `plugins/yf/skills/swarm_run/SKILL.md`** — full lifecycle entry point

### Phase 4: Rules & Integration

**4a. `plugins/yf/rules/swarm-comment-protocol.md`** — comment protocol docs
**4b. `plugins/yf/rules/swarm-formula-dispatch.md`** — plan integration
**4c. `plugins/yf/rules/swarm-archive-bridge.md`** — archive bridge (E5)
**4d. Update `plugins/yf/.claude-plugin/preflight.json`** — register new rules

### Phase 4b: Chronicler & Archivist Enhancements

**4e. Update `plugins/yf/agents/yf_chronicle_diary.md`** (E2)
**4f. Update `plugins/yf/scripts/chronicle-check.sh`** (E3)

### Phase 5: Documentation & Release

**5a. Update `plugins/yf/DEVELOPERS.md`** — add swarm capability
**5b. Update `plugins/yf/README.md`** — add Swarm Execution section
**5c. Update `plugins/yf/.claude-plugin/plugin.json`** — bump to 2.13.0
**5d. Update `CHANGELOG.md`** — add v2.13.0 entry
**5e. Write tests** — `tests/scenarios/unit-swarm-state.yaml`

## Completion Criteria

- [ ] 5 formula files cook without errors
- [ ] 3 new agents follow naming convention and are auto-discovered
- [ ] swarm_run skill drives full wisp lifecycle (create -> dispatch -> squash)
- [ ] swarm_dispatch skill dispatches parallel steps correctly
- [ ] Wisps are ephemeral (not in JSONL, not synced)
- [ ] Comment protocol produces readable audit trail on parent bead
- [ ] Plan tasks with `formula:<name>` label dispatch through swarm
- [ ] Swarm completion auto-creates chronicle bead (E1)
- [ ] research-spike formula creates archive bead in final step (E4)
- [ ] Diary agent enriches swarm-tagged chronicles with step comments (E2)
- [ ] chronicle-check.sh detects wisp squashes as significant activity (E3)
- [ ] swarm-archive-bridge rule suggests archiving when appropriate (E5)
- [ ] All existing tests pass
- [ ] New swarm-state test passes
