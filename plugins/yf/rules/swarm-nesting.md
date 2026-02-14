# Rule: Swarm Nesting Protocol

**Applies:** When dispatching swarm steps with `compose` fields

## Overview

Formulas can compose other formulas via the `compose` field on step definitions. When the dispatch loop encounters a step with `compose: "<formula-name>"`, it invokes `/yf:swarm_run` for that sub-formula instead of launching a bare Task call.

## Depth Limit

- Maximum nesting depth: **2**
- Each nested invocation increments `depth` by 1
- At depth 2, `compose` fields are ignored — steps dispatch as bare Tasks
- This prevents infinite recursion (e.g., formula A composing formula B composing formula A)

| Depth | Behavior |
|-------|----------|
| 0 | Top-level swarm. `compose` fields trigger nested invocations. |
| 1 | Nested swarm. `compose` fields still trigger further nesting. |
| 2 | Max depth. `compose` fields ignored. Steps dispatch as bare Tasks. |

## Context Flow

- Sub-swarm receives upstream FINDINGS from the parent formula's earlier steps as `context`
- Sub-swarm posts CHANGES/TESTS/REVIEW comments on the **outermost** parent bead
- This maintains a single audit trail on the parent bead regardless of nesting depth

## State Tracking

Nested swarms use a prefix convention in `swarm-state.sh`:

```
<parent-mol-id>/<step-id>    # nested step state
```

Use `swarm-state.sh clear --scope <mol-id>` to clean only a sub-swarm's state without affecting the parent.

## Example

The `feature-build` formula's implement step has `"compose": "build-test"`:

```
feature-build (depth 0):
  research → [FINDINGS posted]
  implement → compose:build-test (depth 1):
    build-test:
      implement → [CHANGES posted]
      test → [TESTS posted]
      review → [REVIEW posted]
  review → [REVIEW posted]
```

## Important

- Reactive bugfixes (T3) also increment depth — a reactive bugfix at depth 1 cannot compose further
- The depth parameter is passed through `/yf:swarm_run` — see that skill's documentation
- Nested swarms share the same parent bead for comments but use separate wisp molecules
