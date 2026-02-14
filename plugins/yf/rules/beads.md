# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync beads state with git
```

## Beads Git Workflow

Beads state lives in `.beads/` and is **git-tracked**. Beads manages its own
`.beads/.gitignore` to track essential files (`issues.jsonl`, `config.yaml`,
`metadata.json`, `interactions.jsonl`) while ignoring ephemeral files (`*.db`,
daemon files).

The `beads-sync` branch keeps beads data separate from code branches:
- Git hooks handle JSONL export/import automatically on commit and merge
- A pre-push hook auto-pushes the `beads-sync` branch alongside your code branch
- Code branches stay clean — beads data lives only on `beads-sync`

Run `bd sync` to manually sync beads state with the git remote.

## Landing the Plane (Session Completion)

**When ending a work session**, complete the following steps:

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Capture context** (if significant work was done) - Invoke `/yf:chronicle_capture topic:session-close` to preserve session context as a chronicle bead. Skip if the session was trivial (only minor changes or routine operations).
3. **Generate diary** (if open chronicles exist) - Invoke `/yf:chronicle_diary` to process all open chronicles into diary entries. Stage the generated files for commit.
4. **Run quality gates** (if code changed) - Tests, linters, builds
5. **Update issue status** - Close finished work, update in-progress items
6. **Sync beads** - Run `bd sync` to push beads state
7. **Commit code changes** - Stage and commit implementation files
8. **Push** (only when the user asks) - Do NOT push automatically at session close
9. **Hand off** - Provide context for next session

**IMPORTANT:**
- Push code changes only when the user explicitly requests it
- If the user says "land the plane" or "wrap up", complete steps 1-7 and ask if they want to push
