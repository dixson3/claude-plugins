#!/bin/bash
# .claude/roles/roles-apply.sh
# Usage: roles-apply.sh <agent-name>
# Returns concatenated content of all roles that apply to the agent

AGENT_NAME="${1:-primary}"
ROLES_DIR="$(dirname "$0")"

for role_file in "$ROLES_DIR"/*.md; do
  [ -f "$role_file" ] || continue

  # Extract applies-to list from frontmatter
  if grep -q "applies-to:" "$role_file"; then
    # Check if agent is in the applies-to list
    if sed -n '/^---$/,/^---$/p' "$role_file" | grep -qE "^\s*-\s*${AGENT_NAME}\s*$"; then
      echo "---"
      echo "# Active Role: $(basename "$role_file" .md)"
      echo ""
      # Output content after frontmatter
      sed '1{/^---$/!q;};1,/^---$/d;1,/^---$/d' "$role_file"
      echo ""
    fi
  fi
done
