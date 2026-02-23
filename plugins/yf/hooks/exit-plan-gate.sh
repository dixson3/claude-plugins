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

# Generate hybrid idx-hash plan ID (collision-safe across parallel worktrees)
. "$SCRIPT_DIR/scripts/yf-id.sh"

# Resolve operator name for attribution
OPERATOR=$(yf_operator_name)

mkdir -p "$PLANS_DIR"

# Generate hybrid ID with scope (includes sequential index)
FULL_ID=$(yf_generate_id "plan" "$PLANS_DIR")
PLAN_ID="${FULL_ID#plan-}"   # Strip prefix → "NNNN-xxxxx"
DEST="$PLANS_DIR/plan-${PLAN_ID}.md"

# Copy the plan
cp "$PLAN_FILE" "$DEST"

# Extract title from plan file (first # heading)
PLAN_TITLE=$(grep -m1 '^# ' "$DEST" 2>/dev/null | sed 's/^# //' || echo "Untitled")

# Append entry to _index.md (create if missing)
INDEX_FILE="$PLANS_DIR/_index.md"
if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" <<'HEADER'
# Plan Index

| Idx | ID | Title | Date | Operator | Status |
|-----|-----|-------|------|----------|--------|
HEADER
fi

IDX="${PLAN_ID%%-*}"   # Extract NNNN from NNNN-xxxxx
PLAN_DATE=$(date +%Y-%m-%d)
printf '| %s | plan-%s | %s | %s | %s | Active |\n' \
    "$IDX" "$PLAN_ID" "$PLAN_TITLE" "$PLAN_DATE" "$OPERATOR" >> "$INDEX_FILE"

# Create the gate file
mkdir -p "$PROJECT_DIR/.yoshiko-flow"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"plan_idx":"%s","plan_file":"docs/plans/plan-%s.md","created":"%s","operator":"%s"}\n' \
    "$PLAN_ID" "$PLAN_ID" "$TIMESTAMP" "$OPERATOR" > "$GATE_FILE"

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
