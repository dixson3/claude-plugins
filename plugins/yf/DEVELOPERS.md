# Yoshiko Flow — Developer Guide

This guide covers the architecture, conventions, and extension points for developing and contributing to the yf plugin.

## Plugin Architecture

The yf plugin is composed of six artifact types:

- **Skills** — Auto-invoked behaviors defined in `skills/<name>/SKILL.md`
- **Agents** — Specialized agents defined in `agents/<name>.md`
- **Rules** — Behavioral enforcement symlinked into `.claude/rules/`
- **Scripts** — Shell scripts for deterministic operations
- **Hooks** — Pre/post tool-use hooks declared in `plugin.json`
- **Preflight** — Artifact sync engine that installs rules and creates directories

Skills and agents are auto-discovered from directory structure — they are NOT listed in `plugin.json`.

## Naming & Namespacing Convention

All skills and agents MUST be namespaced with their plugin name to prevent collisions when multiple plugins are installed.

### Skills

The `name` field in SKILL.md frontmatter uses `plugin:skill_name` format:

```yaml
---
name: yf:chronicle_capture          # CORRECT — namespaced
description: Capture context
---
```

```yaml
---
name: capture              # WRONG — will collide with other plugins
---
```

Cross-plugin skill references in content also use this format: `/yf:plan_execute`, `/yf:chronicle_capture`.

### Agents

Agent `name` fields use a `plugin_` prefix (underscore, not colon):

```yaml
---
name: yf_chronicle_recall              # CORRECT — prefixed with plugin name
description: Context recovery agent
---
```

### Rules

Rule files installed to `.claude/rules/` use `yf-` prefix (e.g., `yf-beads.md`, `yf-engage-the-plan.md`). Rules are project-scoped, not plugin-scoped, so the prefix prevents collisions.

### Capability-Prefixed Naming

Within a plugin, skills and agents are grouped by **capability**. The capability name is the first segment after the plugin prefix:

    yf:<capability>_<action>      # skill
    yf_<capability>_<role>        # agent
    ys:<capability>[:subtype]     # bead label
    yf-<capability>-<desc>.md     # rule

Current capabilities:

| Capability | Prefix | Skills | Agents |
|---|---|---|---|
| Plan lifecycle | `plan` | plan_engage, plan_create_beads, plan_execute, plan_pump, plan_breakdown, plan_select_agent, plan_dismiss_gate, plan_intake | — |
| Chronicler | `chronicle` | chronicle_capture, chronicle_recall, chronicle_diary, chronicle_disable | yf_chronicle_recall, yf_chronicle_diary |
| Archivist | `archive` | archive_capture, archive_process, archive_disable, archive_suggest | yf_archive_process |
| Core | (none) | setup | — |

### Adding a New Capability

1. Choose a singular noun prefix (e.g., `review`, `lint`)
2. Name skills as `yf:<prefix>_<action>`
3. Name agents as `yf_<prefix>_<role>`
4. Use `ys:<prefix>` for bead labels
5. Use `yf-<prefix>-` for rule filenames

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`

   Skills and agents are auto-discovered from directory structure — do NOT list them in the manifest. Only include official Claude Code schema fields (name, version, description, author, license, hooks, etc.). Custom fields like `dependencies` and `artifacts` go in `preflight.json` (see step 2b).

   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": { "name": "James Dixson", "email": "dixson3@gmail.com" },
     "license": "MIT",
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash(some-command*)",
           "hooks": [
             {
               "type": "command",
               "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-hook.sh"
             }
           ]
         }
       ]
     }
   }
   ```

2b. **Add preflight config** (optional): `.claude-plugin/preflight.json`

   Artifact declarations, dependencies, and setup commands go here — separate from `plugin.json` to avoid Claude Code's strict schema validation.

   ```json
   {
     "dependencies": [],
     "artifacts": {
       "rules": [
         { "source": "rules/my-rule.md", "target": ".claude/rules/my-rule.md" }
       ],
       "directories": ["docs/my-dir"],
       "setup": [
         { "name": "my-setup", "check": "test -d .my-dir", "run": "my-init-cmd" }
       ]
     }
   }
   ```

3. **Add skills** (optional): `skills/<skill_name>/SKILL.md`
   - Frontmatter `name` MUST be `plugin:skill_name` (namespaced)
   - Include `description` and `arguments` in frontmatter
   - Behavior guidelines and instructions in body

4. **Add agents** (optional): `agents/<plugin_agentname>.md`
   - Frontmatter `name` MUST be prefixed with plugin name (e.g., `yf_chronicle_recall`)
   - Include `description` and optional `on-start` in frontmatter
   - Role, personality, and interaction guidelines in body

5. **Add rules** (optional): `rules/<descriptive-name>.md`
   - Behavioral enforcement installed to `.claude/rules/`
   - Use plugin-prefixed names (e.g., `yf-beads.md`)

6. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

7. **Document**: Add `README.md` to the plugin directory

## Plugin Components

### Skills
Automatic behaviors Claude can invoke contextually. Defined in `skills/<name>/SKILL.md` — the directory name determines the skill identifier. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Agents
Specialized agents for specific tasks. Defined in `agents/<name>.md`. Auto-discovered by the plugin system (not listed in `plugin.json`).

### Rules
Behavioral rules declared in `preflight.json` under `artifacts.rules`. Source files live in `rules/` within the plugin; they are symlinked into `.claude/rules/` in the project by the preflight system.

### Scripts
Shell scripts for deterministic operations (e.g., state transitions). Referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/` in hooks and skills.

### Hooks
Pre/post tool-use hooks declared in `plugin.json` under the `hooks` key. Hook commands use `${CLAUDE_PLUGIN_ROOT}` to reference the plugin directory.

## Preflight System

Plugins declare their artifacts (rules, directories, setup commands) in `.claude-plugin/preflight.json` (separate from `plugin.json` to comply with Claude Code's strict manifest schema). A preflight script (`scripts/plugin-preflight.sh`) runs automatically on SessionStart and syncs artifacts to the project using **symlinks** (not copies):

- **Install**: Missing rules are created as symlinks pointing to the plugin source files
- **Update**: Broken or incorrect symlinks are recreated; regular files (from older versions) are migrated to symlinks
- **Remove**: Symlinks for rules no longer in the manifest are deleted
- **Fast path**: Checks `readlink` targets and symlink count — skips sync when all symlinks are correct

Configuration:
- **`.claude/yf.json`** — Gitignored config + preflight lock state (`enabled`, `config`, `updated`, `preflight`).

Rules in `.claude/rules/yf-*.md` are gitignored symlinks pointing to `plugins/yf/rules/`. Edits to plugin source rules are immediately active — no re-sync needed.

## Configuration Model

All config lives in `.claude/yf.json` (gitignored). This single file holds both user settings and preflight lock state.

```json
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs",
    "chronicler_enabled": true,
    "archivist_enabled": true
  },
  "updated": "2026-02-08T...",
  "preflight": {
    "version": "2.8.0",
    "mode": "symlink",
    "rules": { "..." }
  }
}
```

The `yf-config.sh` shell library provides accessor functions:

| Function | Description |
|----------|-------------|
| `yf_merged_config` | Read merged config as JSON |
| `yf_is_enabled` | Check master switch |
| `yf_is_chronicler_on` | Check chronicler enabled |
| `yf_is_archivist_on` | Check archivist enabled |
| `yf_read_field` | Read arbitrary config field |
| `yf_config_exists` | Check if config file exists |

## Testing

The test suite uses a Go harness at `tests/harness/` with YAML scenarios at `tests/scenarios/`.

### Running Tests

```bash
# Unit tests only (fast, shell-only)
bash tests/run-tests.sh --unit-only

# Full suite (includes integration tests with Claude sessions)
bash tests/run-tests.sh
```

### Writing Test Scenarios

Test scenarios are YAML files in `tests/scenarios/`. Unit tests (prefixed `unit-`) test shell scripts directly without Claude sessions:

```yaml
name: "Test description"
type: unit
steps:
  - name: "Step description"
    command: "bash script.sh arg1 arg2"
    env:
      VAR: "value"
    expect:
      exit_code: 0
      stdout_contains: ["expected output"]
      stdout_not_contains: ["unexpected output"]
```

All new work MUST include automated test cases — add YAML scenarios and verify with `bash tests/run-tests.sh --unit-only`.
