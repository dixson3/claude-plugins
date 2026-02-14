# Rule: Swarm-to-Archive Bridge

**Applies:** After a swarm completes (wisp squashed)

After a swarm execution completes and the wisp is squashed, scan the squash summary for archive-worthy markers. This bridges operational swarm output into the permanent archive system.

## Detection Markers

### Research Worth Archiving

When `FINDINGS:` comments contain:
- URLs or external source references
- Library/tool comparisons
- API documentation references
- Multi-source research synthesis

Suggest: "This swarm produced research findings with external sources. Consider running `/yf:archive_capture type:research` to preserve them as permanent documentation."

### Decisions Worth Archiving

When `REVIEW:BLOCK` comments contain:
- Architectural concerns (not just code style)
- Approach rejection with alternative suggestions
- Strategic rationale for blocking

Suggest: "This swarm review raised architectural concerns. Consider running `/yf:archive_capture type:decision` to document the decision context."

## Behavior

This rule is **advisory only** — it flags and suggests, consistent with `watch-for-archive-worthiness.md`. The user decides whether to archive.

Do NOT auto-create archive beads. Only suggest when markers are clearly present.

## When This Fires

- After `/yf:swarm_run` completes Step 4b (squash) for **any formula**
- After any formula completion — not limited to feature-build; applies to research-spike, bugfix, build-test, code-review, and custom formulas
- When reviewing swarm completion summaries

## When This Does NOT Fire

- During swarm execution (mid-dispatch)
- For swarms that produce no FINDINGS or REVIEW comments
- When findings are purely internal code analysis (no external sources)
- For steps that already auto-archived via Step 6d `archive_findings` opt-in

## Frequency

- At most once per swarm completion
- Do not suggest if the swarm was trivial (e.g., only 2 steps, no research)
