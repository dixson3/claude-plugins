#!/usr/bin/env bash
# pre-compact.sh — PreCompact hook: capture work before context erasure
#
# Runs chronicle-check.sh to create draft beads from significant git
# activity before context compaction erases the conversation history.
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

# --- Run chronicle-check to create drafts from git activity ---
bash "$SCRIPT_DIR/scripts/chronicle-check.sh" check 2>/dev/null || true

# --- Run staleness check with shorter threshold (compaction = urgent) ---
bash "$SCRIPT_DIR/scripts/chronicle-staleness.sh" --threshold 1 2>/dev/null || true

exit 0
