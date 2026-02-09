#!/bin/bash
# plan-exec-guard.sh — Pre-tool-use hook for plan execution enforcement
#
# Fires before bd claim/close operations. Prevents agents from picking up
# or completing tasks on non-executing plans.

set -euo pipefail

# ── Enabled guard: exit early if yf disabled ──────────────────────────
YF_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.json"
if [ -f "$YF_JSON" ] && command -v jq >/dev/null 2>&1; then
  [ "$(jq -r 'if .enabled == null then true else .enabled end' "$YF_JSON" 2>/dev/null)" = "false" ] && exit 0
fi

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
