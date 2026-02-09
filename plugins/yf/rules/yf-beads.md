# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
```

## Beads Are Local

Beads state lives in `.beads/` and is **not committed to git**. It persists locally
across sessions. There is no `bd sync` step and no sync branch.

## Landing the Plane (Session Completion)

**When ending a work session**, complete the following steps:

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Capture context** (if significant work was done) - Invoke `/yf:capture topic:session-close` to preserve session context as a chronicle bead. Skip if the session was trivial (only minor changes or routine operations).
3. **Generate diary** (if open chronicles exist) - Invoke `/yf:diary` to process all open chronicles into diary entries. Stage the generated files for commit.
4. **Run quality gates** (if code changed) - Tests, linters, builds
5. **Update issue status** - Close finished work, update in-progress items
6. **Commit code changes** - Stage and commit implementation files
7. **Push** (only when the user asks) - Do NOT push automatically at session close
8. **Hand off** - Provide context for next session

**IMPORTANT:**
- Beads data persists locally — no push required for issue state
- Do NOT run `bd sync` — beads is not git-synced
- Push code changes only when the user explicitly requests it
- If the user says "land the plane" or "wrap up", complete steps 1-6 and ask if they want to push
