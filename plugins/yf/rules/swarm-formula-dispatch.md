# Rule: Formula-Based Swarm Dispatch During Plan Execution

**Applies:** During plan execution, when the task pump encounters tasks with `formula:<name>` labels

## Detection

When the plan pump (`/yf:plan_pump`) reads a ready bead's labels:

```bash
bd label list <bead-id> --json | jq -r '.[] | select(startswith("formula:"))'
```

If a `formula:<name>` label is found, this task MUST be dispatched through the swarm system via `/yf:swarm_run`. Bare agent dispatch (Task tool with `subagent_type`) of formula-labeled beads is a bug — it bypasses multi-agent workflows, structured bead comments, reactive bugfix, and chronicle capture.

## Behavior

Instead of the normal pump dispatch (Task tool with agent-specific subagent_type), invoke:

```
/yf:swarm_run formula:<name> feature:"<bead title or description>" parent_bead:<bead-id>
```

The swarm_run skill handles the full lifecycle:
1. Instantiates the formula as a wisp
2. Dispatches all steps through specialized agents
3. Posts structured comments on the parent bead
4. Squashes the wisp on completion
5. Auto-creates a chronicle bead
6. Closes the parent bead on success

## Why

This is the integration point between the plan system and the swarm system. It allows plan authors to specify that certain tasks should go through a structured multi-agent workflow rather than being handled by a single agent.

## Example

A plan task:
```
Title: "Implement user authentication"
Labels: plan:28, formula:feature-build
```

The pump sees `formula:feature-build` and dispatches:
```
/yf:swarm_run formula:feature-build feature:"Implement user authentication" parent_bead:marketplace-xyz
```

This runs: research -> implement -> review with specialized agents.

## Validation

Before dispatching any bead during plan execution, verify the dispatch route:

1. **Check for formula label**: `bd label list <bead-id> --json | jq -r '.[] | select(startswith("formula:"))'`
2. **If formula label exists**: Dispatch via `/yf:swarm_run formula:<name> feature:"<title>" parent_bead:<bead-id>`. Do NOT use bare Task tool dispatch.
3. **If no formula label**: Dispatch via bare Task tool with `subagent_type` from the `agent:<name>` label (or `general-purpose` if no agent label).

## Non-Triggers

- Tasks without `formula:` labels are dispatched normally through the pump
- Tasks with `agent:` labels but no `formula:` label use bare agent dispatch
- This rule only applies during plan execution (pump context)
