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

echo ""
echo "=== Unit Tests ==="
$HARNESS --plugin-dir "$PLUGIN_DIR" --unit-only $FLAGS \
    "$SCENARIOS"/unit-*.yaml

if ! $UNIT_ONLY; then
    echo ""
    echo "=== Integration Tests ==="
    $HARNESS --plugin-dir "$PLUGIN_DIR" $FLAGS \
        "$SCENARIOS"/gate-enforcement.yaml \
        "$SCENARIOS"/dismiss-gate.yaml \
        "$SCENARIOS"/full-lifecycle.yaml
fi
