#!/usr/bin/env bash
# worktree-remove.sh — WorktreeRemove hook: cleans up yf artifacts
#
# Fire-and-forget cleanup. Removes rule symlinks and .yoshiko-flow symlink
# from a worktree being removed. Failures only logged to stderr.
#
# Always exits 0. Compatible with bash 3.2+ (macOS default).

set -uo pipefail

# --- Read JSON from stdin ---
INPUT=$(cat)
WT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('worktree_path',''))" 2>/dev/null)

# --- Guard: exit 0 if path empty or not a directory ---
if [ -z "$WT_PATH" ] || [ ! -d "$WT_PATH" ]; then
  exit 0
fi

# --- Remove .claude/rules/yf/ symlinks ---
if [ -d "$WT_PATH/.claude/rules/yf" ]; then
  rm -rf "$WT_PATH/.claude/rules/yf" 2>/dev/null || true
  echo "worktree-remove: removed .claude/rules/yf/" >&2
fi

# --- Remove .yoshiko-flow symlink if present ---
if [ -L "$WT_PATH/.yoshiko-flow" ]; then
  rm -f "$WT_PATH/.yoshiko-flow" 2>/dev/null || true
  echo "worktree-remove: removed .yoshiko-flow symlink" >&2
fi

exit 0
