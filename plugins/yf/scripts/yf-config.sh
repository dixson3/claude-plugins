#!/bin/bash
# yf-config.sh — Shared config library for Yoshiko Flow
#
# Sourceable shell library (bash 3.2 compatible) providing config access.
# Config: .yoshiko-flow/config.json (committed to git).
# Worktree-aware: falls back to main repo's config when in a worktree.
#
# Usage:
#   . "$SCRIPT_DIR/yf-config.sh"
#   yf_is_enabled || exit 0
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")

# --- Worktree detection helpers (defined first for config resolution) ---

# yf_main_repo_root — returns the main repo root when in a worktree, or current project dir
yf_main_repo_root() {
  local proj="${CLAUDE_PROJECT_DIR:-.}"
  local git_common git_dir
  git_common=$(cd "$proj" && git rev-parse --git-common-dir 2>/dev/null) || { echo "$proj"; return; }
  git_dir=$(cd "$proj" && git rev-parse --git-dir 2>/dev/null) || { echo "$proj"; return; }
  if [ -n "$git_common" ] && [ -n "$git_dir" ] && [ "$git_common" != "$git_dir" ]; then
    # In a worktree — resolve main repo root
    (cd "$proj" && cd "$(git rev-parse --git-common-dir)/.." && pwd)
  else
    echo "$proj"
  fi
}

# yf_is_worktree — returns 0 if currently in a git worktree, 1 otherwise
yf_is_worktree() {
  local proj="${CLAUDE_PROJECT_DIR:-.}"
  local git_common git_dir
  git_common=$(cd "$proj" && git rev-parse --git-common-dir 2>/dev/null) || return 1
  git_dir=$(cd "$proj" && git rev-parse --git-dir 2>/dev/null) || return 1
  [ -n "$git_common" ] && [ -n "$git_dir" ] && [ "$git_common" != "$git_dir" ]
}

# --- Config resolution ---

_YF_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
_YF_JSON="$_YF_PROJECT_DIR/.yoshiko-flow/config.json"

# Worktree-aware config resolution: fall back to main repo's config
if [ ! -f "$_YF_JSON" ]; then
  _YF_MAIN=$(yf_main_repo_root 2>/dev/null || echo "$_YF_PROJECT_DIR")
  [ -f "$_YF_MAIN/.yoshiko-flow/config.json" ] && _YF_JSON="$_YF_MAIN/.yoshiko-flow/config.json"
fi

# Local config overlay (gitignored, per-clone settings like operator name)
_YF_LOCAL_JSON="${_YF_JSON%.json}.local.json"
# Worktree fallback: check main repo's config.local.json too
if [ ! -f "$_YF_LOCAL_JSON" ]; then
  _YF_MAIN="${_YF_MAIN:-$(yf_main_repo_root 2>/dev/null || echo "$_YF_PROJECT_DIR")}"
  [ -f "$_YF_MAIN/.yoshiko-flow/config.local.json" ] && _YF_LOCAL_JSON="$_YF_MAIN/.yoshiko-flow/config.local.json"
fi

# --- Config access functions ---

# yf_config_exists — returns 0 if config file exists
yf_config_exists() {
  [ -f "$_YF_JSON" ]
}

# yf_merged_config — prints config JSON to stdout (deep-merges local over base)
yf_merged_config() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "{}"
    return 0
  fi
  local base="{}" local_cfg="{}"
  [ -f "$_YF_JSON" ] && base=$(cat "$_YF_JSON")
  [ -f "$_YF_LOCAL_JSON" ] && local_cfg=$(cat "$_YF_LOCAL_JSON")
  echo "$base" "$local_cfg" | jq -s '.[0] * .[1]' 2>/dev/null || echo "$base"
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
# Two-condition activation gate (DD-015):
#   1. Config exists
#   2. enabled != false
yf_is_enabled() {
  yf_config_exists || return 1
  if command -v jq >/dev/null 2>&1; then
    local val
    val=$(yf_merged_config | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
    [ "$val" = "false" ] && return 1
  fi
  return 0
}

# yf_is_prune — generic prune flag checker
yf_is_prune() { _yf_check_flag ".config.auto_prune.$1"; }

yf_is_prune_on_complete()      { yf_is_prune on_plan_complete; }
yf_is_prune_on_push()          { yf_is_prune on_push; }
yf_is_prune_on_session_close() { yf_is_prune on_session_close; }

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

# yf_operator_name — returns operator name via fallback cascade:
#   1. Merged config → .config.operator (typically from config.local.json)
#   2. plugin.json → .author.name (via CLAUDE_PLUGIN_ROOT)
#   3. git config user.name
#   4. "Unknown"
yf_operator_name() {
  local name
  # 1. Config (merged — local overrides base)
  name=$(yf_read_field '.config.operator' 2>/dev/null)
  if [ -n "$name" ] && [ "$name" != "null" ]; then
    echo "$name"
    return
  fi
  # 2. plugin.json author
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    name=$(jq -r '.author.name // empty' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
    if [ -n "$name" ]; then
      echo "$name"
      return
    fi
  fi
  # 3. git config
  name=$(git config user.name 2>/dev/null)
  if [ -n "$name" ]; then
    echo "$name"
    return
  fi
  # 4. Fallback
  echo "Unknown"
}
