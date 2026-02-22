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

# Generate hash-based plan ID (collision-safe across parallel worktrees)
. "$SCRIPT_DIR/scripts/yf-id.sh"

mkdir -p "$PLANS_DIR"

# Generate ID with collision check
MAX_RETRIES=5
RETRY=0
while true; do
    PLAN_ID=$(yf_generate_id "plan" | sed 's/^plan-//')
    DEST="$PLANS_DIR/plan-${PLAN_ID}.md"
    if [[ ! -f "$DEST" ]]; then
        break
    fi
    RETRY=$((RETRY + 1))
    if (( RETRY >= MAX_RETRIES )); then
        # Extremely unlikely — fall back to timestamp
        PLAN_ID="t$(date +%s)"
        DEST="$PLANS_DIR/plan-${PLAN_ID}.md"
        break
    fi
done

# Copy the plan
cp "$PLAN_FILE" "$DEST"

# Create the gate file
mkdir -p "$PROJECT_DIR/.yoshiko-flow"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"plan_idx":"%s","plan_file":"docs/plans/plan-%s.md","created":"%s"}\n' \
    "$PLAN_ID" "$PLAN_ID" "$TIMESTAMP" > "$GATE_FILE"

# Inform the agent
# Deterministic chronicle: capture plan-save boundary
bash "$SCRIPT_DIR/scripts/plan-chronicle.sh" save "plan:${PLAN_ID}" "$DEST" 2>/dev/null || true

cat <<EOF
Plan saved to docs/plans/plan-${PLAN_ID}.md
Plan gate activated. Auto-chaining plan lifecycle...
PLAN_IDX=${PLAN_ID}
PLAN_FILE=docs/plans/plan-${PLAN_ID}.md
EOF

exit 0
