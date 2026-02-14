#!/bin/bash
# install-beads-push-hook.sh — Install pre-push hook that auto-pushes beads-sync
#
# Idempotent installer: appends to existing .git/hooks/pre-push if present,
# creates it otherwise. Uses sentinel markers for detection.
#
# The hook auto-pushes the beads-sync branch alongside whatever branch the user
# is pushing. Fail-open: always exits 0, even if the beads-sync push fails.
#
# Usage:
#   bash install-beads-push-hook.sh [project-dir]
#
# Compatible with bash 3.2+ (macOS default).
# Always exits 0 (fail-open).
set -uo pipefail

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-.}}"
GIT_DIR="$PROJECT_DIR/.git"
HOOKS_DIR="$GIT_DIR/hooks"
HOOK_FILE="$HOOKS_DIR/pre-push"

SENTINEL="# --- BEADS-SYNC-PUSH ---"

# Guard: must be a git repo
if [ ! -d "$GIT_DIR" ]; then
  echo "install-beads-push-hook: not a git repo, skipping" >&2
  exit 0
fi

# Guard: already installed
if [ -f "$HOOK_FILE" ] && grep -qF "$SENTINEL" "$HOOK_FILE"; then
  echo "install-beads-push-hook: already installed"
  exit 0
fi

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

# The hook snippet
HOOK_SNIPPET="
$SENTINEL
# Auto-push beads-sync branch when pushing any branch.
# Fail-open: beads-sync push failure does not block the main push.
_beads_sync_push() {
  local remote=\"\$1\"
  local sync_branch=\"beads-sync\"

  # Only act if beads-sync branch exists locally
  if ! git rev-parse --verify \"\$sync_branch\" >/dev/null 2>&1; then
    return 0
  fi

  # Check if remote has the branch — compare refs
  local local_ref remote_ref
  local_ref=\$(git rev-parse \"\$sync_branch\" 2>/dev/null)
  remote_ref=\$(git rev-parse \"refs/remotes/\$remote/\$sync_branch\" 2>/dev/null || echo \"\")

  if [ \"\$local_ref\" != \"\$remote_ref\" ]; then
    git push \"\$remote\" \"\$sync_branch\" >/dev/null 2>&1 || true
  fi
}
_beads_sync_push \"\$1\"
$SENTINEL"

if [ -f "$HOOK_FILE" ]; then
  # Append to existing hook
  printf '%s\n' "$HOOK_SNIPPET" >> "$HOOK_FILE"
  echo "install-beads-push-hook: appended to existing pre-push hook"
else
  # Create new hook
  printf '#!/bin/bash\n%s\n' "$HOOK_SNIPPET" > "$HOOK_FILE"
  echo "install-beads-push-hook: created pre-push hook"
fi

chmod +x "$HOOK_FILE"
exit 0
