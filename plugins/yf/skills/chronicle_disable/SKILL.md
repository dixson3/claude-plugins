---
name: yf:chronicle_disable
description: Close all open chronicle beads without generating diary entries
arguments: []
---

# Chronicler Disable Skill

Close all open chronicle beads with a "WONT-DIARY" reason.

## Instructions

When you need to abandon open chronicles without generating diary entries:
1. Query all open chronicle beads
2. Close each with a reason indicating they won't be converted to diary
3. Report what was closed

## Behavior

When invoked with `/yf:chronicle_disable`:

1. **Query beads**: List all open beads with `ys:chronicle` label
2. **Close each**: Close with reason "WONT-DIARY: chronicler disabled"
3. **Report**: Show what was closed

### Closing Beads

For each open chronicle:
```bash
bd close <bead-id> --reason "WONT-DIARY: chronicler disabled"
```

## Expected Output

```
Disabling chronicler - closing open chronicles...

Found 3 open chronicle beads:
- abc123: Implementing user authentication
- def456: Planning API refactor
- ghi789: Investigating memory leak

Closing beads...
- abc123: closed (WONT-DIARY: chronicler disabled)
- def456: closed (WONT-DIARY: chronicler disabled)
- ghi789: closed (WONT-DIARY: chronicler disabled)

3 chronicle beads closed without diary generation.
```

## Use Cases

Use `/yf:chronicle_disable` when:
- You want to abandon captured context
- The captures are no longer relevant
- You're resetting the project state
- You want to start fresh without diary entries

## No Open Chronicles

If no open chronicles exist:

```
Disabling chronicler...

No open chronicle beads found.
Nothing to disable.
```

## Re-enabling

After disable, chronicler remains installed. You can:
- Continue capturing with `/yf:chronicle_capture`
- Generate diaries with `/yf:chronicle_diary`
- Recall won't show disabled chronicles (they're closed)

## Difference from Diary

| Action | `/yf:chronicle_diary` | `/yf:chronicle_disable` |
|--------|---------------------|----------------------|
| Closes beads | Yes | Yes |
| Generates files | Yes | No |
| Close reason | Normal close | "WONT-DIARY: chronicler disabled" |
| Use case | Preserve context | Abandon context |
