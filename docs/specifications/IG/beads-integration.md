# Implementation Guide: Beads Integration

## Overview

Beads-cli is the external persistence layer that provides git-backed issue tracking for plan work. The yf plugin integrates with beads for task tracking, dependency ordering, label-based routing, and state management.

## Use Cases

### UC-025: Beads Setup and Git Workflow

**Actor**: System (preflight setup)

**Preconditions**: beads-cli >= 0.50.0 installed. Git repository initialized.

**Flow**:
1. Preflight checks `test -d .beads` (setup command guard)
2. If `.beads/` does not exist: runs `bd init` (uses `dolt` backend by default since 0.50.0; writes persist immediately)
3. No AGENTS.md is created — the plugin provides beads workflow context via its own rule file (`yf-rules.md`)
4. All task operations (create, update, close, list) use `bd` CLI directly.
5. Beads manages its own `.beads/.gitignore`

**Postconditions**: Beads initialized with `dolt` backend. Writes persist immediately. No AGENTS.md. No hooks installed. No sync branch configured.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/preflight.json`

### UC-026: Bead Lifecycle During Plan Execution

**Actor**: System and Agents

**Preconditions**: Plan beads hierarchy created via `plan_create_beads`.

**Flow**:
1. `plan_create_beads` creates root epic, phase epics, task beads, gates (note: `bd create --type=gate` may fail in some beads-cli versions — gates are created as tasks with `ys:gate` labels as workaround; see TODO-015)
2. Dependencies wired via `bd dep add`
3. Agent labels assigned via `/yf:plan_select_agent`
4. Formula labels assigned via `/yf:swarm_select_formula` (Step 8b)
5. All tasks deferred initially
6. `plan-exec.sh start` resolves gate, undefers tasks
7. Task pump reads `bd ready`, dispatches via Task tool
8. Agents claim: `bd update <id> --status=in_progress`
9. Agents complete: `bd close <id>`
10. Newly unblocked tasks become ready for next pump cycle

**Postconditions**: All tasks closed. Plan transitions to Completed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_create_beads/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-exec.sh`

### UC-027: Automatic Bead Pruning

**Actor**: System

**Preconditions**: Closed beads exist. Pruning is enabled in config.

**Flow**:
1. **Plan-scoped**: When `plan-exec.sh status` returns `completed`:
   a. Script checks `yf_is_prune_on_complete()`
   b. Runs `plan-prune.sh plan <label>` in fail-open subshell
   c. Script soft-deletes closed tasks, epics, gates for the plan
2. **Global**: After `git push` via `post-push-prune.sh` PostToolUse hook:
   a. Hook checks `yf_is_prune_on_push()`
   b. Runs `plan-prune.sh global`
   c. Script runs `bd admin cleanup --older-than <days> --force` (default 7 days)
   d. Script runs `bd admin cleanup --ephemeral --force` for closed wisps

**Postconditions**: Closed beads soft-deleted (tombstones, 30-day recovery).

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-prune.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/post-push-prune.sh`

### UC-028: Session Close Protocol (Landing the Plane)

**Actor**: Operator (via `/yf:session_land`) or Agent (triggered)

**Preconditions**: Work session is ending.

**Flow**:
1. Check dirty tree: `git status --porcelain`. Report changed files.
2. File remaining work: `bd list --status=in_progress`. Ask operator to close, leave open, or create followup.
3. Capture context (conditional): invoke `/yf:chronicle_capture topic:session-close`
4. Generate diary (conditional): invoke `/yf:chronicle_diary` to process open chronicles
5. Run quality gates (conditional, if code changed)
6. Memory reconciliation (conditional, if specs exist): invoke `/yf:memory_reconcile mode:check`
7. Update issue status: close finished beads
8. Session prune: `bash plugins/yf/scripts/session-prune.sh all`
9. Commit: stage changes, present diff summary, commit
10. Push with operator confirmation: AskUserQuestion "Push to remote?" If yes, `git push`.
11. Hand off: summarize done/remaining/context

**Postconditions**: Context preserved. Diary generated. Code committed. Push with operator consent.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/session_land/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/pre-push-land.sh`

### UC-039: Pre-Push Enforcement

**Actor**: System (pre-push-land.sh hook)

**Preconditions**: Agent attempts `git push`.

**Flow**:
1. `pre-push-land.sh` fires as PreToolUse hook on `Bash(git push*)`
2. Check uncommitted changes: `git status --porcelain`
3. Check in-progress beads: `bd list --status=in_progress --json`
4. If either condition fails: exit 2 (block) with structured checklist output
5. If both pass: exit 0 (allow). Existing `pre-push-diary.sh` fires after.

**Postconditions**: Push proceeds only when working tree is clean and no beads are in-progress.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/pre-push-land.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/plugin.json`

### UC-041: Dirty-Tree Cross-Session Awareness

**Actor**: System (session-end.sh and session-recall.sh)

**Preconditions**: Session ending with uncommitted changes, or new session starting after previous dirty session.

**Flow**:
1. **Session end**: `session-end.sh` checks `git status --porcelain`. If dirty, writes `.beads/.dirty-tree` marker with timestamp and file count.
2. **Session start**: `session-recall.sh` reads `.beads/.dirty-tree`. If found, sets `HAS_DIRTY=true` and `DIRTY_FILE_COUNT`, removes marker, includes warning in session recall output.

**Postconditions**: Next session is warned about left-behind uncommitted changes.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/session-end.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/session-recall.sh`
