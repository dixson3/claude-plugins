# Rule: Suggest Research Spike During Planning

**Applies:** During plan mode when significant research activity is detected

## Detection

This rule fires when ALL of these are true during plan mode:

1. The agent has performed 3+ web searches, OR
2. The agent is explicitly comparing alternatives (libraries, tools, approaches), OR
3. The agent has read multiple external API docs or specifications

## Behavior

When you detect significant research activity during planning:

1. Check for existing archive beads: `bd list -l ys:archive --status=open --limit=1`
2. If archive beads already exist for this topic, do NOT suggest (avoids duplicating `/yf:archive_capture`)
3. Otherwise, suggest:

> "This research could benefit from a structured investigation. Consider running `/yf:swarm_run formula:research-spike feature:\"<topic>\"` to formalize the research with investigation, synthesis, and auto-archiving."

## Why

The `research-spike` formula provides structured investigation → synthesis → archive steps. During planning, this produces better-organized research than ad-hoc web searches, and the archive step ensures findings persist as permanent documentation.

The `research-spike` formula is marked `planning_safe: true` — all its steps are read-only or bead-only (no file writes), so the plan gate doesn't interfere.

## Integration with Existing Rules

- `plan-transition-archive.md` fires between plan save and beads creation — handles lightweight research
- `watch-for-archive-worthiness.md` handles general archive suggestions during work
- This rule specifically targets **heavy research during planning** where a full formula adds value over bare `archive_capture`

## When This Does NOT Fire

- Lightweight research (1-2 web searches) — handled by `watch-for-archive-worthiness.md`
- Research outside of plan mode — handled by existing archive rules
- When archive beads already exist for the topic

## Frequency

- At most once per planning session
- Do not suggest if the planning discussion is nearly complete
