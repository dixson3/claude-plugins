#!/bin/bash
# beads-setup.sh — Initialize and validate beads-cli setup for a project
#
# Doctor-driven repair with inactive fallback. Runs bd doctor and categorizes
# warnings into must-fix vs acceptable. Attempts auto-repair for must-fix
# issues. If any must-fix issue remains, emits BEADS_SETUP_FAILED.
#
# Worktree-aware: detects git worktrees and creates a redirect to the main
# repo's .beads/ instead of running bd init.
#
# Compatible with bash 3.2+ (macOS default).
# Fail-open: always exits 0.
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")
#
# Usage:
#   bash beads-setup.sh          # normal setup
#   bash beads-setup.sh repair   # force full re-validation
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config library for yf_bd_available
. "$SCRIPT_DIR/yf-config.sh"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MODE="${1:-}"

# --- Guard: bd available ---
if ! yf_bd_available; then
  echo "beads-setup: skip — bd CLI not available"
  exit 0
fi

# --- Guard: is git repo ---
if ! (cd "$PROJECT_DIR" && git rev-parse --git-dir >/dev/null 2>&1); then
  echo "beads-setup: skip — not a git repository"
  exit 0
fi

# ============================================================
# Phase 1 — Initialize (if .beads/ missing)
# ============================================================
CHANGES=0

if [ ! -d "$PROJECT_DIR/.beads" ]; then
  # Detect git worktree
  GIT_COMMON=$(cd "$PROJECT_DIR" && git rev-parse --git-common-dir 2>/dev/null)
  GIT_DIR=$(cd "$PROJECT_DIR" && git rev-parse --git-dir 2>/dev/null)

  if [ -n "$GIT_COMMON" ] && [ -n "$GIT_DIR" ] && [ "$GIT_COMMON" != "$GIT_DIR" ]; then
    # In a worktree — resolve main repo root and create redirect
    MAIN_REPO=$(cd "$PROJECT_DIR" && cd "$(git rev-parse --git-common-dir)/.." && pwd)
    if [ -d "$MAIN_REPO/.beads" ]; then
      mkdir -p "$PROJECT_DIR/.beads"
      # Write relative path from worktree .beads/ to main .beads/
      python3 -c "import os; print(os.path.relpath('$MAIN_REPO/.beads', '$PROJECT_DIR/.beads'))" > "$PROJECT_DIR/.beads/redirect"
      CHANGES=$((CHANGES + 1))
      echo "beads-setup: created worktree redirect to main repo .beads/"
    else
      echo "beads-setup: skip — main repo has no .beads/ yet"
      exit 0
    fi
  else
    # Main repo — normal init
    echo "beads-setup: initializing beads..."
    if (cd "$PROJECT_DIR" && bd init --skip-hooks -q) 2>/dev/null; then
      CHANGES=$((CHANGES + 1))
      echo "beads-setup: initialized .beads/"
    else
      echo "BEADS_SETUP_FAILED: bd init failed"
      echo "beads-setup: could not initialize beads — manual intervention required"
      exit 0
    fi
  fi
fi

# ============================================================
# Phase 2 — Repair (main repo only, idempotent)
# ============================================================

# Skip repair in worktree — config lives in main repo
if [ -f "$PROJECT_DIR/.beads/redirect" ]; then
  echo "beads-setup: healthy (worktree redirect, $CHANGES changes)"
  exit 0
fi

# Step 1: Ensure no-git-ops is true
NO_GIT_OPS=$(cd "$PROJECT_DIR" && bd config get no-git-ops 2>/dev/null)
if [ "$NO_GIT_OPS" != "true" ]; then
  if (cd "$PROJECT_DIR" && bd config set no-git-ops true) 2>/dev/null; then
    CHANGES=$((CHANGES + 1))
    echo "beads-setup: set no-git-ops=true"
  fi
fi

# Step 2: Remove beads Claude hooks (yf plugin provides its own)
SETTINGS_LOCAL="$PROJECT_DIR/.claude/settings.local.json"
if [ -f "$SETTINGS_LOCAL" ] && grep -q "bd prime" "$SETTINGS_LOCAL" 2>/dev/null; then
  if (cd "$PROJECT_DIR" && bd setup claude --remove --project) 2>/dev/null; then
    CHANGES=$((CHANGES + 1))
    echo "beads-setup: removed beads Claude hooks (yf supersedes)"
  fi
fi

# Step 3: Commit any uncommitted dolt changes (always try — idempotent)
COMMIT_OUT=$(cd "$PROJECT_DIR" && bd vc commit -m "beads-setup: auto-commit" 2>&1) || true
if echo "$COMMIT_OUT" | grep -q "Created commit"; then
  CHANGES=$((CHANGES + 1))
  echo "beads-setup: committed pending dolt changes"
fi

# Step 4: Ensure .beads/.gitignore uses allowlist
BEADS_GI="$PROJECT_DIR/.beads/.gitignore"
EXPECTED_GI_MARKER='!config.yaml'
if [ ! -f "$BEADS_GI" ] || ! grep -qF "$EXPECTED_GI_MARKER" "$BEADS_GI"; then
  cat > "$BEADS_GI" <<'GITIGNORE_EOF'
# Ignore everything except config.yaml and this file
*
!.gitignore
!config.yaml
GITIGNORE_EOF
  CHANGES=$((CHANGES + 1))
  echo "beads-setup: updated .beads/.gitignore to allowlist"
fi

# Step 5: Ensure .beads/ is NOT in project .gitignore
PROJECT_GI="$PROJECT_DIR/.gitignore"
if [ -f "$PROJECT_GI" ] && grep -q '^\.beads/' "$PROJECT_GI" 2>/dev/null; then
  sed '/^\.beads\//d' "$PROJECT_GI" > "$PROJECT_GI.tmp" && mv "$PROJECT_GI.tmp" "$PROJECT_GI"
  CHANGES=$((CHANGES + 1))
  echo "beads-setup: removed .beads/ from project .gitignore"
fi

# ============================================================
# Phase 3 — Validate (run bd doctor, classify warnings)
# ============================================================

DOCTOR_OUTPUT=$(cd "$PROJECT_DIR" && bd doctor 2>&1) || true

# Acceptable warning patterns (yf intentionally diverges or cannot fix)
#   Git Hooks / Git Merge Driver / Git Upstream / Git Working Tree — yf uses no-git-ops
#   Gitignore — yf enforces allowlist pattern, bd doctor expects blocklist
#   Claude Plugin / Claude Integration — yf manages its own integration
#   Sync Branch / Dolt-JSONL Sync — not applicable for local scratchpad
#   Dolt Status / Dolt Lock — transient from normal bd operations
#   Database / Repo Fingerprint / Sync Divergence / Peer Connectivity / Federation — bd init bootstrapping
ACCEPTABLE_PATTERNS=(
  "Git Hooks"
  "Git Merge Driver"
  "Git Upstream"
  "Git Working Tree"
  "Gitignore"
  "Claude Plugin"
  "Claude Integration"
  "Sync Branch"
  "Dolt-JSONL Sync"
  "Dolt Status"
  "Dolt Lock"
  "Dolt Mode"
  "Database"
  "Repo Fingerprint"
  "Sync Divergence"
  "Peer Connectivity"
  "Federation"
)

# Extract warning lines (⚠ markers)
MUST_FIX=0
ACCEPTABLE=0
MUST_FIX_DETAILS=""

while IFS= read -r line; do
  [ -z "$line" ] && continue

  IS_ACCEPTABLE=false
  for pattern in "${ACCEPTABLE_PATTERNS[@]}"; do
    if echo "$line" | grep -q "$pattern"; then
      IS_ACCEPTABLE=true
      break
    fi
  done

  if $IS_ACCEPTABLE; then
    ACCEPTABLE=$((ACCEPTABLE + 1))
  else
    MUST_FIX=$((MUST_FIX + 1))
    MUST_FIX_DETAILS="$MUST_FIX_DETAILS
  - $line"
  fi
done <<< "$(echo "$DOCTOR_OUTPUT" | grep '⚠' | grep -v 'bd doctor' | sed 's/^[[:space:]]*//')"

# Also check for errors (✖) — skip the summary line
ERROR_LINES=$(echo "$DOCTOR_OUTPUT" | grep '✖' | grep -v 'bd doctor' || true)
if [ -n "$ERROR_LINES" ]; then
  ERROR_COUNT=$(echo "$ERROR_LINES" | wc -l | tr -d ' ')
  MUST_FIX=$((MUST_FIX + ERROR_COUNT))
  MUST_FIX_DETAILS="$MUST_FIX_DETAILS
  - ($ERROR_COUNT doctor errors detected)"
fi

# --- Report ---
if [ "$MUST_FIX" -gt 0 ]; then
  echo "BEADS_SETUP_FAILED: $MUST_FIX unresolved issues — manual intervention required"
  echo "Unresolved issues:$MUST_FIX_DETAILS"
  exit 0
fi

echo "beads-setup: healthy ($CHANGES changes, $ACCEPTABLE acceptable warnings)"
exit 0
