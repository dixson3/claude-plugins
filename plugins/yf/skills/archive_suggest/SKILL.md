---
name: yf:archive_suggest
description: Scan git history for archive candidates (research findings and design decisions)
user_invocable: true
arguments:
  - name: draft
    description: "Auto-create draft tasks for detected candidates"
    required: false
  - name: since
    description: "Time range to analyze (default: '24 hours ago')"
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
3. **If `--draft`**: Script auto-creates draft tasks for detected candidates
4. **If no `--draft`**: Suggest manual `/yf:archive_capture` invocations for each candidate

### Arguments

- `--draft` or `-d`: Auto-create draft tasks with `ys:archive:draft` label
- `--since "<timespec>"` or `-s "<timespec>"`: Time range (default: "24 hours ago")

## Expected Output

Report includes: time range analyzed, commit count, research and decision candidates with commit SHAs, summary counts, and recommendations for `/yf:archive_capture` invocations. If `--draft`, reports auto-created draft tasks instead.
