#!/usr/bin/env bash
# session-end.sh — SessionEnd hook: auto-draft chronicles + pending marker
#
# Runs chronicle-check.sh to create draft beads from significant git
# activity, then writes a .beads/.pending-diary marker if open chronicles
# exist. The marker is consumed by session-recall.sh on next SessionStart.
#
# Compatible with bash 3.2+ (macOS default).
# Exit 0 always (fail-open, non-blocking).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"

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

# --- Run chronicle-check to create drafts from git activity ---
bash "$SCRIPT_DIR/scripts/chronicle-check.sh" check 2>/dev/null || true

# --- Query open chronicles ---
CHRONICLES=$( (set +e; bd list --label=ys:chronicle --status=open --format=json 2>/dev/null) || echo "[]")
COUNT=$(echo "$CHRONICLES" | jq 'length' 2>/dev/null || echo "0")

# --- Write pending-diary marker if open chronicles exist ---
if [ "$COUNT" -gt 0 ]; then
  mkdir -p "$BEADS_DIR" 2>/dev/null || true
  DRAFT_CREATED=false
  # Check if chronicle-check created any new drafts (exit code was 0 and output was "1")
  if [ -f "$BEADS_DIR/.chronicle-drafted-$(date +%Y%m%d)" ]; then
    DRAFT_CREATED=true
  fi
  cat > "$BEADS_DIR/.pending-diary" <<MARKER
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "session_end",
  "chronicle_count": $COUNT,
  "draft_created": $DRAFT_CREATED
}
MARKER
fi

exit 0
