# Yoshiko Flow — Agent Rules

Rules are ordered by priority. Hard enforcement rules are checked first; advisory monitoring runs at lowest priority.

## 1. HARD ENFORCEMENT

### 1.0 Activation Gate

yf is INACTIVE when ANY of:
- `.yoshiko-flow/config.json` does not exist
- `.yoshiko-flow/config.json` has `enabled: false`

When inactive: all skills except `/yf:plugin_setup` refuse to execute, all hooks exit silently.
To activate: run `/yf:plugin_setup`.

### 1.1 Tasks Are the Source of Truth

Never create native Tasks (TaskCreate) for plan work. All work items come from yf tasks.
Before writing code for a plan, verify tasks exist: `bash "$YFT" list -l plan:<idx>`.
If none, invoke `/yf:plan_create_tasks` first.

### 1.2 Plan Intake: No Implementation Without Lifecycle

CRITICAL — Backed by `code-gate.sh` (BLOCKS Edit/Write).
Before writing implementation code, self-check:
1. Plan-like content in conversation?
2. User said "implement" + "plan"?
3. `/yf:plan_intake` already run?

If (1) AND (2) AND NOT (3): invoke `/yf:plan_intake`.
Does not apply if auto-chain has already fired.
If `.yoshiko-flow/plan-gate` exists, the plan is gated. Never dismiss the gate to bypass the lifecycle — if auto-chain failed, diagnose and re-run `/yf:plan_intake`.

### 1.3 Formula-Labeled Tasks Route Through Formula Execute

When the task pump reads a task with a `formula:<name>` label, dispatch via `/yf:formula_execute task_id:<task-id> formula:<name>`.
Do NOT use bare Task tool dispatch for formula-labeled tasks.
If no formula label: dispatch via bare Task tool with `subagent_type` from `agent:<name>` label.

### 1.4 Specifications Are Anchor Documents

When `<artifact_dir>/specifications/` exists, specifications define the contract.
- No plan may remove, weaken, or contradict existing spec entries without explicit operator approval.
- New functionality requires spec additions as part of the implementing plan.
- Tests reference specification items (REQ-xxx, UC-xxx, DD-xxx) as their primary basis.
- All spec changes require explicit operator approval via AskUserQuestion.
- When in doubt, read the spec. When the spec is silent, extend it.

### 1.5 Issue Disambiguation

Plugin issues and project issues are distinct destinations. Never cross-route.

- **Plugin issues** (`/yf:plugin_issue`): Bugs, enhancements, and feedback about the yf plugin. Targets the plugin repo (default: `dixson3/d3-claude-plugins`). **Manually initiated only** — never suggest proactively.
- **Project issues** (`/yf:issue_capture`): Bugs, enhancements, and technical debt in the user's project. Stages a `ys:issue` task for deferred submission to the project's tracker.

**Guards:**
- `plugin_issue`: If the issue references project-specific code (not plugin internals), warn and redirect to `/yf:issue_capture`.
- `issue_capture`: If the issue references yf or plugin internals, warn and redirect to `/yf:plugin_issue`.
- `issue_process`: Before submission, verify the plugin repo slug differs from the project tracker slug.
- When ambiguous, ask the user.

### 1.6 Worktree Lifecycle

Use yf worktree skills for epic worktrees — never raw `git worktree` commands.
- **Create**: `/yf:worktree_create epic_name:<name>` (not `git worktree add`)
- **Land**: `/yf:worktree_land` (not `git merge` + `git worktree remove`)

Skills handle validation, rebasing, and cleanup atomically. Raw git commands leave task state inconsistent.
Does NOT apply to Claude Code's implicit `isolation: "worktree"` on Task tool calls.

---

## 2. PLAN LIFECYCLE

### 2.1 Auto-Chain After ExitPlanMode

When ExitPlanMode completes and you see "Auto-chaining plan lifecycle...", execute automatically:
1. Format plan file (standard structure).
2. Specification integrity gate (if specs exist): run intake checklist per `/yf:plan_intake` Step 1.5.
3. Reconcile with specifications: invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`.
4. Update MEMORY.md with plan reference.
5. Create tasks: invoke `/yf:plan_create_tasks`.
6. Start execution: `bash plugins/yf/scripts/plan-exec.sh start "$ROOT_EPIC"`.
7. Begin dispatch: invoke `/yf:plan_execute`.

If any step fails, stop and report. The user can retry or run `/yf:plan_dismiss_gate`.

### 2.2 Plan Lifecycle Phrase Triggers

When the user says lifecycle phrases, invoke `/yf:plan_engage`:
- "the plan is ready" / "activate the plan" -> Ready
- "execute the plan" / "start the plan" / "run the plan" -> Executing
- "pause the plan" / "stop the plan" -> Paused
- "resume the plan" -> Resume
- "mark plan complete" -> Complete

### 2.3 Breakdown Before Building

Before writing code on a claimed task:
1. Read the task: `bash "$YFT" show <task-id>`
2. If non-trivial (multiple files, multiple concerns): invoke `/yf:plan_breakdown <task-id>`
3. If atomic (single file, single concern): proceed directly

### 2.4 Plan Completion Report

When `plan-exec.sh status` returns "completed", invoke `/yf:plan_execute` Step 4 completion sequence.

---

## 3. FORMULA EXECUTION

### 3.1 Comment Protocol

Formula agents communicate via structured comments on the parent task:
- `FINDINGS:` — research/analysis (Purpose, Sources, Summary, Recommendations)
- `CHANGES:` — implementation (Files Modified, Files Created, Summary)
- `REVIEW:PASS` or `REVIEW:BLOCK` — review (Verdict, Summary, Issues, Files Reviewed)
- `TESTS:` — testing (PASS/FAIL counts, Test Files, Coverage)

### 3.2 Nesting Depth Limit

Maximum nesting depth: **2**. At depth 2, reactive bugfix is ineligible.

### 3.3 Reactive Bugfix

After `REVIEW:BLOCK` or `TESTS:` with failures, the `formula_execute` dispatch loop handles reactive bugfix inline.
Eligible when: depth < 2, no prior `ys:bugfix-attempt` label, config `reactive_bugfix` not false.
Design BLOCKs are excluded — they require human judgment.
Budget: 1 retry per step (configurable via `max_retries`).

---

## 4. SESSION PROTOCOL

### 4.2 Landing the Plane

When ending a work session, invoke `/yf:session_land`.
The pre-push hook (`pre-push-land.sh`) enforces clean-tree and closed-tasks prerequisites.

---

## 5. ADVISORY MONITORING

### 5.1 Formula Completion Bridges

After a formula completes (wisp squashed):
- FINDINGS with URLs/external sources: suggest `/yf:archive_capture type:research`
- REVIEW:BLOCK with architectural concerns: suggest `/yf:archive_capture type:decision`
- Feature-build/build-test/code-implement with REVIEW:PASS and specs exist: suggest `/yf:engineer_suggest_updates`

At most once per formula completion. Skip trivial formulas.

### 5.2 Research Spike During Planning

During plan mode, if 3+ web searches or comparing alternatives: suggest `/yf:formula_execute task_id:<task-id> formula:research-spike`.
Check for existing archive tasks first. At most once per planning session.

### 5.3 Chronicle Worthiness

Suggest `/yf:chronicle_capture` for context switches, significant blockers, and session boundaries.
At most once every 15 minutes.

### 5.4 Archive Worthiness

Suggest `/yf:archive_capture type:research` or `type:decision` for web searches, external docs, architecture choices, scope changes with alternatives.
At most once every 15-20 minutes.

### 5.5 Specification Drift

If specs exist, watch for PRD/EDD/IG drift (new functionality not traced to spec entries, contradictions, NFR violations).
Suggest `/yf:engineer_update type:<type>`. At most once every 15-20 minutes.

### 5.6 Issue Worthiness

During planning, design, implementation, and testing, watch for deferred improvements, incidental bugs, enhancement opportunities, and technical debt.

Suggest `/yf:issue_capture` with appropriate type and priority context.
At most once every 15 minutes.
Project issues ONLY — never suggest `/yf:plugin_issue` proactively.
