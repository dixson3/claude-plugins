# Research: Worktree Concurrency, ID Collision, and Swarm Isolation

**Status**: COMPLETED
**Started**: 2026-02-21
**Updated**: 2026-02-21

## Purpose

Investigate the parallel worktree execution model for yf swarm agents. Specifically: understand git worktree concurrency characteristics, evaluate ID collision risk when multiple agents generate identifiers simultaneously, assess Claude Code's built-in worktree isolation support, and design a merge-back strategy for swarm agent output.

## Sources

| Source | URL | Key Findings |
|--------|-----|--------------|
| Git worktree documentation | https://git-scm.com/docs/git-worktree | Worktrees share .git directory but have independent working trees; branch checkout is exclusive per worktree |
| Plan 51 beads redirect pattern | Internal (Plan 51) | `.beads/redirect` enables shared beads database across worktrees |
| Claude Code Task tool | Internal (Claude Code docs) | `isolation: "worktree"` creates worktrees automatically in `.claude/worktrees/`; dispatch loop does not need to manage worktree lifecycle |
| SHA-256 / base36 evaluation | Internal analysis | 5-char base36 truncation of SHA-256 provides 60M collision space with no external dependencies |

## Summary

### Worktree Concurrency

Git worktrees share the same `.git` directory but maintain independent working trees. Multiple worktrees can read and write independently without locking conflicts. The key constraint is that branch checkout is exclusive -- each worktree must be on a unique branch. The `.beads/redirect` pattern from Plan 51 enables a shared beads database across worktrees. Config resolution requires a worktree-aware fallback: check the main repo when local config is absent.

### ID Collision Risk

Sequential ID generation schemes (`plan-NN`, `TODO-NNN`, `REQ-001`) are unsafe across parallel worktrees. Two agents can mint the same ID simultaneously, producing duplicate entries with identical keys on merge. Git provides no content-level protection against this.

**Hash ID algorithm evaluation:**

| Approach | Verdict | Rationale |
|----------|---------|-----------|
| UUID v4 | Rejected | 36 chars, poor human readability |
| Nanoid | Rejected | Requires external dependency |
| SHA-256 truncated to base36 | **Selected** | 5-char base36 gives 60M collision space, macOS-native via `shasum -a 256`, case-insensitive safe (HFS+), no external deps |
| Sequential with locking | Rejected | File locks do not work reliably across worktrees |

The selected implementation, `yf_generate_id()`, hashes timestamp + PID + `$RANDOM` + an internal sequence counter, converts to base36, and truncates to 5 characters. The internal counter prevents duplicates within the same shell session.

### Claude Code Worktree Integration

Claude Code's Task tool supports `isolation: "worktree"` which:
- Creates a git worktree in `.claude/worktrees/` with a new branch based on HEAD
- Sets the agent's working directory to the worktree automatically
- Auto-cleans if no changes were made; returns path and branch if changes exist

This means `swarm_dispatch` only needs to handle merge-back, not worktree creation.

### Merge-Back Strategy

A 4-level escalating conflict resolution model for swarm agent worktree merges:

1. **`git rebase -X theirs`** -- accept the agent's version (agent owns its output)
2. **Claude-driven resolution** -- read conflict markers, resolve with Read+Edit tools
3. **Abort + re-dispatch** -- agent re-runs against updated HEAD
4. **Human escalation** -- leave branch intact, mark as conflict

### Backwards Compatibility

- Sed pattern `[a-z0-9]*` is a superset of `[0-9]*` so old sequential IDs still match
- No migration needed: old and new ID formats coexist
- `ls -t` (mtime) used for "most recent" lookups, not ID sorting
- Spec sanity checks changed from contiguity to uniqueness (no duplicate IDs)

## Recommendations

1. **Adopt hash-based IDs** using the `yf_generate_id()` function for all new identifier generation in yf. The 5-char base36 scheme balances human readability with collision resistance.
2. **Rely on Claude Code's built-in worktree isolation** rather than implementing custom worktree management in the dispatch loop.
3. **Implement the 4-level merge-back strategy** to handle conflicts gracefully, with human escalation as the final fallback.
4. **Maintain backwards compatibility** by ensuring patterns and lookups work with both old sequential and new hash-based IDs.

## Application

These findings directly inform the yf swarm execution model (Plan 52+). The hash ID scheme was adopted in Plan 51 for beads and will extend to plans, TODOs, and requirements. The worktree isolation model shapes how `swarm_dispatch` delegates work to parallel agents without managing worktree lifecycle directly.

## Related

- Plan 51: Beads gitignore allowlist, worktree support, and legacy cleanup
- Plan 52: Swarm execution model (consumer of this research)
- `yf_generate_id()` implementation in yf scripts

---
*Archive bead: yf-3ez*
