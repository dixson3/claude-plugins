# Yoshiko Flow — Agent Rules

Rules are ordered by priority. Hard enforcement rules are checked first; advisory monitoring runs at lowest priority.

## 1. HARD ENFORCEMENT

### 1.0 Activation Gate

yf is INACTIVE when ANY of:
- `.yoshiko-flow/config.json` does not exist
- `.yoshiko-flow/config.json` has `enabled: false`
- The beads plugin (`steveyegge/beads`) is not installed

When inactive: all skills except `/yf:setup` refuse to execute, all hooks exit silently.
To activate: install beads (`/install steveyegge/beads`), then run `/yf:setup`.

### 1.1 Beads Are the Source of Truth

Never create native Tasks (TaskCreate) for plan work. All work items come from beads.
Before writing code for a plan, verify beads exist: `bd list -l plan:<idx>`.
If none, invoke `/yf:plan_create_beads` first.

### 1.2 Plan Intake: No Implementation Without Lifecycle

CRITICAL — Backed by `code-gate.sh` (BLOCKS Edit/Write).
Before writing implementation code, self-check:
1. Plan-like content in conversation?
2. User said "implement" + "plan"?
3. `/yf:plan_intake` already run?

If (1) AND (2) AND NOT (3): invoke `/yf:plan_intake`.
Does not apply if auto-chain has already fired.

### 1.3 Formula-Labeled Beads Route Through Swarm

When the task pump reads a bead with a `formula:<name>` label, dispatch via `/yf:swarm_run formula:<name> feature:"<title>" parent_bead:<bead-id>`.
Do NOT use bare Task tool dispatch for formula-labeled beads.
If no formula label: dispatch via bare Task tool with `subagent_type` from `agent:<name>` label.

### 1.4 Specifications Are Anchor Documents

When `<artifact_dir>/specifications/` exists, specifications define the contract.
- No plan may remove, weaken, or contradict existing spec entries without explicit operator approval.
- New functionality requires spec additions as part of the implementing plan.
- Tests reference specification items (REQ-xxx, UC-xxx, DD-xxx) as their primary basis.
- All spec changes require explicit operator approval via AskUserQuestion.
- When in doubt, read the spec. When the spec is silent, extend it.

---

## 2. PLAN LIFECYCLE

### 2.1 Auto-Chain After ExitPlanMode

When ExitPlanMode completes and you see "Auto-chaining plan lifecycle...", execute automatically:
1. Format plan file (standard structure).
2. Specification integrity gate (if specs exist): run intake checklist per `/yf:plan_intake` Step 1.5.
3. Reconcile with specifications: invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`.
4. Update MEMORY.md with plan reference.
5. Create beads: invoke `/yf:plan_create_beads`.
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
1. Read the task: `bd show <task-id>`
2. If non-trivial (multiple files, multiple concerns): invoke `/yf:plan_breakdown <task-id>`
3. If atomic (single file, single concern): proceed directly

### 2.4 Plan Completion Report

When `plan-exec.sh status` returns "completed", invoke `/yf:plan_execute` Step 4 completion sequence.

---

## 3. SWARM EXECUTION

### 3.1 Comment Protocol

Swarm agents communicate via structured comments on the parent bead:
- `FINDINGS:` — research/analysis (Purpose, Sources, Summary, Recommendations)
- `CHANGES:` — implementation (Files Modified, Files Created, Summary)
- `REVIEW:PASS` or `REVIEW:BLOCK` — review (Verdict, Summary, Issues, Files Reviewed)
- `TESTS:` — testing (PASS/FAIL counts, Test Files, Coverage)

### 3.2 Nesting Depth Limit

Maximum nesting depth: **2**. At depth 2, `compose` fields are ignored.

### 3.3 Reactive Bugfix

After `REVIEW:BLOCK` or `TESTS:` with failures, the dispatch loop invokes `/yf:swarm_react`.
Eligible when: depth < 2, no prior `ys:bugfix-attempt` label, config `reactive_bugfix` not false.
Design BLOCKs are excluded — they require human judgment.
Budget: 1 retry per step (configurable via `max_retries`).

---

## 4. SESSION PROTOCOL

### 4.2 Landing the Plane

When ending a work session, invoke `/yf:session_land`.
The pre-push hook (`pre-push-land.sh`) enforces clean-tree and closed-beads prerequisites.
This protocol supersedes the `bd prime` SESSION CLOSE PROTOCOL.

---

## 5. ADVISORY MONITORING

### 5.1 Swarm Completion Bridges

After a swarm completes (wisp squashed):
- FINDINGS with URLs/external sources: suggest `/yf:archive_capture type:research`
- REVIEW:BLOCK with architectural concerns: suggest `/yf:archive_capture type:decision`
- Feature-build/build-test/code-implement with REVIEW:PASS and specs exist: suggest `/yf:engineer_suggest_updates`

At most once per swarm completion. Skip trivial swarms.

### 5.2 Research Spike During Planning

During plan mode, if 3+ web searches or comparing alternatives: suggest `/yf:swarm_run formula:research-spike feature:"<topic>"`.
Check for existing archive beads first. At most once per planning session.

### 5.3 Chronicle Worthiness

Suggest `/yf:chronicle_capture` for context switches, significant blockers, and session boundaries.
At most once every 15 minutes.
NOT chronicle-worthy: routine completions, config tweaks, formatting, typos.

### 5.4 Archive Worthiness

Suggest `/yf:archive_capture type:research` or `type:decision` for web searches, external docs, architecture choices, scope changes with alternatives.
At most once every 15-20 minutes.

### 5.5 Specification Drift

If specs exist, watch for PRD/EDD/IG drift (new functionality not traced to spec entries, contradictions, NFR violations).
Suggest `/yf:engineer_update type:<type>`. At most once every 15-20 minutes.
