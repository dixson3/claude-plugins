# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

D3 Claude Plugins — A plugin marketplace for Claude Code, hosting a collection of skills, agents, rules, scripts, and hooks.

## Repository Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog with plugin registry
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
├── CLAUDE.md               # This file
├── DEVELOPERS.md           # Developer guide
├── README.md               # Marketplace overview
├── LICENSE                 # MIT License
└── CHANGELOG.md            # Version history
```

## Build / Test Commands

```bash
# Test marketplace locally (from repo root)
claude --plugin-dir .

# Test a specific plugin
claude --plugin-dir ./plugins/yf

# Run unit tests
bash tests/run-tests.sh --unit-only
```

## Naming Convention

Skills use `yf:<capability>_<action>`, agents use `yf_<capability>_<role>`.
See [DEVELOPERS.md](DEVELOPERS.md) for marketplace conventions and [plugins/yf/DEVELOPERS.md](plugins/yf/DEVELOPERS.md) for the full yf capability table.

## README Maintenance

When implementing a new major capability for the yf plugin:
1. Add a capability section to `plugins/yf/README.md` following the existing pattern (Why / How It Works / Artifacts / Skills & Agents)
2. Update the root `README.md` plugin overview with a brief narrative for the new capability
3. Update the capability table in `plugins/yf/DEVELOPERS.md`
4. If there is insufficient narrative or rationale for the new capability, ask the operator for context to ground the documentation

See [DEVELOPERS.md](DEVELOPERS.md) for the marketplace developer guide and [plugins/yf/DEVELOPERS.md](plugins/yf/DEVELOPERS.md) for yf-specific internals.

## Current Plugins

- **yf** (v2.17.0) — Yoshiko Flow — plan lifecycle, swarm execution, context persistence, diary generation, and specification artifacts
