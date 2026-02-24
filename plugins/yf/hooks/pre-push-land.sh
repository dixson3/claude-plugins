#!/usr/bin/env bash
# pre-push-land.sh — PreToolUse hook: block git push when prerequisites unmet
#
# Blocks push (exit 2) when:
#   1. Uncommitted changes exist (dirty working tree)
#   2. In-progress tasks exist (work not completed)
#
# Compatible with bash 3.2+ (macOS default).
# Fail-open on guard failures (exit 0).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
. "$SCRIPT_DIR/scripts/yf-tasks.sh"

# --- Guards: fail-open if yf disabled ---
yf_is_enabled || exit 0

# --- Check conditions ---
BLOCK=false
OUTPUT=""

# Check 1: Uncommitted changes
DIRTY_FILES=$(git status --porcelain 2>/dev/null || echo "")
DIRTY_COUNT=$(echo "$DIRTY_FILES" | grep -c '.' 2>/dev/null || echo "0")
if [ "$DIRTY_COUNT" -gt 0 ]; then
  BLOCK=true
  OUTPUT="${OUTPUT}[ ] Uncommitted changes: ${DIRTY_COUNT} file(s)"$'\n'
  # Show up to 10 files
  SHOWN=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    OUTPUT="${OUTPUT}    ${line}"$'\n'
    SHOWN=$((SHOWN + 1))
    if [ "$SHOWN" -ge 10 ]; then
      REMAINING=$((DIRTY_COUNT - 10))
      if [ "$REMAINING" -gt 0 ]; then
        OUTPUT="${OUTPUT}    ... and ${REMAINING} more"$'\n'
      fi
      break
    fi
  done <<< "$DIRTY_FILES"
  OUTPUT="${OUTPUT}    Action: Commit changes before pushing"$'\n'
  OUTPUT="${OUTPUT}"$'\n'
fi

# Check 2: In-progress tasks
IN_PROGRESS=$(yft_list --status=in_progress --json 2>/dev/null || echo "[]")
IP_COUNT=$(echo "$IN_PROGRESS" | jq 'length' 2>/dev/null || echo "0")
if [ "$IP_COUNT" -gt 0 ]; then
  BLOCK=true
  OUTPUT="${OUTPUT}[ ] In-progress tasks: ${IP_COUNT} issue(s)"$'\n'
  echo "$IN_PROGRESS" | jq -r '.[] | "    \(.id): \(.title)"' 2>/dev/null | while IFS= read -r line; do
    OUTPUT="${OUTPUT}${line}"$'\n'
  done
  # Re-read since pipe subshell loses OUTPUT
  TASK_LIST=$(echo "$IN_PROGRESS" | jq -r '.[] | "    \(.id): \(.title)"' 2>/dev/null || echo "    (unable to list)")
  OUTPUT="${OUTPUT}${TASK_LIST}"$'\n'
  OUTPUT="${OUTPUT}    Action: Close or update status before pushing"$'\n'
  OUTPUT="${OUTPUT}"$'\n'
fi

# --- Block or allow ---
if [ "$BLOCK" = "true" ]; then
  echo ""
  echo "LAND-THE-PLANE: Push blocked — prerequisites not met"
  echo ""
  echo "$OUTPUT"
  echo "Run /yf:session_land to complete the checklist, then retry push."
  echo ""
  exit 2
fi

exit 0
