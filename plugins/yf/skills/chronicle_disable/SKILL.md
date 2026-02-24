---
name: yf:chronicle_disable
description: Close all open chronicle tasks without generating diary entries
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

## Tools

```bash
YFT="$CLAUDE_PLUGIN_ROOT/scripts/yf-task-cli.sh"
```

# Chronicler Disable Skill

Close all open chronicle tasks with a "WONT-DIARY" reason.

## Instructions

When you need to abandon open chronicles without generating diary entries:
1. Query all open chronicle tasks
2. Close each with a reason indicating they won't be converted to diary
3. Report what was closed

## Behavior

When invoked with `/yf:chronicle_disable`:

1. **Query tasks**: List all open tasks with `ys:chronicle` label
2. **Close each**: Close with reason "WONT-DIARY: chronicler disabled"
3. **Report**: Show what was closed

### Closing Tasks

For each open chronicle:
```bash
bash "$YFT" close <task-id> --reason "WONT-DIARY: chronicler disabled"
```

## Expected Output

Report includes: list of open chronicle tasks found, close status for each. If no open chronicles, reports nothing to disable.

After disable, chronicler remains installed — you can continue capturing with `/yf:chronicle_capture` and generate diaries with `/yf:chronicle_diary`. Differs from `/yf:chronicle_diary` in that it closes tasks without generating diary files.
