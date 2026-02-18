# Plan 42: Plugin Activation Gate and Beads Dependency Enforcement

**Status:** Completed
**Date:** 2026-02-17

## Overview

The yf plugin currently activates on any project where it's installed, even without explicit per-project setup. It has no formal dependency on the beads plugin despite requiring it for all task tracking. The `yf_is_enabled` check is fail-open (no config = enabled). This plan adds three-condition activation gating so yf can be installed at user scope but only activates per-project when explicitly configured, with beads installed, and `.yoshiko-flow/` present. It also updates agent-facing beads references to use beads skills (hybrid approach: scripts keep `bd` CLI, agent instructions reference `/beads:*` skills).

## Implementation Sequence

### Step 0: Specification updates (anchor the requirements before code)

All spec changes require operator approval per Rule 1.4. Present changes for approval before writing.

#### PRD.md

- Revise G7: "Achieve zero-configuration setup with fail-open hooks and explicit per-project activation."
- Revise TC-003: Add beads plugin dependency alongside beads-cli
- Revise REQ-028: Add prerequisite — setup requires beads plugin
- Add REQ-034: Three-condition activation gate (P0, Core)
- Add REQ-035: Beads plugin dependency enforcement (P0, Core)
- Add REQ-036: User-scope install with per-project activation (P0, Core)
- Add FS-040: Activation gate implementation details
- Add FS-041: Preflight dependency check implementation

#### EDD/CORE.md

- Add DD-015: Three-Condition Activation Model
- Add DD-016: Hybrid Beads Routing
- Update Architecture diagram: Add "Activation Gate"
- Update Enforcement Model: Add skill-level activation gate

#### IG/marketplace.md

- Revise UC-023: Add beads dependency and config checks to preflight
- Add UC-029: Plugin Activation Gate Check
- Add UC-030: Per-Project Activation via /yf:setup

#### IG/beads-integration.md

- Revise UC-025: Add beads plugin precondition
- Add hybrid routing note

#### TODO.md

- Add TODO-027: E2E validation of activation gate (P2)
- Add TODO-028: Validate hybrid beads routing (P2)

### Step 1: Core activation logic — yf-config.sh

- Add `yf_beads_installed()` function
- Rewrite `yf_is_enabled()` to three-condition check (fail-closed)
- Keep `_yf_check_flag` unchanged for optional config flags

### Step 2: Activation check script — yf-activation-check.sh (new)

- Standalone script outputting structured JSON
- Always exits 0; caller reads JSON
- Three condition checks with specific messages

### Step 3: Preflight enhancement — plugin-preflight.sh

- Insert beads dependency check
- Add inactive exit path when beads missing
- Update setup-needed signal to remove rules when no config

### Step 4: Dependency declaration — preflight.json

- Populate `dependencies` array with beads plugin

### Step 5: Setup skill — setup/SKILL.md

- Add dependency check before config writes

### Step 6: Skill activation guards — 26 SKILL.md files

- Insert standardized activation guard block after YAML frontmatter

### Step 7: Rules update — yf-rules.md

- Add Rule 1.0: Activation Gate
- Update Rule 4.1: Beads skills for agent operations

### Step 8: Tests

- New unit-activation.yaml
- Update unit-yf-config.yaml
- Update unit-preflight.yaml
- Update unit-preflight-disabled.yaml

### Step 9: Documentation and version bump

- DEVELOPERS.md: Activation model section
- README.md: Activation section
- CHANGELOG.md: v2.21.0 entry
- plugin.json: version bump

## Completion Criteria

- [ ] All spec changes approved and written (Step 0)
- [ ] `yf_is_enabled()` enforces three-condition check
- [ ] `yf-activation-check.sh` returns structured JSON
- [ ] Preflight handles missing beads gracefully
- [ ] preflight.json declares beads dependency
- [ ] `/yf:setup` checks beads before activating
- [ ] All 26 skills have activation guards
- [ ] Rules include activation gate (Rule 1.0)
- [ ] All tests pass including new activation tests
- [ ] Documentation updated, version bumped to 2.21.0
