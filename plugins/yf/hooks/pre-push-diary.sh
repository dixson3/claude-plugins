#!/bin/bash
# pre-push-diary.sh
# Hook to check for open chronicle beads before push and suggest diary generation

set -e

# ── Enabled guard: exit early if yf disabled ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

if ! command -v bd &> /dev/null; then
    echo "beads-cli not found, skipping chronicle check"
    exit 0
fi

# ── Advisory warning for open beads (parameterized) ───────────────────
warn_open_beads() {
    local label="$1" header="$2" process_cmd="$3" disable_cmd="$4"
    local beads count
    beads=$(bd list --label="$label" --status=open --format=json 2>/dev/null || echo "[]")
    count=$(echo "$beads" | jq 'length' 2>/dev/null || echo "0")
    [ "$count" -gt 0 ] || return 0
    echo ""
    echo "=========================================="
    echo "  $header"
    echo "=========================================="
    echo ""
    echo "You have $count open bead(s):"
    echo ""
    echo "$beads" | jq -r '.[] | "  - \(.id): \(.title)"' 2>/dev/null || echo "  (unable to list)"
    echo ""
    echo "Consider running $process_cmd to process them"
    echo "before pushing, or $disable_cmd to close them"
    echo "without output."
    echo ""
    echo "=========================================="
    echo ""
}

# ── Auto-create draft chronicles for significant work ──────────────
bash "$SCRIPT_DIR/scripts/chronicle-check.sh" pre-push 2>&1 || true

# ── Advisory: report open chronicles (including any new drafts) ────
warn_open_beads "ys:chronicle" \
    "CHRONICLER: Open chronicles detected" \
    "/yf:chronicle_diary" "/yf:chronicle_disable"

# ── Archivist check: warn about open archive beads ─────────────────
warn_open_beads "ys:archive" \
    "ARCHIVIST: Open archives detected" \
    "/yf:archive_process" "/yf:archive_disable"

# ── Issue tracker check: warn about staged issue beads ─────────────
warn_open_beads "ys:issue" \
    "ISSUE TRACKER: Staged issues detected" \
    "/yf:issue_process" "/yf:issue_disable"

exit 0
