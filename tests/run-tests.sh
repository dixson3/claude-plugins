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
for arg in "$@"; do
    case "$arg" in
        --unit-only) UNIT_ONLY=true ;;
        --verbose)   VERBOSE=true ;;
        --keep)      KEEP=true ;;
    esac
done

FLAGS=""
if $VERBOSE; then FLAGS="$FLAGS --verbose"; fi
if $KEEP; then FLAGS="$FLAGS --keep"; fi

UNIT_EXIT=0
INTEG_EXIT=0

echo ""
echo "=== Unit Tests ==="
$HARNESS --plugin-dir "$PLUGIN_DIR" --unit-only $FLAGS \
    "$SCENARIOS"/unit-*.yaml || UNIT_EXIT=$?

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
