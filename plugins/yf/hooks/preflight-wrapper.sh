#!/bin/bash
# preflight-wrapper.sh — SessionStart hook that triggers plugin preflight
#
# Resolves the marketplace root and calls the preflight sync engine.
# Fail-open: exits 0 even if preflight fails.
MARKETPLACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$MARKETPLACE_ROOT/scripts/plugin-preflight.sh" 2>&1 || true
