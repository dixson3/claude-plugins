#!/bin/bash
# plan-exec-guard.sh — Pre-tool-use hook for plan execution enforcement
#
# Fires before bd claim/close operations. Prevents agents from picking up
# or completing tasks on non-executing plans.
#
# Matches: Bash commands containing:
#   - "bd update" with "--status in_progress" or "--claim"
#   - "bd close"
#
# Install in .claude/settings.local.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "Bash(bd update*--status*in_progress*)",
#         "command": "plugins/workflows/hooks/plan-exec-guard.sh"
#       },
#       {
#         "matcher": "Bash(bd update*--claim*)",
#         "command": "plugins/workflows/hooks/plan-exec-guard.sh"
#       },
#       {
#         "matcher": "Bash(bd close*)",
#         "command": "plugins/workflows/hooks/plan-exec-guard.sh"
#       }
#     ]
#   }
# }

set -euo pipefail

# The hook receives the tool input via environment or stdin
# Extract the command being run
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

if [[ -z "$TOOL_INPUT" ]]; then
    # Read from stdin if not in env
    TOOL_INPUT=$(cat)
fi

# Extract the task ID from the bd command
# Patterns: "bd update <id> --status in_progress", "bd close <id>", "bd update <id> --claim"
TASK_ID=""

# Try to extract ID from the command
if echo "$TOOL_INPUT" | grep -qE 'bd (update|close)'; then
    # Extract the first argument after bd update/close that looks like a bead ID
    TASK_ID=$(echo "$TOOL_INPUT" | grep -oE '(marketplace-[a-z0-9]+(\.[0-9]+)*|bd-[a-z0-9]+)' | head -1)
fi

if [[ -z "$TASK_ID" ]]; then
    # Can't determine task ID — allow (don't block on parsing failures)
    exit 0
fi

# Check if plan-exec.sh exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PLAN_EXEC="$SCRIPT_DIR/plan-exec.sh"

if [[ ! -x "$PLAN_EXEC" ]]; then
    # Script not found — allow
    exit 0
fi

# Run the guard check
if "$PLAN_EXEC" guard "$TASK_ID" 2>/dev/null; then
    exit 0  # Allowed
else
    echo "BLOCKED: Plan is not in Executing state."
    echo "Say 'execute the plan' or 'resume the plan' to start."
    exit 1
fi
