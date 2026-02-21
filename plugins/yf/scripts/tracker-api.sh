#!/bin/bash
# tracker-api.sh — Tracker abstraction layer for issue operations
#
# Provides a uniform interface for create, list, view, transition
# across GitHub, GitLab, and file backends.
#
# Usage:
#   tracker-api.sh create --title "..." --body "..." [--labels "..."]
#   tracker-api.sh list [--state open|closed|all] [--limit N]
#   tracker-api.sh view --issue <num>
#   tracker-api.sh transition --issue <num> --state <state>
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (defaults to ".")
#
# Reads tracker config from tracker-detect.sh output.
# Always exits 0 with JSON output. Errors in {"error":"..."} field.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Detect tracker ---
TRACKER_JSON=$("$SCRIPT_DIR/tracker-detect.sh")
TRACKER=$(echo "$TRACKER_JSON" | jq -r '.tracker')
PROJECT=$(echo "$TRACKER_JSON" | jq -r '.project')
TOOL=$(echo "$TRACKER_JSON" | jq -r '.tool')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' "$PROJECT_DIR/.yoshiko-flow/config.json" 2>/dev/null || echo "docs")
TODO_FILE="$PROJECT_DIR/$ARTIFACT_DIR/specifications/TODO.md"
TODO_DIR="$PROJECT_DIR/$ARTIFACT_DIR/todos"

# --- Parse arguments ---
ACTION="${1:-}"
shift || true

TITLE="" BODY="" LABELS="" STATE="open" LIMIT="50" ISSUE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)  TITLE="$2"; shift 2 ;;
    --body)   BODY="$2"; shift 2 ;;
    --labels) LABELS="$2"; shift 2 ;;
    --state)  STATE="$2"; shift 2 ;;
    --limit)  LIMIT="$2"; shift 2 ;;
    --issue)  ISSUE="$2"; shift 2 ;;
    *)        shift ;;
  esac
done

# --- File backend helpers ---

# _next_todo_id — returns next TODO-NNN id
_next_todo_id() {
  if [ ! -f "$TODO_FILE" ]; then
    echo "TODO-001"
    return
  fi
  local last
  last=$(grep -o 'TODO-[0-9]\{3\}' "$TODO_FILE" 2>/dev/null | sort | tail -1)
  if [ -z "$last" ]; then
    echo "TODO-001"
    return
  fi
  local num="${last#TODO-}"
  num=$((10#$num + 1))
  printf "TODO-%03d" "$num"
}

# _file_create — create a file-based issue
_file_create() {
  mkdir -p "$(dirname "$TODO_FILE")" "$TODO_DIR"

  local id
  id=$(_next_todo_id)
  local date
  date=$(date +%Y-%m-%d)
  local type="task"
  if echo "$LABELS" | grep -q "bug"; then
    type="bug"
  elif echo "$LABELS" | grep -q "feature\|enhancement"; then
    type="feature"
  fi

  # Ensure TODO.md exists with header
  if [ ! -f "$TODO_FILE" ]; then
    cat > "$TODO_FILE" << 'HEADER'
# Project TODOs

## Open

---

## Closed
HEADER
  fi

  # Build entry in a temp file
  local entry_file="${TODO_FILE}.entry"
  cat > "$entry_file" <<ENTRY

### ${id}: ${TITLE}
**Created:** ${date} | **Priority:** Medium | **Type:** ${type}
${BODY}

ENTRY

  # Insert entry before the --- separator in Open section
  # Read file, write before first --- line
  local tmp="${TODO_FILE}.tmp"
  local inserted=false
  while IFS= read -r line; do
    if [ "$line" = "---" ] && [ "$inserted" = false ]; then
      cat "$entry_file"
      inserted=true
    fi
    echo "$line"
  done < "$TODO_FILE" > "$tmp"
  mv "$tmp" "$TODO_FILE"
  rm -f "$entry_file"

  # Create artifact directory
  mkdir -p "$TODO_DIR/$id"

  echo "{\"id\":\"${id}\",\"title\":\"${TITLE}\",\"url\":\"${TODO_FILE}#${id}\"}"
}

# _file_list — list file-based issues
_file_list() {
  if [ ! -f "$TODO_FILE" ]; then
    echo "[]"
    return
  fi

  local section="none"
  local results="["
  local first=true
  local current_id="" current_title="" current_state=""

  while IFS= read -r line; do
    case "$line" in
      "## Open"*)   section="open" ;;
      "## Closed"*) section="closed" ;;
      "### "*)
        # Flush previous entry
        if [ -n "$current_id" ]; then
          if [ "$STATE" = "all" ] || [ "$STATE" = "$current_state" ]; then
            if [ "$first" = true ]; then first=false; else results="$results,"; fi
            results="$results{\"id\":\"${current_id}\",\"title\":\"${current_title}\",\"state\":\"${current_state}\"}"
          fi
        fi
        # Parse new entry — handle ~~strikethrough~~ for closed items
        local stripped="${line### }"
        stripped="${stripped#~~}"
        stripped="${stripped%~~}"
        current_id="${stripped%%:*}"
        current_title="${stripped#*: }"
        current_state="$section"
        ;;
    esac
  done < "$TODO_FILE"

  # Flush last entry
  if [ -n "$current_id" ]; then
    if [ "$STATE" = "all" ] || [ "$STATE" = "$current_state" ]; then
      if [ "$first" = true ]; then first=false; else results="$results,"; fi
      results="$results{\"id\":\"${current_id}\",\"title\":\"${current_title}\",\"state\":\"${current_state}\"}"
    fi
  fi

  echo "${results}]"
}

# _file_view — view a specific file-based issue
_file_view() {
  if [ ! -f "$TODO_FILE" ]; then
    echo "{\"error\":\"TODO.md not found\"}"
    return
  fi

  local capturing=false
  local content=""
  local found=false

  while IFS= read -r line; do
    if echo "$line" | grep -q "^### .*${ISSUE}"; then
      capturing=true
      found=true
      content="$line"
      continue
    fi
    if [ "$capturing" = true ]; then
      if echo "$line" | grep -q "^### \|^## \|^---$"; then
        break
      fi
      content="$content
$line"
    fi
  done < "$TODO_FILE"

  if [ "$found" = false ]; then
    echo "{\"error\":\"Issue ${ISSUE} not found\"}"
    return
  fi

  # Escape for JSON
  local escaped
  escaped=$(echo "$content" | jq -Rs '.')
  echo "{\"id\":\"${ISSUE}\",\"content\":${escaped}}"
}

# _file_transition — move issue between Open/Closed in TODO.md
_file_transition() {
  if [ ! -f "$TODO_FILE" ]; then
    echo "{\"error\":\"TODO.md not found\"}"
    return
  fi

  local date
  date=$(date +%Y-%m-%d)

  if [ "$STATE" = "closed" ] || [ "$STATE" = "close" ]; then
    # Move from Open to Closed, add strikethrough and closed date
    local tmp="${TODO_FILE}.tmp"
    local in_target=false
    local entry_lines=""
    local section="none"

    while IFS= read -r line; do
      case "$line" in
        "## Open"*)   section="open" ;;
        "## Closed"*) section="closed" ;;
      esac

      if [ "$section" = "open" ] && echo "$line" | grep -q "^### .*${ISSUE}"; then
        in_target=true
        # Transform title to strikethrough
        local title_part="${line### }"
        entry_lines="### ~~${title_part}~~
**Closed:** ${date}"
        continue
      fi

      if [ "$in_target" = true ]; then
        if echo "$line" | grep -q "^### \|^## \|^---$"; then
          in_target=false
        else
          entry_lines="$entry_lines
$line"
          continue
        fi
      fi

      echo "$line"
    done < "$TODO_FILE" > "$tmp"

    # Append entry to Closed section
    local entry_file="${TODO_FILE}.closed-entry"
    echo "$entry_lines" > "$entry_file"
    local tmp2="${tmp}.2"
    while IFS= read -r cline; do
      echo "$cline"
      if [ "$cline" = "## Closed" ]; then
        cat "$entry_file"
      fi
    done < "$tmp" > "$tmp2"
    mv "$tmp2" "$TODO_FILE"
    rm -f "$tmp" "$entry_file"

    echo "{\"id\":\"${ISSUE}\",\"state\":\"closed\"}"
  else
    echo "{\"error\":\"Unsupported transition state: ${STATE}\"}"
  fi
}

# --- GitHub backend ---

_github_create() {
  local args=(issue create --repo "$PROJECT" --title "$TITLE" --body "$BODY")
  if [ -n "$LABELS" ]; then
    args+=(--label "$LABELS")
  fi
  local result
  result=$("$TOOL" "${args[@]}" 2>&1) || {
    echo "{\"error\":\"gh issue create failed: ${result}\"}"
    return
  }
  # gh returns the URL
  echo "{\"url\":\"${result}\"}"
}

_github_list() {
  local args=(issue list --repo "$PROJECT" --limit "$LIMIT" --json number,title,state,url)
  if [ "$STATE" != "all" ]; then
    args+=(--state "$STATE")
  fi
  "$TOOL" "${args[@]}" 2>/dev/null || echo "[]"
}

_github_view() {
  "$TOOL" issue view "$ISSUE" --repo "$PROJECT" --json number,title,body,state,labels,url 2>/dev/null || {
    echo "{\"error\":\"Issue ${ISSUE} not found\"}"
  }
}

_github_transition() {
  local gh_state="$STATE"
  case "$STATE" in
    in_progress) gh_state="open" ;;  # GitHub has no in_progress — leave open
    closed|close) gh_state="closed" ;;
  esac
  "$TOOL" issue edit "$ISSUE" --repo "$PROJECT" --remove-label "" 2>/dev/null
  if [ "$gh_state" = "closed" ]; then
    "$TOOL" issue close "$ISSUE" --repo "$PROJECT" 2>/dev/null || {
      echo "{\"error\":\"Failed to close issue ${ISSUE}\"}"
      return
    }
  fi
  echo "{\"id\":\"${ISSUE}\",\"state\":\"${STATE}\"}"
}

# --- GitLab backend ---

_gitlab_create() {
  local args=(issue create --repo "$PROJECT" --title "$TITLE" --description "$BODY")
  if [ -n "$LABELS" ]; then
    args+=(--label "$LABELS")
  fi
  local result
  result=$("$TOOL" "${args[@]}" 2>&1) || {
    echo "{\"error\":\"glab issue create failed: ${result}\"}"
    return
  }
  echo "{\"url\":\"${result}\"}"
}

_gitlab_list() {
  local args=(issue list --repo "$PROJECT" --per-page "$LIMIT")
  if [ "$STATE" != "all" ]; then
    local gl_state="$STATE"
    [ "$gl_state" = "open" ] && gl_state="opened"
    args+=(--state "$gl_state")
  fi
  "$TOOL" "${args[@]}" --output json 2>/dev/null || echo "[]"
}

_gitlab_view() {
  "$TOOL" issue view "$ISSUE" --repo "$PROJECT" --output json 2>/dev/null || {
    echo "{\"error\":\"Issue ${ISSUE} not found\"}"
  }
}

_gitlab_transition() {
  local gl_state="$STATE"
  case "$STATE" in
    in_progress) gl_state="opened" ;;
    closed|close) gl_state="closed" ;;
  esac
  # glab doesn't have direct state transition — use edit or close
  if [ "$gl_state" = "closed" ]; then
    "$TOOL" issue close "$ISSUE" --repo "$PROJECT" 2>/dev/null || {
      echo "{\"error\":\"Failed to close issue ${ISSUE}\"}"
      return
    }
  fi
  echo "{\"id\":\"${ISSUE}\",\"state\":\"${STATE}\"}"
}

# --- Dispatch ---

case "$ACTION" in
  create)
    if [ -z "$TITLE" ]; then
      echo '{"error":"--title is required for create"}'
      exit 0
    fi
    case "$TRACKER" in
      github) _github_create ;;
      gitlab) _gitlab_create ;;
      file)   _file_create ;;
      *)      echo '{"error":"Unknown tracker"}' ;;
    esac
    ;;
  list)
    case "$TRACKER" in
      github) _github_list ;;
      gitlab) _gitlab_list ;;
      file)   _file_list ;;
      *)      echo "[]" ;;
    esac
    ;;
  view)
    if [ -z "$ISSUE" ]; then
      echo '{"error":"--issue is required for view"}'
      exit 0
    fi
    case "$TRACKER" in
      github) _github_view ;;
      gitlab) _gitlab_view ;;
      file)   _file_view ;;
      *)      echo '{"error":"Unknown tracker"}' ;;
    esac
    ;;
  transition)
    if [ -z "$ISSUE" ] || [ -z "$STATE" ]; then
      echo '{"error":"--issue and --state are required for transition"}'
      exit 0
    fi
    case "$TRACKER" in
      github) _github_transition ;;
      gitlab) _gitlab_transition ;;
      file)   _file_transition ;;
      *)      echo '{"error":"Unknown tracker"}' ;;
    esac
    ;;
  *)
    echo '{"error":"Unknown action. Use: create, list, view, transition"}'
    ;;
esac
