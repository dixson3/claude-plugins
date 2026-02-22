---
name: yf:chronicle_recall
description: Recall and summarize open chronicle beads to restore context
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


# Chronicler Recall Skill

Restore context from open chronicle beads at the start of a session.

## Instructions

Use the `yf_chronicle_recall` agent to:
1. Query all open chronicle beads
2. Group them by topic and timeline
3. Synthesize a context summary
4. Present the summary to restore working context

## Behavior

When invoked with `/yf:chronicle_recall`:

1. **Query beads**: List all open beads with `ys:chronicle` label
2. **Launch agent**: Use the `yf_chronicle_recall` agent to process the beads
3. **Output summary**: Present the synthesized context

### Agent Invocation

The recall agent:
- Reads all open chronicle beads
- Groups by topic (feature, bugfix, etc.)
- Orders by recency
- Synthesizes a cohesive summary

## Expected Output

Report includes: list of open chronicle beads with topics and ages, then a synthesized context summary grouped by recency (recent work, in progress, background). If no open chronicles, suggests using `/yf:chronicle_capture`.
