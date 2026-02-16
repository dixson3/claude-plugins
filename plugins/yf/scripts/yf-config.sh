#!/bin/bash
# yf-config.sh — Shared config library for Yoshiko Flow
#
# Sourceable shell library (bash 3.2 compatible) providing config access.
# Config: .yoshiko-flow/config.json (committed to git).
#
# Usage:
#   . "$SCRIPT_DIR/yf-config.sh"
#   yf_is_enabled || exit 0
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")

_YF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
_YF_JSON="$_YF_PROJECT_DIR/.yoshiko-flow/config.json"

# yf_config_exists — returns 0 if config file exists
yf_config_exists() {
  [ -f "$_YF_JSON" ]
}

# yf_merged_config — prints config JSON to stdout
yf_merged_config() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "{}"
    return 0
  fi
  if [ -f "$_YF_JSON" ]; then
    cat "$_YF_JSON"
  else
    echo "{}"
  fi
}

# yf_read_field EXPR — runs jq expression on merged config
yf_read_field() {
  yf_merged_config | jq -r "$1" 2>/dev/null
}

# _yf_check_flag JQ_EXPR — generic boolean flag checker (fail-open)
_yf_check_flag() {
  local expr="$1"
  if ! command -v jq >/dev/null 2>&1; then
    return 0  # fail-open
  fi
  if ! yf_config_exists; then
    return 0  # no config = enabled by default
  fi
  local val
  val=$(yf_merged_config | jq -r "if $expr == null then true else $expr end" 2>/dev/null)
  [ "$val" != "false" ]
}

# yf_is_enabled — returns 0 if enabled, 1 if disabled
yf_is_enabled() { _yf_check_flag '.enabled'; }

# yf_is_prune_on_complete — returns 0 if plan-completion pruning enabled
yf_is_prune_on_complete() { _yf_check_flag '.config.auto_prune.on_plan_complete'; }

# yf_is_prune_on_push — returns 0 if post-push pruning enabled
yf_is_prune_on_push() { _yf_check_flag '.config.auto_prune.on_push'; }

# yf_is_prune_on_session_close — returns 0 if session-close pruning enabled
yf_is_prune_on_session_close() { _yf_check_flag '.config.auto_prune.on_session_close'; }
