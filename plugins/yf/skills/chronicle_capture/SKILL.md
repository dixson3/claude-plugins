---
name: yf:chronicle_capture
description: Capture current context as a chronicle task
arguments:
  - name: topic
    description: Topic label for the chronicle (e.g., feature, bugfix, refactor, docs)
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

# Chronicler Capture Skill

Capture the current context as a chronicle task for later recall.

## Instructions

Create a task that captures the current working context, including:
- What was being worked on
- Key decisions made
- Current state/progress
- Any blockers or next steps

## Behavior

When invoked with `/yf:chronicle_capture [topic:<topic>]`:

1. **Analyze context**: Review the current conversation and work state
2. **Summarize**: Create a concise summary of the context
3. **Create task**: Use yf-task-cli to create the chronicle

### Task Creation

```bash
bash "$YFT" create --title "<brief summary>" \
  --labels=ys:chronicle,ys:topic:<topic> \
  --body "<detailed context>"
```

### Labels

Always include:
- `ys:chronicle` - Marks this as a chronicle task

**Plan-context auto-detection:** Before creating the task, check if a plan is currently executing:
```bash
bash "$YFT" list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null
```
If a plan is executing, extract its `plan:<idx>` label and auto-tag the chronicle task with it. This links the chronicle to the specific plan execution so the diary agent can process plan chronicles as a group.

Optional topic labels:
- `ys:topic:feature` - New feature work
- `ys:topic:bugfix` - Bug fixing
- `ys:topic:refactor` - Code refactoring
- `ys:topic:docs` - Documentation
- `ys:topic:planning` - Planning/design work
- `ys:topic:research` - Research/investigation

## Context to Capture

Include in the task body:

### Summary
Brief description of what was happening.

### Current State
- Files being worked on
- Features in progress
- Tests passing/failing

### Decisions
- Key decisions made and rationale
- Alternatives considered

### Next Steps
- Immediate next actions
- Blockers or questions

### Related
- Related issues/PRs
- Relevant file paths

## Expected Output

Report includes: summary, topic, labels applied, task ID created. Ends with pointer to `/yf:chronicle_recall`.
