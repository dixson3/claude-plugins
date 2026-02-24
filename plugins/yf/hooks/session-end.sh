#!/usr/bin/env bash
# session-end.sh — SessionEnd hook: auto-draft chronicles + pending marker
#
# Runs chronicle-check.sh to create draft tasks from significant git
# activity, then writes a .yoshiko-flow/.pending-diary marker if open
# chronicles exist. The marker is consumed by session-recall.sh on next
# SessionStart.
#
# Compatible with bash 3.2+ (macOS default).
# Exit 0 always (fail-open, non-blocking).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
. "$SCRIPT_DIR/scripts/yf-tasks.sh"

# --- Guards ---
yf_is_enabled || exit 0

# --- Project directory ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
YF_DIR="$PROJECT_DIR/.yoshiko-flow"

# --- Run chronicle-check to create drafts from git activity ---
bash "$SCRIPT_DIR/scripts/chronicle-check.sh" check 2>/dev/null || true

# --- Run staleness check for long sessions with no recent chronicles ---
bash "$SCRIPT_DIR/scripts/chronicle-staleness.sh" 2>/dev/null || true

# --- Session prune: clean stale tasks, ephemeral files, stale drafts ---
bash "$SCRIPT_DIR/scripts/session-prune.sh" all 2>/dev/null || true

# --- Query open chronicles ---
CHRONICLES=$(yft_list -l "ys:chronicle" --status=open --json 2>/dev/null || echo "[]")
COUNT=$(echo "$CHRONICLES" | jq 'length' 2>/dev/null || echo "0")

# --- Write pending-diary marker if open chronicles exist ---
if [ "$COUNT" -gt 0 ]; then
  mkdir -p "$YF_DIR" 2>/dev/null || true
  DRAFT_CREATED=false
  # Check if chronicle-check created any new drafts (exit code was 0 and output was "1")
  if [ -f "$YF_DIR/.chronicle-drafted-$(date +%Y%m%d)" ]; then
    DRAFT_CREATED=true
  fi
  cat > "$YF_DIR/.pending-diary" <<MARKER
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "session_end",
  "chronicle_count": $COUNT,
  "draft_created": $DRAFT_CREATED
}
MARKER
fi

# --- Write dirty-tree marker if uncommitted changes exist ---
DIRTY_COUNT=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_COUNT" -gt 0 ]; then
  mkdir -p "$YF_DIR" 2>/dev/null || true
  cat > "$YF_DIR/.dirty-tree" <<MARKER
{"created":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","reason":"session_end","dirty_count":$DIRTY_COUNT}
MARKER
fi

exit 0
