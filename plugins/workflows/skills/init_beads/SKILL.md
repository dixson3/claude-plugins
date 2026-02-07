---
name: workflows:init_beads
description: Initialize beads issue tracking and install BEADS.md rule (keeps AGENTS.md clean)
arguments: []
---

# Initialize Beads Skill

Set up beads-cli for issue tracking in the current project. Installs a `.claude/rules/BEADS.md` rule for beads workflow directives instead of polluting AGENTS.md.

## Instructions

Initialize beads in the project and install the beads rule file.

## Behavior

When invoked with `/workflows:init_beads`:

### Step 1: Check beads-cli

```bash
bd --version
```

If not installed, provide installation instructions and stop.

### Step 2: Check existing setup

Look for existing `.beads/` directory. If already initialized, skip to Step 4.

### Step 3: Initialize beads

```bash
bd init
```

Verify `.beads/` was created.

### Step 4: Install BEADS.md rule

Create `.claude/rules/BEADS.md` with the beads workflow directives. This is where all beads-related agent instructions live — **not** in AGENTS.md.

```bash
mkdir -p .claude/rules
```

Generate `.claude/rules/BEADS.md` with content sourced from `bd onboard` output, augmented with the session completion protocol. The rule should contain:

```markdown
# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
```

### Step 5: Clean AGENTS.md

If AGENTS.md exists and contains beads directives (e.g., `bd ready`, `bd prime`, "issue tracking" sections), **remove** those sections. The BEADS.md rule now owns all beads workflow instructions.

Do NOT delete AGENTS.md entirely — only remove beads-specific content. Leave any other project instructions intact.

### Step 6: Skip `bd onboard` AGENTS.md injection

Do NOT run `bd onboard` or append its output to AGENTS.md. The BEADS.md rule replaces that pattern entirely. If `bd onboard` has already injected content into AGENTS.md, Step 5 handles cleanup.

### Step 7: Verify

```bash
test -d .beads && echo "beads: OK"
test -f .claude/rules/BEADS.md && echo "BEADS.md rule: OK"
```

## Prerequisites

- **beads-cli** >= 0.44.0 must be installed
- Project must be a git repository

## Expected Output

```
Initializing beads in project...
beads-cli version: X.Y.Z
Created .beads/ directory
Installed .claude/rules/BEADS.md
Beads initialized successfully!
```

If already initialized:
```
Beads already initialized in this project.
.beads/ directory exists.
Verified .claude/rules/BEADS.md is installed.
```

## Why BEADS.md Instead of AGENTS.md

- **Separation of concerns**: AGENTS.md is for project-level agent instructions. Beads workflow is tooling configuration.
- **Plugin-managed**: The workflows plugin owns beads setup. Rules are the plugin installation mechanism.
- **Consistency**: Other plugins install rules to `.claude/rules/` — beads should follow the same pattern.
- **Updatable**: When the plugin updates, it can regenerate BEADS.md without touching AGENTS.md.
