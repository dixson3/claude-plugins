#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build harness
echo "Building test harness..."
cd "$SCRIPT_DIR/harness"
go build -o "$SCRIPT_DIR/bin/test-harness" .

HARNESS="$SCRIPT_DIR/bin/test-harness"
SCENARIOS="$SCRIPT_DIR/scenarios"

# Parse flags
UNIT_ONLY=false
VERBOSE=false
KEEP=false
CHANGED=false
SCENARIO_FILES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit-only) UNIT_ONLY=true; shift ;;
        --verbose)   VERBOSE=true; shift ;;
        --keep)      KEEP=true; shift ;;
        --changed)   CHANGED=true; shift ;;
        --scenarios)
            shift
            while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
                SCENARIO_FILES+=("$1")
                shift
            done
            ;;
        *) shift ;;
    esac
done

FLAGS=""
if $VERBOSE; then FLAGS="$FLAGS --verbose"; fi
if $KEEP; then FLAGS="$FLAGS --keep"; fi

# Resolve scenarios for --changed mode
if $CHANGED && [ ${#SCENARIO_FILES[@]} -eq 0 ]; then
    CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null)
    CHANGED_FILES=$(echo "$CHANGED_FILES" | sort -u)
    if [ -n "$CHANGED_FILES" ]; then
        MATCHED=()
        for cf in $CHANGED_FILES; do
            BASENAME=$(basename "$cf")
            # Search unit test scenarios for references to this file
            for scenario in "$SCENARIOS"/unit-*.yaml; do
                [ -f "$scenario" ] || continue
                if grep -ql "$BASENAME" "$scenario" 2>/dev/null; then
                    MATCHED+=("$scenario")
                fi
            done
        done
        # Deduplicate
        if [ ${#MATCHED[@]} -gt 0 ]; then
            SCENARIO_FILES=($(printf '%s\n' "${MATCHED[@]}" | sort -u))
            echo "Changed-file targeting: ${#SCENARIO_FILES[@]} scenario(s) selected"
            for sf in "${SCENARIO_FILES[@]}"; do
                echo "  $(basename "$sf")"
            done
        else
            echo "Changed-file targeting: no matching scenarios found, falling back to all"
        fi
    else
        echo "Changed-file targeting: no changed files detected, falling back to all"
    fi
fi

UNIT_EXIT=0
INTEG_EXIT=0

echo ""
echo "=== Unit Tests ==="
if [ ${#SCENARIO_FILES[@]} -gt 0 ]; then
    $HARNESS --plugin-dir "$PLUGIN_DIR" --unit-only $FLAGS \
        "${SCENARIO_FILES[@]}" || UNIT_EXIT=$?
else
    $HARNESS --plugin-dir "$PLUGIN_DIR" --unit-only $FLAGS \
        "$SCENARIOS"/unit-*.yaml || UNIT_EXIT=$?
fi

if ! $UNIT_ONLY; then
    # Check if any integration test files exist
    INTEG_FILES=("$SCENARIOS"/integ-*.yaml)
    if [ -e "${INTEG_FILES[0]}" ]; then
        echo ""
        echo "=== Integration Tests ==="
        $HARNESS --plugin-dir "$PLUGIN_DIR" $FLAGS "${INTEG_FILES[@]}" || INTEG_EXIT=$?
    else
        echo ""
        echo "=== Integration Tests ==="
        echo "(no integration test scenarios found)"
    fi
fi

# Exit with failure if either section failed
if [ "$UNIT_EXIT" -ne 0 ] || [ "$INTEG_EXIT" -ne 0 ]; then
    exit 1
fi
