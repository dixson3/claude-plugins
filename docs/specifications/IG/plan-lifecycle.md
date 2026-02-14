# Implementation Guide: Plan Lifecycle

## Overview

The plan lifecycle converts plans into a dependency graph of tracked tasks with automatic decomposition, scheduling, and dispatch. It manages state transitions through hooks, scripts, and rules.

## Use Cases

### UC-001: Auto-Chain Plan Creation

**Actor**: Operator (via ExitPlanMode)

**Preconditions**: Operator has written a plan in Claude Code plan mode.

**Flow**:
1. Operator exits plan mode (ExitPlanMode tool call)
2. `exit-plan-gate.sh` hook fires: saves plan to `docs/plans/plan-NN.md`, creates `.yoshiko-flow/plan-gate`
3. Hook outputs `Auto-chaining plan lifecycle...` with `PLAN_IDX=NN` and `PLAN_FILE=path`
4. `auto-chain-plan.md` rule consumes the signal
5. Rule formats the plan file with standard structure (Status, Date, Overview, Implementation Sequence, Completion Criteria)
6. (Step 1.5) If specifications exist: invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`
7. Rule updates MEMORY.md with plan reference
8. Rule invokes `/yf:plan_create_beads` -- creates epic, tasks, dependencies, gates, labels, and defers all tasks
9. Rule runs `plan-exec.sh start <root-epic>` -- resolves gate, undefers tasks, removes `.yoshiko-flow/plan-gate`
10. Rule invokes `/yf:plan_execute` -- starts task pump dispatch

**Postconditions**: Plan is in Executing state. Beads hierarchy exists. Tasks are being dispatched to agents.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/exit-plan-gate.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/auto-chain-plan.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh`

### UC-002: Manual Plan Intake (Pasted Plan)

**Actor**: Operator

**Preconditions**: Operator pastes a plan into a new session or says "implement this plan" without ExitPlanMode having fired.

**Flow**:
1. `plan-intake.md` rule detects plan-like content without auto-chain signal
2. Rule invokes `/yf:plan_intake`
3. Skill saves plan file to `docs/plans/plan-NN.md` if not already saved
4. Skill invokes `/yf:plan_create_beads` to create beads hierarchy
5. Skill runs `plan-exec.sh start` to begin execution
6. Skill invokes `/yf:chronicle_capture topic:planning` to capture planning context
7. Skill invokes `/yf:plan_execute` to start dispatch

**Postconditions**: Same as UC-001. Plan goes through full lifecycle regardless of entry path.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-intake.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_intake/SKILL.md`

### UC-003: Task Pump Dispatch

**Actor**: System (plan_execute skill)

**Preconditions**: Plan is in Executing state. Ready beads exist.

**Flow**:
1. `/yf:plan_pump` queries `bd list -l plan:<idx> --ready --type=task --json`
2. Groups beads by `agent:<name>` label
3. Checks `pump-state.sh is-dispatched` to skip already-dispatched beads
4. For formula-labeled beads: invokes `/yf:swarm_run` instead of bare Task dispatch
5. For other beads: launches Task tool calls with `subagent_type` from agent label
6. Marks beads as dispatched via `pump-state.sh mark-dispatched`
7. Agents claim beads (`bd update --status=in_progress`), implement work, close beads (`bd close`)
8. Lead marks completed beads via `pump-state.sh mark-done`
9. Loop: newly unblocked beads become ready, pump dispatches next batch

**Postconditions**: All plan tasks completed. Plan transitions to Completed state.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_pump/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/pump-state.sh`

### UC-004: Plan Completion

**Actor**: System (plan-exec.sh status)

**Preconditions**: All plan tasks are closed.

**Flow**:
1. `plan-exec.sh status` detects all tasks closed
2. Script closes chronicle gate beads
3. Script runs plan-scoped bead pruning (fail-open)
4. `/yf:plan_execute` invokes `/yf:chronicle_capture topic:completion`
5. Skill invokes `/yf:chronicle_diary plan:<idx>` to generate plan-scoped diary entries
6. Skill invokes `/yf:archive_process` to process archive beads
7. If specs exist: invokes `/yf:engineer_suggest_updates plan_idx:<idx>`
8. Plan file status updated to Completed
9. Plan completion report generated (tasks, chronicles, diary, archives, qualification, specs)

**Postconditions**: Plan is Completed. Diary entries generated. Closed beads pruned.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_execute/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-completion-report.md`

### UC-005: Code Gate Enforcement

**Actor**: System (code-gate.sh hook)

**Preconditions**: `.yoshiko-flow/plan-gate` file exists.

**Flow**:
1. Agent attempts Edit or Write tool call
2. `code-gate.sh` hook fires (PreToolUse)
3. Hook checks for `.yoshiko-flow/plan-gate` file
4. If gate exists: checks target file path against exempt patterns
5. Exempt paths pass through: `docs/plans/*`, `.yoshiko-flow/*`, `CHANGELOG.md`, `MEMORY.md`, `README.md`, `.beads/*`, `docs/specifications/*`
6. Non-exempt paths: hook outputs block message with instructions to complete lifecycle
7. If no gate: runs safety-net checks (plan without beads, chronicle staleness nudge)

**Postconditions**: Implementation files blocked until plan reaches Executing state.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/code-gate.sh`
