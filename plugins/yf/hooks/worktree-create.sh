#!/usr/bin/env bash
# worktree-create.sh — WorktreeCreate hook: creates git worktree with yf setup
#
# Replaces Claude Code's default git worktree creation. Reads JSON from stdin
# (name, cwd fields), creates the worktree, and prints the absolute path to
# stdout. When yf is active, also sets up .yoshiko-flow directories.
#
# Fail-hard for git worktree creation (Claude Code expects a valid path).
# Fail-open for yf setup (worktree still usable without yf artifacts).
#
# Compatible with bash 3.2+ (macOS default).

set -uo pipefail

# --- Read JSON from stdin ---
INPUT=$(cat)
NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

if [ -z "$NAME" ] || [ -z "$CWD" ]; then
  echo "worktree-create: error: missing name or cwd in input" >&2
  exit 1
fi

# --- Compute worktree path ---
WT_DIR="$CWD/.claude/worktrees/$NAME"

# --- Create git worktree ---
if [ -d "$WT_DIR" ]; then
  # Idempotent: worktree already exists at this path
  echo "worktree-create: worktree already exists at $WT_DIR" >&2
else
  mkdir -p "$(dirname "$WT_DIR")"
  if git -C "$CWD" worktree add -b "worktree/$NAME" "$WT_DIR" HEAD >&2 2>&1; then
    echo "worktree-create: created worktree with new branch worktree/$NAME" >&2
  elif git -C "$CWD" worktree add "$WT_DIR" "worktree/$NAME" >&2 2>&1; then
    echo "worktree-create: created worktree on existing branch worktree/$NAME" >&2
  else
    echo "worktree-create: error: failed to create git worktree" >&2
    exit 1
  fi
fi

# --- yf setup (fail-open) ---
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$PLUGIN_ROOT/scripts"

if [ -f "$SCRIPT_DIR/yf-config.sh" ]; then
  (
    CLAUDE_PROJECT_DIR="$CWD" . "$SCRIPT_DIR/yf-config.sh"
    if yf_is_enabled; then
      echo "worktree-create: yf active, initializing .yoshiko-flow and preflight" >&2
      mkdir -p "$WT_DIR/.yoshiko-flow"/{tasks,chronicler,archivist,issues,todos,molecules} 2>/dev/null || true
      CLAUDE_PROJECT_DIR="$WT_DIR" bash "$SCRIPT_DIR/plugin-preflight.sh" >&2 2>&1 || true
    else
      echo "worktree-create: yf inactive, skipping yf setup" >&2
    fi
  )
fi

# --- Print worktree path (only stdout output) ---
echo "$WT_DIR"
