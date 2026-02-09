#!/bin/bash
# preflight-wrapper.sh — SessionStart hook that triggers plugin preflight
#
# Resolves the plugin root and calls the self-contained preflight sync.
# Fail-open: exits 0 even if preflight fails.
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PLUGIN_ROOT/scripts/plugin-preflight.sh" 2>&1 || true
