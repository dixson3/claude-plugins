---
name: yf:archive_disable
description: Close all open archive beads without generating documentation
arguments: []
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


# Archive Disable Skill

Close all open archive beads with a "WONT-ARCHIVE" reason.

## Instructions

When you need to abandon open archives without generating documentation:
1. Query all open archive beads
2. Close each with a reason indicating they won't be converted to docs
3. Report what was closed

## Behavior

When invoked with `/yf:archive_disable`:

1. **Query beads**: List all open beads with `ys:archive` label
2. **Close each**: Close with reason "WONT-ARCHIVE: archivist disabled"
3. **Report**: Show what was closed

### Closing Beads

For each open archive:
```bash
bd close <bead-id> --reason "WONT-ARCHIVE: archivist disabled"
```

## Expected Output

```
Disabling archivist - closing open archives...

Found 2 open archive beads:
- abc123: Archive: Research on Go GraphQL clients
- def456: Archive: DEC-003 GraphQL client selection

Closing beads...
- abc123: closed (WONT-ARCHIVE: archivist disabled)
- def456: closed (WONT-ARCHIVE: archivist disabled)

2 archive beads closed without documentation generation.
```

## Use Cases

Use `/yf:archive_disable` when:
- You want to abandon captured research/decisions
- The archives are no longer relevant
- You're resetting the project state
- You want to start fresh without documentation

## No Open Archives

If no open archives exist:

```
Disabling archivist...

No open archive beads found.
Nothing to disable.
```

## Re-enabling

After disable, the archivist remains installed. You can:
- Continue archiving with `/yf:archive_capture`
- Process new archives with `/yf:archive_process`
- Recall won't show disabled archives (they're closed)

## Difference from Archive Process

| Action | `/yf:archive_process` | `/yf:archive_disable` |
|--------|----------------------|----------------------|
| Closes beads | Yes | Yes |
| Generates files | Yes | No |
| Close reason | Normal close | "WONT-ARCHIVE: archivist disabled" |
| Use case | Preserve research/decisions | Abandon content |
