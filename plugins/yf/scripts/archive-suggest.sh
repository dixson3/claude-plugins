#!/usr/bin/env bash
# archive-suggest.sh — Analyze git history for archive candidates
#
# Scans recent commits for research and decision activity keywords.
# Optionally creates draft beads for detected candidates.
#
# Usage:
#   bash archive-suggest.sh [--draft] [--since "<timespec>"]
#
# Compatible with bash 3.2+ (macOS default).
# Exit 0 always (fail-open).

set -uo pipefail

# --- Source config library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

# --- Guard: exit if yf disabled or archivist disabled ---
yf_is_enabled || { echo "yf disabled — skipping"; exit 0; }
yf_is_archivist_on || { echo "archivist disabled — skipping"; exit 0; }

# --- Change to project directory ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 0

# --- Check git ---
if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository — skipping"
  exit 0
fi

CREATE_DRAFTS=false
SINCE="24 hours ago"

# Parse arguments
while [ $# -gt 0 ]; do
  case $1 in
    --draft|-d)
      CREATE_DRAFTS=true
      shift
      ;;
    --since|-s)
      SINCE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: archive-suggest.sh [--draft] [--since \"<timespec>\"]"
      echo ""
      echo "Options:"
      echo "  --draft, -d     Auto-create draft beads for candidates"
      echo "  --since, -s     Time range to analyze (default: \"24 hours ago\")"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 0
      ;;
  esac
done

echo "Archive Candidate Analysis"
echo "=========================="
echo "Analyzing commits since: $SINCE"
echo ""

# Get commits in range
COMMITS=$(git log --oneline --since="$SINCE" 2>/dev/null || true)

if [ -z "$COMMITS" ]; then
  echo "No commits found in the specified time range."
  exit 0
fi

COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
echo "Found $COMMIT_COUNT commit(s) to analyze"
echo ""

# Research keywords in commits
echo "Scanning for research indicators..."
RESEARCH_KEYWORDS="researched|investigated|evaluated|compared|analyzed|documentation|API|found that|according to|web search"
RESEARCH_HITS=$(echo "$COMMITS" | grep -iE "$RESEARCH_KEYWORDS" || true)

RESEARCH_COUNT=0
if [ -n "$RESEARCH_HITS" ]; then
  echo "Research activity detected:"
  echo "$RESEARCH_HITS" | while IFS= read -r line; do
    echo "  $line"
  done
  RESEARCH_COUNT=$(echo "$RESEARCH_HITS" | wc -l | tr -d ' ')
  echo ""
fi

# Decision keywords in commits
echo "Scanning for decision indicators..."
DECISION_KEYWORDS="decided|chose|selected|approved|rejected|architecture|design|going with|will use|DEC-[0-9]"
DECISION_HITS=$(echo "$COMMITS" | grep -iE "$DECISION_KEYWORDS" || true)

DECISION_COUNT=0
if [ -n "$DECISION_HITS" ]; then
  echo "Decision activity detected:"
  echo "$DECISION_HITS" | while IFS= read -r line; do
    echo "  $line"
  done
  DECISION_COUNT=$(echo "$DECISION_HITS" | wc -l | tr -d ' ')
  echo ""
fi

# Summary
echo "Summary"
echo "======="

if [ "$RESEARCH_COUNT" -eq 0 ] && [ "$DECISION_COUNT" -eq 0 ]; then
  echo "No obvious archive candidates detected."
  exit 0
fi

echo "Research candidates: $RESEARCH_COUNT"
echo "Decision candidates: $DECISION_COUNT"
echo ""

# Check existing beads
if command -v bd >/dev/null 2>&1; then
  OPEN_BEADS=$( (set +e; bd list --label=ys:archive --status=open --format=json 2>/dev/null | jq 'length' 2>/dev/null) || echo "0")
  echo "Open archive beads: $OPEN_BEADS"
  echo ""
fi

if $CREATE_DRAFTS; then
  if ! command -v bd >/dev/null 2>&1; then
    echo "beads-cli not found — cannot create drafts"
    exit 0
  fi

  echo "Creating draft beads..."
  echo ""

  CREATED=0

  if [ "$RESEARCH_COUNT" -gt 0 ]; then
    RESEARCH_SUMMARY=$(echo "$RESEARCH_HITS" | head -3)
    bd create --type task --priority 3 \
      --labels "ys:archive,ys:archive:research,ys:archive:draft" \
      --title "Archive: Draft - Research activity detected" \
      --description "## Auto-Detected Archive Candidate

**Status**: Draft - needs review and enrichment
**Type**: research
**Detection**: archive-suggest scan ($SINCE)

## Commits with Research Indicators
$RESEARCH_SUMMARY

## TODO
- [ ] Review if archive-worthy
- [ ] Identify the specific topic(s) researched
- [ ] Add sources consulted with URLs
- [ ] Summarize findings
- [ ] Add recommendations

## Instructions
Review the commits above and enrich this bead with actual research details.
If multiple distinct research topics, create separate beads for each.
Close this bead if not archive-worthy." 2>/dev/null && CREATED=$((CREATED + 1))
    echo "Created research draft bead"
  fi

  if [ "$DECISION_COUNT" -gt 0 ]; then
    DECISION_SUMMARY=$(echo "$DECISION_HITS" | head -3)
    bd create --type task --priority 2 \
      --labels "ys:archive,ys:archive:decision,ys:archive:draft" \
      --title "Archive: Draft - Decision activity detected" \
      --description "## Auto-Detected Archive Candidate

**Status**: Draft - needs review and enrichment
**Type**: decision
**Detection**: archive-suggest scan ($SINCE)

## Commits with Decision Indicators
$DECISION_SUMMARY

## TODO
- [ ] Review if archive-worthy
- [ ] Assign decision ID (check _index.md for next number)
- [ ] Document the decision clearly
- [ ] Add alternatives considered
- [ ] Document reasoning and consequences

## Instructions
Review the commits above and enrich this bead with actual decision details.
If multiple distinct decisions, create separate beads for each.
Close this bead if not archive-worthy." 2>/dev/null && CREATED=$((CREATED + 1))
    echo "Created decision draft bead"
  fi

  echo ""
  echo "Created $CREATED draft bead(s)"
  echo "Run /yf:archive_process to process them after enrichment."
else
  echo "Recommendations:"
  echo ""
  if [ "$RESEARCH_COUNT" -gt 0 ]; then
    echo "1. Run /yf:archive_capture type:research to document the research findings"
  fi
  if [ "$DECISION_COUNT" -gt 0 ]; then
    echo "2. Run /yf:archive_capture type:decision to document the decisions"
  fi
  echo ""
  echo "Or run with --draft to auto-create draft beads:"
  echo "  /yf:archive_suggest --draft"
fi

exit 0
