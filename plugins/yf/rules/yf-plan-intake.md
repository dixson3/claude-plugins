# Rule: Plan Intake — Catch Manual & Pasted Plans

**Applies:** When the user asks to implement a plan without the auto-chain having fired

## Detection

This rule fires when ALL of these are true:

1. The user says "implement the/this plan", "implement the following plan", or provides plan content to execute
2. The conversation contains plan-like content (headings like "## Implementation", "## Phases", "## Completion Criteria", structured task lists)
3. The auto-chain has NOT fired in this conversation (no "Auto-chaining plan lifecycle..." message from the ExitPlanMode hook)

If the auto-chain HAS fired, this rule does NOT apply — the auto-chain already handles the full lifecycle.

## Behavior

When you detect a manual/pasted plan, invoke `/yf:plan_intake` before writing
any implementation code. The skill handles the full checklist:
1. Save plan file to docs/plans/
2. Create beads hierarchy via /yf:plan_to_beads
3. Start execution via plan-exec.sh
4. Capture planning context via /yf:capture
5. Dispatch via /yf:execute_plan

Idempotent — safe to re-run if partially completed.

## Why This Rule Exists

The auto-chain lifecycle (ExitPlanMode hook → auto-chain rule) depends on a specific trigger: the ExitPlanMode tool being called in the same session where the plan was written. This breaks when:

- The user pastes a plan into a new session ("implement the following plan:")
- The user clears context and starts fresh
- The user manually created the plan file outside of plan mode
- ExitPlanMode was called with "bypass permissions" which may skip hooks

This rule is the fallback that ensures plans always go through the proper lifecycle regardless of how they enter the conversation.

## Non-Triggers

Do NOT fire this rule when:
- The auto-chain has already fired (you see "Auto-chaining plan lifecycle...")
- The user is just discussing a plan without asking for implementation
- The user is working on individual beads that already exist (normal execution)
- The user explicitly says to skip the lifecycle
