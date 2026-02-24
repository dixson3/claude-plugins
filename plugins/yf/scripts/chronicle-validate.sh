#!/bin/bash
# chronicle-validate.sh — Verify chronicle coverage for a plan
#
# Checks that all plan lifecycle boundaries have chronicle entries.
# Creates fallback stubs for any missing boundaries.
#
# Usage:
#   chronicle-validate.sh <plan_label>
#
# Boundaries checked:
#   1. plan-save or plan-intake (save/intake boundary)
#   2. start transition (plan-exec.sh start)
#   3. complete transition (plan-exec.sh status=completed)
#
# Fail-open: always exits 0.

set -euo pipefail

PLAN_LABEL="${1:-}"

if [[ -z "$PLAN_LABEL" ]]; then
    echo "Usage: chronicle-validate.sh <plan_label>" >&2
    exit 0  # fail-open
fi

# --- Source task library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-tasks.sh"

# --- Query all chronicles for this plan ---
ALL_CHRONICLES=$(yft_list -l "ys:chronicle,${PLAN_LABEL}" --limit=0 --json 2>/dev/null || echo "[]")

# --- Check each boundary ---
TOTAL=3
COVERED=0
CREATED=0

check_boundary() {
    local pattern="$1"
    local boundary_name="$2"

    local found
    found=$(echo "$ALL_CHRONICLES" | jq -r --arg pat "$pattern" \
        '[.[] | select(.title | ascii_downcase | contains($pat))] | length' 2>/dev/null || echo "0")

    if [[ "$found" -gt 0 ]]; then
        COVERED=$((COVERED + 1))
        return 0
    fi
    return 1
}

# Boundary 1: save or intake
if check_boundary "save" "plan-save" || check_boundary "intake" "plan-intake"; then
    : # covered
else
    # Create fallback
    yft_create --type=chronicle --priority=3 \
        -l "ys:chronicle,ys:chronicle:auto,ys:chronicle:fallback,ys:topic:planning,${PLAN_LABEL}" \
        --title "Chronicle (Fallback): Plan ${PLAN_LABEL} — save/intake" \
        --description "## Fallback Chronicle

**Plan**: ${PLAN_LABEL}
**Boundary**: save/intake (missing — created by chronicle-validate.sh)
**Date**: $(date '+%Y-%m-%d %H:%M')

This fallback was created because no save or intake chronicle was found for this plan.
The original planning context may have been lost." >/dev/null 2>&1 || true
    CREATED=$((CREATED + 1))
    COVERED=$((COVERED + 1))
fi

# Boundary 2: start transition
if check_boundary "start" "start"; then
    : # covered
else
    yft_create --type=chronicle --priority=3 \
        -l "ys:chronicle,ys:chronicle:auto,ys:chronicle:fallback,ys:topic:planning,${PLAN_LABEL}" \
        --title "Chronicle (Fallback): Plan ${PLAN_LABEL} — start" \
        --description "## Fallback Chronicle

**Plan**: ${PLAN_LABEL}
**Boundary**: start (missing — created by chronicle-validate.sh)
**Date**: $(date '+%Y-%m-%d %H:%M')

This fallback was created because no start transition chronicle was found for this plan." >/dev/null 2>&1 || true
    CREATED=$((CREATED + 1))
    COVERED=$((COVERED + 1))
fi

# Boundary 3: complete transition
if check_boundary "complete" "complete"; then
    : # covered
else
    yft_create --type=chronicle --priority=3 \
        -l "ys:chronicle,ys:chronicle:auto,ys:chronicle:fallback,ys:topic:planning,${PLAN_LABEL}" \
        --title "Chronicle (Fallback): Plan ${PLAN_LABEL} — complete" \
        --description "## Fallback Chronicle

**Plan**: ${PLAN_LABEL}
**Boundary**: complete (missing — created by chronicle-validate.sh)
**Date**: $(date '+%Y-%m-%d %H:%M')

This fallback was created because no completion chronicle was found for this plan." >/dev/null 2>&1 || true
    CREATED=$((CREATED + 1))
    COVERED=$((COVERED + 1))
fi

if [[ "$CREATED" -gt 0 ]]; then
    echo "${COVERED}/${TOTAL} boundaries covered, created ${CREATED} fallback(s)"
else
    echo "${COVERED}/${TOTAL} boundaries covered"
fi
