---
name: chronicler:capture
description: Capture current context as a chronicle bead
arguments:
  - name: topic
    description: Topic label for the chronicle (e.g., feature, bugfix, refactor, docs)
    required: false
---

# Chronicler Capture Skill

Capture the current context as a chronicle bead for later recall.

## Instructions

Create a bead that captures the current working context, including:
- What was being worked on
- Key decisions made
- Current state/progress
- Any blockers or next steps

## Behavior

When invoked with `/chronicler:capture [topic:<topic>]`:

1. **Analyze context**: Review the current conversation and work state
2. **Summarize**: Create a concise summary of the context
3. **Create bead**: Use beads-cli to create the chronicle

### Bead Creation

```bash
bd create --title "<brief summary>" \
  --labels=ys:chronicle,ys:topic:<topic> \
  --body "<detailed context>"
```

### Labels

Always include:
- `ys:chronicle` - Marks this as a chronicle bead

**Plan-context auto-detection:** Before creating the bead, check if a plan is currently executing:
```bash
bd list -l exec:executing --type=epic --status=open --limit=1 --json 2>/dev/null
```
If a plan is executing, extract its `plan:<idx>` label and auto-tag the chronicle bead with it. This links the chronicle to the specific plan execution so the diary agent can process plan chronicles as a group.

Optional topic labels:
- `ys:topic:feature` - New feature work
- `ys:topic:bugfix` - Bug fixing
- `ys:topic:refactor` - Code refactoring
- `ys:topic:docs` - Documentation
- `ys:topic:planning` - Planning/design work
- `ys:topic:research` - Research/investigation

## Context to Capture

Include in the bead body:

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

## Usage Examples

```bash
# Capture with auto-detected topic
/chronicler:capture

# Capture with specific topic
/chronicler:capture topic:feature

# Capture before context switch
/chronicler:capture topic:planning
```

## Expected Output

```
Capturing context...

Summary: Implementing user authentication flow
Topic: feature
Labels: ys:chronicle, ys:topic:feature

Created chronicle bead: abc123

Context captured successfully. Use /chronicler:recall to restore later.
```

## When to Capture

Capture context when:
- Switching to a different task
- Before taking a break
- After completing a significant milestone
- When encountering a blocker
- Before a session ends
- When the watch-for-chronicle-worthiness role suggests it
