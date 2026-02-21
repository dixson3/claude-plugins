# Yoshiko Flow — Developer Guide

This guide covers the architecture, conventions, and extension points for the yf plugin.

## Plugin Architecture

The yf plugin is composed of six artifact types:

- **Skills** — Contextually invoked behaviors, defined in `skills/<name>/SKILL.md`
- **Agents** — Task-specific subprocesses, defined in `agents/<name>.md`
- **Rules** — Behavioral enforcement, symlinked into `.claude/rules/`
- **Scripts** — Shell scripts for deterministic operations
- **Hooks** — Lifecycle and tool-use hooks (SessionStart, SessionEnd, PreCompact, PreToolUse), declared in `plugin.json`
- **Preflight** — Artifact sync engine that installs rules and creates directories

Skills and agents are auto-discovered from directory structure — they are NOT listed in `plugin.json`. Rules are declared in `preflight.json` and symlinked into the project. Scripts and hooks are referenced by path from skills, agents, and hook declarations.

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
| Swarm | `swarm` | swarm_run, swarm_dispatch, swarm_status, swarm_list_formulas, swarm_select_formula, swarm_react, swarm_qualify | yf_swarm_researcher, yf_swarm_reviewer, yf_swarm_tester |
| Engineer | `engineer` | engineer_analyze_project, engineer_reconcile, engineer_update, engineer_suggest_updates | yf_engineer_synthesizer |
| Coder | `code` | (uses swarm formulas) | yf_code_researcher, yf_code_writer, yf_code_tester, yf_code_reviewer |
| Memory | `memory` | memory_reconcile | — |
| Beads | `beads` | beads_setup | — |
| Session | `session` | session_land | — |
| Plugin | `plugin` | plugin_setup, plugin_issue | — |
| Issue | `issue` | issue_capture, issue_process, issue_disable, issue_list, issue_plan | yf_issue_triage |

### Adding a New Capability

1. Choose a singular noun prefix (e.g., `review`, `lint`)
2. Name skills as `yf:<prefix>_<action>`
3. Name agents as `yf_<prefix>_<role>`
4. Use `ys:<prefix>` for bead labels
5. Use `yf-<prefix>-` for rule filenames

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`

   Only include official Claude Code schema fields (name, version, description, author, license, hooks). Skills and agents are auto-discovered from directory structure — do not list them in the manifest.

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

3. **Add preflight config** (optional): `.claude-plugin/preflight.json`

   Artifact declarations, dependencies, and setup commands live here — separate from `plugin.json` to comply with Claude Code's strict manifest schema.

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

4. **Add skills** (optional): `skills/<skill_name>/SKILL.md`
   - Frontmatter `name` MUST be `plugin:skill_name` (namespaced)
   - Include `description` and `arguments` in frontmatter
   - Behavior guidelines and instructions in body

5. **Add agents** (optional): `agents/<plugin_agentname>.md`
   - Frontmatter `name` MUST be prefixed with plugin name (e.g., `yf_chronicle_recall`)
   - Include `description` and optional `on-start` in frontmatter
   - Role, personality, and interaction guidelines in body

6. **Add rules** (optional): `rules/<descriptive-name>.md`
   - Behavioral enforcement installed to `.claude/rules/`
   - Use plugin-prefixed names (e.g., `yf-beads.md`)

7. **Register in marketplace**: Update `.claude-plugin/marketplace.json`

8. **Document**: Add `README.md` to the plugin directory

## Activation Model

Yoshiko Flow uses **explicit per-project activation** (DD-015). Installing yf globally does not activate it — each project must run `/yf:plugin_setup` to opt in.

### Three-Condition Gate

`yf_is_enabled()` enforces three conditions (fail-closed):

1. **Config exists** — `.yoshiko-flow/config.json` must be present
2. **Enabled flag** — `enabled` field must not be `false`
3. **bd available** — The bd CLI must be available

When any condition fails, yf is inactive: skills refuse (via `yf-activation-check.sh`), hooks exit silently, and preflight removes rules.

### Activation Check Script

`yf-activation-check.sh` is a standalone script that outputs structured JSON:

```json
{"active": true}
{"active": false, "reason": "No .yoshiko-flow/config.json found", "action": "Run /yf:plugin_setup to configure this project"}
```

All skills (except `/yf:plugin_setup`) include an activation guard that runs this script before executing.

### Beads Dependency

The `yf_bd_available()` function checks `command -v bd`.

### Fail-Open vs. Fail-Closed

The **activation model** is fail-closed: no config = inactive. This is distinct from hooks and optional config flags, which remain fail-open:

- `yf_is_enabled()` — fail-closed (three conditions)
- `_yf_check_flag()` — fail-open (used by `yf_is_prune_on_complete`, etc.)
- Hooks — fail-open (exit 0 on internal errors, TC-005)

## Preflight System

Plugins declare their artifacts (rules, directories, setup commands) in `.claude-plugin/preflight.json`. This file is separate from `plugin.json` to comply with Claude Code's strict manifest schema.

A preflight script (`scripts/plugin-preflight.sh`) runs on SessionStart and syncs artifacts to the project using **symlinks**, not copies:

- **Install**: Missing rules are created as symlinks pointing to the plugin source files
- **Update**: Broken or incorrect symlinks are recreated; regular files (from older versions) are migrated to symlinks
- **Remove**: Symlinks for rules no longer in the manifest are deleted
- **Fast path**: Checks `readlink` targets and symlink count — skips sync when all symlinks are correct

Lock state is stored in `.yoshiko-flow/lock.json` under the `preflight` key.

Because rules are symlinks, edits to plugin source files are immediately active — no re-sync needed.

### Project Environment Setup

Preflight also calls `setup-project.sh` after setup commands to manage two project-level files:

**`.gitignore` sentinel block** — A bracketed block of entries for yf ephemeral files:

```
# >>> yf-managed >>>
# Plugin-managed rule symlinks
.claude/rules/yf/
# <<< yf-managed <<<
```

The sentinel markers (`# >>> yf-managed >>>` / `# <<< yf-managed <<<`) make the block identifiable for idempotent updates. User entries outside the block are preserved. Block replacement uses awk for bash 3.2 / macOS compatibility.

**AGENTS.md cleanup** — `bd init` creates an AGENTS.md with session-close instructions. The yf rules are the canonical source for agent instructions (beads workflow, session protocol), so this content is removed to prevent duplication and conflicts. The script detects and removes bd-generated content, preserving any non-bd sections.

## Configuration Model

Config is split across two files in `.yoshiko-flow/`:

- **`config.json`** — User config (committed to git): `{enabled, config}`
- **`lock.json`** — Preflight lock state (gitignored): `{updated, preflight}`

`.yoshiko-flow/.gitignore` ignores everything except `config.json`, so config is committable while state remains ephemeral.

```json
// .yoshiko-flow/config.json (committed)
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs"
  }
}

// .yoshiko-flow/lock.json (gitignored)
{
  "updated": "2026-02-13T...",
  "preflight": {
    "plugins": {
      "yf": {
        "version": "2.11.0",
        "mode": "symlink",
        "artifacts": { "..." }
      }
    }
  }
}
```

The `yf-config.sh` shell library provides accessor functions:

| Function | Description |
|----------|-------------|
| `yf_merged_config` | Read merged config as JSON |
| `yf_is_enabled` | Three-condition activation gate (config exists + enabled + bd available) |
| `yf_bd_available` | Check if bd CLI is available (`command -v bd`) |
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
