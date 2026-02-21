#!/bin/bash
# tracker-detect.sh — Detect project tracker from config or git remote
#
# Outputs JSON: {"tracker":"github","project":"owner/repo","tool":"gh"}
#
# Priority:
#   1. Explicit config (config.project_tracking)
#   2. Auto-detect from git remote origin
#   3. File fallback (always available)
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")
#
# Always exits 0. Caller reads JSON output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# --- Check explicit config override ---
CONFIGURED_TRACKER=$(yf_project_tracker)
CONFIGURED_SLUG=$(yf_project_slug)
CONFIGURED_TOOL=$(yf_tracker_tool)

if [ "$CONFIGURED_TRACKER" != "auto" ]; then
  # Explicit config — use it directly
  case "$CONFIGURED_TRACKER" in
    github)
      TOOL="${CONFIGURED_TOOL:-gh}"
      if ! command -v "$TOOL" >/dev/null 2>&1; then
        # Tool not available — fall back to file
        echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
        exit 0
      fi
      echo "{\"tracker\":\"github\",\"project\":\"${CONFIGURED_SLUG}\",\"tool\":\"${TOOL}\"}"
      ;;
    gitlab)
      TOOL="${CONFIGURED_TOOL:-glab}"
      if ! command -v "$TOOL" >/dev/null 2>&1; then
        echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
        exit 0
      fi
      echo "{\"tracker\":\"gitlab\",\"project\":\"${CONFIGURED_SLUG}\",\"tool\":\"${TOOL}\"}"
      ;;
    file)
      echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
      ;;
    *)
      # Unknown tracker type — fall back to file
      echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
      ;;
  esac
  exit 0
fi

# --- Auto-detect from git remote ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
REMOTE_URL=""
if command -v git >/dev/null 2>&1; then
  REMOTE_URL=$(cd "$PROJECT_DIR" && git remote get-url origin 2>/dev/null) || REMOTE_URL=""
fi

if [ -z "$REMOTE_URL" ]; then
  echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
  exit 0
fi

# Parse owner/repo from remote URL
# Handles SSH: git@github.com:owner/repo.git
# Handles HTTPS: https://github.com/owner/repo.git
#
# Bash 3.2 compatible: uses parameter expansion instead of sed -E
_extract_slug() {
  local url="$1" host="$2"
  # Strip .git suffix
  url="${url%.git}"
  # Strip everything up to and including the host + separator (: or /)
  case "$url" in
    *"${host}:"*) url="${url##*${host}:}" ;;
    *"${host}/"*) url="${url##*${host}/}" ;;
    *) return 1 ;;
  esac
  echo "$url"
}

SLUG=""
case "$REMOTE_URL" in
  *github.com*)
    SLUG=$(_extract_slug "$REMOTE_URL" "github.com") || SLUG=""
    if [ -n "$SLUG" ] && command -v gh >/dev/null 2>&1; then
      echo "{\"tracker\":\"github\",\"project\":\"${SLUG}\",\"tool\":\"gh\"}"
      exit 0
    fi
    ;;
  *gitlab.com*)
    SLUG=$(_extract_slug "$REMOTE_URL" "gitlab.com") || SLUG=""
    if [ -n "$SLUG" ] && command -v glab >/dev/null 2>&1; then
      echo "{\"tracker\":\"gitlab\",\"project\":\"${SLUG}\",\"tool\":\"glab\"}"
      exit 0
    fi
    ;;
esac

# --- File fallback ---
echo "{\"tracker\":\"file\",\"project\":\"local\",\"tool\":\"\"}"
