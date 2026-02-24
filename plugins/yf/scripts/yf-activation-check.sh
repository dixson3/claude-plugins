#!/bin/bash
# yf-activation-check.sh — Standalone activation check for skill gating
#
# Outputs structured JSON:
#   {"active":true}  — all conditions pass
#   {"active":false,"reason":"...","action":"..."}  — specific failure
#
# Always exits 0. Caller reads JSON output.
#
# Two conditions (DD-015):
#   1. .yoshiko-flow/config.json exists
#   2. enabled != false
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# Check condition 1: config exists
if ! yf_config_exists; then
  echo '{"active":false,"reason":"No .yoshiko-flow/config.json found","action":"Run /yf:plugin_setup to configure this project"}'
  exit 0
fi

# Check condition 2: enabled != false
if command -v jq >/dev/null 2>&1; then
  val=$(yf_merged_config | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
  if [ "$val" = "false" ]; then
    echo '{"active":false,"reason":"Plugin is disabled in config","action":"Run /yf:plugin_setup to reactivate"}'
    exit 0
  fi
fi

# All conditions pass
echo '{"active":true}'
