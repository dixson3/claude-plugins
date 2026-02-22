#!/bin/bash
# xref-check.sh — Cross-reference consistency checker
#
# Builds a canonical name registry from skill/agent frontmatter, then scans
# active artifact files for /yf:* references that don't resolve to canonical
# names. Reports stale references with file, line number, and closest match.
#
# Exit codes:
#   0 — all references resolve (or no references found)
#   1 — stale references found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/yf"

# ── Build canonical name registry (newline-delimited file) ───────────
CANONICAL_FILE=$(mktemp)
trap 'rm -f "$CANONICAL_FILE"' EXIT

SKILL_COUNT=0
AGENT_COUNT=0

# Skills: extract name: from frontmatter
for dir in "$PLUGIN_DIR"/skills/*/; do
  [ -d "$dir" ] || continue
  skill_file="$dir/SKILL.md"
  [ -f "$skill_file" ] || continue
  name=$(grep '^name:' "$skill_file" | head -1 | sed 's/^name: *//')
  if [ -n "$name" ]; then
    echo "$name" >> "$CANONICAL_FILE"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done

# Agents: extract name: from frontmatter
for agent in "$PLUGIN_DIR"/agents/*.md; do
  [ -f "$agent" ] || continue
  name=$(grep '^name:' "$agent" | head -1 | sed 's/^name: *//')
  if [ -n "$name" ]; then
    echo "$name" >> "$CANONICAL_FILE"
    AGENT_COUNT=$((AGENT_COUNT + 1))
  fi
done

# ── Collect files to scan (active artifacts only) ────────────────────
SCAN_LIST=$(mktemp)
trap 'rm -f "$CANONICAL_FILE" "$SCAN_LIST"' EXIT

for pattern in \
  "$PLUGIN_DIR"/skills/*/SKILL.md \
  "$PLUGIN_DIR"/agents/*.md \
  "$PLUGIN_DIR"/rules/*.md \
  "$PLUGIN_DIR"/hooks/*.sh \
  "$PLUGIN_DIR"/scripts/*.sh \
  "$PLUGIN_DIR"/formulas/*.json; do
  for f in $pattern; do
    [ -f "$f" ] && echo "$f" >> "$SCAN_LIST"
  done
done

# ── Find closest canonical match (simple substring matching) ─────────
find_closest() {
  local ref="$1"
  local ref_action="${ref#yf:}"

  # Try substring match on the action part
  while IFS= read -r canon; do
    local canon_action="${canon#yf:}"
    case "$canon_action" in
      *"$ref_action"*) echo "$canon"; return ;;
    esac
    case "$ref_action" in
      *"$canon_action"*) echo "$canon"; return ;;
    esac
  done < "$CANONICAL_FILE"

  # Try matching last segment
  local ref_tail="${ref_action##*_}"
  while IFS= read -r canon; do
    local canon_action="${canon#yf:}"
    case "$canon_action" in
      *"$ref_tail") echo "$canon"; return ;;
    esac
  done < "$CANONICAL_FILE"

  echo ""
}

# ── Scan for /yf: references and check resolution ───────────────────
STALE_COUNT=0
ERROR_OUTPUT=""

while IFS= read -r file; do
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    # Extract all /yf:<name> references from this line
    refs=$(echo "$line" | grep -oE '/yf:[a-zA-Z0-9_]+' || true)
    [ -z "$refs" ] && continue

    for ref in $refs; do
      # Strip the leading / to get the canonical form
      canon_ref="${ref#/}"

      # Check if it exists in canonical file
      if ! grep -qxF "$canon_ref" "$CANONICAL_FILE"; then
        STALE_COUNT=$((STALE_COUNT + 1))
        rel_path="${file#$REPO_ROOT/}"
        closest=$(find_closest "$canon_ref")
        if [ -n "$closest" ]; then
          ERROR_OUTPUT="$ERROR_OUTPUT  $rel_path:$line_num  $ref  ->  suggest /$closest
"
        else
          ERROR_OUTPUT="$ERROR_OUTPUT  $rel_path:$line_num  $ref  (no close match found)
"
        fi
      fi
    done
  done < "$file"
done < "$SCAN_LIST"

# ── Report ───────────────────────────────────────────────────────────
if [ "$STALE_COUNT" -gt 0 ]; then
  echo "FAIL: $STALE_COUNT stale cross-reference(s) found:"
  printf '%s' "$ERROR_OUTPUT"
  exit 1
else
  echo "OK: all cross-references resolve to canonical names ($SKILL_COUNT skills, $AGENT_COUNT agents checked)"
  exit 0
fi
