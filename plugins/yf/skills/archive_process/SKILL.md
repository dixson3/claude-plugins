---
name: yf:archive_process
description: Process archive tasks into permanent documentation (research summaries and decision records)
arguments:
  - name: plan_idx
    description: "Optional plan index to filter archives (e.g., 0019-k4m9q). Only processes archives tagged with plan:<idx>."
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

# Archive Process Skill

Generate permanent documentation from open archive tasks.

## Instructions

Use the `yf_archive_process` agent to:
1. Query all open archive tasks
2. Determine type (research or decision) from labels
3. Generate SUMMARY.md files and update indexes
4. Close the processed tasks

## Behavior

When invoked with `/yf:archive_process [plan:<idx>]`:

1. **Query tasks**: List all open tasks with `ys:archive` label (optionally filtered by `plan:<idx>`)
2. **Launch agent**: Use the `yf_archive_process` agent to process
3. **Write files**: Create SUMMARY.md files and update index files from agent response
4. **Close tasks**: Mark processed tasks as closed
5. **Report results**: Show what was created

### Agent Invocation

If `plan_idx` is specified:
```bash
bash "$YFT" list --label=ys:archive --label=plan:<idx> --status=open
```

If no `plan_idx`:
```bash
bash "$YFT" list --label=ys:archive --status=open
```

### File Creation

For each entry from the agent:
- Create the directory: `mkdir -p $(dirname <path>)`
- Write the SUMMARY.md file
- Write or update the index file

### Closing Tasks

For each task in `tasks_to_close`:
```bash
bash "$YFT" close <task-id>
```

For each task in `tasks_to_close_with_reason`:
```bash
bash "$YFT" close <task-id> --reason "<reason>"
```

## Expected Output

Report includes: list of open archive tasks, generated file paths (SUMMARY.md per task), updated indexes, close status for each task, and total count. If no open archives, reports nothing to process.

## Archive Directory

Documentation is written to `docs/research/` and `docs/decisions/`. These directories are created automatically by preflight.
