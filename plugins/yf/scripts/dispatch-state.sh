#!/bin/bash
# dispatch-state.sh — Track which tasks/steps have been dispatched to agents
#
# Unified dispatch state for both the plan pump and formula dispatch loop.
# Manages ephemeral state in .yoshiko-flow/<store>-state.json files.
#
# Usage:
#   dispatch-state.sh <store> <command> [args]
#
# Stores:
#   pump    — Plan pump dispatch state (.yoshiko-flow/task-pump.json)
#   formula — Formula dispatch state (.yoshiko-flow/formula-state.json)
#
# Commands:
#   is-dispatched <id>           Check if id already dispatched (exit 0=yes, 1=no)
#   mark-dispatched <id>         Record dispatch
#   mark-done <id>               Remove from dispatched
#   mark-retrying <id>           Mark for retry (formula only, no-op for pump)
#   pending                      List dispatched ids
#   clear [--scope <prefix>]     Reset state (--scope: formula only, no-op for pump)
#
# Exit codes:
#   0 — success (for is-dispatched: yes, it is dispatched)
#   1 — not dispatched (for is-dispatched only)

set -euo pipefail

STORE="${1:-}"
COMMAND="${2:-}"
ID="${3:-}"

# Resolve state file from store name
case "$STORE" in
    pump)
        STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/task-pump.json"
        ;;
    formula)
        STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/formula-state.json"
        ;;
    *)
        echo "Usage: dispatch-state.sh <pump|formula> <command> [args]" >&2
        exit 1
        ;;
esac

# Ensure .yoshiko-flow directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize empty state if file doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"dispatched":{}}' > "$STATE_FILE"
fi

case "$COMMAND" in
    is-dispatched)
        [[ -n "$ID" ]] || { echo "Usage: dispatch-state.sh $STORE is-dispatched <id>" >&2; exit 1; }
        RESULT=$(jq -r --arg id "$ID" '.dispatched[$id] // empty' "$STATE_FILE" 2>/dev/null) || exit 1
        if [[ -n "$RESULT" ]]; then
            echo "dispatched"
            exit 0
        else
            echo "not-dispatched"
            exit 1
        fi
        ;;

    mark-dispatched)
        [[ -n "$ID" ]] || { echo "Usage: dispatch-state.sh $STORE mark-dispatched <id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.dispatched[$id] = $ts' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-dispatched"
        ;;

    mark-done)
        [[ -n "$ID" ]] || { echo "Usage: dispatch-state.sh $STORE mark-done <id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$ID" 'del(.dispatched[$id])' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-done"
        ;;

    mark-retrying)
        # Only meaningful for formula store — no-op for pump
        if [[ "$STORE" != "formula" ]]; then
            echo "no-op"
            exit 0
        fi
        [[ -n "$ID" ]] || { echo "Usage: dispatch-state.sh formula mark-retrying <id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$ID" 'del(.dispatched[$id])' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-retrying"
        ;;

    pending)
        jq -r '.dispatched | keys[]' "$STATE_FILE" 2>/dev/null || true
        ;;

    clear)
        # Check for --scope flag (scoped clear for nested formulas, formula only)
        SCOPE=""
        if [[ "${ID:-}" == "--scope" ]]; then
            SCOPE="${4:-}"
        fi

        if [[ -n "$SCOPE" ]] && [[ "$STORE" == "formula" ]]; then
            TEMP=$(mktemp)
            jq --arg scope "$SCOPE/" '.dispatched |= with_entries(select(.key | startswith($scope) | not))' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
            echo "cleared-scope:$SCOPE"
        else
            echo '{"dispatched":{}}' > "$STATE_FILE"
            echo "cleared"
        fi
        ;;

    *)
        echo "Usage: dispatch-state.sh <pump|formula> <is-dispatched|mark-dispatched|mark-done|mark-retrying|pending|clear> [id]" >&2
        exit 1
        ;;
esac
