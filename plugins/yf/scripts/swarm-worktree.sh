#!/bin/bash
# swarm-worktree.sh — Helper for swarm worktree isolation
#
# Manages worktree setup, merge-back, cleanup, and conflict detection
# for swarm agents running in isolated worktrees via Claude Code's
# `isolation: "worktree"` Task parameter.
#
# Usage:
#   swarm-worktree.sh setup <worktree-path>
#   swarm-worktree.sh merge <worktree-path>
#   swarm-worktree.sh cleanup <worktree-path>
#   swarm-worktree.sh conflict-files <worktree-path>
#
# Exit codes:
#   0 — success
#   1 — error or conflict (details in JSON output)
#
# Compatible with bash 3.2+ (macOS default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ACTION="${1:-}"
shift || true

# --- setup <worktree-path> ---
# Run plugin-preflight in worktree context to establish .yoshiko-flow
do_setup() {
  local wt_path="${1:-}"

  if [ -z "$wt_path" ]; then
    echo '{"status":"error","message":"Usage: swarm-worktree.sh setup <worktree-path>"}'
    exit 1
  fi

  if [ ! -d "$wt_path" ]; then
    echo '{"status":"error","message":"Worktree path does not exist"}'
    exit 1
  fi

  # Create .yoshiko-flow directories in worktree
  mkdir -p "$wt_path/.yoshiko-flow/tasks" \
           "$wt_path/.yoshiko-flow/chronicler" \
           "$wt_path/.yoshiko-flow/archivist" \
           "$wt_path/.yoshiko-flow/issues" \
           "$wt_path/.yoshiko-flow/todos" \
           "$wt_path/.yoshiko-flow/molecules" 2>/dev/null || true

  # Run plugin-preflight with worktree as project dir
  local setup_out
  setup_out=$(CLAUDE_PROJECT_DIR="$wt_path" bash "$SCRIPT_DIR/plugin-preflight.sh" 2>&1) || true

  # Check if .yoshiko-flow was created
  if [ -d "$wt_path/.yoshiko-flow" ]; then
    echo '{"status":"ok","yf_setup":true}'
  else
    echo "{\"status\":\"ok\",\"yf_setup\":false,\"setup_output\":\"$setup_out\"}"
  fi
}

# --- merge <worktree-path> ---
# Rebase worktree branch onto current HEAD with -X theirs strategy
do_merge() {
  local wt_path="${1:-}"

  if [ -z "$wt_path" ]; then
    echo '{"status":"error","message":"Usage: swarm-worktree.sh merge <worktree-path>"}'
    exit 1
  fi

  if [ ! -d "$wt_path" ]; then
    echo '{"status":"error","message":"Worktree path does not exist"}'
    exit 1
  fi

  # Get worktree branch name
  local branch
  branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo '{"status":"error","message":"Cannot determine worktree branch"}'
    exit 1
  }

  # Get current main branch HEAD
  local main_branch
  main_branch=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo '{"status":"error","message":"Cannot determine main branch"}'
    exit 1
  }

  # Attempt rebase with -X theirs (accept agent's version on conflicts)
  local rebase_out
  if rebase_out=$(git -C "$wt_path" rebase -X theirs "$main_branch" 2>&1); then
    # Rebase succeeded — fast-forward merge into main
    local merge_out
    if merge_out=$(git -C "$PROJECT_DIR" merge --ff-only "$branch" 2>&1); then
      echo "{\"status\":\"ok\",\"branch\":\"$branch\",\"merged_into\":\"$main_branch\"}"
    else
      echo "{\"status\":\"error\",\"message\":\"Fast-forward merge failed after rebase\",\"branch\":\"$branch\"}"
      exit 1
    fi
  else
    # -X theirs failed (e.g., deleted-vs-modified conflict)
    # Collect conflict files for Claude-driven resolution
    local conflict_files
    conflict_files=$(git -C "$wt_path" diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ',' | sed 's/,$//')

    if [ -n "$conflict_files" ]; then
      echo "{\"status\":\"conflict\",\"strategy\":\"theirs\",\"branch\":\"$branch\",\"conflict_files\":\"$conflict_files\"}"
    else
      # Rebase failed but no conflict markers — abort and report
      git -C "$wt_path" rebase --abort 2>/dev/null || true
      echo "{\"status\":\"error\",\"message\":\"Rebase failed without conflict markers\",\"output\":\"$(echo "$rebase_out" | head -5)\"}"
    fi
    exit 1
  fi
}

# --- cleanup <worktree-path> ---
# Remove worktree and delete its branch
do_cleanup() {
  local wt_path="${1:-}"

  if [ -z "$wt_path" ]; then
    echo '{"status":"error","message":"Usage: swarm-worktree.sh cleanup <worktree-path>"}'
    exit 1
  fi

  local branch=""
  if [ -d "$wt_path" ]; then
    branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch=""
  fi

  # Remove worktree
  git -C "$PROJECT_DIR" worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"

  # Delete branch if known
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    git -C "$PROJECT_DIR" branch -D "$branch" 2>/dev/null || true
  fi

  echo "{\"status\":\"ok\",\"removed\":\"$wt_path\",\"branch_deleted\":\"${branch:-unknown}\"}"
}

# --- conflict-files <worktree-path> ---
# List files with unresolved conflicts (for Claude-driven resolution)
do_conflict_files() {
  local wt_path="${1:-}"

  if [ -z "$wt_path" ]; then
    echo '{"status":"error","message":"Usage: swarm-worktree.sh conflict-files <worktree-path>"}'
    exit 1
  fi

  if [ ! -d "$wt_path" ]; then
    echo '{"status":"error","message":"Worktree path does not exist"}'
    exit 1
  fi

  local files
  files=$(git -C "$wt_path" diff --name-only --diff-filter=U 2>/dev/null)

  if [ -z "$files" ]; then
    echo '{"status":"ok","conflict_files":[]}'
  else
    # Build JSON array
    local json_arr="["
    local first=true
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if $first; then first=false; else json_arr="$json_arr,"; fi
      json_arr="$json_arr\"$f\""
    done <<< "$files"
    json_arr="$json_arr]"
    echo "{\"status\":\"conflict\",\"conflict_files\":$json_arr}"
  fi
}

# --- Dispatch ---
case "$ACTION" in
  setup)          do_setup "$@" ;;
  merge)          do_merge "$@" ;;
  cleanup)        do_cleanup "$@" ;;
  conflict-files) do_conflict_files "$@" ;;
  *)
    echo "Usage: swarm-worktree.sh <setup|merge|cleanup|conflict-files> [args...]" >&2
    exit 1
    ;;
esac
