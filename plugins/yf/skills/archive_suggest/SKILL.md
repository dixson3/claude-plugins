---
name: yf:archive_suggest
description: Scan git history for archive candidates (research findings and design decisions)
user_invocable: true
arguments:
  - name: draft
    description: "Auto-create draft beads for detected candidates"
    required: false
  - name: since
    description: "Time range to analyze (default: '24 hours ago')"
    required: false
---

# Archive Suggest Skill

Scan recent git history for commits that indicate research or decision activity worth archiving.

## Instructions

Run the archive-suggest script to analyze commits:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/archive-suggest.sh" [--draft] [--since "<timespec>"]
```

## Behavior

When invoked with `/yf:archive_suggest [--draft] [--since "<timespec>"]`:

1. **Run the script**: Execute `archive-suggest.sh` with provided arguments
2. **Report findings**: Show research and decision candidates found
3. **If `--draft`**: Script auto-creates draft beads for detected candidates
4. **If no `--draft`**: Suggest manual `/yf:archive` invocations for each candidate

### Arguments

- `--draft` or `-d`: Auto-create draft beads with `ys:archive:draft` label
- `--since "<timespec>"` or `-s "<timespec>"`: Time range (default: "24 hours ago")

## Expected Output

```
Archive Candidate Analysis
==========================
Analyzing commits since: 24 hours ago

Found 15 commit(s) to analyze

Scanning for research indicators...
Research activity detected:
  abc1234 Researched Go GraphQL client libraries
  def5678 Evaluated Redis vs Memcached for caching

Scanning for decision indicators...
Decision activity detected:
  ghi9012 Chose Khan/genqlient for GraphQL operations

Summary
=======
Research candidates: 2
Decision candidates: 1

Recommendations:
1. Run /yf:archive type:research to document the research findings
2. Run /yf:archive type:decision to document the decisions
```

## Use Cases

- End-of-session review: Check if any research or decisions were missed
- Weekly review: Scan the last week for undocumented findings
- Pre-push check: Ensure important context is archived before pushing
