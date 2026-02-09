#!/bin/bash
# yf-config.sh — Shared config library for Yoshiko Flow
#
# Sourceable shell library (bash 3.2 compatible) providing config access
# with two-file merge semantics: yf.json (committed) + yf.local.json (gitignored).
# Local keys always win on merge.
#
# Usage:
#   . "$SCRIPT_DIR/yf-config.sh"
#   yf_is_enabled || exit 0
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")

_YF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
_YF_JSON="$_YF_PROJECT_DIR/.claude/yf.json"
_YF_LOCAL_JSON="$_YF_PROJECT_DIR/.claude/yf.local.json"

# yf_config_exists — returns 0 if either config file exists
yf_config_exists() {
  [ -f "$_YF_JSON" ] || [ -f "$_YF_LOCAL_JSON" ]
}

# yf_merged_config — prints merged JSON to stdout
# Merge semantics: yf.json * yf.local.json (local keys win via jq recursive merge)
yf_merged_config() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "{}"
    return 0
  fi
  if [ -f "$_YF_JSON" ] && [ -f "$_YF_LOCAL_JSON" ]; then
    jq -s '.[0] * .[1]' "$_YF_JSON" "$_YF_LOCAL_JSON" 2>/dev/null || echo "{}"
  elif [ -f "$_YF_JSON" ]; then
    cat "$_YF_JSON"
  elif [ -f "$_YF_LOCAL_JSON" ]; then
    cat "$_YF_LOCAL_JSON"
  else
    echo "{}"
  fi
}

# yf_read_field EXPR — runs jq expression on merged config
yf_read_field() {
  yf_merged_config | jq -r "$1" 2>/dev/null
}

# yf_is_enabled — returns 0 if enabled, 1 if disabled
yf_is_enabled() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0  # fail-open
  fi
  if ! yf_config_exists; then
    return 0  # no config = enabled by default
  fi
  local val
  val=$(yf_merged_config | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
  [ "$val" != "false" ]
}

# yf_is_chronicler_on — returns 0 if chronicler enabled, 1 if disabled
yf_is_chronicler_on() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0  # fail-open
  fi
  if ! yf_config_exists; then
    return 0  # no config = enabled by default
  fi
  local val
  val=$(yf_merged_config | jq -r 'if .config.chronicler_enabled == null then true else .config.chronicler_enabled end' 2>/dev/null)
  [ "$val" != "false" ]
}
