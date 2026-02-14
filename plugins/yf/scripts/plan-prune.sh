#!/bin/bash
# plan-prune.sh — Automatic bead pruning for completed plans and stale closed beads
#
# Usage:
#   plan-prune.sh plan <plan-label>    # Prune closed beads for a specific plan
#   plan-prune.sh global               # Prune all stale closed beads
#   plan-prune.sh plan <plan-label> --dry-run   # Preview mode
#   plan-prune.sh global --dry-run              # Preview mode
#
# Both subcommands are fail-open (exit 0 always) and configurable via
# .yoshiko-flow/config.json auto_prune settings.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

COMMAND="${1:-}"
TARGET="${2:-}"
DRY_RUN=false

# Parse --dry-run from any position
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ -z "$COMMAND" ]; then
  echo "Usage: plan-prune.sh <plan|global> [target] [--dry-run]" >&2
  exit 0
fi

# Guard: bd must be available
if ! command -v bd >/dev/null 2>&1; then
  exit 0
fi

# Read older_than_days from config (default: 7)
get_older_than_days() {
  local days
  days=$(yf_read_field '.config.auto_prune.older_than_days' 2>/dev/null)
  if [ -z "$days" ] || [ "$days" = "null" ]; then
    echo "7"
  else
    echo "$days"
  fi
}

case "$COMMAND" in
  plan)
    if [ -z "$TARGET" ]; then
      echo "Usage: plan-prune.sh plan <plan-label>" >&2
      exit 0
    fi

    PLAN_LABEL="$TARGET"

    # Config guard
    yf_is_prune_on_complete 2>/dev/null || { echo "Plan prune disabled by config"; exit 0; }

    # Query closed tasks for this plan
    CLOSED_TASKS=$(bd list -l "$PLAN_LABEL" --status=closed --type=task --limit=0 --json 2>/dev/null || echo "[]")
    CLOSED_EPICS=$(bd list -l "$PLAN_LABEL" --status=closed --type=epic --limit=0 --json 2>/dev/null || echo "[]")

    # Combine IDs
    TASK_IDS=$(echo "$CLOSED_TASKS" | jq -r '.[].id' 2>/dev/null || true)
    EPIC_IDS=$(echo "$CLOSED_EPICS" | jq -r '.[].id' 2>/dev/null || true)

    ALL_IDS=""
    [ -n "$TASK_IDS" ] && ALL_IDS="$TASK_IDS"
    if [ -n "$EPIC_IDS" ]; then
      [ -n "$ALL_IDS" ] && ALL_IDS="$ALL_IDS"$'\n'"$EPIC_IDS" || ALL_IDS="$EPIC_IDS"
    fi

    if [ -z "$ALL_IDS" ]; then
      echo "No closed beads to prune for $PLAN_LABEL"
      exit 0
    fi

    COUNT=$(echo "$ALL_IDS" | wc -l | tr -d ' ')

    if [ "$DRY_RUN" = "true" ]; then
      echo "Dry run: would prune $COUNT beads for $PLAN_LABEL:"
      echo "$ALL_IDS" | while IFS= read -r id; do
        [ -n "$id" ] && echo "  - $id"
      done
      exit 0
    fi

    # Delete with reason (soft delete / tombstones)
    echo "$ALL_IDS" | xargs bd delete --force --reason="plan completion auto-prune" 2>/dev/null || true
    echo "Pruned $COUNT beads for $PLAN_LABEL"
    ;;

  global)
    # Config guard
    yf_is_prune_on_push 2>/dev/null || { echo "Global prune disabled by config"; exit 0; }

    DAYS=$(get_older_than_days)

    if [ "$DRY_RUN" = "true" ]; then
      echo "Dry run: would run global cleanup (older than $DAYS days):"
      bd admin cleanup --older-than "$DAYS" --dry-run 2>/dev/null || true
      echo ""
      echo "Dry run: would clean ephemeral wisps:"
      bd admin cleanup --ephemeral --dry-run 2>/dev/null || true
      exit 0
    fi

    # Soft-delete closed beads older than threshold
    RESULT=$(bd admin cleanup --older-than "$DAYS" --force 2>&1 || true)
    CLEANED=$(echo "$RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

    # Clean up closed wisps regardless of age
    WISP_RESULT=$(bd admin cleanup --ephemeral --force 2>&1 || true)
    WISPS=$(echo "$WISP_RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

    echo "Global prune: $CLEANED beads cleaned, $WISPS ephemeral cleaned (threshold: ${DAYS}d)"
    ;;

  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: plan-prune.sh <plan|global> [target] [--dry-run]" >&2
    exit 0
    ;;
esac

exit 0
