#!/bin/bash
# plan-exec-guard.sh — Pre-tool-use hook for plan execution enforcement
#
# Fires before bd claim/close operations. Prevents agents from picking up
# or completing tasks on non-executing plans.

set -euo pipefail

# ── Enabled guard: exit early if yf disabled ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

if [[ -z "$TOOL_INPUT" ]]; then
    TOOL_INPUT=$(cat)
fi

TASK_ID=""

if echo "$TOOL_INPUT" | grep -qE 'bd (update|close)'; then
    TASK_ID=$(echo "$TOOL_INPUT" | grep -oE '(marketplace-[a-z0-9]+(\.[0-9]+)*|bd-[a-z0-9]+)' | head -1)
fi

if [[ -z "$TASK_ID" ]]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PLAN_EXEC="$SCRIPT_DIR/plan-exec.sh"

if [[ ! -x "$PLAN_EXEC" ]]; then
    exit 0
fi

if "$PLAN_EXEC" guard "$TASK_ID" 2>/dev/null; then
    exit 0
else
    echo "BLOCKED: Plan is not in Executing state."
    echo "Say 'execute the plan' or 'resume the plan' to start."
    exit 1
fi
