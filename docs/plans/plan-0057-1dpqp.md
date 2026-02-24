# Plan: Update specifications for v3.0.0 (beads-cli removal)

## Context

Plan 0056 removed the beads-cli external dependency and replaced it with a self-contained file-based JSON task system stored under `.yoshiko-flow/` subdirectories. The code migration is complete (committed as `9c85bd6`), but the specification documents still reference beads-cli (`bd` commands, `.beads/` paths, dolt backend, three-condition activation, `beads-setup.sh`, etc.) extensively. These specs need to reflect the v3.0.0 architecture accurately.

## Scope

All specification files under `docs/specifications/` that reference beads-cli concepts. Also updates to `CLAUDE.md`, `yf-rules.md`, and `test-coverage.md` for consistency.

## File-by-File Changes

### 1. EDD/CORE.md (heaviest changes)

**Architecture diagram**: Replace "Beads Persistence Layer (.beads/dolt/)" with "File-Based Task Layer (.yoshiko-flow/{tasks,chronicler,archivist,...})"

**Activation Gate box**: "three-condition check: config + enabled + beads" -> "two-condition check: config + enabled"

**Enforcement Model item 4**: "Beads (persistent): Git-backed issue tracker providing gates, dependencies, labels, and deferred state" -> "File-based tasks (persistent): JSON files under .yoshiko-flow/ providing gates, dependencies, labels, and deferred state"

**Data Flow**: Replace `plan_create_beads -> beads DAG created` with `plan_create_tasks -> task DAG created` and `beads pruned` with `tasks pruned`

**DD-001**: Rename "Beads as Persistent Task Store" -> "File-Based Persistent Task Store". Rewrite context/decision/rationale to describe JSON files under `.yoshiko-flow/` instead of beads-cli. Update consequences to note zero external dependencies. Reference Plan 56.

**DD-003**: Rename "Dolt-Native Persistence" -> "Dolt-Native Persistence — **Superseded**". Mark as superseded by DD-001 update (Plan 56). The dolt backend is no longer used; persistence is direct JSON files.

**DD-005**: Remove "bd-safety-net" reference. Update to note that `code-gate.sh` and `plan-exec-guard.sh` are the remaining hook enforcement mechanisms; the safety-net hook was removed in v3.0.0.

**DD-006**: Rename "Formula-Driven Swarm Execution with Wisps" — update to note wisps are now JSON molecule files under `.yoshiko-flow/molecules/` instead of beads formulas. Remove "Requires beads-cli >= 0.50.0" from consequences. Update TC-003 reference.

**DD-011**: Rename "Soft-Delete Bead Pruning" -> "Soft-Delete Task Pruning". Replace `bd admin cleanup` with `yft_cleanup`. Replace "bead" with "task" throughout.

**DD-015**: Rename "Three-Condition Activation Model" -> "Two-Condition Activation Model". Remove the bd CLI condition. Update `yf_is_enabled()` description to two conditions: config exists + enabled != false. Source: Plan 42 (original), Plan 56 (simplified).

**DD-016**: Already marked as Reversed — update source to note Plan 56 completed full removal.

**DD-017**: Replace "in-progress beads" with "in-progress tasks" throughout. Remove `bd prime` references. Remove `bd sync` references.

**Overview paragraph**: Replace "with beads-cli as the external persistence layer" with "with a file-based JSON task system under `.yoshiko-flow/`"

### 2. IG/beads-integration.md -> IG/task-system.md (rename + full rewrite)

Rename file from `beads-integration.md` to `task-system.md`. Rewrite all use cases:

**UC-025**: "Beads Setup and Git Workflow" -> "Task System Setup". Remove all `bd init`, `.beads/` directory, dolt, AGENTS.md references. New flow: preflight creates `.yoshiko-flow/` subdirectories (tasks/, chronicler/, archivist/, issues/, todos/, molecules/). No external CLI dependency.

**UC-026**: "Bead Lifecycle During Plan Execution" -> "Task Lifecycle During Plan Execution". Replace all `bd` commands with `yft_*` equivalents (`yft_create`, `yft_update`, `yft_close`, `yft_list --ready`). Replace `plan_create_beads` with `plan_create_tasks`.

**UC-027**: "Automatic Bead Pruning" -> "Automatic Task Pruning". Replace `bd admin cleanup` with `yft_cleanup`. Replace `.beads/` paths. Update plan-prune.sh description to use `rm -rf .yoshiko-flow/tasks/<epic-dir>/` for plan-scoped cleanup.

**UC-028**: "Session Close Protocol" -> keep name. Replace `bd list --status=in_progress` with `yft_list --status=in_progress`. Remove `bd prime` SESSION CLOSE PROTOCOL reference (no longer relevant).

**UC-039**: Replace `bd list --status=in_progress --json` with `yft_list --status=in_progress --json`.

**UC-041**: Replace `.beads/.dirty-tree` with `.yoshiko-flow/.dirty-tree`. Replace `.beads/.pending-diary` references if present.

### 3. IG/marketplace.md

**UC-023 Step 2.5**: Remove the `command -v bd` check step entirely. Update flow to show 2-part activation gate (config exists + enabled).

**UC-035**: "Plugin Activation Gate Check" — update from "three conditions: config exists, enabled:true, beads installed" to "two conditions: config exists, enabled != false". Remove beads condition from flow.

**UC-036**: "Per-Project Activation via /yf:plugin_setup" — remove "bd CLI available" precondition. Remove "If bd missing: report dependency" step. Remove "beads init" from postconditions. Update flow to show that setup writes config and runs preflight to install rules and create directories (no beads initialization).

### 4. PRD.md

**TC-003**: Remove entirely or rewrite. The beads-cli dependency no longer exists. Replace with: "TC-003: jq required for JSON processing (external dependency)" — consolidating with TC-002 or renumbering.

**TC-009**: Remove "Beads state persisted via embedded dolt database..." — replace with "Task state persisted as JSON files under `.yoshiko-flow/` subdirectories; writes immediate via filesystem"

**REQ-003**: "Plans must be convertible into a beads hierarchy" -> "Plans must be convertible into a task hierarchy (epics, tasks, dependencies, gates) with agent assignments". Update code reference from `plan_create_beads` to `plan_create_tasks`.

**REQ-006**: Update "create beads" to "create tasks" in auto-chain description.

**REQ-008**: Replace `bd ready` with `yft_list --ready`. Replace "beads" with "tasks" throughout.

**REQ-009**: "Chronicle beads" -> "Chronicle entries"

**REQ-011**: "Chronicle beads must be composable" -> "Chronicle entries must be composable"

**REQ-012**: "Chronicle gate beads" -> "Chronicle gates"

**REQ-013**: "archive beads" -> "archive entries"

**REQ-014**: "archive beads" -> "archive entries"

**REQ-018**: "parent bead" -> "parent task"

**REQ-026**: "Closed beads must be automatically pruned" -> "Closed tasks must be automatically pruned". Remove "soft-delete tombstones" (file system uses `rm`).

**REQ-027**: Remove entirely (beads initialization is no longer relevant). Or replace with: "REQ-027: Task directories must be automatically created under `.yoshiko-flow/` during preflight."

**REQ-028**: Remove "bd CLI to be available" and "bd CLI and blocks activation if absent." Update to: "Setup requires no external CLI dependencies."

**REQ-034**: "Three-condition activation gate" -> "Two-condition activation gate: (1) `.yoshiko-flow/config.json` exists, (2) `enabled != false`." Remove bd CLI condition.

**REQ-035**: Remove entirely (no bd CLI dependency enforcement). Or replace with: "REQ-035: Preflight must create `.yoshiko-flow/` subdirectories and manage rule symlinks."

**REQ-039**: "in-progress beads" -> "in-progress tasks"

**REQ-040**: Update code reference.

**REQ-041**: Replace `.beads/` marker references.

**REQ-043**: "ys:issue beads" -> "ys:issue tasks"

**REQ-044**: "issue beads" -> "issue tasks"

**FS-006**: "beads-native (gates/defer)" -> "task-native (gates/defer)"

**FS-009**: "beads grouped by agent label" -> "tasks grouped by agent label"

**FS-012**: "ephemeral wisps; results persist as comments on parent bead" -> "ephemeral wisps; results persist as comments on parent task"

**FS-014**: "auto-select at bead creation" -> "auto-select at task creation"

**FS-015**: "Chronicle beads capture" -> "Chronicle entries capture"

**FS-016**: Remove "beads" from description.

**FS-018**: "draft beads" -> "draft entries"

**FS-026**: "Beads is the source of truth" -> "File-based tasks are the source of truth"

**FS-027**: Remove entirely (beads/dolt setup is gone).

**FS-028**: Replace "beads" with "tasks". Remove "soft-delete (tombstones, 30-day recovery)" — file deletion is immediate.

**FS-029**: Remove entirely (bd-safety-net hook removed).

**FS-040**: "Three-condition activation gate" -> "Two-condition activation gate". Remove bd CLI condition.

**FS-041**: Remove entirely (no bd dependency check).

**FS-043**: Replace all `bd create` references with `yft_create`. Replace "bead" with "task/entry" as appropriate.

**FS-044**: "in-progress beads" -> "in-progress tasks"

**FS-045**: "in-progress beads" -> "in-progress tasks"

**FS-047**: ".beads/.dirty-tree" -> ".yoshiko-flow/.dirty-tree"

**FS-048**: Remove `bd prime` reference. Simplify to just note that yf manages git workflow via session_land.

**FS-050**: "bead with `ys:issue` label" -> "task with `ys:issue` label"

**FS-054**: "open `ys:issue` beads" -> "open `ys:issue` tasks". "warn_open_beads" -> "warn_open_tasks" (if function was renamed).

### 5. IG/plan-lifecycle.md

**UC-001**: Replace "plan_create_beads" with "plan_create_tasks" in steps 8-9. Replace "Beads hierarchy exists" with "Task hierarchy exists" in postconditions. Replace "beads creation" in chronicle guidance.

**UC-002**: Replace "plan_create_beads" with "plan_create_tasks" in step 5. Replace "beads hierarchy" references.

**UC-003**: Replace `bd list -l plan:<idx> --ready --type=task --json` with `yft_list -l plan:<idx> --ready --type=task --json`. Replace "beads by agent label" with "tasks by agent label". Replace all `bd update`/`bd close` with `yft_update`/`yft_close`. Replace "dispatched beads" with "dispatched tasks". Replace "completed beads" with "completed tasks".

**UC-004**: Replace "chronicle gate beads" with "chronicle gates". Replace "bead pruning" with "task pruning". Replace "archive beads" with "archive entries". Replace "Closed beads pruned" with "Closed tasks pruned".

**UC-005**: Replace "Plan without beads" with "Plan without tasks" in step 7a. Replace `.beads/*` exempt path with `.yoshiko-flow/*` (if not already done). Replace "beads exist for its plan label" with "tasks exist for its plan label". Replace references to `bd list` implicit in the safety-net check.

### 6. IG/swarm-execution.md

**UC-006**: Replace `bd mol wisp <formula-path>` with `yft_mol_wisp <formula-path>`. Replace "parent bead" with "parent task" (5+ occurrences). Replace `bd mol squash` with `yft_mol_squash`. Replace "chronicle bead" with "chronicle entry".

**UC-007**: Replace "bead creation" with "task creation". Replace "plan_create_beads" with "plan_create_tasks". Replace "bead" with "task" throughout.

**UC-008**: Replace "parent bead" with "parent task".

**UC-009**: Replace "parent bead" with "parent task" throughout.

### 7. IG/chronicler.md

**UC-010**: Replace `bd create --type=task --title="Chronicle: <topic>"` with `yft_create --type=chronicle --title="Chronicle: <topic>"`. Replace "chronicle bead" with "chronicle entry". Replace "`bd` is available" precondition.

**UC-011**: Replace `bd list --label=ys:chronicle --status=open --format=json` with `yft_list -l ys:chronicle --status=open --json`. Replace `.beads/.pending-diary` with `.yoshiko-flow/.pending-diary`.

**UC-012**: Replace `.beads/.chronicle-drafted-YYYYMMDD` with `.yoshiko-flow/.chronicle-drafted-YYYYMMDD`. Replace "draft chronicle bead" with "draft chronicle entry". Replace `.beads/.pending-diary` with `.yoshiko-flow/.pending-diary`. Replace "in-progress beads" with "in-progress tasks".

**UC-013**: Replace "chronicle beads" with "chronicle entries". Replace "chronicle gate is closed" language. Replace "draft beads" with "draft entries". Replace "parent bead" with "parent task". Replace "processed chronicle beads" with "processed chronicle entries".

**UC-038**: Replace `bd create --type task --title` with `yft_create --type=chronicle --title`. Replace "`bd` is available" precondition. Replace "chronicle bead" with "chronicle entry". Replace `bd create` in flow step 3.

### 8. IG/archivist.md

**UC-014**: Replace "archive bead" with "archive entry". Replace "Bead labeled" with "Entry labeled".

**UC-015**: Replace "archive bead" with "archive entry". Replace "Bead labeled" with "Entry labeled".

**UC-016**: Replace "archive beads" with "archive entries". Replace "Beads closed" with "Entries closed".

**UC-017**: Replace "archive beads" with "archive entries". Replace "draft archive beads" with "draft archive entries".

### 9. IG/engineer.md

**UC-019**: No direct beads references, but update "plan beads" to "plan tasks" if present.

**UC-021**: Replace "completed plan beads" with "completed plan tasks". Replace "CHANGES/FINDINGS/REVIEW comments" context if it references beads.

### 10. test-coverage.md

**REQ-003**: Update summary "Plans to beads hierarchy" -> "Plans to task hierarchy"

**REQ-026**: "Bead auto-pruning" -> "Task auto-pruning"

**REQ-027**: "Beads git-tracked" -> mark as removed/superseded. Remove `unit-beads-git.yaml` reference (file deleted).

**REQ-035**: "bd CLI dependency enforcement" -> update to "Preflight directory management" or mark as superseded.

**DD-001**: "Beads as persistent task store" -> "File-based persistent task store"

**DD-003**: "Dolt-native persistence" -> mark as superseded

**DD-011**: "Soft-delete bead pruning" -> "Soft-delete task pruning"

**DD-015**: "Three-condition activation model" -> "Two-condition activation model"

**UC-025**: "Beads setup and git workflow" -> "Task system setup". Remove `unit-beads-git.yaml` and `unit-beads-setup.yaml` references (deleted). Update test file references.

**UC-026**: "Bead lifecycle" -> "Task lifecycle"

**UC-027**: "Automatic bead pruning" -> "Automatic task pruning"

**UC-028**: Update test file references.

**UC-039**: Update "beads" references.

**UC-041**: Update `.beads/` marker references.

**Coverage Summary**: Update totals (some tests deleted, new tests added — 824 assertions per last run).

**Priority Gaps item 4**: "Plans-to-beads hierarchy" -> "Plans-to-task hierarchy"

### 11. TODO.md

**TODO-003**: Replace "plan_create_beads" with "plan_create_tasks"

**TODO-006**: Remove or mark complete — `bd cook --dry-run` is no longer applicable; formulas are now instantiated via `yft_mol_wisp`.

**TODO-009**: Remove or mark complete — "legacy local-only beads deployments" no longer relevant.

**TODO-015**: Remove or mark complete — `bd create --type=gate` workaround no longer relevant (file-based system handles gates directly).

**TODO-C01, TODO-C05, TODO-008**: Update completed item descriptions to note these are historical (beads era). No changes needed beyond acknowledging context.

### 12. CLAUDE.md (root)

**Current Plugins bullet**: Remove "doctor-driven beads repair" from the v3.0.0 description. Already partially done — verify current text is accurate.

### 13. yf-rules.md (already loaded into context — verify accuracy)

**Rule 1.0**: Already updated in code migration? Verify: should say two conditions, no bd CLI mention.

**Rule 1.1**: "Beads Are the Source of Truth" -> "Tasks Are the Source of Truth". Replace "Never create native Tasks (TaskCreate) for plan work. All work items come from beads." with appropriate v3.0 language. Replace `bd list -l plan:<idx>` with `yft_list -l plan:<idx>`. Replace `plan_create_beads` with `plan_create_tasks`.

**Rule 1.3**: Replace "bead" with "task" throughout. Update `bd` references if any remain.

**Rule 2.1**: Replace "Create beads" with "Create tasks". Replace `plan_create_beads` with `plan_create_tasks`.

**Rule 2.3**: Replace `bd show <task-id>` with `yft_show <task-id>`.

**Rule 3.1**: Replace "parent bead" with "parent task".

**Rule 4.2**: Replace any remaining beads references.

**Rule 5.1**: Replace "parent bead" with "parent task". Replace "bead" with "task" where applicable.

## Implementation Order

1. **EDD/CORE.md** — Foundation document; DD changes cascade to all other specs
2. **IG/beads-integration.md -> IG/task-system.md** — Full rename + rewrite
3. **PRD.md** — REQ/FS/TC updates
4. **IG/marketplace.md** — Activation gate updates
5. **IG/plan-lifecycle.md** — bd command replacements
6. **IG/swarm-execution.md** — Bead -> task terminology
7. **IG/chronicler.md** — bd command + .beads/ path replacements
8. **IG/archivist.md** — Terminology updates
9. **IG/engineer.md** — Minor terminology
10. **test-coverage.md** — Test file references + terminology
11. **TODO.md** — Mark superseded items, update terminology
12. **CLAUDE.md** — Verify current description accuracy
13. **yf-rules.md** — Verify all beads references removed

## Verification

1. `grep -riE 'beads-cli|bd create|bd list|bd show|bd update|bd close|bd comment|bd label|bd dep|bd gate|bd mol|bd init|bd config|bd doctor|bd vc|bd delete|bd count|bd ready|bd admin|bd prime|bd sync|bd setup|bd cook|\.beads/' docs/specifications/` — should return zero results
2. `grep -riE 'beads-cli|\.beads/' plugins/yf/rules/yf-rules.md` — should return zero results
3. `grep -ri 'three-condition' docs/specifications/` — should return zero results (all updated to two-condition)
4. `grep -ri 'plan_create_beads' docs/specifications/` — should return zero results
5. `bash tests/run-tests.sh --unit-only` — 824 tests still pass (spec changes are documentation-only)
