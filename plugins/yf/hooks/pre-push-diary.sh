#!/bin/bash
# pre-push-diary.sh
# Hook to check for open chronicle beads before push and suggest diary generation

set -e

# ── Enabled guard: exit early if yf disabled ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

# ── Chronicler guard: exit early if chronicler disabled ───────────────
yf_is_chronicler_on || exit 0

if ! command -v bd &> /dev/null; then
    echo "beads-cli not found, skipping chronicle check"
    exit 0
fi

# ── Auto-create draft chronicles for significant work ──────────────
bash "$SCRIPT_DIR/scripts/chronicle-check.sh" pre-push 2>/dev/null || true

# ── Advisory: report open chronicles (including any new drafts) ────
OPEN_CHRONICLES=$(bd list --label=ys:chronicle --status=open --format=json 2>/dev/null || echo "[]")

COUNT=$(echo "$OPEN_CHRONICLES" | jq 'length' 2>/dev/null || echo "0")

if [ "$COUNT" -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "  CHRONICLER: Open chronicles detected"
    echo "=========================================="
    echo ""
    echo "You have $COUNT open chronicle bead(s):"
    echo ""
    echo "$OPEN_CHRONICLES" | jq -r '.[] | "  - \(.id): \(.title)"' 2>/dev/null || echo "  (unable to list)"
    echo ""
    echo "Consider running /yf:diary to generate diary entries"
    echo "before pushing, or /yf:disable to close them without"
    echo "diary generation."
    echo ""
    echo "=========================================="
    echo ""
fi

# ── Archivist check: warn about open archive beads ─────────────────
if yf_is_archivist_on; then
    OPEN_ARCHIVES=$(bd list --label=ys:archive --status=open --format=json 2>/dev/null || echo "[]")
    ARCHIVE_COUNT=$(echo "$OPEN_ARCHIVES" | jq 'length' 2>/dev/null || echo "0")

    if [ "$ARCHIVE_COUNT" -gt 0 ]; then
        echo ""
        echo "=========================================="
        echo "  ARCHIVIST: Open archives detected"
        echo "=========================================="
        echo ""
        echo "You have $ARCHIVE_COUNT open archive bead(s):"
        echo ""
        echo "$OPEN_ARCHIVES" | jq -r '.[] | "  - \(.id): \(.title)"' 2>/dev/null || echo "  (unable to list)"
        echo ""
        echo "Consider running /yf:archive_process to generate"
        echo "documentation, or /yf:archive_disable to close"
        echo "them without documentation."
        echo ""
        echo "=========================================="
        echo ""
    fi
fi

exit 0
