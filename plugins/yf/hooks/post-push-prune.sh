#!/bin/bash
# post-push-prune.sh — PostToolUse hook: global task pruning after push
#
# Sequence: code push completed → prune stale tasks
# This ensures code is safely upstream before cleanup.
set -uo pipefail

# ── Enabled guard ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0
yf_is_prune_on_push 2>/dev/null || exit 0

# ── Prune stale tasks ────────────────────────────────────────────────
bash "$SCRIPT_DIR/scripts/plan-prune.sh" global 2>&1 || true

exit 0
