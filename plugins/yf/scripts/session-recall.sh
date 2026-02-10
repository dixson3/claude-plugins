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
yf_is_chronicler_on || exit 0

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

# --- Query open chronicles ---
CHRONICLES=$( (set +e; bd list --label=ys:chronicle --status=open --format=json 2>/dev/null) || echo "[]")
COUNT=$(echo "$CHRONICLES" | jq 'length' 2>/dev/null || echo "0")

# --- Exit silently if nothing to report ---
if [ "$COUNT" -eq 0 ] && [ "$HAS_PENDING" = "false" ]; then
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

if $HAS_PENDING; then
  echo "Run /yf:chronicle_diary to process pending entries"
else
  echo "Run /yf:chronicle_recall for full context recovery"
fi

echo ""

exit 0
