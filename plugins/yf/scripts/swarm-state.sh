#!/bin/bash
# swarm-state.sh — Track which swarm steps have been dispatched to agents
#
# Manages the ephemeral dispatch state in .yoshiko-flow/swarm-state.json
# to prevent double-dispatch when the swarm dispatch loop runs multiple times.
#
# Usage:
#   swarm-state.sh is-dispatched <step-id>           # Check if step already dispatched
#   swarm-state.sh mark-dispatched <step-id>         # Record dispatch
#   swarm-state.sh mark-done <step-id>               # Remove from dispatched
#   swarm-state.sh mark-retrying <step-id>           # Mark step for retry (remove done, allow re-dispatch)
#   swarm-state.sh pending                           # List dispatched steps
#   swarm-state.sh clear [--scope <mol-id>]          # Reset state (all or scoped to a nested swarm)
#
# Exit codes:
#   0 — success (for is-dispatched: yes, it is dispatched)
#   1 — not dispatched (for is-dispatched only)

set -euo pipefail

COMMAND="${1:-}"
STEP_ID="${2:-}"

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/swarm-state.json"

# Ensure .yoshiko-flow directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize empty state if file doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"dispatched":{}}' > "$STATE_FILE"
fi

case "$COMMAND" in
    is-dispatched)
        [[ -n "$STEP_ID" ]] || { echo "Usage: swarm-state.sh is-dispatched <step-id>" >&2; exit 1; }
        RESULT=$(jq -r --arg id "$STEP_ID" '.dispatched[$id] // empty' "$STATE_FILE" 2>/dev/null) || exit 1
        if [[ -n "$RESULT" ]]; then
            echo "dispatched"
            exit 0
        else
            echo "not-dispatched"
            exit 1
        fi
        ;;

    mark-dispatched)
        [[ -n "$STEP_ID" ]] || { echo "Usage: swarm-state.sh mark-dispatched <step-id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$STEP_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.dispatched[$id] = $ts' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-dispatched"
        ;;

    mark-done)
        [[ -n "$STEP_ID" ]] || { echo "Usage: swarm-state.sh mark-done <step-id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$STEP_ID" 'del(.dispatched[$id])' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-done"
        ;;

    pending)
        jq -r '.dispatched | keys[]' "$STATE_FILE" 2>/dev/null || true
        ;;

    mark-retrying)
        [[ -n "$STEP_ID" ]] || { echo "Usage: swarm-state.sh mark-retrying <step-id>" >&2; exit 1; }
        # Remove from dispatched to allow re-dispatch
        TEMP=$(mktemp)
        jq --arg id "$STEP_ID" 'del(.dispatched[$id])' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-retrying"
        ;;

    clear)
        # Check for --scope flag (scoped clear for nested swarms)
        SCOPE=""
        if [[ "${STEP_ID:-}" == "--scope" ]]; then
            SCOPE="${3:-}"
        fi

        if [[ -n "$SCOPE" ]]; then
            # Scoped clear: remove only entries matching the scope prefix
            TEMP=$(mktemp)
            jq --arg scope "$SCOPE/" '.dispatched |= with_entries(select(.key | startswith($scope) | not))' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
            echo "cleared-scope:$SCOPE"
        else
            echo '{"dispatched":{}}' > "$STATE_FILE"
            echo "cleared"
        fi
        ;;

    *)
        echo "Usage: swarm-state.sh <is-dispatched|mark-dispatched|mark-done|mark-retrying|pending|clear> [step-id]" >&2
        exit 1
        ;;
esac
