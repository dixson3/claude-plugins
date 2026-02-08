# Rule: Plan Intake — Catch Manual & Pasted Plans

**Applies:** When the user asks to implement a plan without the auto-chain having fired

## Detection

This rule fires when ALL of these are true:

1. The user says "implement the/this plan", "implement the following plan", or provides plan content to execute
2. The conversation contains plan-like content (headings like "## Implementation", "## Phases", "## Completion Criteria", structured task lists)
3. The auto-chain has NOT fired in this conversation (no "Auto-chaining plan lifecycle..." message from the ExitPlanMode hook)

If the auto-chain HAS fired, this rule does NOT apply — the auto-chain already handles the full lifecycle.

## Behavior

When you detect a manual/pasted plan, execute these checks in order before writing any implementation code:

### Step 1: Ensure Plan File Exists

Check if a plan file exists in `docs/plans/` for this plan:
```bash
ls docs/plans/plan-*.md
```

- **If no matching plan file exists**: Save the plan content to `docs/plans/plan-<next-idx>.md` using the standard format (see auto-chain-plan.md for the format).
- **If plan file already exists**: Use the existing file. Determine the plan index from the filename.

### Step 2: Ensure Beads Exist

Check if beads have been created for this plan:
```bash
bd list -l plan:<idx> --type=epic
```

- **If no beads exist**: Invoke `/workflows:plan_to_beads docs/plans/plan-<idx>.md` to create the structured hierarchy (epic, tasks, gates, dependencies).
- **If beads already exist**: Skip this step.

### Step 3: Ensure Plan is Executing

Check if the plan is in Executing state:
```bash
test -f .claude/.plan-gate && echo "gate exists" || echo "no gate"
```

- **If gate exists** (plan is Draft/Ready, not yet Executing):
  ```bash
  ROOT_EPIC=$(bd list -l plan:<idx> --type=epic --status=open --limit=1 --json 2>/dev/null \
    | jq -r '.[0].id // empty')
  bash plugins/workflows/scripts/plan-exec.sh start "$ROOT_EPIC"
  ```
- **If no gate**: Plan is already in Executing state (or was never gated). Proceed.

### Step 4: Capture Planning Context

If this is the start of implementation and there was planning discussion in the conversation (design rationale, alternatives considered, architectural decisions):
- Invoke `/chronicler:capture topic:planning` to preserve the planning context as a chronicle bead.
- Skip if the planning discussion was trivial (less than a few exchanges).

### Step 5: Dispatch via Task Pump

Invoke `/workflows:execute_plan` to begin structured dispatch via the task pump.

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
