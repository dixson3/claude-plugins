# Plan 21: Capability-Prefixed Skill & Agent Naming Convention

**Status:** Completed
**Date:** 2026-02-08

## Overview

Rename all 17 skills and 3 agents to follow `yf:<capability>_<action>` convention. Update all cross-references (rules, hooks, scripts, tests, docs). Document the convention in CLAUDE.md for future development.

## Naming Convention

**Pattern:** `yf:<capability>_<action>`

| Capability | Prefix | Purpose |
|---|---|---|
| Plan lifecycle | `plan` | Plan creation, state machine, execution |
| Chronicler | `chronicle` | Context capture, recall, diary generation |
| Archivist | `archive` | Research & decision documentation |
| Core | (none) | Plugin-level operations |

## Complete Rename Mapping

### Skills (17 total, 13 renamed, 4 unchanged)

| Current | New |
|---|---|
| `yf:capture` | `yf:chronicle_capture` |
| `yf:recall` | `yf:chronicle_recall` |
| `yf:diary` | `yf:chronicle_diary` |
| `yf:disable` | `yf:chronicle_disable` |
| `yf:archive` | `yf:archive_capture` |
| `yf:archive_process` | (unchanged) |
| `yf:archive_disable` | (unchanged) |
| `yf:archive_suggest` | (unchanged) |
| `yf:engage_plan` | `yf:plan_engage` |
| `yf:plan_to_beads` | `yf:plan_create_beads` |
| `yf:plan_intake` | (unchanged) |
| `yf:execute_plan` | `yf:plan_execute` |
| `yf:task_pump` | `yf:plan_pump` |
| `yf:breakdown_task` | `yf:plan_breakdown` |
| `yf:select_agent` | `yf:plan_select_agent` |
| `yf:dismiss_gate` | `yf:plan_dismiss_gate` |
| `yf:setup` | (unchanged) |

### Agents (3 total, all renamed)

| Current | New |
|---|---|
| `yf_recall` | `yf_chronicle_recall` |
| `yf_diary` | `yf_chronicle_diary` |
| `yf_archivist` | `yf_archive_process` |

## Implementation Sequence

### Phase 1: Skill Directory Renames (13 renames)
### Phase 2: Agent File Renames (3 renames)
### Phase 3: Cross-Reference Updates (bulk find/replace)
### Phase 4: Test Scenario Updates
### Phase 5: Convention Documentation
### Phase 6: Version Bump & Changelog

## Completion Criteria

- [ ] All 13 skill directories renamed via `git mv`
- [ ] All 3 agent files renamed via `git mv`
- [ ] All `name:` frontmatter fields updated
- [ ] All cross-references updated in skills, agents, rules, hooks
- [ ] CLAUDE.md updated with capability-prefixed naming convention
- [ ] MEMORY.md updated with new skill/agent names
- [ ] README.md (root + plugin) updated
- [ ] Test scenarios updated with new names
- [ ] New naming convention test scenario added
- [ ] CHANGELOG.md has new entry
- [ ] Plugin version bumped to 2.8.0
- [ ] `bash tests/run-tests.sh --unit-only` passes
