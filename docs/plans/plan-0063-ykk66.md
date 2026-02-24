# Plan: Automatic Semver Enforcement on Push

## Context

The yf plugin version has been stuck at 3.0.0 since Plan 0056, despite 6 plans (0057-0062) shipping bug fixes, new features, new test cases, and a new IG specification. The existing `scripts/bump-version.sh` handles the file updates but is manual-only — nothing enforces that a version bump happens before pushing code changes. This plan adds a pre-push check that blocks pushes when plugin code has changed without a version bump, and adds a session_land step to prompt for the bump.

## Changes (3 items)

### 1. Pre-push version-check hook (`plugins/yf/hooks/pre-push-version.sh`)

New PreToolUse hook on `Bash(git push*)`, inserted into the existing hook chain alongside `pre-push-land.sh`.

**Logic:**
1. Source `yf-config.sh`, guard on `yf_is_enabled`
2. Read current version from `plugins/yf/.claude-plugin/plugin.json`
3. Diff `HEAD` vs `origin/main` (or tracking branch) for changes in `plugins/yf/` — excluding docs, CHANGELOG.md, and test-only changes
4. If plugin code changed AND version is unchanged from remote: **block** (exit 2) with message directing user to run `bash scripts/bump-version.sh <version>`
5. If no plugin code changed, or version already bumped: **allow** (exit 0)

**Change detection scope** (files that warrant a version bump):
- `plugins/yf/scripts/*.sh`
- `plugins/yf/hooks/*.sh`
- `plugins/yf/skills/*/SKILL.md`
- `plugins/yf/agents/*.md`
- `plugins/yf/rules/*.md`
- `plugins/yf/formulas/*.json`
- `plugins/yf/.claude-plugin/plugin.json` (manifest changes)
- `plugins/yf/.claude-plugin/preflight.json`

**Excluded** (don't require version bump):
- `plugins/yf/README.md`, `plugins/yf/DEVELOPERS.md`
- `tests/scenarios/*.yaml` (test-only)
- `docs/**`
- `CHANGELOG.md`, `README.md`, `CLAUDE.md` (root-level docs)

### 2. Register hook in `plugin.json`

Add `pre-push-version.sh` to the existing `Bash(git push*)` PreToolUse hook array, after `pre-push-land.sh` (landing prerequisites) and before `pre-push-diary.sh` (advisory).

Order:
1. `pre-push-land.sh` — blocks on dirty tree / in-progress tasks
2. `pre-push-version.sh` — blocks on missing version bump **(new)**
3. `pre-push-diary.sh` — advisory open chronicles warning

### 3. Session land step: version bump prompt

Add a step to `session_land/SKILL.md` between Step 8b (clean completed plans) and Step 9 (commit). When plugin code has changed and the version hasn't been bumped:
- Present the changes summary
- Ask operator for the new version via AskUserQuestion with options:
  - "Patch (X.Y.Z+1)" — bug fixes, refactoring, test additions
  - "Minor (X.Y+1.0)" — new features, new specs, capability additions
  - "Major (X+1.0.0)" — breaking changes
  - "Skip version bump" — escape hatch
- Run `bash scripts/bump-version.sh <chosen-version>`
- Remind operator to add CHANGELOG entry (or offer to draft one)

## Critical Files

- `plugins/yf/hooks/pre-push-version.sh` — **new** (hook implementation)
- `plugins/yf/.claude-plugin/plugin.json` — add hook registration
- `plugins/yf/skills/session_land/SKILL.md` — add version bump step
- `scripts/bump-version.sh` — existing, no changes needed
- `plugins/yf/.claude-plugin/plugin.json` — version source of truth

## Verification

1. Run baseline: `bash tests/run-tests.sh --unit-only`
2. Add test scenario `unit-pre-push-version.yaml`:
   - Case 1: No plugin changes → exits 0
   - Case 2: Plugin script changed, same version → exits 2 (blocked)
   - Case 3: Plugin script changed, version bumped → exits 0
   - Case 4: Only test/doc changes → exits 0
   - Case 5: yf disabled → exits 0
3. Full suite: `bash tests/run-tests.sh --unit-only`
4. Manual check: immediate bump to 3.1.0 with CHANGELOG entry covering plans 0057-0062
