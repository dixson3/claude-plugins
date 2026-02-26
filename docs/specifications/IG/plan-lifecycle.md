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
8. Rule invokes `/yf:plan_create_tasks` -- creates epic, tasks, dependencies, gates, labels, and defers all tasks
9. Rule runs `plan-exec.sh start <root-epic>` -- resolves gate, undefers tasks, removes `.yoshiko-flow/plan-gate`
10. Rule invokes `/yf:plan_execute` -- starts task pump dispatch

**Postconditions**: Plan is in Executing state. Task hierarchy exists. Tasks are being dispatched to agents.

**Chronicle/archive guidance**: A plan-save chronicle stub is created automatically by `exit-plan-gate.sh`. If the planning discussion had significant design rationale beyond the plan file, optionally invoke `/yf:chronicle_capture topic:planning`. If the discussion involved web searches or comparing alternatives, invoke `/yf:archive_capture type:research` or `type:decision` between plan save and task creation. If any step fails, stop and report — the user can retry or run `/yf:plan_dismiss_gate`.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/exit-plan-gate.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/auto-chain-plan.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh`

### UC-002: Manual Plan Intake (Pasted Plan)

**Actor**: Operator

**Preconditions**: Operator pastes a plan into a new session or says "implement this plan" without ExitPlanMode having fired.

**Detection criteria** (fires when ALL are true):
- The user says "implement the/this plan" or provides plan content to execute
- Plan-like content exists (headings like "## Implementation", structured task lists)
- The auto-chain has NOT fired (no "Auto-chaining plan lifecycle..." message)

**Flow**:
1. `plan-intake.md` rule detects plan-like content without auto-chain signal
2. Rule invokes `/yf:plan_intake`
3. (Step 0) Foreshadowing check: auto-classify and commit uncommitted changes (UC-040)
3b. (Step 0.5) Clean prior plan state: `bash plugins/yf/scripts/session-prune.sh completed-plans` — removes residual state from completed prior plans (fail-open)
4. Skill saves plan file to `docs/plans/plan-NN.md` if not already saved
5. Skill invokes `/yf:plan_create_tasks` to create task hierarchy
6. Skill runs `plan-exec.sh start` to begin execution
7. Skill invokes `/yf:chronicle_capture topic:planning` to capture planning context
8. Skill invokes `/yf:plan_execute` to start dispatch

**Postconditions**: Same as UC-001. Plan goes through full lifecycle regardless of entry path.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-intake.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_intake/SKILL.md`

### UC-003: Task Pump Dispatch

**Actor**: System (plan_execute skill)

**Preconditions**: Plan is in Executing state. Ready tasks exist.

**Flow**:
1. `/yf:plan_pump` queries `yft_list -l plan:<idx> --ready --type=task --json`
2. Groups tasks by `agent:<name>` label
3. Checks `pump-state.sh is-dispatched` to skip already-dispatched tasks
4. For formula-labeled tasks: invokes `/yf:formula_execute` instead of bare Task dispatch
5. For other tasks: launches Task tool calls with `subagent_type` from agent label
6. Marks tasks as dispatched via `pump-state.sh mark-dispatched`
7. Agents claim tasks (`yft_update --status=in_progress`), implement work, close tasks (`yft_close`)
8. Lead marks completed tasks via `pump-state.sh mark-done`
9. Loop: newly unblocked tasks become ready, pump dispatches next batch

**Postconditions**: All plan tasks completed. Plan transitions to Completed state.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_pump/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/pump-state.sh`

### UC-004: Plan Completion

**Actor**: System (plan-exec.sh status)

**Preconditions**: All plan tasks are closed.

**Flow**:
1. `plan-exec.sh status` detects all tasks closed
2. Script closes chronicle gates
3. Script runs plan-scoped task pruning (fail-open)
4. `/yf:plan_execute` invokes `/yf:chronicle_capture topic:completion`
5. Skill invokes `/yf:chronicle_diary plan:<idx>` to generate plan-scoped diary entries
6. Skill invokes `/yf:archive_process` to process archive entries
7. If specs exist: invokes `/yf:engineer_suggest_updates plan_idx:<idx>`
8. Plan file status updated to Completed
9. Plan completion report generated (tasks, chronicles, diary, archives, qualification, specs)

**Postconditions**: Plan is Completed. Diary entries generated. Closed tasks pruned.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_execute/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/plan-completion-report.md`

### UC-005: Code Gate Enforcement

**Actor**: System (code-gate.sh hook)

**Preconditions**: `.yoshiko-flow/plan-gate` file exists, or plan files exist in `docs/plans/`.

**Flow**:
1. Agent attempts Edit or Write tool call
2. `code-gate.sh` hook fires (PreToolUse)
3. Hook checks for `.yoshiko-flow/plan-gate` file
4. If gate exists: checks target file path against exempt patterns
5. Exempt paths pass through: `docs/plans/*`, `.yoshiko-flow/*`, `CHANGELOG.md`, `MEMORY.md`, `README.md`, `docs/specifications/*`
6. Non-exempt paths: hook outputs block message with instructions to complete lifecycle
7. If no gate: runs safety-net checks:
   a. **Plan without tasks**: If a plan file exists in `docs/plans/` with status != Completed and no tasks exist for its `plan:<idx>` label, BLOCK the edit. Direct agent to `/yf:plan_intake` (to set up the lifecycle) or `/yf:plan_dismiss_gate` (to abandon it). **The skip marker (`.yoshiko-flow/plan-intake-skip`) must only be created by `/yf:plan_dismiss_gate` — agents must never create it directly.**
   b. **Chronicle staleness nudge**: If in-progress tasks exist with no recent chronicle, emit advisory nudge (non-blocking).
8. Skip marker `.yoshiko-flow/plan-intake-ok` (from successful intake) or `.yoshiko-flow/plan-intake-skip` (from dismiss gate) suppresses the tasks check for the remainder of the session.

**Postconditions**: Implementation files blocked until plan reaches Executing state or is explicitly dismissed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/code-gate.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_dismiss_gate/SKILL.md`

### UC-040: Plan Foreshadowing at Intake

**Actor**: System (plan_intake skill, Step 0)

**Preconditions**: Plan intake invoked. Working tree has uncommitted changes.

**Flow**:
1. `plan_intake` Step 0 runs `git status --porcelain`. If clean, skip to Step 1.
2. Parse plan content to identify target scope (file paths, directories, modules).
3. For each uncommitted file, check overlap with plan scope:
   - **Foreshadowing**: file path overlaps plan targets (same directory/module/component)
   - **Unrelated**: no overlap
4. Commit unrelated changes: `"Pre-plan commit: unrelated changes before plan-<idx>"`
5. Commit foreshadowing changes: `"Plan foreshadowing (plan-<idx>): <summary>"`
6. Report classification and commits.

**Postconditions**: Working tree is clean. Uncommitted changes classified and committed with descriptive messages.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_intake/SKILL.md`
