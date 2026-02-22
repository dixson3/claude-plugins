#!/usr/bin/env bash
# session-recall.sh — SessionStart hook: output open chronicle summary
#
# Outputs open chronicle bead summaries to stdout so the agent starts
# every session with recovered context. Detects and consumes a
# .beads/.pending-diary marker left by session-end.sh.
#
# Usage:
#   bash session-recall.sh
#
# Output goes to stdout → injected into agent context by SessionStart.
# Compatible with bash 3.2+ (macOS default).
# Exit 0 always (fail-open).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# --- Guards ---
yf_is_enabled || exit 0

if ! command -v bd >/dev/null 2>&1; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# --- Project directory ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BEADS_DIR="$PROJECT_DIR/.beads"
PENDING_MARKER="$BEADS_DIR/.pending-diary"
PLANS_DIR="$PROJECT_DIR/docs/plans"

# --- Check for pending-diary marker from previous session ---
HAS_PENDING=false
PENDING_REASON=""
PENDING_COUNT=0
if [ -f "$PENDING_MARKER" ]; then
  HAS_PENDING=true
  PENDING_REASON=$(jq -r '.reason // "unknown"' "$PENDING_MARKER" 2>/dev/null || echo "unknown")
  PENDING_COUNT=$(jq -r '.chronicle_count // 0' "$PENDING_MARKER" 2>/dev/null || echo "0")
  rm -f "$PENDING_MARKER"
fi

# --- Check for dirty-tree marker from previous session ---
DIRTY_MARKER="$BEADS_DIR/.dirty-tree"
HAS_DIRTY=false
DIRTY_FILE_COUNT=0
if [ -f "$DIRTY_MARKER" ]; then
  HAS_DIRTY=true
  DIRTY_FILE_COUNT=$(jq -r '.dirty_count // 0' "$DIRTY_MARKER" 2>/dev/null || echo "0")
  rm -f "$DIRTY_MARKER"
fi

# --- Query open chronicles ---
CHRONICLES=$( (set +e; bd list --label=ys:chronicle --status=open --format=json 2>/dev/null) || echo "[]")
COUNT=$(echo "$CHRONICLES" | jq 'length' 2>/dev/null || echo "0")

# --- Check for plans without beads ---
HAS_PLAN_WARNING=false
PLAN_WARNING_IDX=""
if [ -d "$PLANS_DIR" ]; then
  LATEST_PLAN=$(ls -t "$PLANS_DIR"/plan-*.md 2>/dev/null | head -1)
  if [ -n "$LATEST_PLAN" ]; then
    if ! grep -q 'Status: Completed' "$LATEST_PLAN" 2>/dev/null; then
      PLAN_IDX=$(basename "$LATEST_PLAN" .md | sed 's/^plan-//')
      if [ -n "$PLAN_IDX" ]; then
        EPIC_COUNT=$(bd list -l "plan:$PLAN_IDX" --type=epic --limit=1 --json 2>/dev/null \
          | jq 'length' 2>/dev/null) || EPIC_COUNT="0"
        if [ "$EPIC_COUNT" = "0" ]; then
          HAS_PLAN_WARNING=true
          PLAN_WARNING_IDX="$PLAN_IDX"
        fi
      fi
    fi
  fi
fi

# --- Exit silently if nothing to report ---
if [ "$COUNT" -eq 0 ] && [ "$HAS_PENDING" = "false" ] && [ "$HAS_PLAN_WARNING" = "false" ] && [ "$HAS_DIRTY" = "false" ]; then
  exit 0
fi

# --- Output ---
echo ""

if $HAS_PENDING; then
  echo "=========================================="
  echo "  DEFERRED DIARY: Previous session left $PENDING_COUNT open chronicle(s)"
  echo "=========================================="
  echo ""
  echo "Reason: $PENDING_REASON"
  echo ""
fi

if [ "$COUNT" -gt 0 ]; then
  echo "CHRONICLER: $COUNT open chronicle(s) detected"
  echo ""
  echo "$CHRONICLES" | jq -r '.[] | "  - \(.id): \(.title)"' 2>/dev/null || echo "  (unable to list)"
  echo ""
fi

if $HAS_PLAN_WARNING; then
  echo "WARNING: Plan $PLAN_WARNING_IDX exists but has no beads. Run /yf:plan_intake to set up the lifecycle."
  echo ""
fi

if $HAS_DIRTY; then
  echo "=========================================="
  echo "  DIRTY TREE: Previous session left $DIRTY_FILE_COUNT uncommitted file(s)"
  echo "=========================================="
  echo ""
  echo "Review with: git status"
  echo "Commit before starting new work, or run /yf:session_land to close out."
  echo ""
fi

if $HAS_PENDING; then
  echo "Run /yf:chronicle_diary to process pending entries"
elif [ "$COUNT" -gt 0 ]; then
  echo "Run /yf:chronicle_recall for full context recovery"
fi

echo ""

exit 0
