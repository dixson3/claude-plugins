# Plan 24: Migrate yf state from `.claude/` to `.yoshiko-flow/`

**Status:** Completed
**Date:** 2026-02-13

## Overview

yf currently stores all config and state inside `.claude/` alongside Claude Code's own files. This couples plugin state to the IDE directory and makes everything gitignored (config can't be shared across a team). Moving to a dedicated `.yoshiko-flow/` directory separates concerns, lets `yf.json` config be committed, and isolates ephemeral state behind its own `.gitignore`.

## Target Layout

```
.yoshiko-flow/
├── .gitignore         # ignores everything except yf.json
├── yf.json            # config only (COMMITTED)
├── lock.json          # preflight lock state (gitignored)
├── task-pump.json     # pump dispatch state (gitignored)
├── plan-gate          # plan lifecycle gate (gitignored)
└── plan-intake-ok     # intake session marker (gitignored)
```

Rule symlinks stay in `.claude/rules/` (Claude Code's discovery location — unchanged).

## Implementation Sequence

### Phase 1: Core Scripts (5 files)

1. `plugins/yf/scripts/yf-config.sh` — Change `_YF_JSON` path
2. `plugins/yf/scripts/plugin-preflight.sh` — Migration logic, lock split, new paths
3. `plugins/yf/scripts/setup-project.sh` — Update MANAGED_BLOCK
4. `plugins/yf/scripts/pump-state.sh` — Change STATE_FILE path
5. `plugins/yf/scripts/plan-exec.sh` — Change PLAN_GATE path

### Phase 2: Hooks (2 files)

6. `plugins/yf/hooks/code-gate.sh` — Update GATE_FILE, INTAKE_MARKER, exempt patterns
7. `plugins/yf/hooks/exit-plan-gate.sh` — Update GATE_FILE, mkdir

### Phase 3: Skills (4 files)

8. `plugins/yf/skills/setup/SKILL.md` — All .claude/yf.json refs
9. `plugins/yf/skills/plan_intake/SKILL.md` — Gate and intake marker paths
10. `plugins/yf/skills/plan_engage/SKILL.md` — Gate path and mkdir
11. `plugins/yf/skills/plan_dismiss_gate/SKILL.md` — Gate path

### Phase 4: Rules & Preflight Declarations (2 files)

12. `plugins/yf/rules/yf-auto-chain-plan.md` — Gate path reference
13. `plugins/yf/.claude-plugin/preflight.json` — Add .yoshiko-flow directory

### Phase 5: Documentation (3 files)

14. `plugins/yf/README.md` — Config path, artifacts, JSON example
15. `plugins/yf/DEVELOPERS.md` — Lock state, gitignore, config model
16. Root `README.md` — Config path

### Phase 6: Tests (28 files + 1 new)

Mechanical path substitutions across all test scenarios, plus new migration test.

### Phase 7: Cleanup

- CHANGELOG.md update
- Version bump to 2.11.0

## Completion Criteria

- [ ] All scripts reference `.yoshiko-flow/` for config and state
- [ ] Migration logic moves old `.claude/yf.json` + state files on first run
- [ ] `.yoshiko-flow/.gitignore` created automatically, ignoring everything except `yf.json`
- [ ] Lock state separated into `lock.json`
- [ ] All hooks reference new paths and exempt `.yoshiko-flow/`
- [ ] All skills reference new paths
- [ ] Tests updated and passing
- [ ] New migration test validates split + move + cleanup
- [ ] Documentation updated
- [ ] CHANGELOG and version bump done
