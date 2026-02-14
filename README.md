# D3 Claude Plugins

A plugin marketplace for [Claude Code](https://claude.ai/code). The plugins here automate the organizational discipline that keeps software maintainable — structured plans, captured rationale, and archived research — so knowledge survives beyond the session that produced it.

## Installation

```bash
# Install the marketplace as a plugin directory
claude --plugin-dir /path/to/d3-claude-plugins
```

On first session start, the preflight system automatically installs rules and creates artifact directories.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [yf](plugins/yf/) | Yoshiko Flow — plan lifecycle, context persistence, and research/decision archiving | 2.11.0 |

## Yoshiko Flow (yf)

Yoshiko Flow freezes the context that makes software maintainable. It breaks plans into tracked task graphs, captures observations as diary entries that trace how and why changes were made, and preserves research and decisions as permanent documentation.

### Getting Started

1. **Install [beads-cli](https://github.com/dixson3/beads-cli)** (>= 0.44.0) — a git-backed issue tracker used for plan tracking.

2. **Install [jq](https://jqlang.github.io/jq/)** — JSON processor used by internal scripts.

3. **Load the marketplace** and run setup:
   ```bash
   claude --plugin-dir /path/to/d3-claude-plugins
   ```
   Then inside your Claude session:
   ```
   /yf:setup
   ```

4. **Start planning** — Enter plan mode, write your plan, exit. Yoshiko Flow takes it from there: saving the plan, creating tracked tasks, and beginning execution.

### Plan Lifecycle

Converts plans into a dependency graph of tracked tasks with automatic decomposition, scheduling, and dispatch.

```
Draft ───> Ready ───> Executing <──> Paused ───> Completed
```

The auto-chain on ExitPlanMode handles the full lifecycle without manual intervention: it formats the plan, creates the beads hierarchy, resolves the gate, and begins dispatch. Manual triggers exist for finer control.

| Skill | Description |
|-------|-------------|
| `/yf:plan_engage` | State machine for all lifecycle transitions |
| `/yf:plan_create_beads` | Convert plan docs to beads hierarchy |
| `/yf:plan_intake` | Intake checklist for plans entering outside the auto-chain |
| `/yf:plan_execute` | Orchestrated task dispatch with dependency ordering |
| `/yf:plan_pump` | Pull ready beads into parallel agent dispatch |
| `/yf:plan_breakdown` | Recursive decomposition of non-trivial tasks |
| `/yf:plan_select_agent` | Auto-discover agents and match to tasks |
| `/yf:plan_dismiss_gate` | Escape hatch to abandon plan gate |

### Chronicler (Context Persistence)

Captures observations and context as work progresses, then composes diary entries that trace how and why changes were made. Sessions lose context on compaction, clear, or new session start — the chronicler preserves it.

| Skill | Description |
|-------|-------------|
| `/yf:chronicle_capture` | Capture context as a chronicle bead |
| `/yf:chronicle_recall` | Restore context from open chronicles |
| `/yf:chronicle_diary` | Generate diary entries from chronicles |
| `/yf:chronicle_disable` | Close chronicles without diary generation |

### Archivist (Research & Decision Records)

Flags research findings and design decisions during work, then processes them into indexed permanent documentation for PRDs and ERDs.

| Skill | Description |
|-------|-------------|
| `/yf:archive_capture` | Capture research or decisions as archive beads |
| `/yf:archive_process` | Process archive beads into permanent docs |
| `/yf:archive_disable` | Close archive beads without generating docs |
| `/yf:archive_suggest` | Scan git history for archive candidates |

### Engineer (Specification Artifacts)

Synthesizes and maintains specification documents — PRD, EDD, Implementation Guides, and TODO register — from existing project context. When specs exist, plans are reconciled against them before execution, creating a feedback loop between specification and implementation.

| Skill | Description |
|-------|-------------|
| `/yf:engineer_analyze_project` | Synthesize specs from project context |
| `/yf:engineer_update` | Add, update, or deprecate spec entries |
| `/yf:engineer_reconcile` | Reconcile plans against specifications |
| `/yf:engineer_suggest_updates` | Suggest spec updates after plan completion |

### Configuration

Run `/yf:setup` to enable Yoshiko Flow. Config lives in `.yoshiko-flow/config.json` (committed to git).

| Setting | Description |
|---------|-------------|
| `enabled` | Master switch — when `false`, all rule symlinks are removed |
| `artifact_dir` | Base directory for plans and diary (default: `docs`) |

Chronicler and archivist are always on when yf is enabled. Use `/yf:setup disable` to disable yf entirely.

## Contributing

See [DEVELOPERS.md](DEVELOPERS.md) for the plugin structure, naming conventions, and how to create new plugins. The [yf developer guide](plugins/yf/DEVELOPERS.md) covers yf-specific internals.

## Author

James Dixson — [dixson3](https://github.com/dixson3)

## License

MIT License — See [LICENSE](LICENSE) for details.
