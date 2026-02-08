#!/bin/bash
# exit-plan-gate.sh — PreToolUse hook for ExitPlanMode
#
# Fires when Claude exits plan mode. Saves the plan to docs/plans/ and
# creates a gate file so the plan lifecycle can proceed (plan_to_beads,
# then execute).
#
# If ExitPlanMode isn't a valid hook matcher, the engage_plan skill
# handles gating as a fallback — this hook is a best-effort intercept.
#
# Install in plugin.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "ExitPlanMode",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "${CLAUDE_PLUGIN_ROOT}/hooks/exit-plan-gate.sh"
#           }
#         ]
#       }
#     ]
#   }
# }

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
GATE_FILE="$PROJECT_DIR/.claude/.plan-gate"
PLANS_DIR="$PROJECT_DIR/docs/plans"
CLAUDE_PLANS_DIR="$PROJECT_DIR/.claude/plans"

# Idempotent: if engage_plan already created the gate, nothing to do
if [[ -f "$GATE_FILE" ]]; then
    exit 0
fi

# Find the most recent plan file from Claude's internal plan directory
if [[ ! -d "$CLAUDE_PLANS_DIR" ]]; then
    exit 0
fi

PLAN_FILE=$(ls -t "$CLAUDE_PLANS_DIR"/*.md 2>/dev/null | head -1)

if [[ -z "$PLAN_FILE" ]]; then
    exit 0
fi

# Determine next plan index by scanning existing docs/plans/plan-*.md
HIGHEST=0
if [[ -d "$PLANS_DIR" ]]; then
    for f in "$PLANS_DIR"/plan-*.md; do
        [[ -e "$f" ]] || continue
        # Extract numeric index from plan-XX.md or plan-XX-partN-name.md
        idx=$(basename "$f" | sed -n 's/^plan-\([0-9]*\).*/\1/p')
        if [[ -n "$idx" ]]; then
            # Strip leading zeros for arithmetic
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
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"plan_idx":"%s","plan_file":"docs/plans/plan-%s.md","created":"%s"}\n' \
    "$NEXT_PAD" "$NEXT_PAD" "$TIMESTAMP" > "$GATE_FILE"

# Inform the agent
cat <<EOF
Plan saved to docs/plans/plan-${NEXT_PAD}.md
Plan gate activated. Complete the lifecycle:
  1. Run /workflows:plan_to_beads to create beads
  2. Say "execute the plan" to start
  Or: /workflows:dismiss_gate to abandon
EOF

exit 0
