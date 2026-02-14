#!/bin/bash
# post-push-prune.sh — PostToolUse hook: global bead pruning after push
#
# Sequence: code push completed → prune stale beads → bd sync (pushes pruned state to beads-sync)
# This ensures code is safely upstream before cleanup, and beads-sync reflects the pruned database.
set -uo pipefail

# ── Enabled guard ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"
yf_is_enabled || exit 0
yf_is_prune_on_push 2>/dev/null || exit 0

# ── bd guard ──────────────────────────────────────────────────────────
command -v bd >/dev/null 2>&1 || exit 0

# ── Step 1: Prune stale beads ────────────────────────────────────────
bash "$SCRIPT_DIR/scripts/plan-prune.sh" global 2>&1 || true

# ── Step 2: Sync pruned state to beads-sync branch ───────────────────
bd sync 2>/dev/null || true

exit 0
