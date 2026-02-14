# Developer Guide

Guide for contributing plugins to this marketplace and working with the codebase.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
├── plugins/
│   └── yf/                 # Yoshiko Flow plugin
│       ├── .claude-plugin/
│       │   ├── plugin.json     # Plugin manifest
│       │   └── preflight.json  # Artifact declarations
│       ├── skills/         # Auto-invoked skills (*/SKILL.md)
│       ├── agents/         # Specialized agents (*.md)
│       ├── rules/          # Behavioral rules (*.md)
│       ├── scripts/        # Shell scripts (*.sh)
│       ├── hooks/          # Pre/post tool-use hooks (*.sh)
│       └── README.md       # Plugin documentation
├── docs/
│   ├── plans/              # Plan documentation
│   └── diary/              # Generated diary entries
├── tests/
│   ├── harness/            # Go test harness source
│   ├── scenarios/          # YAML test scenarios (unit-*.yaml)
│   └── run-tests.sh        # Test runner script
├── CLAUDE.md               # Claude Code guidance
├── DEVELOPERS.md           # This file
├── README.md               # Public-facing overview
├── LICENSE                 # MIT License
└── CHANGELOG.md            # Version history
```

## Plugin Structure

Each plugin follows a standard directory layout:

```
plugin-name/
├── .claude-plugin/
│   ├── plugin.json       # Plugin manifest (required)
│   └── preflight.json    # Artifact declarations (optional)
├── skills/               # Automatic skills
│   └── skill-name/
│       └── SKILL.md
├── agents/               # Specialized agents
│   └── *.md
├── rules/                # Behavioral rules
│   └── *.md
├── scripts/              # Shell scripts
│   └── *.sh
├── hooks/                # Pre/post tool-use hooks
│   └── *.sh
└── README.md             # Plugin documentation
```

Skills and agents are auto-discovered from directory structure — they are NOT listed in `plugin.json`. Rules are declared in `preflight.json` and symlinked into the project. Scripts and hooks are referenced by path from skills, agents, and hook declarations.

## Creating a New Plugin

1. **Create plugin directory**: `plugins/<plugin-name>/`

2. **Add plugin manifest**: `.claude-plugin/plugin.json`

   Only include official Claude Code schema fields (name, version, description, author, license, hooks).

   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": { "name": "Your Name", "email": "you@example.com" },
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

## Naming & Namespacing Convention

All skills and agents MUST be namespaced with their plugin name to prevent collisions when multiple plugins are installed.

- **Skills**: `plugin:skill_name` (colon separator) — e.g., `yf:chronicle_capture`
- **Agents**: `plugin_agentname` (underscore separator) — e.g., `yf_chronicle_recall`
- **Rules**: `plugin-description.md` (hyphen separator) — e.g., `yf-beads.md`

Within a plugin, skills and agents are grouped by capability:

```
yf:<capability>_<action>      # skill
yf_<capability>_<role>        # agent
yf-<capability>-<desc>.md     # rule
```

## Build & Test

```bash
# Test marketplace locally (from repo root)
claude --plugin-dir .

# Test a specific plugin
claude --plugin-dir ./plugins/yf

# Run unit tests (fast, shell-only)
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

All new work MUST include automated test cases.

## README Maintenance

When implementing a new major capability for a plugin:
1. Add a capability section to the plugin's `README.md`
2. Update the root `README.md` plugin overview
3. Update the capability table in the plugin's developer guide

## Plugin-Specific Developer Guides

- [Yoshiko Flow developer guide](plugins/yf/DEVELOPERS.md) — Architecture, internals, naming tables, and extension points for the yf plugin
