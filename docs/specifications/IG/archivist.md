# Implementation Guide: Archivist (Research & Decision Records)

## Overview

The archivist captures research findings and design decisions as permanent, indexed documentation. Unlike the chronicler (which captures ephemeral working context), the archivist captures the "why" -- research topics with references and design decisions with alternatives.

## Use Cases

### UC-014: Archive Research Findings

**Actor**: Operator

**Preconditions**: Research activity has occurred (web searches, API docs, library comparisons).

**Flow**:
1. `watch-for-archive-worthiness` rule suggests archiving
2. Operator invokes `/yf:archive_capture type:research area:<area>`
3. Skill creates archive entry with structured template:
   - Topic/question investigated
   - Sources consulted (URLs, docs, repos)
   - Key findings
   - Recommendations
4. Entry labeled: `ys:archive,ys:archive:research,ys:area:<slug>[,plan:<idx>]`

**Postconditions**: Archive entry exists with research content.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_capture/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/watch-for-archive-worthiness.md`

### UC-015: Archive Design Decisions

**Actor**: Operator

**Preconditions**: Architecture choice, technology selection, or scope change has occurred.

**Flow**:
1. `watch-for-archive-worthiness` rule suggests archiving
2. Operator invokes `/yf:archive_capture type:decision area:<area>`
3. Skill creates archive entry with structured template:
   - Context (what prompted the decision)
   - Alternatives considered
   - Decision made
   - Reasoning/rationale
   - Consequences/trade-offs
4. Entry labeled: `ys:archive,ys:archive:decision,ys:area:<slug>[,plan:<idx>]`
5. Decision gets sequential DEC-NNN ID

**Postconditions**: Archive entry exists with decision context.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_capture/SKILL.md`

### UC-016: Process Archives into Documentation

**Actor**: System or Operator

**Preconditions**: Open archive entries exist.

**Flow**:
1. `/yf:archive_process` invoked (optionally with `plan_idx`)
2. Skill launches `yf_archive_process` agent
3. Agent reads open archive entries
4. For research entries: generates `docs/research/<topic>/SUMMARY.md`
5. For decision entries: generates `docs/decisions/DEC-NNN-<slug>/SUMMARY.md`
6. Agent updates `_index.md` files for cross-referencing
7. Agent closes processed archive entries

**Postconditions**: SUMMARY.md files written. Index updated. Entries closed.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_process/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_archive_process.md`

### UC-017: Scan Git History for Archive Candidates

**Actor**: Operator

**Preconditions**: Git repository with commit history.

**Flow**:
1. `/yf:archive_suggest` invoked (optionally with `--since` and `--draft`)
2. Skill runs `archive-suggest.sh` to scan commits
3. Script detects research keywords (evaluated, compared, investigated, API, library) and decision keywords (decided, chose, approved, rejected, architecture)
4. Script outputs candidate list with commit references
5. If `--draft`: creates draft archive entries for each candidate

**Postconditions**: Archive candidates identified. Optional draft entries created.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/archive-suggest.sh`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/archive_suggest/SKILL.md`
