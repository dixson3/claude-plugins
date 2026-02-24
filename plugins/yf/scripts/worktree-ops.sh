#!/bin/bash
# worktree-ops.sh — Epic worktree lifecycle operations
#
# Core script for creating, validating, rebasing, and landing worktrees
# used for epic-scoped development branches.
#
# Usage:
#   worktree-ops.sh create <base-branch> <epic-name>
#   worktree-ops.sh validate <worktree-path>
#   worktree-ops.sh rebase <worktree-path> <base-branch>
#   worktree-ops.sh land <worktree-path> <base-branch>
#
# Exit codes:
#   0 — success
#   1 — error (details in JSON output)
#
# Compatible with bash 3.2+ (macOS default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ACTION="${1:-}"
shift || true

# --- JSON output helpers ---
json_ok() {
  echo "{\"status\":\"ok\"$1}"
}

json_err() {
  echo "{\"status\":\"error\",\"message\":\"$1\"}"
  exit 1
}

# --- create <base-branch> <epic-name> ---
do_create() {
  local base="${1:-}"
  local epic="${2:-}"

  if [ -z "$base" ] || [ -z "$epic" ]; then
    json_err "Usage: worktree-ops.sh create <base-branch> <epic-name>"
  fi

  local branch="${base}/${epic}"
  local wt_dir="$PROJECT_DIR/.claude/worktrees/${base}-${epic}"

  # Check if worktree already exists
  if [ -d "$wt_dir" ]; then
    json_err "Worktree already exists at $wt_dir"
  fi

  # Check if branch already exists
  if git -C "$PROJECT_DIR" rev-parse --verify "$branch" >/dev/null 2>&1; then
    json_err "Branch $branch already exists"
  fi

  # Create worktree with new branch
  mkdir -p "$(dirname "$wt_dir")"
  git -C "$PROJECT_DIR" worktree add -b "$branch" "$wt_dir" "$base" 2>/dev/null || {
    json_err "Failed to create worktree"
  }

  # Ensure .yoshiko-flow/ exists in worktree if yf is active in main repo
  if [ -d "$PROJECT_DIR/.yoshiko-flow" ]; then
    mkdir -p "$wt_dir/.yoshiko-flow"
  fi

  json_ok ",\"branch\":\"$branch\",\"worktree\":\"$wt_dir\""
}

# --- validate <worktree-path> ---
do_validate() {
  local wt_path="${1:-}"

  if [ -z "$wt_path" ]; then
    json_err "Usage: worktree-ops.sh validate <worktree-path>"
  fi

  if [ ! -d "$wt_path" ]; then
    json_err "Worktree path does not exist: $wt_path"
  fi

  local issues=""
  local pass=true

  # Check for clean working tree
  local status
  status=$(git -C "$wt_path" status --porcelain 2>/dev/null)
  if [ -n "$status" ]; then
    pass=false
    issues="${issues}uncommitted changes, "
  fi

  # Run tests if test runner exists
  local test_result="skipped"
  if [ -f "$wt_path/tests/run-tests.sh" ]; then
    if (cd "$wt_path" && bash tests/run-tests.sh --unit-only) >/dev/null 2>&1; then
      test_result="pass"
    else
      pass=false
      test_result="fail"
      issues="${issues}tests failed, "
    fi
  fi

  # Trim trailing ", "
  issues="${issues%, }"

  if $pass; then
    json_ok ",\"tests\":\"$test_result\""
  else
    echo "{\"status\":\"fail\",\"tests\":\"$test_result\",\"issues\":\"$issues\"}"
    exit 1
  fi
}

# --- rebase <worktree-path> <base-branch> ---
do_rebase() {
  local wt_path="${1:-}"
  local base="${2:-}"

  if [ -z "$wt_path" ] || [ -z "$base" ]; then
    json_err "Usage: worktree-ops.sh rebase <worktree-path> <base-branch>"
  fi

  if [ ! -d "$wt_path" ]; then
    json_err "Worktree path does not exist: $wt_path"
  fi

  # Attempt rebase
  local rebase_output
  if rebase_output=$(git -C "$wt_path" rebase "$base" 2>&1); then
    json_ok ",\"rebased_onto\":\"$base\""
  else
    # Conflict detected — collect conflict files and abort
    local conflict_files
    conflict_files=$(git -C "$wt_path" diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    git -C "$wt_path" rebase --abort 2>/dev/null || true

    echo "{\"status\":\"conflict\",\"base\":\"$base\",\"conflict_files\":\"$conflict_files\"}"
    exit 1
  fi
}

# --- land <worktree-path> <base-branch> ---
do_land() {
  local wt_path="${1:-}"
  local base="${2:-}"

  if [ -z "$wt_path" ] || [ -z "$base" ]; then
    json_err "Usage: worktree-ops.sh land <worktree-path> <base-branch>"
  fi

  if [ ! -d "$wt_path" ]; then
    json_err "Worktree path does not exist: $wt_path"
  fi

  # Get the branch name from the worktree
  local branch
  branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    json_err "Cannot determine branch for worktree"
  }

  # Fast-forward merge only (rebase must have been done first)
  local merge_output
  if merge_output=$(git -C "$PROJECT_DIR" merge --ff-only "$branch" 2>&1); then
    # Clean up: remove worktree and branch
    git -C "$PROJECT_DIR" worktree remove "$wt_path" 2>/dev/null || rm -rf "$wt_path"
    git -C "$PROJECT_DIR" branch -d "$branch" 2>/dev/null || true

    json_ok ",\"merged_branch\":\"$branch\",\"into\":\"$base\""
  else
    echo "{\"status\":\"error\",\"message\":\"Not fast-forwardable. Run rebase first.\",\"branch\":\"$branch\",\"base\":\"$base\"}"
    exit 1
  fi
}

# --- Dispatch ---
case "$ACTION" in
  create)   do_create "$@" ;;
  validate) do_validate "$@" ;;
  rebase)   do_rebase "$@" ;;
  land)     do_land "$@" ;;
  *)
    echo "Usage: worktree-ops.sh <create|validate|rebase|land> [args...]" >&2
    exit 1
    ;;
esac
