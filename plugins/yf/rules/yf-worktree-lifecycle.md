# Rule: Worktree Lifecycle

**Priority:** Hard enforcement

## Rule

When creating or landing epic worktrees, always use the yf worktree skills — never raw `git worktree` commands.

- **Create**: Use `/yf:worktree_create epic_name:<name>` instead of `git worktree add`
- **Land**: Use `/yf:worktree_land` instead of `git merge` + `git worktree remove`

The skills handle beads redirect setup, validation, rebasing, and cleanup as a single atomic workflow. Raw git commands skip these steps and can leave beads in an inconsistent state.

This rule does NOT apply to Claude Code's implicit `isolation: "worktree"` on Task tool calls — that mechanism is managed by the swarm dispatch loop.
