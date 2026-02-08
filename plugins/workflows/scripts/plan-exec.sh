#!/bin/bash
# plan-exec.sh — Deterministic state transitions for plan execution
#
# All plan state changes go through this script to ensure atomic, consistent transitions.
#
# Usage:
#   plan-exec.sh start  <root-epic-id>   # Ready/Paused → Executing
#   plan-exec.sh pause  <root-epic-id>   # Executing → Paused
#   plan-exec.sh status <root-epic-id>   # Query current state
#   plan-exec.sh next   <root-epic-id>   # Guarded bd ready (returns empty if paused)
#   plan-exec.sh guard  <task-id>        # Check if task's plan allows execution

set -euo pipefail

COMMAND="${1:-}"
TARGET="${2:-}"

if [[ -z "$COMMAND" || -z "$TARGET" ]]; then
    echo "Usage: plan-exec.sh <command> <id>" >&2
    echo "Commands: start, pause, status, next, guard" >&2
    exit 1
fi

# Get the plan label from an issue
get_plan_label() {
    local issue_id="$1"
    bd label list "$issue_id" --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1
}

# Find the root epic for a plan label
find_root_epic() {
    local plan_label="$1"
    bd list -l "$plan_label" --type=epic --status=open --limit=1 --json 2>/dev/null | jq -r '.[0].id // empty'
}

# Find open plan-exec gate on a root epic
find_open_gate() {
    local root_epic="$1"
    bd gate list --json 2>/dev/null | jq -r --arg parent "$root_epic" \
        '.[] | select(.parent == $parent and (.labels // [] | any(. == "plan-exec"))) | .id' | head -1
}

# Get plan label from root epic
get_epic_plan_label() {
    local root_epic="$1"
    bd label list "$root_epic" --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' | head -1
}

# Get all task IDs for a plan (non-epic, non-gate)
get_plan_tasks() {
    local plan_label="$1"
    local status_filter="${2:-open}"
    bd list -l "$plan_label" --status="$status_filter" --type=task --limit=0 --json 2>/dev/null | jq -r '.[].id'
}

case "$COMMAND" in
    start)
        ROOT_EPIC="$TARGET"
        echo "Starting plan execution for $ROOT_EPIC..."

        # Find and resolve the open gate
        GATE_ID=$(find_open_gate "$ROOT_EPIC")
        if [[ -n "$GATE_ID" ]]; then
            bd gate resolve "$GATE_ID" --reason "Plan execution started" 2>/dev/null
            echo "Gate $GATE_ID resolved."
        else
            echo "No open gate found (plan may already be executing)."
        fi

        # Remove plan gate file if it exists (unblock Edit/Write)
        PLAN_GATE="${CLAUDE_PROJECT_DIR:-.}/.claude/.plan-gate"
        if [[ -f "$PLAN_GATE" ]]; then
            rm -f "$PLAN_GATE"
            echo "Plan gate removed (code edits unblocked)."
        fi

        # Get plan label
        PLAN_LABEL=$(get_epic_plan_label "$ROOT_EPIC")
        if [[ -z "$PLAN_LABEL" ]]; then
            echo "Error: Could not determine plan label for $ROOT_EPIC" >&2
            exit 1
        fi

        # Undefer all pending tasks
        TASK_IDS=$(get_plan_tasks "$PLAN_LABEL" "deferred")
        if [[ -n "$TASK_IDS" ]]; then
            COUNT=0
            while IFS= read -r task_id; do
                bd update "$task_id" --defer="" 2>/dev/null
                COUNT=$((COUNT + 1))
            done <<< "$TASK_IDS"
            echo "Undeferred $COUNT tasks."
        else
            echo "No deferred tasks to undefer."
        fi

        # Update execution state label
        bd label remove "$ROOT_EPIC" exec:paused 2>/dev/null || true
        bd label remove "$ROOT_EPIC" exec:ready 2>/dev/null || true
        bd label add "$ROOT_EPIC" exec:executing 2>/dev/null
        echo "State: executing"
        ;;

    pause)
        ROOT_EPIC="$TARGET"
        echo "Pausing plan execution for $ROOT_EPIC..."

        # Get plan label
        PLAN_LABEL=$(get_epic_plan_label "$ROOT_EPIC")
        if [[ -z "$PLAN_LABEL" ]]; then
            echo "Error: Could not determine plan label for $ROOT_EPIC" >&2
            exit 1
        fi

        # Create new gate on root epic
        GATE_ID=$(bd create --type=gate \
            --title="Plan execution gate (paused)" \
            --parent="$ROOT_EPIC" \
            -l plan-exec,"$PLAN_LABEL" \
            --silent 2>/dev/null)
        echo "Gate $GATE_ID created."

        # Defer all pending (not in_progress) tasks
        TASK_IDS=$(get_plan_tasks "$PLAN_LABEL" "open")
        if [[ -n "$TASK_IDS" ]]; then
            COUNT=0
            while IFS= read -r task_id; do
                bd update "$task_id" --defer=+100y 2>/dev/null
                COUNT=$((COUNT + 1))
            done <<< "$TASK_IDS"
            echo "Deferred $COUNT pending tasks."
        fi

        # Update execution state label
        bd label remove "$ROOT_EPIC" exec:executing 2>/dev/null || true
        bd label add "$ROOT_EPIC" exec:paused 2>/dev/null
        echo "State: paused"
        ;;

    status)
        ROOT_EPIC="$TARGET"

        # Check for open gate
        GATE_ID=$(find_open_gate "$ROOT_EPIC")

        # Get plan label and check task states
        PLAN_LABEL=$(get_epic_plan_label "$ROOT_EPIC")

        if [[ -z "$PLAN_LABEL" ]]; then
            echo "unknown"
            exit 1
        fi

        OPEN_COUNT=$(bd count -l "$PLAN_LABEL" --status=open --type=task 2>/dev/null || echo "0")
        IN_PROGRESS_COUNT=$(bd count -l "$PLAN_LABEL" --status=in_progress --type=task 2>/dev/null || echo "0")
        DEFERRED_COUNT=$(bd count -l "$PLAN_LABEL" --status=deferred --type=task 2>/dev/null || echo "0")

        TOTAL_OPEN=$((OPEN_COUNT + IN_PROGRESS_COUNT + DEFERRED_COUNT))

        if [[ "$TOTAL_OPEN" -eq 0 ]]; then
            echo "completed"
        elif [[ -n "$GATE_ID" ]]; then
            # Check if this was ever started
            LABELS=$(bd label list "$ROOT_EPIC" --json 2>/dev/null | jq -r '.[]' 2>/dev/null)
            if echo "$LABELS" | grep -q "exec:paused"; then
                echo "paused"
            else
                echo "ready"
            fi
        else
            echo "executing"
        fi
        ;;

    next)
        ROOT_EPIC="$TARGET"

        # Check status first
        STATUS=$("$0" status "$ROOT_EPIC")

        if [[ "$STATUS" != "executing" ]]; then
            echo "Plan is not in Executing state (current: $STATUS)." >&2
            echo "Say 'execute the plan' or 'resume the plan' to start." >&2
            exit 0  # Exit 0 but with empty stdout — caller checks stdout
        fi

        # Get plan label
        PLAN_LABEL=$(get_epic_plan_label "$ROOT_EPIC")

        # Return ready tasks for this plan
        bd list -l "$PLAN_LABEL" --ready --type=task --limit=0 2>/dev/null
        ;;

    guard)
        TASK_ID="$TARGET"

        # Get the plan label from the task
        PLAN_LABEL=$(get_plan_label "$TASK_ID")

        if [[ -z "$PLAN_LABEL" ]]; then
            # Task is not part of a plan — allow
            exit 0
        fi

        # Find root epic for this plan
        ROOT_EPIC=$(find_root_epic "$PLAN_LABEL")

        if [[ -z "$ROOT_EPIC" ]]; then
            # Can't find root epic — allow (don't block on missing data)
            exit 0
        fi

        # Check execution status
        STATUS=$("$0" status "$ROOT_EPIC")

        if [[ "$STATUS" == "executing" ]]; then
            exit 0  # Allow
        else
            echo "Plan is not in Executing state (current: $STATUS)." >&2
            echo "Say 'execute the plan' or 'resume the plan' to start." >&2
            exit 1  # Block
        fi
        ;;

    *)
        echo "Unknown command: $COMMAND" >&2
        echo "Usage: plan-exec.sh <start|pause|status|next|guard> <id>" >&2
        exit 1
        ;;
esac
