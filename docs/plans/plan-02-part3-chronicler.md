# Plan 02 - Part 3: Chronicler Plugin

**Status:** Completed
**Parent:** plan-02.md
**Dependencies:** plan-02-part1-roles.md, plan-02-part2-workflows.md

## Overview

Create the `chronicler` plugin providing context persistence across Claude sessions using beads for storage and diary generation.

## Directory Structure

```
plugins/chronicler/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── init/SKILL.md            # /chronicler:init
│   ├── capture/SKILL.md         # /chronicler:capture
│   ├── recall/SKILL.md          # /chronicler:recall
│   ├── diary/SKILL.md           # /chronicler:diary
│   └── disable/SKILL.md         # /chronicler:disable
├── agents/
│   ├── chronicler_recall.md     # Context recovery agent
│   └── chronicler_diary.md      # Diary generation agent
├── roles/
│   └── watch-for-chronicle-worthiness.md
├── hooks/
│   └── pre-push-diary.sh
└── README.md
```

## Files to Create

### 1. `plugins/chronicler/.claude-plugin/plugin.json`

```json
{
  "name": "chronicler",
  "version": "1.0.0",
  "description": "Context persistence across Claude sessions using beads",
  "author": {
    "name": "James Dixson",
    "email": "dixson3@gmail.com",
    "organization": "Yoshiko Studios LLC",
    "github": "dixson3"
  },
  "license": "MIT",
  "dependencies": {
    "plugins": ["roles", "workflows"],
    "cli": { "beads-cli": ">=0.44.0" }
  },
  "skills": [
    "skills/init/SKILL.md",
    "skills/capture/SKILL.md",
    "skills/recall/SKILL.md",
    "skills/diary/SKILL.md",
    "skills/disable/SKILL.md"
  ],
  "agents": [
    "agents/chronicler_recall.md",
    "agents/chronicler_diary.md"
  ],
  "installs": {
    "roles": ["roles/watch-for-chronicle-worthiness.md"],
    "hooks": ["hooks/pre-push-diary.sh"]
  }
}
```

### 2. Skills

#### `skills/init/SKILL.md`

```markdown
---
name: init
description: Initialize chronicler in the current project
---

# Chronicler Init Skill

Initialize the chronicler system for context persistence.

## Behavior

### Step 1: Initialize Beads
Run `/workflows:init_beads` to ensure beads is set up.

### Step 2: Install Role
Copy `watch-for-chronicle-worthiness.md` to `.claude/roles/`.
Create `.claude/roles/` directory if needed.

### Step 3: Assign Role to All Agents
Update the role's applies-to list to include all known agents.
Default: assign to "primary" and any agents in `.claude/agents/`.

### Step 4: Install roles-apply.sh
Copy the roles filter script to `.claude/roles/` if not present.

### Step 5: Configure Hooks
Add SessionStart hook for auto-recall to `.claude/settings.json`.
Add PreToolUse hook for pre-push diary processing.

### Step 6: Create Diary Directory
Create `docs/diary/` if it doesn't exist.

### Step 7: Report Success
```
Chronicler initialized!

- Beads: Ready
- Role: watch-for-chronicle-worthiness installed
- Hooks: SessionStart (recall), PreToolUse (pre-push diary)
- Diary: docs/diary/ ready

Use /chronicler:capture to record context.
Use /chronicler:recall to recover context.
```
```

#### `skills/capture/SKILL.md`

```markdown
---
name: capture
description: Capture current context as a chronicle bead
arguments:
  - name: topic
    description: Optional topic tag (e.g., feature, bugfix, refactor)
    required: false
---

# Chronicler Capture Skill

Capture current conversation context as a chronicle bead.

## Behavior

### Step 1: Summarize Context
Generate a concise summary including:
- Current task/problem being worked on
- Key decisions made
- Progress achieved
- Pending items or blockers
- Next steps

### Step 2: Build Labels
- Always include: `ys:chronicle`
- If topic provided: `ys:topic:<topic>`
- Auto-detect if possible (feature, bugfix, refactor, docs)

### Step 3: Create Bead
```bash
bd create --title "<brief title>" --labels=ys:chronicle,ys:topic:<topic> --body "<detailed summary>"
```

### Step 4: Confirm
Report the bead ID and summary.

## Usage
```
/chronicler:capture
/chronicler:capture topic:feature
```
```

#### `skills/recall/SKILL.md`

```markdown
---
name: recall
description: Summarize open chronicle beads for context recovery
---

# Chronicler Recall Skill

Recover context from previous sessions by summarizing open chronicle beads.

## Behavior

### Step 1: Query Open Chronicles
```bash
bd list --label=ys:chronicle --status=open --format=json
```

If no beads found, report "No open chronicles" and exit.

### Step 2: Delegate to Recall Agent
Pass bead list to `chronicler_recall` agent for summarization.

### Step 3: Present Summary
Output the agent's context recovery summary.

## Auto-Trigger
This skill auto-runs on SessionStart when chronicler is initialized.

## Usage
```
/chronicler:recall
```
```

#### `skills/diary/SKILL.md`

```markdown
---
name: diary
description: Process open chronicles into diary entries
---

# Chronicler Diary Skill

Convert open chronicle beads into permanent diary entries.

## Behavior

### Step 1: Query Open Chronicles
```bash
bd list --label=ys:chronicle --status=open --format=json
```

If no beads, report "No chronicles to process" and exit.

### Step 2: Delegate to Diary Agent
Pass bead list to `chronicler_diary` agent for processing.

The agent returns JSON with diary entries:
```json
[
  {
    "filename": "26-02-04.14-30.feature.md",
    "content": "...",
    "chronicle_ids": ["ys-123", "ys-124"]
  }
]
```

### Step 3: Write Diary Entries
For each entry, write to `docs/diary/<filename>`.

### Step 4: Close Chronicle Beads
For each processed bead:
```bash
bd close <bead-id> --reason "Processed to diary: docs/diary/<filename>"
```

### Step 5: Report Results
```
Diary entries written:
- docs/diary/26-02-04.14-30.feature.md (3 chronicles)

3 chronicle beads closed.
```

## Usage
```
/chronicler:diary
```
```

#### `skills/disable/SKILL.md`

```markdown
---
name: disable
description: Stop chronicler and close all open chronicles
---

# Chronicler Disable Skill

Disable chronicler and close all open chronicle beads.

## Behavior

### Step 1: Query Open Chronicles
```bash
bd list --label=ys:chronicle --status=open --format=json
```

### Step 2: Close All with WONT-DIARY
For each open bead:
```bash
bd close <bead-id> --reason "WONT-DIARY: chronicler disabled by user"
```

### Step 3: Report
```
Chronicler disabled.
- <N> chronicle beads closed with WONT-DIARY

To re-enable, run /chronicler:init
```

## Usage
```
/chronicler:disable
```
```

### 3. Agents

#### `agents/chronicler_recall.md`

```markdown
---
name: chronicler_recall
description: Agent that summarizes open chronicle beads for context recovery
---

# Chronicler Recall Agent

You summarize open chronicle beads to help users recover context from previous sessions.

## Input
JSON array of open chronicle beads with id, title, body, labels, created_at.

## Process
1. Sort by timestamp (newest first)
2. Group by topic labels
3. Identify common threads
4. Synthesize coherent summary
5. Extract pending items and blockers

## Output Format

```markdown
## Context Recovery Summary

### What You Were Working On
<High-level description>

### Recent Activity
- [Timestamp] <Summary>
- [Timestamp] <Summary>

### Open Items
- [ ] <Pending task>

### Decisions Made
- <Decision and rationale>

### Suggested Next Step
<Recommended action>
```
```

#### `agents/chronicler_diary.md`

```markdown
---
name: chronicler_diary
description: Agent that processes chronicles into diary entries
---

# Chronicler Diary Agent

You transform chronicle beads into polished diary entries.

## Input
JSON array of chronicle beads to process.

## Process
1. Group beads by topic/theme
2. Consolidate related chronicles
3. Generate diary entry content
4. Determine filenames

## Output Format

Return JSON array:
```json
[
  {
    "filename": "YY-MM-DD.HH-MM.<topic>.md",
    "title": "Entry Title",
    "topics": ["topic1", "topic2"],
    "chronicle_ids": ["id1", "id2"],
    "content": "# Diary Entry: ...\n\n**Date**: ...\n..."
  }
]
```

## Diary Entry Template

```markdown
# Diary Entry: <Title>

**Date**: YYYY-MM-DD HH:MM
**Topics**: <comma-separated>
**Chronicle IDs**: <bead IDs>

## Summary
<Consolidated narrative>

## Decisions
- <Key decisions and rationale>

## Next Steps
- [ ] <Action items>

---
*Generated by chronicler from N chronicle beads*
```
```

### 4. Role File

#### `roles/watch-for-chronicle-worthiness.md`

```markdown
---
name: watch-for-chronicle-worthiness
applies-to:
  - primary
---

# Role: Watch for Chronicle-Worthiness

**Purpose**: Monitor context for events worth recording in the project diary.

## When Active

Watch for and flag chronicle-worthy moments:

### Capture Triggers
- Significant progress (feature complete, bug fixed)
- Important decisions (architecture, technology choices)
- Context switches (before breaks, task changes)
- Blockers or questions needing resolution
- Session boundaries

### Behavior

When you notice a chronicle-worthy event:
1. Briefly note: "This seems chronicle-worthy"
2. Suggest: "Consider running `/chronicler:capture` to save this context"

Do NOT auto-capture. Only flag and suggest.

### Non-Triggers
- Trivial changes (typos, formatting)
- Already-committed work with good messages
- Simple Q&A that doesn't affect project state
```

### 5. Hook Script

#### `hooks/pre-push-diary.sh`

```bash
#!/bin/bash
# Pre-push hook for chronicler
# Signals that chronicles should be processed before push

set -e

# Check if bd command exists
if ! command -v bd &> /dev/null; then
    exit 0
fi

# Check for open chronicle beads
COUNT=$(bd list --label=ys:chronicle --status=open 2>/dev/null | wc -l || echo "0")

if [ "$COUNT" -gt 0 ]; then
    echo "CHRONICLER: $COUNT open chronicle(s) found"
    echo "CHRONICLER: Run /chronicler:diary before pushing"
fi

exit 0
```

### 6. README.md

Document the chronicler plugin with:
- Overview and purpose
- Prerequisites (beads-cli, roles plugin, workflows plugin)
- Installation (`/chronicler:init`)
- All skills with usage examples
- Chronicle bead format
- Diary entry format
- Configuration options

## Update Marketplace

Add to `.claude-plugin/marketplace.json` plugins array:

```json
{
  "name": "chronicler",
  "path": "plugins/chronicler",
  "description": "Context persistence using beads and diary generation",
  "version": "1.0.0"
}
```

## Update CHANGELOG.md

Add entry for chronicler plugin release.

## Verification

```bash
# Initialize
/chronicler:init

# Verify role
/roles:list

# Test capture
/chronicler:capture topic:test

# Verify bead created
bd list --label=ys:chronicle

# Test recall
/chronicler:recall

# Test diary
/chronicler:diary
ls docs/diary/

# Test disable
/chronicler:capture topic:test2
/chronicler:disable
```

## Completion Criteria

- [x] Directory structure created
- [x] plugin.json manifest written
- [x] All 5 skills written
- [x] Both agents written
- [x] Role file written
- [x] Hook script written
- [x] README.md written
- [x] marketplace.json updated
- [x] CHANGELOG.md updated
