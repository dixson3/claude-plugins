---
name: yf:archive_capture
description: Capture research findings or design decisions as archive tasks
arguments:
  - name: type
    description: "Archive type: research or decision (required)"
    required: true
  - name: area
    description: "Topic area slug (e.g., api, architecture, tooling, security, performance)"
    required: false
---

## Activation Guard

Before proceeding, check that yf is active:

```bash
ACTIVATION=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-activation-check.sh")
IS_ACTIVE=$(echo "$ACTIVATION" | jq -r '.active')
```

If `IS_ACTIVE` is not `true`, read the `reason` and `action` fields from `$ACTIVATION` and tell the user:

> Yoshiko Flow is not active: {reason}. {action}

Then stop. Do not execute the remaining steps.

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

# Archivist Capture Skill

Capture research findings or design decisions as archive tasks for later processing into permanent documentation.

## Instructions

Create a task that captures either a research finding (sources, conclusions) or a design decision (context, alternatives, reasoning).

## Behavior

When invoked with `/yf:archive_capture type:<type> [area:<area>]`:

1. **Validate type**: Must be `research` or `decision`
2. **Analyze context**: Review the current conversation for the relevant research or decision
3. **Create task**: Use yf-task-cli to create the archive task

### For Research (`type:research`)

```bash
bash "$YFT" create --title "Archive: Research on [topic]" \
  --type task \
  --priority 3 \
  --labels "ys:archive,ys:archive:research[,ys:area:<area>][,plan:<idx>]" \
  --description "[research template below]"
```

### Operator Resolution

Resolve operator name via fallback cascade: merged config `.config.operator` → `plugin.json` `.author.name` → `git config user.name` → `"Unknown"`. In shell scripts, use `yf_operator_name()` from `yf-config.sh`. In agent context, read `.yoshiko-flow/config.local.json` then `.yoshiko-flow/config.json` for `.config.operator`, falling back to `git config user.name`.

**Research task body template:**

```
Type: research
Topic: [specific topic being researched]
Operator: [resolved operator name]
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

First, generate a hybrid idx-hash DEC ID:

```bash
# Generate hybrid DEC ID with scope for sequential indexing
. "${CLAUDE_PLUGIN_ROOT}/scripts/yf-id.sh"
DEC_ID=$(yf_generate_id "DEC" "docs/decisions/_index.md")
```

```bash
bash "$YFT" create --title "Archive: $DEC_ID [decision title]" \
  --type task \
  --priority 2 \
  --labels "ys:archive,ys:archive:decision[,ys:area:<area>][,plan:<idx>]" \
  --description "[decision template below]"
```

**Decision task body template:**

```
Type: decision
ID: DEC-NNN-[slug]
Operator: [resolved operator name]
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
- `ys:archive` — Marks this as an archive task
- `ys:archive:research` or `ys:archive:decision` — Type label

Optional:
- `ys:area:<area>` — Topic area (e.g., `ys:area:api`, `ys:area:architecture`, `ys:area:tooling`)

**Plan-context auto-detection:** Before creating the task, check if a plan is currently executing:
```bash
bash "$YFT" list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null
```
If a plan is executing, extract its `plan:<idx>` label and auto-tag the archive task with it.

## Expected Output

Report includes: topic, type, area, labels applied, task ID created. Ends with pointer to `/yf:archive_process`.

## Content Guidelines

- **Research tasks**: 200-400 words minimum. Include all sources with URLs.
- **Decision tasks**: 300-500 words minimum. Include alternatives considered with pros/cons.
- Include enough detail for the archivist agent to generate a complete SUMMARY.md.
