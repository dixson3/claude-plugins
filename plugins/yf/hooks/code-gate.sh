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
YF_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.json"
if [ -f "$YF_JSON" ] && command -v jq >/dev/null 2>&1; then
  [ "$(jq -r 'if .enabled == null then true else .enabled end' "$YF_JSON" 2>/dev/null)" = "false" ] && exit 0
fi

# ── Fast path: no gate file means no enforcement ──────────────────────
GATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.plan-gate"
[[ -f "$GATE_FILE" ]] || exit 0

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
