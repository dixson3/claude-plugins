# Implementation Guide: Swarm Execution

## Overview

Swarm execution runs structured, parallel agent workflows using formula templates, wisps (ephemeral molecules), and a dispatch loop. Formulas define reusable multi-agent pipelines where research feeds implementation feeds review.

## Use Cases

### UC-006: Full Swarm Lifecycle

**Actor**: System (plan pump or operator)

**Preconditions**: A formula template exists. A parent task is available for comment posting.

**Flow**:
1. `/yf:swarm_run` is invoked with formula name, feature description, and parent task ID
2. Skill reads formula JSON from `plugins/yf/formulas/<name>.formula.json`
3. Skill instantiates formula as a wisp: `yft_mol_wisp <formula-path> --vars feature="<desc>"`
4. Skill invokes `/yf:swarm_dispatch` with molecule ID and parent task ID
5. Dispatch loop identifies ready steps (steps whose `needs` are all completed)
6. Dispatch parses `SUBAGENT:<type>` annotations from step descriptions
7. Dispatch launches parallel Task tool calls with appropriate `subagent_type`
8. Each agent reads upstream comments from parent task, performs work, posts structured comment
9. Dispatch marks steps as done via `swarm-state.sh mark-done`
10. Loop continues until all steps complete
11. Skill squashes wisp: `yft_mol_squash <mol-id>`
12. Skill creates chronicle entry from squash summary
13. If all steps passed: closes parent task

**Postconditions**: Wisp squashed. Comments persist on parent task. Chronicle entry created.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_run/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_dispatch/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/swarm-state.sh`

### UC-007: Formula Auto-Selection During Plan Setup

**Actor**: System (plan_create_tasks Step 8b)

**Preconditions**: Tasks are being created from a plan. No explicit `formula:` label on task.

**Flow**:
1. `/yf:swarm_select_formula` reads task title and description
2. Skill checks for existing `formula:*` label (respects author override)
3. Skill matches against heuristic table: implement->feature-build, fix->bugfix, research->research-spike, review->code-review, test->build-test, code/write/program+language->code-implement (see UC-030 in IG/coder.md for the code-implement refinement)
4. Skill assesses atomicity: single-file, single-concern tasks skip formula assignment
5. If match found: adds `formula:<name>` label to task
6. During plan pump, `swarm-formula-dispatch` rule detects the label and dispatches through swarm

**Postconditions**: Task has `formula:<name>` label for swarm dispatch.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_select_formula/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-formula-select.md`

### UC-008: Reactive Bugfix on Failure

**Actor**: System (swarm dispatch Step 6b)

**Preconditions**: A swarm step posts REVIEW:BLOCK or TESTS with failures. Depth < 2. No prior `ys:bugfix-attempt` label.

**Flow**:
1. Dispatch loop detects failure in step comment
2. `/yf:swarm_react` evaluates eligibility (not design-BLOCK, depth < 2, no prior attempt)
3. Skill adds `ys:bugfix-attempt` label to prevent re-triggering
4. Skill invokes `/yf:swarm_run formula:bugfix` with failure context at depth+1
5. Bugfix formula runs: diagnose -> fix -> verify
6. If bugfix succeeds: original step is marked for retry via `swarm-state.sh mark-retrying`
7. Dispatch loop re-dispatches the original step
8. If retry fails again: block stands permanently

**Postconditions**: Either the bug is fixed and the step passes on retry, or the block stands for manual intervention.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_react/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-reactive.md`

### UC-009: Nested Formula Composition

**Actor**: System (swarm dispatch Step 3-4)

**Preconditions**: A formula step has a `compose` field referencing another formula. Depth < 2.

**Flow**:
1. Dispatch loop encounters a step with `compose: "<formula-name>"`
2. Instead of launching a bare Task call, dispatch invokes `/yf:swarm_run formula:<name>` at depth+1
3. Sub-swarm receives upstream FINDINGS from parent formula as `context`
4. Sub-swarm posts comments on the outermost parent task (single audit trail)
5. Sub-swarm uses prefixed state tracking: `<parent-mol-id>/<step-id>`
6. On completion, dispatch marks the compose step as done

**Postconditions**: Sub-swarm completed. Comments on parent task. State scoped correctly.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-nesting.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/feature-build.formula.json`
