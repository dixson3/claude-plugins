---
name: yf:archive_process
description: Process archive beads into permanent documentation (research summaries and decision records)
arguments:
  - name: plan_idx
    description: "Optional plan index to filter archives (e.g., 19). Only processes archives tagged with plan:<idx>."
    required: false
---

# Archive Process Skill

Generate permanent documentation from open archive beads.

## Instructions

Use the `yf_archive_process` agent to:
1. Query all open archive beads
2. Determine type (research or decision) from labels
3. Generate SUMMARY.md files and update indexes
4. Close the processed beads

## Behavior

When invoked with `/yf:archive_process [plan:<idx>]`:

1. **Query beads**: List all open beads with `ys:archive` label (optionally filtered by `plan:<idx>`)
2. **Launch agent**: Use the `yf_archive_process` agent to process
3. **Write files**: Create SUMMARY.md files and update index files from agent response
4. **Close beads**: Mark processed beads as closed
5. **Report results**: Show what was created

### Agent Invocation

If `plan_idx` is specified:
```bash
bd list --label=ys:archive --label=plan:<idx> --status=open
```

If no `plan_idx`:
```bash
bd list --label=ys:archive --status=open
```

### File Creation

For each entry from the agent:
- Create the directory: `mkdir -p $(dirname <path>)`
- Write the SUMMARY.md file
- Write or update the index file

### Closing Beads

For each bead in `beads_to_close`:
```bash
bd close <bead-id>
```

For each bead in `beads_to_close_with_reason`:
```bash
bd close <bead-id> --reason "<reason>"
```

## Expected Output

```
Processing archive beads...

Found 2 open archive beads:
- abc123: Archive: Research on Go GraphQL clients (research)
- def456: Archive: DEC-003 GraphQL client selection (decision)

Generating documentation...

[1] docs/research/go-graphql-clients/SUMMARY.md
    - Type: research
    - Title: Go GraphQL clients
    - Created successfully

[2] docs/decisions/DEC-003-graphql-client-selection/SUMMARY.md
    - Type: decision
    - Title: GraphQL client selection
    - Created successfully

Updated indexes:
- docs/research/_index.md
- docs/decisions/_index.md

Closing processed beads...
- abc123: closed
- def456: closed

Archive processing complete!
2 entries created from 2 archive beads.
```

## No Open Archives

If no open archives exist:

```
Processing archive beads...

No open archive beads found.
Nothing to process.
```

## Archive Directory

Documentation is written to `docs/research/` and `docs/decisions/`. These directories are created automatically by preflight.
