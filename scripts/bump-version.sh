#!/usr/bin/env bash
# bump-version.sh — Update version references across all marketplace files.
# Usage: bash scripts/bump-version.sh <new-version>

set -euo pipefail

NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
  echo "Usage: bash scripts/bump-version.sh <new-version>"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Read current version from the source of truth
CURRENT_VERSION=$(jq -r '.version' "$REPO_ROOT/plugins/yf/.claude-plugin/plugin.json")
if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" = "null" ]; then
  echo "ERROR: Could not read current version from plugins/yf/.claude-plugin/plugin.json"
  exit 1
fi

echo "Bumping version: $CURRENT_VERSION -> $NEW_VERSION"
echo ""

# 1. plugins/yf/.claude-plugin/plugin.json
jq --arg v "$NEW_VERSION" '.version = $v' \
  "$REPO_ROOT/plugins/yf/.claude-plugin/plugin.json" > "$REPO_ROOT/plugins/yf/.claude-plugin/plugin.json.tmp"
mv "$REPO_ROOT/plugins/yf/.claude-plugin/plugin.json.tmp" "$REPO_ROOT/plugins/yf/.claude-plugin/plugin.json"
echo "  Updated: plugins/yf/.claude-plugin/plugin.json"

# 2. .claude-plugin/marketplace.json — metadata.version and plugins[0].version
jq --arg v "$NEW_VERSION" '.metadata.version = $v | .plugins[0].version = $v' \
  "$REPO_ROOT/.claude-plugin/marketplace.json" > "$REPO_ROOT/.claude-plugin/marketplace.json.tmp"
mv "$REPO_ROOT/.claude-plugin/marketplace.json.tmp" "$REPO_ROOT/.claude-plugin/marketplace.json"
echo "  Updated: .claude-plugin/marketplace.json"

# 3. README.md — plugin table line
sed -i '' "s/| ${CURRENT_VERSION} |/| ${NEW_VERSION} |/" "$REPO_ROOT/README.md"
echo "  Updated: README.md"

# 4. CLAUDE.md — Current Plugins line
sed -i '' "s/(v${CURRENT_VERSION})/(v${NEW_VERSION})/" "$REPO_ROOT/CLAUDE.md"
echo "  Updated: CLAUDE.md"

# 5. plugins/yf/README.md — first heading line
sed -i '' "s/v${CURRENT_VERSION}/v${NEW_VERSION}/" "$REPO_ROOT/plugins/yf/README.md"
echo "  Updated: plugins/yf/README.md"

echo ""
echo "Version bumped to $NEW_VERSION in all files."
echo ""
echo "Manual steps remaining:"
echo "  - Add CHANGELOG.md entry for v$NEW_VERSION"
echo "  - Review marketplace.json description text if capabilities changed"
