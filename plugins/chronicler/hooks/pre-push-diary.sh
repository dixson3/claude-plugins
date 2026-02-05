#!/bin/bash
# pre-push-diary.sh
# Hook to check for open chronicle beads before push and suggest diary generation
#
# Install to: .claude/hooks/pre-push-diary.sh
# Configure in .claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "Bash(git push:*)",
#         "command": ".claude/hooks/pre-push-diary.sh"
#       }
#     ]
#   }
# }

set -e

# Check if beads-cli is available
if ! command -v bd &> /dev/null; then
    echo "beads-cli not found, skipping chronicle check"
    exit 0
fi

# Check for open chronicle beads
OPEN_CHRONICLES=$(bd list --label=ys:chronicle --status=open --format=json 2>/dev/null || echo "[]")

# Count open chronicles
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
    echo "Consider running /chronicler:diary to generate diary entries"
    echo "before pushing, or /chronicler:disable to close them without"
    echo "diary generation."
    echo ""
    echo "=========================================="
    echo ""
fi

# Always allow push to proceed - this is informational only
exit 0
