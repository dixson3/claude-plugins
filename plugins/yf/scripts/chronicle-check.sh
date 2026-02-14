#!/usr/bin/env bash
# chronicle-check.sh — Auto-create draft chronicle beads from git activity
#
# Analyzes git commits for keywords, significant file changes, and activity
# volume. Creates draft chronicle beads that the diary agent can later
# enrich, consolidate, or close.
#
# Usage:
#   bash chronicle-check.sh [check|pre-push] [--since "<timespec>"]
#
# Modes:
#   check    (default) — analyze and create drafts, return attention count
#   pre-push — wrapper around check with header/summary output
#
# Compatible with bash 3.2+ (macOS default).
# Exit 0 always (fail-open).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# --- Guard: exit if yf disabled ---
yf_is_enabled || exit 0

# --- Change to project directory ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 0

# --- Check prerequisites ---
if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

if ! command -v bd >/dev/null 2>&1; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# --- Parse arguments ---
MODE="check"
SINCE="24 hours ago"

while [ $# -gt 0 ]; do
  case $1 in
    check)
      MODE="check"
      shift
      ;;
    pre-push)
      MODE="pre-push"
      shift
      ;;
    --since|-s)
      SINCE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: chronicle-check.sh [check|pre-push] [--since \"<timespec>\"]"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

# --- Dedup file (daily, inside .yoshiko-flow/ which is gitignored) ---
DEDUP_DIR="${PROJECT_DIR}/.yoshiko-flow"
DEDUP_FILE="${DEDUP_DIR}/.chronicle-drafted-$(date +%Y%m%d)"

# Ensure dedup directory exists
mkdir -p "$DEDUP_DIR" 2>/dev/null || true

# Read dedup entries into a newline-separated string
DEDUP_ENTRIES=""
if [ -f "$DEDUP_FILE" ]; then
  DEDUP_ENTRIES=$(cat "$DEDUP_FILE" 2>/dev/null || true)
fi

is_already_drafted() {
  local key="$1"
  if [ -z "$DEDUP_ENTRIES" ]; then
    return 1
  fi
  echo "$DEDUP_ENTRIES" | grep -qF "$key"
}

mark_drafted() {
  local key="$1"
  echo "$key" >> "$DEDUP_FILE" 2>/dev/null || true
}

# --- Significant file patterns (yf-specific) ---
SIGNIFICANT_PATTERNS='plugins/|skills/|agents/|rules/|hooks/|scripts/|docs/plans/|\.claude/|CLAUDE\.md|CHANGELOG\.md|MEMORY\.md|preflight\.json|plugin\.json|marketplace\.json'

# --- Keyword patterns ---
KEYWORDS='decided|chose|realized|discovered|learned|important|architecture|pattern|insight|lesson|changed approach|pivoted|refactored|capability|breaking change|added feature|new skill|new agent|new rule'

# --- Get commits in range ---
COMMITS=$(git log --oneline --since="$SINCE" 2>/dev/null || true)

COMMIT_COUNT=0
KEYWORD_HITS=""
KEYWORD_COUNT=0
SIGNIFICANT_FILES=""
SIGNIFICANT_COUNT=0

if [ -n "$COMMITS" ]; then
  COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')

  # --- Analyze: keyword matches ---
  KEYWORD_HITS=$(echo "$COMMITS" | grep -iE "$KEYWORDS" || true)
  if [ -n "$KEYWORD_HITS" ]; then
    KEYWORD_COUNT=$(echo "$KEYWORD_HITS" | wc -l | tr -d ' ')
  fi

  # --- Analyze: significant file changes ---
  CHANGED_FILES=$(git diff --name-only HEAD~"${COMMIT_COUNT}"..HEAD 2>/dev/null || git diff --name-only --since="$SINCE" 2>/dev/null || true)
  if [ -n "$CHANGED_FILES" ]; then
    SIGNIFICANT_FILES=$(echo "$CHANGED_FILES" | grep -E "$SIGNIFICANT_PATTERNS" || true)
  fi
fi
if [ -n "$SIGNIFICANT_FILES" ]; then
  SIGNIFICANT_COUNT=$(echo "$SIGNIFICANT_FILES" | wc -l | tr -d ' ')
fi

# --- Analyze: activity volume (high volume = worth chronicling) ---
VOLUME_THRESHOLD=5
VOLUME_HIT=false
if [ "$COMMIT_COUNT" -ge "$VOLUME_THRESHOLD" ]; then
  VOLUME_HIT=true
fi

# --- Determine if any candidates exist ---
CANDIDATES=0
CANDIDATE_REASONS=""

if [ "$KEYWORD_COUNT" -gt 0 ]; then
  CANDIDATES=$((CANDIDATES + 1))
  CANDIDATE_REASONS="${CANDIDATE_REASONS}keywords:${KEYWORD_COUNT} "
fi

if [ "$SIGNIFICANT_COUNT" -gt 0 ]; then
  CANDIDATES=$((CANDIDATES + 1))
  CANDIDATE_REASONS="${CANDIDATE_REASONS}significant-files:${SIGNIFICANT_COUNT} "
fi

if $VOLUME_HIT; then
  CANDIDATES=$((CANDIDATES + 1))
  CANDIDATE_REASONS="${CANDIDATE_REASONS}high-volume:${COMMIT_COUNT}-commits "
fi

# --- Analyze: wisp squashes (swarm activity) ---
WISP_SQUASH_COUNT=0
WISP_LIST=$(bd mol wisp list --json 2>/dev/null || echo "[]")
if [ "$WISP_LIST" != "[]" ] && [ -n "$WISP_LIST" ]; then
  WISP_SQUASH_COUNT=$(echo "$WISP_LIST" | jq '[.[] | select(.status == "squashed")] | length' 2>/dev/null || echo "0")
fi

if [ "$WISP_SQUASH_COUNT" -gt 0 ]; then
  CANDIDATES=$((CANDIDATES + 1))
  CANDIDATE_REASONS="${CANDIDATE_REASONS}wisp-squashes:${WISP_SQUASH_COUNT} "
fi

# --- Analyze: in-progress beads (work without commits) ---
IN_PROGRESS_BEADS=""
IN_PROGRESS_COUNT=0
IN_PROGRESS_BEADS=$(bd list --status=in_progress --type=task --limit=0 --json 2>/dev/null || echo "[]")
IN_PROGRESS_COUNT=$(echo "$IN_PROGRESS_BEADS" | jq 'length' 2>/dev/null || echo "0")

if [ "$IN_PROGRESS_COUNT" -gt 0 ]; then
  CANDIDATES=$((CANDIDATES + 1))
  CANDIDATE_REASONS="${CANDIDATE_REASONS}in-progress-beads:${IN_PROGRESS_COUNT} "
fi

if [ "$CANDIDATES" -eq 0 ]; then
  if [ "$MODE" = "pre-push" ]; then
    echo "chronicle-check: no candidates ($COMMIT_COUNT commits, no significant patterns)"
  fi
  exit 0
fi

# --- Detect plan context (only executing plans) ---
PLAN_LABEL=""
PLAN_IDX=""
PLAN_EPIC=$( (set +e; bd list --type=epic --status=open -l exec:executing --format=json 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null) || true)
if [ -n "$PLAN_EPIC" ]; then
  PLAN_LABEL=$( (set +e; bd label list "$PLAN_EPIC" --json 2>/dev/null | jq -r '.[] | select(startswith("plan:"))' 2>/dev/null | head -1) || true)
  if [ -n "$PLAN_LABEL" ]; then
    PLAN_IDX="${PLAN_LABEL#plan:}"
  fi
fi

# --- Create draft beads ---
CREATED=0

# Build a dedup key from the combination of reasons
DEDUP_KEY="chronicle-${CANDIDATE_REASONS}"

if is_already_drafted "$DEDUP_KEY"; then
  if [ "$MODE" = "pre-push" ]; then
    echo "chronicle-check: candidates found but already drafted today"
  fi
  exit 0
fi

# Build title
TITLE="Chronicle (Draft): "
if [ "$KEYWORD_COUNT" -gt 0 ]; then
  # Use first keyword commit as title hint
  FIRST_KEYWORD=$(echo "$KEYWORD_HITS" | head -1 | sed 's/^[a-f0-9]* //')
  TITLE="${TITLE}${FIRST_KEYWORD}"
elif [ "$SIGNIFICANT_COUNT" -gt 0 ]; then
  TITLE="${TITLE}Significant changes to $(echo "$SIGNIFICANT_FILES" | head -1)"
elif $VOLUME_HIT; then
  TITLE="${TITLE}High activity session (${COMMIT_COUNT} commits)"
elif [ "$IN_PROGRESS_COUNT" -gt 0 ]; then
  TITLE="${TITLE}In-progress work (${IN_PROGRESS_COUNT} tasks)"
fi

# Truncate title to reasonable length
if [ ${#TITLE} -gt 120 ]; then
  TITLE="${TITLE:0:117}..."
fi

# Build description
DESCRIPTION="## Auto-Detected Chronicle Candidate

**Detection**: chronicle-check (${CANDIDATE_REASONS})
**Commits analyzed**: ${COMMIT_COUNT} (since: ${SINCE})
**Date**: $(date +%Y-%m-%d)
"

if [ "$KEYWORD_COUNT" -gt 0 ]; then
  DESCRIPTION="${DESCRIPTION}
## Keyword Matches
$(echo "$KEYWORD_HITS" | head -5)"
fi

if [ "$SIGNIFICANT_COUNT" -gt 0 ]; then
  DESCRIPTION="${DESCRIPTION}
## Significant Files Changed
$(echo "$SIGNIFICANT_FILES" | head -10)"
fi

if $VOLUME_HIT; then
  DESCRIPTION="${DESCRIPTION}
## Activity Volume
${COMMIT_COUNT} commits in the analysis window.
$(echo "$COMMITS" | head -5)
..."
fi

if [ "$IN_PROGRESS_COUNT" -gt 0 ]; then
  IN_PROGRESS_TITLES=$(echo "$IN_PROGRESS_BEADS" | jq -r '.[0:5] | .[].title' 2>/dev/null || true)
  DESCRIPTION="${DESCRIPTION}
## In-Progress Work
${IN_PROGRESS_COUNT} tasks currently in progress:
${IN_PROGRESS_TITLES}"
fi

if [ -n "$COMMITS" ]; then
  DESCRIPTION="${DESCRIPTION}

## Recent Commits
$(echo "$COMMITS" | head -10)"
fi

# Build labels
LABELS="ys:chronicle,ys:chronicle:draft"
if [ -n "$PLAN_LABEL" ]; then
  LABELS="${LABELS},${PLAN_LABEL}"
fi

# Create the draft bead
bd create --type task --priority 3 \
  --labels "$LABELS" \
  --title "$TITLE" \
  --description "$DESCRIPTION" >/dev/null 2>&1 && CREATED=1

if [ "$CREATED" -eq 1 ]; then
  mark_drafted "$DEDUP_KEY"
fi

# --- Output ---
if [ "$MODE" = "pre-push" ]; then
  if [ "$CREATED" -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "  CHRONICLE-CHECK: Draft bead created"
    echo "=========================================="
    echo ""
    echo "Auto-detected significant work:"
    echo "  ${CANDIDATE_REASONS}"
    echo ""
    echo "A draft chronicle bead has been created."
    echo "Run /yf:chronicle_diary to process it into a diary entry."
    echo ""
    echo "=========================================="
    echo ""
  else
    echo "chronicle-check: candidates found but draft creation failed (non-blocking)"
  fi
elif [ "$MODE" = "check" ]; then
  echo "$CREATED"
fi

exit 0
