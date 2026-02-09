#!/bin/bash
# yf-config.sh — Shared config library for Yoshiko Flow
#
# Sourceable shell library (bash 3.2 compatible) providing config access.
# Config: .claude/yf.json (gitignored, local-only).
#
# Usage:
#   . "$SCRIPT_DIR/yf-config.sh"
#   yf_is_enabled || exit 0
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")

_YF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
_YF_JSON="$_YF_PROJECT_DIR/.claude/yf.json"

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

# yf_is_archivist_on — returns 0 if archivist enabled, 1 if disabled
yf_is_archivist_on() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0  # fail-open
  fi
  if ! yf_config_exists; then
    return 0  # no config = enabled by default
  fi
  local val
  val=$(yf_merged_config | jq -r 'if .config.archivist_enabled == null then true else .config.archivist_enabled end' 2>/dev/null)
  [ "$val" != "false" ]
}
