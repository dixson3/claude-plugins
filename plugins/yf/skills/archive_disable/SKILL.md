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

Report includes: list of open archive beads found, close status for each. If no open archives, reports nothing to disable.

After disable, the archivist remains installed — you can continue archiving with `/yf:archive_capture` and process new archives with `/yf:archive_process`. Differs from `/yf:archive_process` in that it closes beads without generating documentation files.
