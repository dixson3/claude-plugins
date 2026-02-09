#!/bin/bash
# code-gate.sh — Pre-tool-use hook for Edit and Write tool calls
#
# Enforces a plan gate that blocks code edits when a plan has been saved
# but not yet reached Executing state. If .claude/.plan-gate does not
# exist, the hook exits immediately with zero overhead.
#
# Matches: Edit(*), Write(*)
#
# Exit codes:
#   0 — allow (no gate, exempt file, or parse failure — fail-open)
#   2 — deny  (gate active, non-exempt file)

set -euo pipefail

# ── Enabled guard: exit early if yf disabled ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

# ── Fast path: no gate file means no enforcement ──────────────────────
GATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.plan-gate"
if [[ ! -f "$GATE_FILE" ]]; then
  # ── Beads safety net: warn if active plan has no beads ──────────────
  # Fail-open: entire check runs in a subshell so errors never block edits
  INTAKE_MARKER="${CLAUDE_PROJECT_DIR:-.}/.claude/.plan-intake-ok"
  if [[ ! -f "$INTAKE_MARKER" ]]; then
    (
      set +e
      command -v bd >/dev/null 2>&1 || exit 0
      PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/docs/plans"
      [[ -d "$PLANS_DIR" ]] || exit 0
      LATEST_PLAN=$(ls -t "$PLANS_DIR"/plan-*.md 2>/dev/null | head -1)
      [[ -n "$LATEST_PLAN" ]] || exit 0
      grep -q 'Status: Completed' "$LATEST_PLAN" 2>/dev/null && exit 0
      PLAN_IDX=$(basename "$LATEST_PLAN" | sed -n 's/^plan-\([0-9]*\).*/\1/p')
      [[ -n "$PLAN_IDX" ]] || exit 0
      EPIC_COUNT=$(bd list -l "plan:$PLAN_IDX" --type=epic --limit=1 --json 2>/dev/null \
        | jq 'length' 2>/dev/null) || EPIC_COUNT="0"
      if [[ "$EPIC_COUNT" = "0" ]]; then
        echo "WARNING: Plan $PLAN_IDX exists but has no beads. Run /yf:plan_intake to set up the lifecycle."
      fi
    ) || true
    touch "$INTAKE_MARKER"
  fi
  exit 0
fi

# ── Read tool input from stdin ────────────────────────────────────────
TOOL_INPUT=$(cat)

# ── Parse file_path via jq (fail-open on errors) ─────────────────────
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -n "$FILE_PATH" ]] || exit 0

# ── Exempt file patterns (allow even with gate active) ────────────────
case "$FILE_PATH" in
    */docs/plans/*)          exit 0 ;; # Plan lifecycle artifacts
    */.claude/*)             exit 0 ;; # Config, rules, settings
    */CHANGELOG.md)          exit 0 ;; # Documentation during transitions
    */MEMORY.md)             exit 0 ;; # Session context always editable
    */.claude-plugin/*.json) exit 0 ;; # Plugin manifest updates
    */README.md)             exit 0 ;; # Documentation, not implementation
    */.beads/*)              exit 0 ;; # Beads internal state
esac

# ── Read plan index from gate file ────────────────────────────────────
PLAN_IDX=$(cat "$GATE_FILE" 2>/dev/null || echo "unknown")

# ── Deny: gate active, non-exempt file ────────────────────────────────
jq -n --arg idx "$PLAN_IDX" '{
  "decision": "block",
  "reason": ("BLOCKED: Plan " + $idx + " is saved but not yet executing. To proceed: 1. Run /yf:plan_to_beads to create beads. 2. Say '\''execute the plan'\'' to start. Or run /yf:dismiss_gate to abandon.")
}'

exit 2
