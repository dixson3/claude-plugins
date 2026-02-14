#!/bin/bash
# setup-project.sh — Manage .gitignore sentinel block and AGENTS.md cleanup
#
# Maintains a sentinel-bracketed block of .gitignore entries for yf ephemeral
# files, and removes conflicting bd init / bd onboard content from AGENTS.md.
#
# Usage:
#   bash setup-project.sh gitignore   # manage .gitignore only
#   bash setup-project.sh agents      # cleanup AGENTS.md only
#   bash setup-project.sh all         # both (default)
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
MODE="${1:-all}"

GITIGNORE="$PROJECT_DIR/.gitignore"
AGENTSMD="$PROJECT_DIR/AGENTS.md"

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

# --- AGENTS.md cleanup ---
cleanup_agents() {
  if [ ! -f "$AGENTSMD" ]; then
    echo "setup-project: no AGENTS.md, skipping"
    return 0
  fi

  # Check if the file starts with "# Agent Instructions" (bd init content)
  if ! head -1 "$AGENTSMD" | grep -q "^# Agent Instructions"; then
    # Not bd-generated content — check for bd onboard sections
    if grep -q "^## Issue Tracking" "$AGENTSMD" || grep -q "^## Quick Reference" "$AGENTSMD"; then
      # Mixed content — remove bd sections using awk
      # Remove sections: "## Quick Reference", "## Landing the Plane", "## Issue Tracking"
      awk '
        /^## (Quick Reference|Landing the Plane|Issue Tracking)/ { skip=1; next }
        /^## / && skip { skip=0 }
        /^# / && skip { skip=0 }
        !skip { print }
      ' "$AGENTSMD" > "$AGENTSMD.tmp"

      # Check if result is whitespace-only
      if ! grep -q '[^[:space:]]' "$AGENTSMD.tmp"; then
        rm -f "$AGENTSMD" "$AGENTSMD.tmp"
        echo "setup-project: removed AGENTS.md (only bd content)"
        return 0
      fi

      mv "$AGENTSMD.tmp" "$AGENTSMD"
      echo "setup-project: cleaned bd sections from AGENTS.md"
      return 0
    fi

    echo "setup-project: AGENTS.md has no bd content, skipping"
    return 0
  fi

  # File starts with "# Agent Instructions" — check if it's entirely bd content
  # bd init creates: # Agent Instructions, ## Quick Reference, ## Landing the Plane
  # bd onboard adds: ## Issue Tracking
  # Check for any non-bd headings (anything other than known bd sections)
  NON_BD_HEADINGS=$(awk '
    /^# Agent Instructions/ { next }
    /^## Quick Reference/ { next }
    /^## Landing the Plane/ { next }
    /^## Issue Tracking/ { next }
    /^##? / { print; found=1 }
  ' "$AGENTSMD")

  if [ -z "$NON_BD_HEADINGS" ]; then
    # Entirely bd content — delete the file
    rm -f "$AGENTSMD"
    echo "setup-project: removed AGENTS.md (bd-only content)"
    return 0
  fi

  # Mixed content starting with "# Agent Instructions" — remove bd sections, keep rest
  awk '
    /^# Agent Instructions/ { skip=1; next }
    /^## (Quick Reference|Landing the Plane|Issue Tracking)/ { skip=1; next }
    /^## / && skip { skip=0 }
    /^# / && skip { skip=0 }
    !skip { print }
  ' "$AGENTSMD" > "$AGENTSMD.tmp"

  # Check if result is whitespace-only
  if ! grep -q '[^[:space:]]' "$AGENTSMD.tmp"; then
    rm -f "$AGENTSMD" "$AGENTSMD.tmp"
    echo "setup-project: removed AGENTS.md (only bd content)"
    return 0
  fi

  mv "$AGENTSMD.tmp" "$AGENTSMD"
  echo "setup-project: cleaned bd sections from AGENTS.md"
  return 0
}

# --- Main ---
case "$MODE" in
  gitignore)
    manage_gitignore
    ;;
  agents)
    cleanup_agents
    ;;
  all)
    manage_gitignore
    cleanup_agents
    ;;
  *)
    echo "setup-project: unknown mode: $MODE (expected: gitignore, agents, all)" >&2
    ;;
esac

exit 0
