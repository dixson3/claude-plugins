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

### UC-037: Memory Reconciliation

**Actor**: Operator or System (Rule 4.2 step 4.5)

**Preconditions**: yf is enabled. MEMORY.md exists with content beyond the "no active items" sentinel. Specification files and/or CLAUDE.md exist.

**Flow**:
1. Operator invokes `/yf:memory_reconcile` (or system runs it at session close per Rule 4.2)
2. Skill reads MEMORY.md
3. Skill reads CLAUDE.md and specification files (PRD.md, EDD/CORE.md, IG/*.md, TODO.md)
4. Skill classifies each memory item: contradiction, gap, or ephemeral/duplicate
5. Skill presents structured report with proposed actions
6. In gate mode: operator approves changes via AskUserQuestion; spec changes require individual approval per Rule 1.4
7. In check mode: report only, no modifications
8. Skill executes approved changes: corrects contradictions, promotes gaps via `/yf:engineer_update`, removes ephemeral items
9. Skill writes cleaned MEMORY.md

**Postconditions**: MEMORY.md contains only items that genuinely belong there. Gaps promoted to appropriate spec files.

**Key Files**:
- `plugins/yf/skills/memory_reconcile/SKILL.md`

### UC-038: Skill-Level Auto-Chronicle at Decision Points

**Actor**: System (skill auto-capture)

**Preconditions**: yf is enabled. `bd` is available. A skill that produces a decision point (verdict, spec mutation, scope change, qualification outcome) is executing.

**Flow**:
1. Skill reaches a decision point (e.g., reconciliation verdict, spec update, qualification result, task decomposition)
2. Skill evaluates the chronicle trigger condition (e.g., NEEDS-RECONCILIATION verdict, any spec mutation, 3+ child beads)
3. If triggered: skill creates a chronicle bead via `bd create --type task --title "Chronicle: <skill> — <outcome>" -l ys:chronicle,ys:chronicle:auto,ys:topic:<topic>[,plan:<idx>]`
4. Bead description captures structured context: verdict details, conflicts, operator choices, rationale
5. For formula-flagged steps: `swarm_dispatch` Step 6c creates the chronicle bead when the step has `"chronicle": true`
6. For read-only agents: `CHRONICLE-SIGNAL:` line in structured comments triggers chronicle creation by the dispatch loop

**Postconditions**: Chronicle bead exists with decision context. Tagged to active plan if applicable. Auto-chronicles labeled `ys:chronicle:auto` for diary triage.

**Key Files**:
- `plugins/yf/rules/yf-rules.md` (Rule 5.3)
- `plugins/yf/skills/engineer_reconcile/SKILL.md` (Step 7.5)
- `plugins/yf/skills/engineer_update/SKILL.md` (Step 3.5)
- `plugins/yf/skills/swarm_qualify/SKILL.md` (Step 6.5)
- `plugins/yf/skills/plan_breakdown/SKILL.md` (Step 5.5)
- `plugins/yf/skills/plan_intake/SKILL.md` (Step 1.5g)
- `plugins/yf/skills/swarm_dispatch/SKILL.md` (Step 6c)
