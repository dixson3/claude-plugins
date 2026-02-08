# Plan 09: Remove Roles Plugin — Inline to Rules

**Status:** Completed
**Date:** 2026-02-08

## Context

The roles plugin (`plugins/roles/`) was designed to provide per-agent behavioral instructions — a middle ground between global rules (apply to everyone) and agent bodies (apply to one agent). In practice, it's non-functional:

- **1 role exists** (`watch-for-chronicle-worthiness`), assigned to `primary`
- **Primary never loads it** — no automatic mechanism triggers `/roles:apply` for the primary session
- **2 chronicler agents** have `on-start: /roles:apply <name>`, but **zero roles are assigned to them** — the calls are no-ops
- **5 skills** manage what amounts to dead infrastructure

The plugin adds a dependency for chronicler, a shell script with fragile YAML parsing, and complexity without delivering value.

**Resolution:** Claude Code already has two mechanisms for behavioral instructions:
1. **Rules** (`.claude/rules/`) — auto-loaded for all sessions
2. **Agent bodies** — loaded only for that specific agent

The sole role (`watch-for-chronicle-worthiness`) works fine as a global rule because its trigger conditions (completing features, making architecture decisions) only occur during interactive primary-session work. Short-lived subagents will never hit those triggers.

## Implementation

### Phase 1: Migrate role to rule (chronicler plugin)

1. **Create rule file** `plugins/chronicler/rules/watch-for-chronicle-worthiness.md`
   - Same content as current role file, minus the `applies-to` frontmatter
   - Keep the `name` field in frontmatter for identification

2. **Delete role source** `plugins/chronicler/roles/watch-for-chronicle-worthiness.md`
   - Then delete empty `plugins/chronicler/roles/` directory

3. **Update `plugins/chronicler/agents/chronicler_recall.md`**
   - Remove `on-start: /roles:apply chronicler_recall` from frontmatter (it's a no-op)

4. **Update `plugins/chronicler/agents/chronicler_diary.md`**
   - Remove `on-start: /roles:apply chronicler_diary` from frontmatter (it's a no-op)

5. **Rewrite `plugins/chronicler/skills/init/SKILL.md`**
   - Remove Steps 2-4 (roles:init, install role, assign role)
   - Add `watch-for-chronicle-worthiness.md` to Step 6 (rules install) alongside `plan-transition-chronicle.md`
   - Update description: remove "roles" mention
   - Renumber to 4 steps: beads init → diary dir → install rules → verify
   - Update expected output

6. **Update `plugins/chronicler/rules/plan-transition-chronicle.md`** line 22
   - Change "the watch-for-chronicle-worthiness role handles it" → "the watch-for-chronicle-worthiness rule handles it"

7. **Update `plugins/chronicler/README.md`**
   - Remove `roles plugin` from Dependencies
   - Rename "Role: watch-for-chronicle-worthiness" section → "Rule: watch-for-chronicle-worthiness"
   - Change "Installed to `.claude/roles/`" → "Installed to `.claude/rules/`"
   - Update Installation steps (remove roles init mention)
   - Update Workflow section (remove "role suggests" → "rule suggests")

8. **Bump chronicler version** in `plugins/chronicler/.claude-plugin/plugin.json` to `1.2.0`

### Phase 2: Delete roles plugin

9. **Delete `plugins/roles/`** entirely

### Phase 3: Update marketplace & docs

10. **Update `.claude-plugin/marketplace.json`**
    - Remove the roles plugin entry
    - Bump chronicler version to `1.2.0`
    - Bump marketplace version to `1.6.0`

11. **Update `CLAUDE.md`**
    - Remove `roles` from "Current Plugins" list (line listing roles v1.1.0)

12. **Update `README.md`**
    - Remove roles plugin references

13. **Update `CHANGELOG.md`**
    - Add `[1.6.0]` entry documenting the removal and migration

### Phase 4: Clean up installed state

14. **Remove `.claude/roles/`** directory (contains `roles-apply.sh` and the old role file)

15. **Install migrated rule** — copy `watch-for-chronicle-worthiness.md` to `.claude/rules/`

### Phase 5: Tests

16. **Add test scenario** `tests/scenarios/unit-chronicler-init.yaml`
    - Verify chronicler init installs `watch-for-chronicle-worthiness.md` to `.claude/rules/`
    - Verify no reference to `/roles:init` or `/roles:assign` in init skill

17. **Run tests**: `bash tests/run-tests.sh --unit-only`

### Phase 6: Memory update

18. **Update MEMORY.md**
    - Add plan-09 to Current Plans
    - Remove roles references from Workflows Plugin Architecture section
    - Update plugin dependency note

## Files Modified

| File | Action |
|------|--------|
| `plugins/chronicler/rules/watch-for-chronicle-worthiness.md` | Create (migrate from roles/) |
| `plugins/chronicler/roles/watch-for-chronicle-worthiness.md` | Delete |
| `plugins/chronicler/roles/` | Delete directory |
| `plugins/chronicler/agents/chronicler_recall.md` | Remove `on-start` |
| `plugins/chronicler/agents/chronicler_diary.md` | Remove `on-start` |
| `plugins/chronicler/skills/init/SKILL.md` | Rewrite (remove roles dependency) |
| `plugins/chronicler/rules/plan-transition-chronicle.md` | s/role/rule/ |
| `plugins/chronicler/README.md` | Remove roles dependency, update sections |
| `plugins/chronicler/.claude-plugin/plugin.json` | Bump to 1.2.0 |
| `plugins/roles/` | Delete entire directory |
| `.claude-plugin/marketplace.json` | Remove roles entry, bump versions |
| `CLAUDE.md` | Remove roles from plugin list |
| `README.md` | Remove roles references |
| `CHANGELOG.md` | Add 1.6.0 entry |
| `.claude/roles/` | Delete directory |
| `.claude/rules/watch-for-chronicle-worthiness.md` | Create (installed copy) |
| `tests/scenarios/unit-chronicler-init.yaml` | Create test |

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass
2. `.claude/rules/watch-for-chronicle-worthiness.md` exists and has correct content (no `applies-to`)
3. `.claude/roles/` directory does not exist
4. `plugins/roles/` directory does not exist
5. No remaining references to `/roles:` in any plugin file
6. `grep -r "roles" plugins/` returns only the changelog/history references
