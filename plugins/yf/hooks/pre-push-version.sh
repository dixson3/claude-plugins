#!/usr/bin/env bash
# pre-push-version.sh — PreToolUse hook: block git push when plugin code changed without version bump
#
# Blocks push (exit 2) when:
#   Plugin code changed between HEAD and origin/main AND version is unchanged.
#
# Compatible with bash 3.2+ (macOS default).
# Fail-open on guard failures (exit 0).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh"

# --- Guards: fail-open if yf disabled ---
yf_is_enabled || exit 0

# --- Determine comparison ref ---
TRACKING_BRANCH=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
if [ -z "$TRACKING_BRANCH" ]; then
  TRACKING_BRANCH="origin/main"
fi

# Fail-open if remote ref doesn't exist (first push, no remote)
git rev-parse "$TRACKING_BRANCH" >/dev/null 2>&1 || exit 0

# --- Read local version ---
PLUGIN_JSON="plugins/yf/.claude-plugin/plugin.json"
LOCAL_VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "")
[ -z "$LOCAL_VERSION" ] && exit 0  # fail-open

# --- Read remote version ---
REMOTE_VERSION=$(git show "${TRACKING_BRANCH}:${PLUGIN_JSON}" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
[ -z "$REMOTE_VERSION" ] && exit 0  # fail-open (new file, no remote copy)

# --- If version already bumped, allow ---
if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
  exit 0
fi

# --- Check for plugin code changes ---
# Include paths that warrant a version bump
INCLUDE_PATHS=(
  "plugins/yf/scripts/"
  "plugins/yf/hooks/"
  "plugins/yf/skills/"
  "plugins/yf/agents/"
  "plugins/yf/rules/"
  "plugins/yf/formulas/"
  "plugins/yf/.claude-plugin/"
)

# Get all changed files between HEAD and remote
CHANGED_FILES=$(git diff --name-only "${TRACKING_BRANCH}...HEAD" -- "${INCLUDE_PATHS[@]}" 2>/dev/null || echo "")
[ -z "$CHANGED_FILES" ] && exit 0  # no plugin changes

# --- Filter out excluded paths ---
CODE_CHANGES=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  # Exclude docs within plugin dir
  case "$file" in
    plugins/yf/README.md|plugins/yf/DEVELOPERS.md) continue ;;
  esac
  CODE_CHANGES="${CODE_CHANGES}${file}"$'\n'
done <<< "$CHANGED_FILES"

# Trim trailing newline and check
CODE_CHANGES="${CODE_CHANGES%$'\n'}"
[ -z "$CODE_CHANGES" ] && exit 0

# --- Block: plugin code changed but version not bumped ---
CHANGE_COUNT=$(echo "$CODE_CHANGES" | grep -c '.' 2>/dev/null || echo "0")

echo ""
echo "VERSION-CHECK: Push blocked — plugin code changed without version bump"
echo ""
echo "  Version: $LOCAL_VERSION (unchanged from $TRACKING_BRANCH)"
echo "  Changed plugin files: $CHANGE_COUNT"
echo ""
# Show up to 10 files
SHOWN=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  echo "    $file"
  SHOWN=$((SHOWN + 1))
  if [ "$SHOWN" -ge 10 ]; then
    REMAINING=$((CHANGE_COUNT - 10))
    if [ "$REMAINING" -gt 0 ]; then
      echo "    ... and $REMAINING more"
    fi
    break
  fi
done <<< "$CODE_CHANGES"
echo ""
echo "  Action: bash scripts/bump-version.sh <new-version>"
echo "  Or run /yf:session_land which will prompt for the version."
echo ""

exit 2
