#!/bin/bash
# code-gate.sh — Pre-tool-use hook for Edit and Write tool calls
#
# Enforces a plan gate that blocks code edits when a plan has been saved
# but not yet reached Executing state. If .yoshiko-flow/plan-gate does not
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
GATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-gate"
if [[ ! -f "$GATE_FILE" ]]; then
  # ── Chronicle staleness nudge (subshell, fail-open) ────────────────
  (
    set +e
    command -v bd >/dev/null 2>&1 || exit 0
    command -v jq >/dev/null 2>&1 || exit 0

    NUDGE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/.chronicle-nudge"
    NUDGE_INTERVAL=1800  # 30 minutes

    # Time gate: check last nudge
    if [ -f "$NUDGE_FILE" ]; then
      LAST_EPOCH=$(cat "$NUDGE_FILE" 2>/dev/null || echo "0")
      NOW_EPOCH=$(date "+%s")
      ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
      [ "$ELAPSED" -lt "$NUDGE_INTERVAL" ] && exit 0
    fi

    # Check for in-progress beads
    IP_COUNT=$(bd list --status=in_progress --type=task --limit=1 --json 2>/dev/null \
      | jq 'length' 2>/dev/null) || IP_COUNT=0
    [ "$IP_COUNT" -eq 0 ] && exit 0

    # Check for recent chronicle (within 1 hour)
    LATEST=$(bd list --label=ys:chronicle --status=open --limit=1 --json 2>/dev/null || echo "[]")
    LATEST_CREATED=$(echo "$LATEST" | jq -r '.[0].created // empty' 2>/dev/null || true)
    if [ -n "$LATEST_CREATED" ]; then
      CHRON_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LATEST_CREATED%%.*}" "+%s" 2>/dev/null \
        || date -d "${LATEST_CREATED}" "+%s" 2>/dev/null \
        || echo "0")
      NOW_EPOCH=$(date "+%s")
      [ $((NOW_EPOCH - CHRON_EPOCH)) -lt 3600 ] && exit 0
    fi

    # Emit nudge and update timestamp
    echo "NOTE: ${IP_COUNT} task(s) in progress with no recent chronicle. Consider running /yf:chronicle_capture to preserve context."
    mkdir -p "$(dirname "$NUDGE_FILE")" 2>/dev/null || true
    date "+%s" > "$NUDGE_FILE" 2>/dev/null || true
  ) || true

  # ── Beads safety net: BLOCK if active plan has no beads ─────────────
  PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/docs/plans"
  SKIP_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-intake-skip"
  CACHE_FILE="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/.beads-check-cache"

  if [[ ! -f "$SKIP_FILE" ]] && [[ -d "$PLANS_DIR" ]] && ls "$PLANS_DIR"/plan-*.md >/dev/null 2>&1; then
    # Read tool input to check exempt files (same exemptions as plan-gate)
    TOOL_INPUT_PEEK=$(cat)
    FILE_PATH_PEEK=$(echo "$TOOL_INPUT_PEEK" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || FILE_PATH_PEEK=""
    case "$FILE_PATH_PEEK" in
      */docs/plans/*|*/docs/research/*|*/docs/decisions/*|*/docs/specifications/*) ;; # exempt
      */.claude/*|*/.yoshiko-flow/*|*/CHANGELOG.md|*/MEMORY.md) ;;
      */.claude-plugin/*.json|*/README.md|*/.beads/*) ;;
      *)
        # Non-exempt file — check beads
        BEADS_RESULT=""
        CACHE_VALID=false
        if [[ -f "$CACHE_FILE" ]]; then
          CACHE_TS=$(head -1 "$CACHE_FILE" 2>/dev/null || echo "0")
          CACHE_VAL=$(tail -1 "$CACHE_FILE" 2>/dev/null || echo "")
          NOW_EPOCH=$(date "+%s")
          if [[ -n "$CACHE_TS" ]] && [[ $((NOW_EPOCH - CACHE_TS)) -lt 60 ]]; then
            BEADS_RESULT="$CACHE_VAL"
            CACHE_VALID=true
          fi
        fi

        if ! $CACHE_VALID; then
          BEADS_RESULT=$(
            set +e
            command -v bd >/dev/null 2>&1 || { echo "skip"; exit 0; }
            LATEST_PLAN=$(ls -t "$PLANS_DIR"/plan-*.md 2>/dev/null | head -1)
            [[ -n "$LATEST_PLAN" ]] || { echo "skip"; exit 0; }
            grep -q 'Status: Completed' "$LATEST_PLAN" 2>/dev/null && { echo "skip"; exit 0; }
            PLAN_IDX=$(basename "$LATEST_PLAN" | sed -n 's/^plan-\([a-z0-9]*\).*/\1/p')
            [[ -n "$PLAN_IDX" ]] || { echo "skip"; exit 0; }
            EPIC_COUNT=$(bd list -l "plan:$PLAN_IDX" --type=epic --limit=1 --json 2>/dev/null \
              | jq 'length' 2>/dev/null) || EPIC_COUNT="0"
            if [[ "$EPIC_COUNT" = "0" ]]; then
              echo "block:$PLAN_IDX"
            else
              echo "skip"
            fi
          ) || BEADS_RESULT="skip"
          # Write cache
          mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true
          printf '%s\n%s\n' "$(date '+%s')" "$BEADS_RESULT" > "$CACHE_FILE" 2>/dev/null || true
        fi

        if [[ "$BEADS_RESULT" == block:* ]]; then
          BLOCKED_IDX="${BEADS_RESULT#block:}"
          jq -n --arg idx "$BLOCKED_IDX" '{
            "decision": "block",
            "reason": ("BLOCKED: Plan " + $idx + " exists but has no beads. Run /yf:plan_intake to set up the lifecycle, or /yf:plan_dismiss_gate to abandon it.")
          }'
          exit 2
        fi
        ;;
    esac
  fi

  # ── Chronicle safety net: warn if active plan has beads but no chronicle ──
  CHRONICLE_MARKER="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/plan-chronicle-ok"
  if [[ ! -f "$CHRONICLE_MARKER" ]] && [[ -d "$PLANS_DIR" ]] && ls "$PLANS_DIR"/plan-*.md >/dev/null 2>&1; then
    (
      set +e
      command -v bd >/dev/null 2>&1 || exit 0
      command -v jq >/dev/null 2>&1 || exit 0
      LATEST_PLAN=$(ls -t "$PLANS_DIR"/plan-*.md 2>/dev/null | head -1)
      [[ -n "$LATEST_PLAN" ]] || exit 0
      grep -q 'Status: Completed' "$LATEST_PLAN" 2>/dev/null && exit 0
      PLAN_IDX=$(basename "$LATEST_PLAN" | sed -n 's/^plan-\([a-z0-9]*\).*/\1/p')
      [[ -n "$PLAN_IDX" ]] || exit 0
      # Only check if beads exist (plan is past intake)
      EPIC_COUNT=$(bd list -l "plan:$PLAN_IDX" --type=epic --limit=1 --json 2>/dev/null \
        | jq 'length' 2>/dev/null) || EPIC_COUNT="0"
      [[ "$EPIC_COUNT" != "0" ]] || exit 0
      # Check for any chronicle for this plan
      CHRON_COUNT=$(bd list -l "ys:chronicle,plan:$PLAN_IDX" --limit=1 --json 2>/dev/null \
        | jq 'length' 2>/dev/null) || CHRON_COUNT="0"
      if [[ "$CHRON_COUNT" = "0" ]]; then
        echo "WARNING: Plan $PLAN_IDX has tasks but no chronicle. Run /yf:chronicle_capture topic:planning to preserve planning context."
      fi
    ) || true
    touch "$CHRONICLE_MARKER"
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
    */docs/research/*)       exit 0 ;; # Archivist research docs
    */docs/decisions/*)      exit 0 ;; # Archivist decision docs
    */docs/specifications/*) exit 0 ;; # Engineer spec artifacts
    */.claude/*)             exit 0 ;; # Config, rules, settings
    */.yoshiko-flow/*)       exit 0 ;; # yf state files
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
