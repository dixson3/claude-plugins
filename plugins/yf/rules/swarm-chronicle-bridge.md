# Rule: Swarm-to-Chronicle Bridge

**Applies:** During swarm execution when reactive bugfix triggers

## Overview

Auto-captures a chronicle bead when reactive bugfix fires. Unlike advisory rules, this fires automatically to preserve mid-swarm context that would otherwise be lost when the wisp is squashed.

## When This Fires

1. **After `swarm_react` spawns a bugfix formula** — captures failure context, bugfix formula ID, and the step being retried
2. **After a bugfix retry result is known** — captures whether the retry succeeded or the block stands

## What Gets Captured

The chronicle bead includes:
- Failure verdict (REVIEW:BLOCK or TESTS:FAIL)
- Step that failed and why
- Bugfix formula ID that was spawned
- Files involved in the failure
- Retry outcome (if known)

## Labels

Chronicle beads created by this bridge use:
```
ys:chronicle,ys:topic:swarm,ys:swarm,ys:chronicle:auto
```

Plus the parent bead's plan label if present.

## Behavior

This is **NOT advisory** — it fires automatically. The context captured here is transient (wisp state, mid-execution details) and would be permanently lost after squashing without this bridge.

## When This Does NOT Fire

- Swarm steps that complete successfully (REVIEW:PASS, TESTS all passing)
- Steps that don't go through the reactive bugfix path
- Manual bugfix runs (only reactive bugfix triggers this)
- Swarms without failures

## Integration

- The `swarm_react` skill's Step 4.5 creates the chronicle bead
- The `chronicle_diary` agent reads these beads via the `ys:swarm` label for enriched diary entries
- This rule complements `swarm-archive-bridge.md` (which handles post-completion archival)
