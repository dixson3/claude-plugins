#!/bin/bash
# setup-project.sh — Manage .gitignore sentinel block
#
# Maintains a sentinel-bracketed block of .gitignore entries for yf ephemeral
# files.
#
# Usage:
#   bash setup-project.sh gitignore   # manage .gitignore only
#   bash setup-project.sh all         # same (default)
#
# Compatible with bash 3.2+ (macOS default).
# Always exits 0 (fail-open).
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (required)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# --- Guard: yf must be enabled ---
yf_is_enabled || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

GITIGNORE="$PROJECT_DIR/.gitignore"

SENTINEL_START="# >>> yf-managed >>>"
SENTINEL_END="# <<< yf-managed <<<"

# The managed block content (without sentinels)
MANAGED_BLOCK='# Plugin-managed rule symlinks
.claude/rules/yf/'

# Full block with sentinels
FULL_BLOCK="$SENTINEL_START
$MANAGED_BLOCK
$SENTINEL_END"

# --- Gitignore management ---
manage_gitignore() {
  if [ ! -f "$GITIGNORE" ]; then
    # No .gitignore — create with managed block
    printf '%s\n' "$FULL_BLOCK" > "$GITIGNORE"
    echo "setup-project: created .gitignore with yf-managed block"
    return 0
  fi

  # Check for existing sentinel block
  if grep -qF "$SENTINEL_START" "$GITIGNORE"; then
    # Extract existing block and compare
    EXISTING=$(awk "/$SENTINEL_START/,/$SENTINEL_END/" "$GITIGNORE")
    if [ "$EXISTING" = "$FULL_BLOCK" ]; then
      echo "setup-project: .gitignore up to date"
      return 0
    fi

    # Replace existing block: concat before + new block + after
    {
      # Lines before sentinel start
      awk -v start="$SENTINEL_START" '$0 == start { exit } { print }' "$GITIGNORE"
      # New block
      printf '%s\n' "$FULL_BLOCK"
      # Lines after sentinel end
      awk -v end="$SENTINEL_END" 'found { print } $0 == end { found=1 }' "$GITIGNORE"
    } > "$GITIGNORE.tmp"
    mv "$GITIGNORE.tmp" "$GITIGNORE"
    echo "setup-project: updated .gitignore yf-managed block"
    return 0
  fi

  # No sentinel — append block at end
  printf '\n%s\n' "$FULL_BLOCK" >> "$GITIGNORE"
  echo "setup-project: appended yf-managed block to .gitignore"
  return 0
}

# --- Main ---
manage_gitignore

exit 0
