# Implementation Guide: Beads Integration

## Overview

Beads-cli is the external persistence layer that provides git-backed issue tracking for plan work. The yf plugin integrates with beads for task tracking, dependency ordering, label-based routing, and state management.

## Use Cases

### UC-025: Beads Setup and Git Workflow

**Actor**: System (preflight setup)

**Preconditions**: beads-cli >= 0.44.0 installed. Git repository initialized.

**Flow**:
1. Preflight checks `test -d .beads` (setup command guard)
2. If `.beads/` does not exist: runs `bd init`
3. Configures sync branch: `bd config set sync.branch beads-sync`
4. Enables mass-delete protection: `bd config set sync.require_confirmation_on_mass_delete true`
5. Installs git hooks: `bd hooks install`
6. Runs `install-beads-push-hook.sh` to add pre-push hook for beads-sync auto-push
7. Beads manages its own `.beads/.gitignore`

**Postconditions**: Beads initialized with git tracking. Sync branch configured. Push hook installed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/.claude-plugin/preflight.json`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/install-beads-push-hook.sh`

### UC-026: Bead Lifecycle During Plan Execution

**Actor**: System and Agents

**Preconditions**: Plan beads hierarchy created via `plan_create_beads`.

**Flow**:
1. `plan_create_beads` creates root epic, phase epics, task beads, gates
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
   e. Hook runs `bd sync` to push pruned state to beads-sync

**Postconditions**: Closed beads soft-deleted (tombstones, 30-day recovery).

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/plan-prune.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/post-push-prune.sh`

### UC-028: Session Close Protocol (Landing the Plane)

**Actor**: Operator (manual) or Agent (triggered)

**Preconditions**: Work session is ending.

**Flow**:
1. File issues for remaining work (create beads)
2. Capture context: invoke `/yf:chronicle_capture topic:session-close`
3. Generate diary: invoke `/yf:chronicle_diary` to process open chronicles
4. Run quality gates (if code changed)
5. Update issue status: close finished work
6. Sync beads: `bd sync`
7. Commit code changes
8. Push only when operator asks

**Postconditions**: Context preserved. Diary generated. Beads synced.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/beads.md`
