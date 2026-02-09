---
name: yf:archive_capture
description: Capture research findings or design decisions as archive beads
arguments:
  - name: type
    description: "Archive type: research or decision (required)"
    required: true
  - name: area
    description: "Topic area slug (e.g., api, architecture, tooling, security, performance)"
    required: false
---

# Archivist Capture Skill

Capture research findings or design decisions as archive beads for later processing into permanent documentation.

## Instructions

Create a bead that captures either a research finding (sources, conclusions) or a design decision (context, alternatives, reasoning).

## Behavior

When invoked with `/yf:archive_capture type:<type> [area:<area>]`:

1. **Validate type**: Must be `research` or `decision`
2. **Analyze context**: Review the current conversation for the relevant research or decision
3. **Create bead**: Use beads-cli to create the archive bead

### For Research (`type:research`)

```bash
bd create --title "Archive: Research on [topic]" \
  --type task \
  --priority 3 \
  --labels "ys:archive,ys:archive:research[,ys:area:<area>][,plan:<idx>]" \
  --description "[research template below]"
```

**Research bead body template:**

```
Type: research
Topic: [specific topic being researched]
Status: COMPLETED

## Purpose
[Why this research was needed — what question are we answering]

## Sources Consulted
1. [Source name] - [URL]
   Key findings: [what we learned]

2. [Source name] - [URL]
   Key findings: [what we learned]

## Summary of Findings
[Synthesized conclusions from all sources]

## Recommendations
[Based on findings, what should we do]

## Application
[How this research will be/was applied to the project]

## Related
- Decisions informed: [DEC-NNN if any]
- Related research: [other topics if any]
```

### For Decisions (`type:decision`)

First, determine the next DEC-NNN ID:

```bash
# Check existing decisions index
if [ -f docs/decisions/_index.md ]; then
  # Extract highest DEC number from index
  LAST_NUM=$(grep -oE 'DEC-[0-9]+' docs/decisions/_index.md | sed 's/DEC-//' | sort -n | tail -1)
  NEXT_NUM=$((LAST_NUM + 1))
else
  NEXT_NUM=1
fi
DEC_ID=$(printf "DEC-%03d" $NEXT_NUM)
```

```bash
bd create --title "Archive: $DEC_ID [decision title]" \
  --type task \
  --priority 2 \
  --labels "ys:archive,ys:archive:decision[,ys:area:<area>][,plan:<idx>]" \
  --description "[decision template below]"
```

**Decision bead body template:**

```
Type: decision
ID: DEC-NNN-[slug]
Status: Accepted

## Context
[What problem or question prompted this decision]
[What constraints or requirements apply]

## Research Basis
[Link to research topics that informed this, if any]

## The Decision
[Clear statement of what was decided]

## Alternatives Considered

### Alternative A: [name]
- Description: [what this option entails]
- Pros: [benefits]
- Cons: [drawbacks]
- Why rejected: [reasoning]

### Chosen: [name]
- Description: [what this option entails]
- Pros: [benefits]
- Cons: [drawbacks]
- Why chosen: [reasoning]

## Consequences
[Expected impact and implications of this decision]

## Implementation Notes
[How this decision will be/was implemented]
```

### Labels

Always include:
- `ys:archive` — Marks this as an archive bead
- `ys:archive:research` or `ys:archive:decision` — Type label

Optional:
- `ys:area:<area>` — Topic area (e.g., `ys:area:api`, `ys:area:architecture`, `ys:area:tooling`)

**Plan-context auto-detection:** Before creating the bead, check if a plan is currently executing:
```bash
bd list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null
```
If a plan is executing, extract its `plan:<idx>` label and auto-tag the archive bead with it.

## Expected Output

```
Archiving research finding...

Topic: Go GraphQL client libraries
Type: research
Area: tooling
Labels: ys:archive, ys:archive:research, ys:area:tooling

Created archive bead: abc123

Research archived. Run /yf:archive_process to generate documentation.
```

## Content Guidelines

- **Research beads**: 200-400 words minimum. Include all sources with URLs.
- **Decision beads**: 300-500 words minimum. Include alternatives considered with pros/cons.
- Include enough detail for the archivist agent to generate a complete SUMMARY.md.
