---
name: chronicler:recall
description: Recall and summarize open chronicle beads to restore context
arguments: []
---

# Chronicler Recall Skill

Restore context from open chronicle beads at the start of a session.

## Instructions

Use the `chronicler_recall` agent to:
1. Query all open chronicle beads
2. Group them by topic and timeline
3. Synthesize a context summary
4. Present the summary to restore working context

## Behavior

When invoked with `/chronicler:recall`:

1. **Query beads**: List all open beads with `ys:chronicle` label
2. **Launch agent**: Use the `chronicler_recall` agent to process the beads
3. **Output summary**: Present the synthesized context

### Agent Invocation

The recall agent:
- Reads all open chronicle beads
- Groups by topic (feature, bugfix, etc.)
- Orders by recency
- Synthesizes a cohesive summary

## Expected Output

```
Recalling context from open chronicles...

Found 3 open chronicle beads:
- abc123: Implementing user authentication (feature) - 2 hours ago
- def456: Planning API refactor (planning) - 1 day ago
- ghi789: Investigating memory leak (bugfix) - 3 days ago

## Context Summary

### Recent Work (Last Session)
You were implementing user authentication:
- Added login/logout endpoints
- JWT token generation working
- Next: Add token refresh endpoint

### In Progress
API refactor planning:
- Decision: Moving to REST from GraphQL
- Concerns about breaking changes documented

### Background
Memory leak investigation:
- Narrowed to connection pooling
- Waiting for metrics from production

---
3 chronicles recalled. Use /chronicler:capture to save new context.
```

## Auto-Recall

When `/chronicler:init` is run, it can configure a session start hook to auto-run recall:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "claude --skill chronicler:recall"
      }
    ]
  }
}
```

## When Recall Runs

- At the start of a new session
- After `/clear` to restore context
- When explicitly invoked
- When switching back to a project

## No Open Chronicles

If no open chronicles exist:

```
Recalling context...

No open chronicle beads found.
This could mean:
- You haven't captured any context yet
- All previous chronicles have been converted to diary entries

Use /chronicler:capture to start capturing context.
```
