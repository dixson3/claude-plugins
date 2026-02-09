# Rule: Archive Research & Decisions During Plan Transitions

**Applies:** When a plan is saved via ExitPlanMode auto-chain

When you see "Plan saved to docs/plans/" in the conversation (from the ExitPlanMode hook), check whether the planning discussion that preceded it contained research findings or design decisions worth archiving.

## Behavior

Before proceeding with beads creation (the plan_to_beads step of the auto-chain):

1. **Check for research**: Did the planning discussion involve web searches, external documentation, or tool evaluations?
2. **Check for decisions**: Did the planning discussion involve architecture choices, technology selections, or scope changes with alternatives considered?

If research was conducted, invoke `/yf:archive type:research` to create an archive bead capturing the research findings (sources, conclusions, recommendations).

If significant decisions were made (with alternatives considered), invoke `/yf:archive type:decision` to create an archive bead capturing the decision (context, alternatives, reasoning).

These beads will automatically be tagged with the plan label if a plan is active.

## Why

Planning discussions often contain the richest research and decision context. Once execution begins, the specific sources consulted and alternatives evaluated are buried in conversation history that may be compacted. Archiving them preserves the "why" as permanent documentation.

## Timing

This fires between the plan save and beads creation steps of the auto-chain. Archive bead creation is fast (a single `bd create` call per item) and does not interfere with the lifecycle.

## Important

- This rule only applies when the auto-chain is active (you see "Auto-chaining" in hook output)
- For manual plan transitions, the watch-for-archive-worthiness rule handles detection normally
- Do NOT archive if the planning discussion had no research or decisions (only task breakdowns)
- This is separate from the chronicle capture — chronicles capture working context, archives capture research and decisions
