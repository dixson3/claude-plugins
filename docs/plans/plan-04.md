# Plan 04: Roles & Chronicler Plugin Consistency Fixes

**Status: Completed**

## Context

The workflows plugin was recently updated to v1.1.0 with significant structural changes (plan lifecycle, hook format updates, init pattern). The roles and chronicler plugins remained at v1.0.0 and had drifted out of consistency. This plan corrected inconsistencies in hook formats, init patterns, cross-plugin coupling, and documentation.

## Inconsistencies Found

| # | Plugin | Issue | Severity |
|---|--------|-------|----------|
| 1 | chronicler | Init Step 7 (manual hook config) is redundant — `plugin.json` already handles it | Medium |
| 2 | chronicler | Init Step 7 uses wrong hook format (flat `command` vs nested `hooks[]`) and wrong matcher (`git push:*` vs `git push*`) | Medium |
| 3 | chronicler | Init Step 4 copies `roles-apply.sh` across plugins (fragile coupling) | Medium |
| 4 | chronicler | `pre-push-diary.sh` header comments show outdated install path and format | Low |
| 5 | chronicler | README pre-push hook section shows wrong format and path | Low |
| 6 | chronicler | Init expected output says [1/6]–[6/6] but instructions list 7 steps | Low |
| 7 | workflows | Init SKILL.md Step 5 shows flat hook format instead of nested | Low |
| 8 | roles | No `/roles:init` skill (inconsistent with workflows and chronicler) | Medium |
| 9 | CLAUDE.md | Plugin structure doesn't document `roles/` directory | Low |

## Changes

### 1. Create `/roles:init` skill (NEW FILE)

**File**: `plugins/roles/skills/init/SKILL.md`

New init skill that:
1. Creates `.claude/roles/` directory
2. Copies `roles-apply.sh` from `plugins/roles/scripts/` to `.claude/roles/`
3. Makes script executable
4. Verifies installation

### 2. Fix chronicler init SKILL.md

**File**: `plugins/chronicler/skills/init/SKILL.md`

- Removed Step 4 (copy `roles-apply.sh` from roles plugin) — replaced with `/roles:init` invocation
- Removed Step 7 (manual hook config) — `plugin.json` auto-discovery handles it
- Renumbered to 5 steps, fixed Expected Output to match

### 3. Fix `pre-push-diary.sh` header comments

**File**: `plugins/chronicler/hooks/pre-push-diary.sh`

Replaced outdated install path and flat hook format with note that `plugin.json` manages installation automatically.

### 4. Fix chronicler README pre-push hook section

**File**: `plugins/chronicler/README.md`

- Updated "This will:" list — removed item about manual hook config, added roles init
- Replaced JSON example with note that `plugin.json` handles it automatically

### 5. Fix workflows init hook format documentation

**File**: `plugins/workflows/skills/init/SKILL.md`

Updated Step 5 JSON example from flat `"command"` format to nested `"hooks": [{"type":"command","command":"..."}]` format.

### 6. Update CLAUDE.md

- Added `roles/` directory to plugin structure template
- Updated Current Plugins versions: roles → v1.1.0, chronicler → v1.1.0

### 7. Version bumps

- `plugins/roles/.claude-plugin/plugin.json`: 1.0.0 → 1.1.0
- `plugins/chronicler/.claude-plugin/plugin.json`: 1.0.0 → 1.1.0
- `.claude-plugin/marketplace.json`: roles 1.0.0 → 1.1.0, chronicler 1.0.0 → 1.1.0, marketplace 1.2.0 → 1.3.0

### 8. Update CHANGELOG.md

Added `[1.3.0]` entry documenting all changes.
