# Yoshiko Flow (yf) Plugin — v2.16.0

Yoshiko Flow freezes the context that makes software maintainable — structured plans, captured rationale, and archived research — so knowledge survives beyond the session that produced it.

## Why Yoshiko Flow

The natural state of software is _maintenance_. How hard or easy that maintenance is depends on how well teams share knowledge — with each other now, and with people in the future they'll never meet. Design docs, PRDs, issue trackers, and code comments are all methods of "freezing context" so that work and investigations stay focused in the right areas.

Traditionally, producing this content is a chore that requires real organizational discipline. Agentic coding makes the problem worse: agents generate context faster than humans can catalog it, and each session starts with a blank slate. Yoshiko Flow automates the discipline — capturing plans, observations, and decisions as structured artifacts without requiring the operator to remember to do it.

It does this through four capabilities:

1. **Plan Lifecycle** — Breaks plans into a dependency graph of tracked tasks, with automatic decomposition, scheduling, and dispatch
2. **Swarm Execution** — Runs structured, parallel agent workflows using formula templates, wisps, and a dispatch loop
3. **Chronicler** — Captures observations and context as work progresses, then composes diary entries that trace how and why changes were made
4. **Archivist** — Preserves research findings and design decisions as permanent documentation that supports PRDs and ERDs

## Getting Started

1. **Install beads-cli** — Beads is a git-backed issue tracker that yf uses for plan tracking. See [beads-cli](https://github.com/dixson3/beads-cli) for installation.

2. **Load the marketplace:**
   ```bash
   claude --plugin-dir /path/to/yoshiko-studios-marketplace
   ```

3. **Run setup:**
   ```
   /yf:setup
   ```
   Setup automatically adds `.gitignore` entries for yf ephemeral files and cleans up any conflicting `bd init` content from AGENTS.md.

4. **Start planning** — Enter plan mode, write your plan, exit. Yoshiko Flow takes it from there — saving the plan, creating tracked tasks, and beginning execution. See [Plan Lifecycle](#plan-lifecycle) for details.

> **Note:** Beads uses a `beads-sync` branch for issue state. Code branches stay clean.

## Plan Lifecycle

### Why

Plans written in a Claude session disappear when the context window compresses or the session ends. Without external state, there's no way to track what was done, what remains, or what depends on what. Yoshiko Flow converts plans into a dependency graph of beads — tracked issues that persist across sessions. Each task is assessed for scope and decomposed further when needed, so the graph grows to reflect the actual shape of the work.

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

In the typical flow, the auto-chain on ExitPlanMode handles all of this without manual intervention: it formats the plan, creates the beads hierarchy, resolves the gate, and begins dispatch. The manual triggers exist for cases where you need finer control.

### Enforcement

Three layers prevent out-of-state operations:

1. **Beads-native** — Gates control execution state. Deferred tasks are hidden from `bd ready`.
2. **Scripts** — `plan-exec.sh` handles atomic state transitions.
3. **Hooks** — `code-gate.sh` blocks implementation edits and `plan-exec-guard.sh` blocks task operations until the plan reaches Executing.

### Artifacts

- **Plan files**: `docs/plans/plan-NN.md`
- **Plan gate**: `.yoshiko-flow/plan-gate` (temporary, blocks edits until Executing)
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

## Swarm Execution

### Why

The plan lifecycle dispatches tasks one-at-a-time to agents. But many tasks have internal structure — a feature needs research before implementation, and review after. Running these as separate beads loses the tight coupling between steps. Swarm execution uses beads formulas to define reusable multi-agent workflows where research feeds implementation feeds review, all within a single tracked unit of work.

### How It Works

A formula defines a pipeline of steps with dependencies and agent annotations:

```
feature-build: research (Explore) → implement (general-purpose) → review (Explore)
research-spike: investigate (Explore) → synthesize → archive
bugfix: diagnose (Explore) → fix → verify
```

When invoked, the formula is instantiated as a **wisp** (ephemeral molecule). The dispatch loop identifies ready steps, parses agent annotations, and launches parallel Task calls. Agents communicate through structured comments (`FINDINGS:`, `CHANGES:`, `REVIEW:`, `TESTS:`) on the parent bead. On completion, the wisp is squashed into a digest and a chronicle is auto-created.

Plan tasks labeled `formula:<name>` are automatically dispatched through the swarm system instead of bare agent dispatch.

### Implicit Triggers

Formulas can fire automatically based on lifecycle events and task semantics — no manual labeling required:

| Trigger | Signal | Formula | Phase |
|---------|--------|---------|-------|
| **Auto-select** | Task title keywords (implement, fix, research...) | Best match | Plan setup |
| **Composition** | `compose` field in formula step JSON | Sub-formula | Execution |
| **Reactive bugfix** | REVIEW:BLOCK or test failures | `bugfix` | Execution |
| **Qualification** | All plan tasks closed | `code-review` | Completion |
| **Research spike** | 3+ web searches during planning | `research-spike` (advisory) | Planning |

Auto-selection runs during `plan_create_beads`, applying `formula:<name>` labels based on task semantics. Atomic tasks (single-file, single-concern) are left for bare agent dispatch. Formulas can nest via `compose` fields (max depth 2). Reactive bugfixes auto-spawn on failure with a retry budget. Qualification gates block plan completion until code review passes.

### Artifacts

- **Formulas**: `plugins/yf/formulas/*.formula.json` (5 shipped)
- **Dispatch state**: `.yoshiko-flow/swarm-state.json` (ephemeral)
- **Comments**: Structured audit trail on parent beads (persists after squash)

### Skills & Agents

| Skill / Agent | Description |
|---------------|-------------|
| `/yf:swarm_run` | Full swarm lifecycle — instantiate, dispatch, squash |
| `/yf:swarm_dispatch` | Core dispatch loop driving agents through molecule steps |
| `/yf:swarm_status` | Show active swarm state and step progress |
| `/yf:swarm_list_formulas` | List available formula templates |
| `/yf:swarm_select_formula` | Auto-assign formula labels based on task semantics |
| `/yf:swarm_react` | Reactive bugfix from BLOCK/FAIL verdicts |
| `/yf:swarm_qualify` | Run code-review qualification gate before completion |
| Agent: `yf_swarm_researcher` | Read-only research agent (posts FINDINGS) |
| Agent: `yf_swarm_reviewer` | Read-only review agent (posts REVIEW with PASS/BLOCK) |
| Agent: `yf_swarm_tester` | Test-writing agent (posts TESTS with results) |

## Chronicler (Context Persistence)

### Why

Claude sessions lose context on compaction, clear, or new session start. The insights, rationale, and working state accumulated during a session vanish. The chronicler captures this context as chronicle beads — lightweight snapshots of observations, progress, and reasoning. At plan completion or on demand, these chronicles are composed into diary entries: a readable narrative of how changes came into being. Because chronicles are tagged to the active plan, the diary entries tell a coherent story rather than a disconnected log.

### How It Works

- **Manual**: `/yf:chronicle_capture` to snapshot current context
- **Automatic**: SessionStart hook outputs open chronicle summaries for immediate context recovery
- **Automatic**: SessionEnd and PreCompact hooks create draft chronicles from significant git activity
- **Automatic**: Pre-push hook creates draft chronicles and warns about open chronicles
- **Automatic**: Plan transitions capture planning context
- **Recovery**: `/yf:chronicle_recall` restores context in new sessions (also triggered automatically via SessionStart)
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

Research findings and decision rationale discussed in sessions are lost once the conversation ends. The archivist flags research and decisions as they arise, prompting the operator to capture them. Captured items are processed into indexed summaries — providing permanent records that support PRDs and ERDs long after the original conversation is gone.

### How It Works

- **Capture**: `/yf:archive_capture` for research findings or design decisions
- **Advisory**: Rules suggest archiving during work (the operator decides when to capture)
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

Config lives in `.yoshiko-flow/config.json` (committed to git), while lock state lives in `.yoshiko-flow/lock.json` (gitignored).

```json
{
  "enabled": true,
  "config": {
    "artifact_dir": "docs"
  }
}
```

- **`enabled`** — Master switch. When `false`, preflight removes all rule symlinks.
- **`config.artifact_dir`** — Base directory for plans and diary (default: `docs`).

Chronicler and archivist are always on when yf is enabled. Old configs with `chronicler_enabled`/`archivist_enabled` fields are automatically pruned on first preflight run.

Lock state (`lock.json`) is managed by `plugin-preflight.sh` — do not edit manually.

Run `/yf:setup` to create or reconfigure this file interactively.

## Internals

### Rules (19)

All rules are installed into `.claude/rules/yf/` (gitignored, symlinked back to `plugins/yf/rules/`):

| Rule | Purpose |
|------|---------|
| `beads.md` | Agent instructions for beads workflow and session close protocol |
| `engage-the-plan.md` | Maps trigger phrases to plan lifecycle transitions |
| `plan-to-beads.md` | Enforces beads must exist before implementing a plan |
| `breakdown-the-work.md` | Enforces task decomposition before coding non-trivial tasks |
| `auto-chain-plan.md` | Drives automatic lifecycle after ExitPlanMode |
| `beads-drive-tasks.md` | Enforces beads as source of truth for plan work |
| `plan-intake.md` | Catches manual/pasted plans for lifecycle processing |
| `watch-for-chronicle-worthiness.md` | Monitors for chronicle-worthy events |
| `plan-transition-chronicle.md` | Captures planning context during transitions |
| `watch-for-archive-worthiness.md` | Monitors for archive-worthy research and decisions |
| `plan-transition-archive.md` | Archives research and decisions during plan transitions |
| `plan-completion-report.md` | Enforces structured completion report with chronicle/diary/archive summary |
| `swarm-comment-protocol.md` | Documents FINDINGS/CHANGES/REVIEW/TESTS comment protocol for swarm agents |
| `swarm-formula-dispatch.md` | Routes plan tasks with `formula:<name>` label through swarm execution |
| `swarm-archive-bridge.md` | Suggests archiving swarm output when research or decisions are detected |
| `swarm-formula-select.md` | Heuristics for automatic formula assignment to plan tasks |
| `swarm-nesting.md` | Nesting protocol, depth limits, and context flow for composed formulas |
| `swarm-reactive.md` | Reactive bugfix spawning on REVIEW:BLOCK or test failures |
| `swarm-planning-research.md` | Advisory: suggests research-spike formula during heavy planning research |

### Scripts (9)

| Script | Description |
|--------|-------------|
| `plugin-preflight.sh` | Symlink-based artifact sync engine |
| `yf-config.sh` | Sourceable shell library for config access |
| `plan-exec.sh` | Deterministic state transitions for plan execution |
| `pump-state.sh` | Tracks dispatched/done beads to prevent double-dispatch |
| `archive-suggest.sh` | Scans git commits for research/decision archive candidates |
| `chronicle-check.sh` | Auto-creates draft chronicle beads from significant git activity (detects wisp squashes) |
| `swarm-state.sh` | Tracks dispatched/done swarm steps to prevent double-dispatch |
| `session-recall.sh` | Outputs open chronicle summaries on SessionStart for context recovery |
| `setup-project.sh` | Manages `.gitignore` sentinel block and AGENTS.md cleanup |

### Hooks (7)

| Hook | Trigger | Description |
|------|---------|-------------|
| `preflight-wrapper.sh` | SessionStart | Triggers plugin preflight sync |
| `exit-plan-gate.sh` | ExitPlanMode | Saves plan and creates gate |
| `code-gate.sh` | Edit, Write | Blocks implementation edits when plan not executing |
| `plan-exec-guard.sh` | `bd update/close` | Blocks task ops on non-executing plans |
| `pre-push-diary.sh` | `git push` | Auto-creates draft chronicles and reminds about open chronicles before push |
| `session-end.sh` | SessionEnd | Auto-creates draft chronicles and writes pending-diary marker |
| `pre-compact.sh` | PreCompact | Auto-creates draft chronicles before context compaction |

## Dependencies

- [**beads-cli**](https://github.com/dixson3/beads-cli) >= 0.44.0 — Git-backed issue tracker providing the task DAG for plan tracking
- **jq** — JSON processing (used by scripts)

## License

MIT License - Yoshiko Studios LLC
