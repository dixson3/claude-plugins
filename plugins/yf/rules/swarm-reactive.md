# Rule: Reactive Bugfix Spawning

**Applies:** During swarm dispatch when a step posts REVIEW:BLOCK or TESTS with failures

## When This Fires

After a swarm step completes and posts a failure comment:

- `REVIEW:BLOCK` — The review step blocked the implementation
- `TESTS:` with `FAIL: N` where N > 0 — Tests failed

The dispatch loop (Step 6b) invokes `/yf:swarm_react` to evaluate and potentially spawn a bugfix formula.

## Eligibility

Reactive bugfix is eligible when ALL conditions are met:

1. **Depth < 2** — Cannot trigger at max nesting depth (prevents recursion)
2. **No prior attempt** — `ys:bugfix-attempt` label not present on parent bead
3. **Config enabled** — `reactive_bugfix` is not `false` in `.yoshiko-flow/config.json`
4. **Bug, not design** — The BLOCK is about a specific bug, not a design concern

## Design BLOCKs (Excluded)

These signals indicate a **design-level** BLOCK that requires human judgment:

- "wrong approach", "needs redesign"
- "should use X instead of Y"
- "architectural concern"
- "scope too large", "needs to be split"

Design BLOCKs are NOT eligible for reactive bugfix. The parent bead stays open for manual intervention.

## Retry Budget

- Default: 1 retry per step (configurable via `max_retries` field in formula step JSON)
- After bugfix completes, the original failed step is marked for retry via `swarm-state.sh mark-retrying`
- If the retry fails again, the block stands permanently

## Guard Rails

- Reactive bugfix runs at `depth+1` — it cannot itself trigger further reactive bugfixes
- Only one reactive bugfix attempt per step execution (`ys:bugfix-attempt` label)
- The bugfix formula (diagnose → fix → verify) runs within the existing swarm context
- Config escape hatch: `reactive_bugfix: false` in `.yoshiko-flow/config.json`

## When This Does NOT Fire

- Step completes with REVIEW:PASS
- Step completes with TESTS: all passing
- Steps that don't post review or test comments (research, implementation)
- Manual swarm runs outside of the dispatch loop
