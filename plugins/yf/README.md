# Yoshiko Flow (yf) Plugin — v2.8.0

Yoshiko Flow enhances Claude Code with structured plan lifecycle management, persistent context capture, and research/decision archiving — freezing the context that makes software maintainable.

> **Note:** Beads (`.beads/`) is local-only — not committed to git.

## Why Yoshiko Flow

The natural state of software is _maintenance_. How hard or easy that maintenance is depends on how well teams share knowledge and transfer information — to each other now, and to people in the future they'll never meet. Projects have design docs, PRDs, issue trackers, and code comments — all methods of "freezing context" to constrain work and investigations to the most appropriate areas.

Traditionally, producing this content is a chore requiring real organizational discipline to maintain consistency. The real challenge in making agentic coding scalable is moving it toward a workflow that supports multiple collaborators, all with potentially different agentic interaction preferences.

Yoshiko Flow does three things to enhance an engineering workflow:

1. **Plan Lifecycle** — Breaks plans into a dependency graph of tracked tasks, with automatic decomposition, scheduling, and dispatch
2. **Chronicler** — Captures observations and context as work progresses, then composes diary entries that record the evolutionary path of how changes came into being
3. **Archivist** — Preserves research findings and design decisions as permanent documentation that helps justify features and design in PRDs and ERDs

## Getting Started

1. **Install beads-cli** — Beads is a git-backed issue tracker that provides the task DAG underlying yf's plan tracking. See [beads-cli](https://github.com/dixson3/beads-cli) for installation.

2. **Load the marketplace:**
   ```bash
   claude --plugin-dir /path/to/yoshiko-studios-marketplace
   ```

3. **Run setup:**
   ```
   /yf:setup
   ```

4. **Start planning** — Enter plan mode, write a plan, exit. The auto-chain handles the rest: saving the plan, creating beads, resolving the gate, and dispatching work.

## Plan Lifecycle

### Why

Plans written in Claude sessions evaporate on context compaction. Without structure, there's no way to track what was done, what remains, or what depends on what. Breaking plans into beads with dependencies gives control structures beyond native Claude TaskLists — additional reasoning is applied to each task, including discovering and creating new tasks. The breakdown and scheduling is automatic and implicit: hooks and skills trigger the decomposition and work through to completion.

### How It Works

```
Draft ───► Ready ───► Executing ◄──► Paused ───► Completed
```

| State | Trigger | What Happens |
|---|---|---|
| **Draft** | ExitPlanMode (auto) | Plan saved to `docs/plans/`. Auto-chain drives through to Executing. |
| **Ready** | "the plan is ready" | Beads hierarchy created. Gate open. Tasks deferred. |
| **Executing** | "execute the plan" | Gate resolved. Tasks undeferred. Dispatch active. |
| **Paused** | "pause the plan" | New gate. Pending tasks deferred. In-flight work finishes. |
| **Completed** | Automatic | All tasks closed. Plan status updated. Diary generated. |

The auto-chain on ExitPlanMode drives the full lifecycle without manual intervention: format the plan, create the beads hierarchy, resolve the gate, and begin dispatch.

### Enforcement

Three layers prevent out-of-state operations:

1. **Beads-native** — Gates control execution state. Deferred tasks are hidden from `bd ready`.
2. **Scripts** — `plan-exec.sh` handles atomic state transitions.
3. **Hooks** — `plan-exec-guard.sh` blocks task operations on non-executing plans. `code-gate.sh` blocks implementation edits until the plan reaches Executing.

### Artifacts

- **Plan files**: `docs/plans/plan-NN.md`
- **Plan gate**: `.claude/.plan-gate` (temporary, blocks edits until Executing)
- **Beads hierarchy**: Epics, tasks, and dependencies in `.beads/`

### Skills (8)

| Skill | Description |
|-------|-------------|
| `/yf:plan_engage` | State machine for all lifecycle transitions |
| `/yf:plan_create_beads` | Convert plan documents into a beads hierarchy |
| `/yf:plan_intake` | Intake checklist for plans entering outside the auto-chain |
| `/yf:plan_execute` | Orchestrated task dispatch with dependency ordering |
| `/yf:plan_pump` | Pull ready beads into parallel agent dispatch |
| `/yf:plan_breakdown` | Recursive decomposition of non-trivial tasks |
| `/yf:plan_select_agent` | Auto-discover agents and match to tasks |
| `/yf:plan_dismiss_gate` | Escape hatch to abandon the plan gate |

## Chronicler (Context Persistence)

### Why

Claude sessions lose context on compaction, clear, or new session start. The insights, rationale, and working state accumulated during a session disappear. The chronicler captures this context: rules and hooks evaluate the conversation and changes, recording observations as chronicle beads. At plan completion or on demand, the chronicler composes diary entries — capturing the evolutionary path of how changes came into being. Since chronicles are captured in the context of a plan, they correlate to a bigger picture.

### How It Works

- **Manual**: `/yf:chronicle_capture` to snapshot current context
- **Automatic**: Pre-push hook creates draft chronicles from significant git activity
- **Automatic**: Plan transitions capture planning context
- **Recovery**: `/yf:chronicle_recall` restores context in new sessions
- **Consolidation**: `/yf:chronicle_diary` generates permanent markdown diary entries

### Artifacts

- **Diary entries**: `docs/diary/YY-MM-DD.HH-MM.<topic>.md`

### Skills & Agents

| Skill / Agent | Description |
|---------------|-------------|
| `/yf:chronicle_capture` | Capture current context as a chronicle bead |
| `/yf:chronicle_recall` | Restore context from open chronicles |
| `/yf:chronicle_diary` | Generate diary entries from chronicles |
| `/yf:chronicle_disable` | Close chronicles without diary generation |
| Agent: `yf_chronicle_recall` | Context recovery agent |
| Agent: `yf_chronicle_diary` | Diary generation agent |

## Archivist (Research & Decision Records)

### Why

Research findings and decision rationale discussed in sessions are lost once the conversation ends. The archivist automatically captures research into topics and key decisions based on that research. These decision and research records help justify features and design in PRDs and ERDs.

### How It Works

- **Capture**: `/yf:archive_capture` for research findings or design decisions
- **Advisory**: Rules suggest archiving during work (not auto-capture)
- **Transitions**: Plan transitions check for archive-worthy content
- **Processing**: `/yf:archive_process` converts archive beads to indexed `SUMMARY.md` files
- **Discovery**: `/yf:archive_suggest` scans git history for candidates

### Artifacts

- **Research**: `docs/research/<topic>/SUMMARY.md` + `_index.md`
- **Decisions**: `docs/decisions/DEC-NNN-<slug>/SUMMARY.md` + `_index.md`

### Skills & Agents

| Skill / Agent | Description |
|---------------|-------------|
| `/yf:archive_capture` | Capture research or decisions as archive beads |
| `/yf:archive_process` | Process archive beads into permanent documentation |
| `/yf:archive_disable` | Close archive beads without generating docs |
| `/yf:archive_suggest` | Scan git history for archive candidates |
| Agent: `yf_archive_process` | Archive processing agent |

## Configuration

All config lives in `.claude/yf.json` (gitignored). This single file holds both user settings and preflight lock state.

```json
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs",
    "chronicler_enabled": true,
    "archivist_enabled": true
  },
  "preflight": { "..." }
}
```

- **`enabled`** — Master switch. When `false`, preflight removes all rule symlinks.
- **`config.artifact_dir`** — Base directory for plans and diary (default: `docs`).
- **`config.chronicler_enabled`** — When `false`, chronicle rules are not installed.
- **`config.archivist_enabled`** — When `false`, archivist rules are not installed.
- **`preflight`** — Lock state managed by `plugin-preflight.sh` (do not edit manually).

Run `/yf:setup` to create or reconfigure this file interactively.

## Internals

### Rules (11)

All rules are prefixed with `yf-` and symlinked into `.claude/rules/` (gitignored, pointing to `plugins/yf/rules/`):

| Rule | Purpose |
|------|---------|
| `yf-beads.md` | Agent instructions for beads workflow and session close protocol |
| `yf-engage-the-plan.md` | Maps trigger phrases to plan lifecycle transitions |
| `yf-plan-to-beads.md` | Enforces beads must exist before implementing a plan |
| `yf-breakdown-the-work.md` | Enforces task decomposition before coding non-trivial tasks |
| `yf-auto-chain-plan.md` | Drives automatic lifecycle after ExitPlanMode |
| `yf-beads-drive-tasks.md` | Enforces beads as source of truth for plan work |
| `yf-plan-intake.md` | Catches manual/pasted plans for lifecycle processing |
| `yf-watch-for-chronicle-worthiness.md` | Monitors for chronicle-worthy events |
| `yf-plan-transition-chronicle.md` | Captures planning context during transitions |
| `yf-watch-for-archive-worthiness.md` | Monitors for archive-worthy research and decisions |
| `yf-plan-transition-archive.md` | Archives research and decisions during plan transitions |

### Scripts (6)

| Script | Description |
|--------|-------------|
| `plugin-preflight.sh` | Symlink-based artifact sync engine |
| `yf-config.sh` | Sourceable shell library for config access |
| `plan-exec.sh` | Deterministic state transitions for plan execution |
| `pump-state.sh` | Tracks dispatched/done beads to prevent double-dispatch |
| `archive-suggest.sh` | Scans git commits for research/decision archive candidates |
| `chronicle-check.sh` | Auto-creates draft chronicle beads from significant git activity |

### Hooks (5)

| Hook | Trigger | Description |
|------|---------|-------------|
| `preflight-wrapper.sh` | SessionStart | Triggers plugin preflight sync |
| `exit-plan-gate.sh` | ExitPlanMode | Saves plan and creates gate |
| `code-gate.sh` | Edit, Write | Blocks implementation edits when plan not executing |
| `plan-exec-guard.sh` | `bd update/close` | Blocks task ops on non-executing plans |
| `pre-push-diary.sh` | `git push` | Auto-creates draft chronicles and reminds about open chronicles before push |

## Dependencies

- [**beads-cli**](https://github.com/dixson3/beads-cli) >= 0.44.0 — Git-backed issue tracker providing the task DAG for plan tracking
- **jq** — JSON processing (used by scripts)

## License

MIT License - Yoshiko Studios LLC
