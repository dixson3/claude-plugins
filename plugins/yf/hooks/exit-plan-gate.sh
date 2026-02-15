#!/bin/bash
# exit-plan-gate.sh — PreToolUse hook for ExitPlanMode
#
# Fires when Claude exits plan mode. Saves the plan to docs/plans/ and
# creates a gate file. Outputs auto-chain signal so the auto-chain-plan
# rule drives the full lifecycle (plan_to_beads → execute) automatically.
#
# If engage_plan already created the gate, this hook exits silently
# (idempotent) and the auto-chain rule does NOT fire.

set -euo pipefail

# ── Enabled guard: exit early if yf disabled ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
GATE_FILE="$PROJECT_DIR/.yoshiko-flow/plan-gate"
PLANS_DIR="$PROJECT_DIR/docs/plans"
CLAUDE_PLANS_DIR="${HOME}/.claude/plans"

# Idempotent: if engage_plan already created the gate, nothing to do
if [[ -f "$GATE_FILE" ]]; then
    exit 0
fi

# Find the most recent plan file from Claude's internal plan directory
if [[ ! -d "$CLAUDE_PLANS_DIR" ]]; then
    exit 0
fi

PLAN_FILE=$(find "$CLAUDE_PLANS_DIR" -maxdepth 1 -name '*.md' -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -1)

if [[ -z "$PLAN_FILE" ]]; then
    exit 0
fi

# Determine next plan index by scanning existing docs/plans/plan-*.md
HIGHEST=0
if [[ -d "$PLANS_DIR" ]]; then
    for f in "$PLANS_DIR"/plan-*.md; do
        [[ -e "$f" ]] || continue
        idx=$(basename "$f" | sed -n 's/^plan-\([0-9]*\).*/\1/p')
        if [[ -n "$idx" ]]; then
            idx_num=$((10#$idx))
            if (( idx_num > HIGHEST )); then
                HIGHEST=$idx_num
            fi
        fi
    done
fi

NEXT=$(( HIGHEST + 1 ))
NEXT_PAD=$(printf "%02d" "$NEXT")

# Ensure docs/plans/ exists
mkdir -p "$PLANS_DIR"

# Copy the plan
DEST="$PLANS_DIR/plan-${NEXT_PAD}.md"
cp "$PLAN_FILE" "$DEST"

# Create the gate file
mkdir -p "$PROJECT_DIR/.yoshiko-flow"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"plan_idx":"%s","plan_file":"docs/plans/plan-%s.md","created":"%s"}\n' \
    "$NEXT_PAD" "$NEXT_PAD" "$TIMESTAMP" > "$GATE_FILE"

# Inform the agent
# Deterministic chronicle: capture plan-save boundary
bash "$SCRIPT_DIR/scripts/plan-chronicle.sh" save "plan:${NEXT_PAD}" "$DEST" 2>/dev/null || true

cat <<EOF
Plan saved to docs/plans/plan-${NEXT_PAD}.md
Plan gate activated. Auto-chaining plan lifecycle...
PLAN_IDX=${NEXT_PAD}
PLAN_FILE=docs/plans/plan-${NEXT_PAD}.md
EOF

exit 0
