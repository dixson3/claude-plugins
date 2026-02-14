#!/bin/bash
# bd-safety-net.sh — Pre-tool-use hook for Bash(bd delete*) commands
#
# Advisory-only hook that warns when destructive bd operations happen
# without proper plan lifecycle or chronicle capture. Always exits 0.
#
# Checks:
#   1. If an incomplete plan file exists without beads → warn about plan-intake
#   2. If no open chronicle exists and delete targets >5 beads → warn about chronicle
#
# Matches: Bash(bd delete*)
#
# Exit codes:
#   0 — always (advisory only, never blocks)

set -uo pipefail

# ── Enabled guard ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

# ── Guards: need bd and jq ──────────────────────────────────────────
command -v bd >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# ── Read tool input to extract command ──────────────────────────────
TOOL_INPUT=$(cat)
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[[ -n "$COMMAND" ]] || exit 0

# ── Only act on bd delete commands ──────────────────────────────────
if ! echo "$COMMAND" | grep -q 'bd delete'; then
  exit 0
fi

# ── Count delete targets ────────────────────────────────────────────
# Extract bead IDs from the command (everything after "bd delete")
DELETE_ARGS=$(echo "$COMMAND" | sed 's/.*bd delete//' | tr -s ' ')
TARGET_COUNT=0
for arg in $DELETE_ARGS; do
  # Skip flags (--force, --yes, etc.)
  case "$arg" in
    -*) continue ;;
    *) TARGET_COUNT=$((TARGET_COUNT + 1)) ;;
  esac
done

# ── Check 1: Plan lifecycle ─────────────────────────────────────────
# If an incomplete plan exists without beads, warn about missing intake
INTAKE_MARKER="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-intake-ok"
PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/docs/plans"

if [[ ! -f "$INTAKE_MARKER" ]] && [[ -d "$PLANS_DIR" ]]; then
  LATEST_PLAN=$(ls -t "$PLANS_DIR"/plan-*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST_PLAN" ]]; then
    if ! grep -q 'Status: Completed' "$LATEST_PLAN" 2>/dev/null; then
      PLAN_IDX=$(basename "$LATEST_PLAN" | sed -n 's/^plan-\([0-9]*\).*/\1/p')
      if [[ -n "$PLAN_IDX" ]]; then
        EPIC_COUNT=$(bd list -l "plan:$PLAN_IDX" --type=epic --limit=1 --json 2>/dev/null \
          | jq 'length' 2>/dev/null) || EPIC_COUNT="0"
        if [[ "$EPIC_COUNT" = "0" ]]; then
          echo "WARNING: Plan $PLAN_IDX exists but has no beads. Destructive bd operations should go through the plan lifecycle. Run /yf:plan_intake to set up the lifecycle."
        fi
      fi
    fi
  fi
fi

# ── Check 2: Chronicle capture for bulk deletes ────────────────────
if [[ "$TARGET_COUNT" -gt 5 ]]; then
  CHRON_COUNT=$(bd list --label=ys:chronicle --status=open --limit=1 --json 2>/dev/null \
    | jq 'length' 2>/dev/null) || CHRON_COUNT="0"
  if [[ "$CHRON_COUNT" = "0" ]]; then
    echo "WARNING: Bulk delete ($TARGET_COUNT targets) with no open chronicle. Consider running /yf:chronicle_capture to preserve context before proceeding."
  fi
fi

exit 0
