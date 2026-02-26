# Implementation Guide: Formula Execution

## Overview

Formula execution runs structured, parallel agent workflows using formula templates, wisps (ephemeral molecules), and a dispatch loop. Formulas define reusable multi-agent pipelines where research feeds implementation feeds review.

## Use Cases

### UC-006: Full Formula Lifecycle

**Actor**: System (plan pump or operator)

**Preconditions**: A formula template exists. A parent task is available for comment posting.

**Flow**:
1. `/yf:formula_execute` is invoked with task ID, formula name, and optional context
2. Skill reads formula JSON from `plugins/yf/formulas/<name>.formula.json`
3. Skill instantiates formula as a wisp: `yft_mol_wisp <formula-path> --vars feature="<desc>"`
4. Dispatch loop identifies ready steps (steps whose `needs` are all completed)
5. Dispatch parses `SUBAGENT:<type>` annotations from step descriptions
6. Dispatch launches parallel Task tool calls with appropriate `subagent_type`
7. Each agent reads upstream comments from parent task, performs work, posts structured comment
8. Dispatch marks steps as done via `dispatch-state.sh formula mark-done`
9. Loop continues until all steps complete
10. Skill squashes wisp: `yft_mol_squash <mol-id>`
11. Skill creates chronicle entry from squash summary
12. If all steps passed: closes parent task

**Postconditions**: Wisp squashed. Comments persist on parent task. Chronicle entry created.

**Key Files**:
- `plugins/yf/skills/formula_execute/SKILL.md`
- `plugins/yf/scripts/dispatch-state.sh`

### UC-007: Formula Auto-Selection During Plan Setup

**Actor**: System (plan_create_tasks Step 8b)

**Preconditions**: Tasks are being created from a plan. No explicit `formula:` label on task.

**Flow**:
1. `/yf:formula_select` reads task title and description
2. Skill checks for existing `formula:*` label (respects author override)
3. Skill matches against heuristic table: implement->feature-build, fix->bugfix, research->research-spike, review->code-review, test->build-test, code/write/program+language->code-implement (see UC-030 in IG/coder.md for the code-implement refinement)
4. Skill assesses atomicity: single-file, single-concern tasks skip formula assignment
5. If match found: adds `formula:<name>` label to task
6. During plan pump, formula dispatch rule detects the label and dispatches through formula execution

**Postconditions**: Task has `formula:<name>` label for formula dispatch.

**Key Files**:
- `plugins/yf/skills/formula_select/SKILL.md`

### UC-008: Reactive Bugfix on Failure

**Actor**: System (formula_execute dispatch loop Step 3i)

**Preconditions**: A formula step posts REVIEW:BLOCK or TESTS with failures. Depth < 2. No prior `ys:bugfix-attempt` label.

**Flow**:
1. Dispatch loop detects failure in step comment
2. `formula_execute` evaluates eligibility (not design-BLOCK, depth < 2, no prior attempt)
3. Skill adds `ys:bugfix-attempt` label to prevent re-triggering
4. Skill invokes `/yf:formula_execute formula:bugfix` with failure context at depth+1
5. Bugfix formula runs: diagnose -> fix -> verify
6. If bugfix succeeds: original step is marked for retry via `dispatch-state.sh formula mark-retrying`
7. Dispatch loop re-dispatches the original step
8. If retry fails again: block stands permanently

**Postconditions**: Either the bug is fixed and the step passes on retry, or the block stands for manual intervention.

**Key Files**:
- `plugins/yf/skills/formula_execute/SKILL.md` (Step 3i)
