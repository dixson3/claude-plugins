# Rule: Beads Drive Task Orchestration

**Applies:** During plan execution (all agents)

Beads are the source of truth for all plan work. The Claude Task system (TaskCreate/TaskList) is NOT used for plan work — beads owns the persistent state. The Task tool with `subagent_type` is the execution mechanism.

## Enforcement

When working on a plan:

1. **Never create native Tasks (TaskCreate) for plan work.** All work items come from beads via `bd ready`.
2. **The task pump dispatches beads to agents.** The pump reads `bd ready`, groups by `agent:<name>` label, and launches Task tool calls with the appropriate `subagent_type`.
3. **Agents claim beads, not native tasks.** Use `bd update <id> --status=in_progress` to claim work, `bd close <id>` to complete it.
4. **Dependencies live in beads.** Use `bd dep add` for ordering. The beads dependency system controls what's ready.

## Why

- Beads are git-backed and persist across sessions, machines, and context compaction
- Beads support rich metadata (labels, notes, design, acceptance criteria)
- Beads support querying and filtering (`bd list -l plan:07 --ready`)
- Native Tasks are session-scoped and ephemeral — they don't survive session end
- The Task tool's `subagent_type` is the mechanism for launching specialized agents
