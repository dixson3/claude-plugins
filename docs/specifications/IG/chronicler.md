# Implementation Guide: Chronicler (Context Persistence)

## Overview

The chronicler captures observations and context as work progresses, then composes diary entries that trace how and why changes were made. It operates through manual capture, automatic session boundary hooks, and plan lifecycle integration.

## Use Cases

### UC-010: Manual Chronicle Capture

**Actor**: Operator

**Preconditions**: yf is enabled. `bd` is available.

**Flow**:
1. Operator invokes `/yf:chronicle_capture topic:<topic>`
2. Skill snapshots current context: recent conversation highlights, decisions made, progress achieved
3. Skill checks for active plan: looks for `exec:executing` label on any open epic
4. If plan active: auto-tags chronicle bead with `plan:<idx>` label
5. Skill creates bead: `bd create --type=task --title="Chronicle: <topic>" -l ys:chronicle,ys:topic:<topic>[,plan:<idx>]`
6. Skill adds context as bead note

**Postconditions**: Chronicle bead exists with context snapshot. Tagged to active plan if applicable.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/chronicle_capture/SKILL.md`

### UC-011: Automatic Session Start Recovery

**Actor**: System (session-recall.sh)

**Preconditions**: yf is enabled. Open chronicle beads exist from a previous session.

**Flow**:
1. SessionStart hook triggers `session-recall.sh`
2. Script queries `bd list --label=ys:chronicle --status=open --format=json`
3. Script checks for `.beads/.pending-diary` marker from previous session
4. If marker found: outputs "DEFERRED DIARY" header, deletes marker
5. Script formats chronicle summaries: ID, title, age
6. Output injected into agent context via SessionStart stdout
7. Agent starts session with recovered context

**Postconditions**: Agent has context from previous session. Pending diary marker consumed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/session-recall.sh`

### UC-012: Automatic Draft Creation (Pre-Push/SessionEnd/PreCompact)

**Actor**: System (chronicle-check.sh)

**Preconditions**: Significant git activity detected (keywords, file changes, volume).

**Flow**:
1. Hook invokes `chronicle-check.sh check`
2. Script analyzes recent commits for keywords (decided, chose, architecture, new skill, etc.)
3. Script detects significant file changes (plugins/, skills/, agents/, docs/plans/, etc.)
4. Script detects high activity volume (5+ commits)
5. Script detects in-progress beads
6. Script checks daily dedup marker (`.beads/.chronicle-drafted-YYYYMMDD`)
7. If candidate reasons found and not deduped: creates draft chronicle bead
8. Bead labeled: `ys:chronicle,ys:chronicle:draft[,plan:<idx>]`
9. SessionEnd hook additionally writes `.beads/.pending-diary` marker

**Postconditions**: Draft chronicle bead created. Marker bridges to next session.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/chronicle-check.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/session-end.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/hooks/pre-compact.sh`

### UC-013: Diary Generation

**Actor**: System or Operator

**Preconditions**: Open chronicle beads exist. (If plan-scoped: chronicle gate is closed.)

**Flow**:
1. `/yf:chronicle_diary` invoked (optionally with `plan_idx`)
2. Skill checks for open chronicle gates (warns if plan still executing)
3. Skill launches `yf_chronicle_diary` agent
4. Agent reads all open chronicle beads (filtered by plan if specified)
5. Agent triages draft beads: enriches worthy ones, closes unworthy ones, consolidates duplicates
6. For swarm-tagged chronicles: reads FINDINGS/CHANGES/REVIEW/TESTS comments from parent bead
7. Agent composes diary entry: Summary, Decisions, Next Steps sections
8. Agent writes entry to `docs/diary/YY-MM-DD.HH-MM.<topic>.md`
9. Agent closes processed chronicle beads

**Postconditions**: Diary entry written. Chronicle beads closed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/chronicle_diary/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_chronicle_diary.md`
