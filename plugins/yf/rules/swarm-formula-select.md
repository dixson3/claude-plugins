# Rule: Automatic Formula Selection for Plan Tasks

**Applies:** During `plan_create_beads` Step 8b (after agent selection)

When creating beads from a plan, each task is evaluated for swarm formula assignment. This rule documents the heuristics used by `/yf:swarm_select_formula`.

## Heuristic Table

| Task Signal | Formula | Why |
|-------------|---------|-----|
| Implementation verbs: create, add, build, implement | `feature-build` | Needs research → implement → review |
| Bug-fix verbs: fix, resolve, debug, repair | `bugfix` | Needs diagnose → fix → verify |
| Research verbs: research, investigate, evaluate, spike | `research-spike` | Needs investigate → synthesize → archive |
| Review verbs: review, audit, inspect | `code-review` | Needs analyze → report |
| Test verbs: test, spec, coverage, verify | `build-test` | Needs implement → test → review |

## When NOT to Assign a Formula

Atomic tasks should use **bare agent dispatch** (no formula):

- Single-file creation or modification
- Configuration changes (JSON, YAML edits)
- Rule/doc-only changes
- Tasks labeled `atomic` or `trivial`
- Chore-type tasks

The overhead of a multi-agent swarm (wisp instantiation, dispatch loop, squash) is not justified for simple, focused changes.

## Author Override

If the plan text explicitly specifies a formula (e.g., `formula:bugfix` in the task description), the explicit label takes priority. The `/yf:swarm_select_formula` skill checks for existing `formula:*` labels before applying heuristics.

## Integration

This rule is informational — the actual logic lives in `/yf:swarm_select_formula`. The `swarm-formula-dispatch` rule handles dispatching labeled tasks through the swarm system during plan pump execution.
