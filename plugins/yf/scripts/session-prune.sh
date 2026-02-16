#!/bin/bash
# session-prune.sh — Dynamic cleanup of stale artifacts at session close
#
# Usage:
#   session-prune.sh beads [--dry-run]      # Clean stale closed beads
#   session-prune.sh ephemeral [--dry-run]   # Remove stale .yoshiko-flow/ files
#   session-prune.sh drafts [--dry-run]      # Close stale auto-generated drafts
#   session-prune.sh all [--dry-run]         # Run all three in sequence
#
# Fail-open (exit 0 always). Config-gated via auto_prune.on_session_close.
# Compatible with bash 3.2+ (macOS default).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

COMMAND="${1:-}"
DRY_RUN=false

# Parse --dry-run from any position
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ -z "$COMMAND" ]; then
  echo "Usage: session-prune.sh <beads|ephemeral|drafts|all> [--dry-run]" >&2
  exit 0
fi

# Config guard
yf_is_prune_on_session_close 2>/dev/null || { echo "Session prune disabled by config"; exit 0; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
YF_DIR="$PROJECT_DIR/.yoshiko-flow"
TODAY=$(date +%Y%m%d)

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

do_beads() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "session-prune beads: bd not available, skipping"
    return 0
  fi

  DAYS=$(get_older_than_days)

  if [ "$DRY_RUN" = "true" ]; then
    echo "Dry run: would run beads cleanup (older than $DAYS days):"
    bd admin cleanup --older-than "$DAYS" --dry-run 2>/dev/null || true
    echo ""
    echo "Dry run: would clean ephemeral wisps:"
    bd admin cleanup --ephemeral --dry-run 2>/dev/null || true
    return 0
  fi

  RESULT=$(bd admin cleanup --older-than "$DAYS" --force 2>&1 || true)
  CLEANED=$(echo "$RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

  WISP_RESULT=$(bd admin cleanup --ephemeral --force 2>&1 || true)
  WISPS=$(echo "$WISP_RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

  echo "session-prune beads: $CLEANED beads cleaned, $WISPS ephemeral cleaned (threshold: ${DAYS}d)"
}

do_ephemeral() {
  if [ ! -d "$YF_DIR" ]; then
    echo "session-prune ephemeral: no .yoshiko-flow directory, skipping"
    return 0
  fi

  # Protected files — never remove these
  # config.json, .gitignore, lock.json, plan-gate, task-pump.json, swarm-state.json

  local removed=0

  # Remove date-stamped files where date != today
  for pattern in ".chronicle-drafted-" ".chronicle-staleness-" ".chronicle-transition-" ".chronicle-plan-"; do
    for f in "$YF_DIR"/${pattern}*; do
      [ -f "$f" ] || continue
      local basename
      basename=$(basename "$f")
      # Extract date suffix (last 8 chars should be YYYYMMDD)
      local date_suffix="${basename##*-}"
      if [ "$date_suffix" != "$TODAY" ]; then
        if [ "$DRY_RUN" = "true" ]; then
          echo "Dry run: would remove $basename (stale date: $date_suffix)"
        else
          rm -f "$f"
        fi
        removed=$((removed + 1))
      fi
    done
  done

  # Remove session sentinels (always, regardless of date)
  for sentinel in ".chronicle-nudge" ".beads-check-cache" "plan-chronicle-ok" "plan-intake-ok" "plan-intake-skip"; do
    if [ -f "$YF_DIR/$sentinel" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run: would remove $sentinel (session sentinel)"
      else
        rm -f "$YF_DIR/$sentinel"
      fi
      removed=$((removed + 1))
    fi
  done

  echo "session-prune ephemeral: $removed files cleaned"
}

do_drafts() {
  if ! command -v bd >/dev/null 2>&1; then
    echo "session-prune drafts: bd not available, skipping"
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "session-prune drafts: jq not available, skipping"
    return 0
  fi

  # Query open chronicle drafts
  local drafts
  drafts=$(bd list --label=ys:chronicle --label=ys:chronicle:draft --status=open --format=json 2>/dev/null || echo "[]")

  local now_epoch
  now_epoch=$(date +%s)
  local threshold=$((24 * 60 * 60))  # 24 hours in seconds
  local closed=0

  # Iterate over drafts, close any older than 24 hours
  local ids
  ids=$(echo "$drafts" | jq -r '.[] | .id' 2>/dev/null || true)
  if [ -z "$ids" ]; then
    echo "session-prune drafts: no stale drafts found"
    return 0
  fi

  echo "$ids" | while IFS= read -r id; do
    [ -z "$id" ] && continue
    local created
    created=$(echo "$drafts" | jq -r --arg id "$id" '.[] | select(.id == $id) | .created // empty' 2>/dev/null || true)
    if [ -z "$created" ]; then
      continue
    fi

    # Parse ISO timestamp to epoch (portable: try date -d first, fallback to date -j)
    local created_epoch
    created_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${created%%.*}" +%s 2>/dev/null || \
                    date -d "$created" +%s 2>/dev/null || echo "0")

    local age=$((now_epoch - created_epoch))
    if [ "$age" -gt "$threshold" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run: would close $id (age: $((age / 3600))h)"
      else
        bd close "$id" --reason="session-prune: stale auto-generated draft (>24h)" 2>/dev/null || true
      fi
      closed=$((closed + 1))
    fi
  done

  echo "session-prune drafts: $closed stale drafts closed"
}

case "$COMMAND" in
  beads)
    do_beads
    ;;
  ephemeral)
    do_ephemeral
    ;;
  drafts)
    do_drafts
    ;;
  all)
    "$0" beads "$@" || true
    "$0" ephemeral "$@" || true
    "$0" drafts "$@" || true
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: session-prune.sh <beads|ephemeral|drafts|all> [--dry-run]" >&2
    ;;
esac

exit 0
