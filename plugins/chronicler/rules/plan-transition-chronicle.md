# Rule: Chronicle Planning Context During Plan Transitions

**Applies:** When a plan is saved via ExitPlanMode auto-chain

When you see "Plan saved to docs/plans/" in the conversation (from the ExitPlanMode hook), the planning discussion that preceded it contains valuable context: design rationale, alternatives considered, architectural decisions, trade-offs.

## Behavior

Before proceeding with beads creation (the plan_to_beads step of the auto-chain), invoke `/chronicler:capture topic:planning` to capture the planning context as a chronicle bead. This bead will automatically be tagged with the plan label if a plan is active.

## Why

Planning discussions are the richest source of "why" context. Once execution begins, the planning rationale is buried in conversation history that may be compacted. Capturing it as a chronicle bead preserves it for diary generation.

## Timing

This fires between the plan save and beads creation steps of the auto-chain. The chronicle capture is fast (a single `bd create` call) and does not interfere with the lifecycle.

## Important

- This rule only applies when the auto-chain is active (you see "Auto-chaining" in hook output)
- For manual plan transitions (user says "engage the plan" explicitly), the watch-for-chronicle-worthiness role handles it normally
- Do NOT capture if the planning discussion was trivial (less than a few exchanges)
