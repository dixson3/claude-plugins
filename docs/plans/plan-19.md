# Plan 19: Archivist Capability for yf Plugin

**Status:** Completed
**Date:** 2026-02-08

## Overview

Add archivist capability to the yf plugin for capturing research findings and design decisions as permanent, indexed documentation. The chronicler captures working context as ephemeral beads; the archivist captures the "why" — research topics with references and design decisions with alternatives — as permanent docs under `docs/research/` and `docs/decisions/`.

Adds 4 skills (`yf:archive`, `yf:archive_process`, `yf:archive_disable`, `yf:archive_suggest`), 1 agent (`yf_archivist`), 2 rules, and 1 script. Integrates with existing config, preflight, hooks, and plan lifecycle. Version bump to 2.6.0.

## Implementation Sequence

### Phase 1: Config Infrastructure
- Add `yf_is_archivist_on()` to `yf-config.sh`
- Add conditional archivist rule handling to `plugin-preflight.sh`
- Add archivist rules and directories to `preflight.json`
- Add archivist config question to `yf:setup`
- Tests: `unit-archivist-config.yaml`, `unit-preflight-archivist.yaml`

### Phase 2: Rules
- Create `yf-watch-for-archive-worthiness.md` detection rule
- Create `yf-plan-transition-archive.md` plan transition rule

### Phase 3: Skills + Agent
- Create `yf:archive` capture skill
- Create `yf_archivist` processing agent
- Create `yf:archive_process` processing skill
- Create `yf:archive_disable` close-without-docs skill
- Add `docs/research/` and `docs/decisions/` exemptions to `code-gate.sh`

### Phase 4: Suggest Script + Skill
- Create `archive-suggest.sh` commit scanner script
- Create `yf:archive_suggest` skill
- Tests: `unit-archive-suggest.yaml`

### Phase 5: Lifecycle Integration
- Extend `pre-push-diary.sh` with archive bead check
- Add archive processing to `yf:execute_plan` completion step
- Tests: `unit-pre-push-archive.yaml`

### Phase 6: Documentation + Version
- Version bump `plugin.json` to 2.6.0
- Update `README.md`, `marketplace.json`, `CHANGELOG.md`, `MEMORY.md`

## Completion Criteria

- [ ] `yf_is_archivist_on()` config function works with default/true/false
- [ ] Preflight conditionally installs/removes archivist rules based on config
- [ ] `/yf:setup` asks archivist question and persists answer
- [ ] `/yf:archive type:research` creates properly labeled bead with structured content
- [ ] `/yf:archive type:decision` creates properly labeled bead with DEC-NNN ID
- [ ] `/yf:archive_process` generates SUMMARY.md files and updates indexes
- [ ] `/yf:archive_suggest` scans commits and optionally creates draft beads
- [ ] Pre-push hook warns about open archive beads
- [ ] Plan completion triggers archive processing
- [ ] `code-gate.sh` exempts `docs/research/` and `docs/decisions/`
- [ ] All new and existing unit tests pass
- [ ] Version bumped to 2.6.0, CHANGELOG updated
