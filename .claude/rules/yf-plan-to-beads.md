# Rule: Beads Before Implementation

**Applies:** When starting implementation of any plan

Before writing code for a plan, beads must exist. Plans that haven't been converted to beads cannot be implemented.

## Enforcement

When you're about to implement something from a plan in `docs/plans/`:

1. **Check for existing beads**: `bd list -l plan:<idx>` for the relevant plan
2. **If no beads exist**: Stop and invoke `/yf:plan_to_beads` first
3. **If beads exist**: Proceed with implementation, using `bd update --status=in_progress` to claim tasks

## Why

- Plans without beads have no tracked progress
- Dependencies aren't enforced without beads
- Context is lost between sessions without beads
- Multiple agents can't coordinate without beads

## Reminder

If you notice yourself implementing a plan without corresponding beads, pause and run:
```
/yf:plan_to_beads docs/plans/plan-<idx>.md
```
