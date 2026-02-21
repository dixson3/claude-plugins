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

# yf_bd_available — returns 0 if bd CLI is available
yf_bd_available() {
  command -v bd >/dev/null 2>&1
}

# yf_is_enabled — returns 0 if enabled, 1 if disabled
# Three-condition activation gate (DD-015):
#   1. Config exists
#   2. enabled != false
#   3. bd CLI available
yf_is_enabled() {
  yf_config_exists || return 1
  if command -v jq >/dev/null 2>&1; then
    local val
    val=$(yf_merged_config | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
    [ "$val" = "false" ] && return 1
  fi
  yf_bd_available || return 1
  return 0
}

# yf_is_prune_on_complete — returns 0 if plan-completion pruning enabled
yf_is_prune_on_complete() { _yf_check_flag '.config.auto_prune.on_plan_complete'; }

# yf_is_prune_on_push — returns 0 if post-push pruning enabled
yf_is_prune_on_push() { _yf_check_flag '.config.auto_prune.on_push'; }

# yf_is_prune_on_session_close — returns 0 if session-close pruning enabled
yf_is_prune_on_session_close() { _yf_check_flag '.config.auto_prune.on_session_close'; }

# yf_sanity_check_mode — returns sanity check mode (blocking|advisory|disabled)
yf_sanity_check_mode() {
  local mode
  mode=$(yf_read_field '.config.engineer.sanity_check_mode' 2>/dev/null)
  if [ -z "$mode" ] || [ "$mode" = "null" ]; then
    echo "blocking"
  else
    echo "$mode"
  fi
}

# yf_plugin_repo — returns plugin repo slug (default: dixson3/d3-claude-plugins)
yf_plugin_repo() {
  local repo
  repo=$(yf_read_field '.config.plugin_repo' 2>/dev/null)
  if [ -z "$repo" ] || [ "$repo" = "null" ]; then
    echo "dixson3/d3-claude-plugins"
  else
    echo "$repo"
  fi
}

# yf_project_tracker — returns project tracker type (github|gitlab|file|auto)
yf_project_tracker() {
  local tracker
  tracker=$(yf_read_field '.config.project_tracking.tracker' 2>/dev/null)
  if [ -z "$tracker" ] || [ "$tracker" = "null" ]; then
    echo "auto"
  else
    echo "$tracker"
  fi
}

# yf_project_slug — returns project owner/repo slug
yf_project_slug() {
  local slug
  slug=$(yf_read_field '.config.project_tracking.project' 2>/dev/null)
  if [ -z "$slug" ] || [ "$slug" = "null" ]; then
    echo ""
  else
    echo "$slug"
  fi
}

# yf_tracker_tool — returns tracker CLI tool override (gh|glab)
yf_tracker_tool() {
  local tool
  tool=$(yf_read_field '.config.project_tracking.tracker_tool' 2>/dev/null)
  if [ -z "$tool" ] || [ "$tool" = "null" ]; then
    echo ""
  else
    echo "$tool"
  fi
}
