# Rule: Enrich Planning Context During Plan Transitions

**Applies:** When a plan is saved via ExitPlanMode auto-chain

A plan-save chronicle stub is automatically created by `exit-plan-gate.sh` via `plan-chronicle.sh`. This stub contains the first 20 lines of the plan file as context. This rule governs optional enrichment.

## Behavior

If the planning discussion had significant design rationale beyond what the plan file captures — alternatives considered, architectural debates, research findings, trade-off analysis — invoke `/yf:chronicle_capture topic:planning` to create an enriched chronicle bead. This bead will automatically be tagged with the plan label if a plan is active.

## Why

Planning discussions are the richest source of "why" context. The deterministic stub guarantees a chronicle always exists. Enrichment adds the deeper rationale that isn't captured in the plan file itself.

## Timing

This fires between the plan save and beads creation steps of the auto-chain. The stub is already created by the hook; enrichment is additive.

## Important

- This rule only applies when the auto-chain is active (you see "Auto-chaining" in hook output)
- The stub chronicle is guaranteed by `exit-plan-gate.sh` — this rule is about optional enrichment only
- For manual plan transitions (user says "engage the plan" explicitly), the watch-for-chronicle-worthiness rule handles it normally
- Do NOT enrich if the planning discussion was trivial (less than a few exchanges) or if the plan file already captures all relevant rationale
