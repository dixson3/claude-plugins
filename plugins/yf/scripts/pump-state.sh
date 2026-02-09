#!/bin/bash
# pump-state.sh — Track which beads have been dispatched to agents
#
# Manages the ephemeral dispatch state in .claude/.task-pump.json
# to prevent double-dispatch when the pump runs multiple times.
#
# Usage:
#   pump-state.sh is-dispatched <bead-id>   # Check if bead already dispatched
#   pump-state.sh mark-dispatched <bead-id> # Record dispatch
#   pump-state.sh mark-done <bead-id>       # Remove from dispatched
#   pump-state.sh pending                   # List dispatched beads
#   pump-state.sh clear                     # Reset all state
#
# Exit codes:
#   0 — success (for is-dispatched: yes, it is dispatched)
#   1 — not dispatched (for is-dispatched only)

set -euo pipefail

COMMAND="${1:-}"
BEAD_ID="${2:-}"

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.task-pump.json"

# Ensure .claude directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize empty state if file doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"dispatched":{}}' > "$STATE_FILE"
fi

case "$COMMAND" in
    is-dispatched)
        [[ -n "$BEAD_ID" ]] || { echo "Usage: pump-state.sh is-dispatched <bead-id>" >&2; exit 1; }
        RESULT=$(jq -r --arg id "$BEAD_ID" '.dispatched[$id] // empty' "$STATE_FILE" 2>/dev/null) || exit 1
        if [[ -n "$RESULT" ]]; then
            echo "dispatched"
            exit 0
        else
            echo "not-dispatched"
            exit 1
        fi
        ;;

    mark-dispatched)
        [[ -n "$BEAD_ID" ]] || { echo "Usage: pump-state.sh mark-dispatched <bead-id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$BEAD_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.dispatched[$id] = $ts' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-dispatched"
        ;;

    mark-done)
        [[ -n "$BEAD_ID" ]] || { echo "Usage: pump-state.sh mark-done <bead-id>" >&2; exit 1; }
        TEMP=$(mktemp)
        jq --arg id "$BEAD_ID" 'del(.dispatched[$id])' "$STATE_FILE" > "$TEMP" && mv "$TEMP" "$STATE_FILE"
        echo "marked-done"
        ;;

    pending)
        jq -r '.dispatched | keys[]' "$STATE_FILE" 2>/dev/null || true
        ;;

    clear)
        echo '{"dispatched":{}}' > "$STATE_FILE"
        echo "cleared"
        ;;

    *)
        echo "Usage: pump-state.sh <is-dispatched|mark-dispatched|mark-done|pending|clear> [bead-id]" >&2
        exit 1
        ;;
esac
