#!/bin/bash
# yf-tasks.sh — File-based task management library for Yoshiko Flow
#
# Replaces beads-cli with JSON files under .yoshiko-flow/ subdirectories.
# All entities (tasks, epics, gates, chronicles, archives, issues, todos,
# molecules) are stored as individual JSON files.
#
# Sourceable library — functions prefixed with yft_.
# Compatible with bash 3.2+ (macOS default).
# Requires: jq
#
# Usage:
#   . "$SCRIPT_DIR/yf-tasks.sh"
#   ID=$(yft_create --type=task --title="Implement feature" -l "plan:0054")
#   yft_show "$ID" --json
#   yft_update "$ID" --status=in_progress
#   yft_close "$ID" --reason="Done"

# --- Source dependencies ---
_YFT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_YFT_SCRIPT_DIR/yf-id.sh"

# --- Configuration ---
_YFT_ROOT="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow"

# --- Directory mapping by type ---
_yft_type_dir() {
  local type="$1"
  case "$type" in
    task|epic|gate) echo "$_YFT_ROOT/tasks" ;;
    chronicle)      echo "$_YFT_ROOT/chronicler" ;;
    archive)        echo "$_YFT_ROOT/archivist" ;;
    issue)          echo "$_YFT_ROOT/issues" ;;
    todo)           echo "$_YFT_ROOT/todos" ;;
    molecule|mol)   echo "$_YFT_ROOT/molecules" ;;
    *)              echo "$_YFT_ROOT/tasks" ;;
  esac
}

# --- ID prefix mapping ---
_yft_type_prefix() {
  local type="$1"
  case "$type" in
    task|epic|gate) echo "task" ;;
    chronicle)      echo "chron" ;;
    archive)        echo "arch" ;;
    issue)          echo "issue" ;;
    todo)           echo "todo" ;;
    molecule|mol)   echo "mol" ;;
    *)              echo "task" ;;
  esac
}

# --- Ensure directories exist ---
_yft_ensure_dirs() {
  mkdir -p "$_YFT_ROOT/tasks" "$_YFT_ROOT/chronicler" "$_YFT_ROOT/archivist" \
           "$_YFT_ROOT/issues" "$_YFT_ROOT/todos" "$_YFT_ROOT/molecules" 2>/dev/null || true
}

# --- Find file by ID (prefix match) ---
_yft_find_file() {
  local id="$1"
  [[ -z "$id" ]] && return 1

  local dirs=("$_YFT_ROOT/tasks" "$_YFT_ROOT/chronicler" "$_YFT_ROOT/archivist"
              "$_YFT_ROOT/issues" "$_YFT_ROOT/todos" "$_YFT_ROOT/molecules")

  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue

    # Exact match first (includes subdirectories for epics)
    local exact
    exact=$(find "$dir" -name "${id}.json" -print -quit 2>/dev/null)
    if [[ -n "$exact" ]]; then
      echo "$exact"
      return 0
    fi

    # Check for _epic.json inside an epic directory named by the ID
    if [[ -d "$dir/$id" && -f "$dir/$id/_epic.json" ]]; then
      echo "$dir/$id/_epic.json"
      return 0
    fi

    # Prefix match (for shortened IDs)
    local match
    match=$(find "$dir" -name "${id}*.json" -print 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  done

  return 1
}

# --- Atomic write with temp file ---
_yft_atomic_write() {
  local dest="$1"
  local content="$2"
  local tmp
  tmp=$(mktemp)
  echo "$content" > "$tmp"
  mv "$tmp" "$dest"
}

# --- Generate next child index for an epic ---
_yft_next_child_idx() {
  local epic_dir="$1"
  local parent_id="$2"
  local count=0
  if [[ -d "$epic_dir" ]]; then
    count=$(find "$epic_dir" -maxdepth 1 -name "${parent_id}.*.json" 2>/dev/null | wc -l | tr -d ' ')
  fi
  printf '%02d' $((count + 1))
}

# ═══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════

# --- yft_create ---
# Create a new entity.
# Args: --type=<type> --title=<t> [--description=<d>] [--design=<d>]
#       [--acceptance=<a>] [--notes=<n>] [--parent=<id>] [-l <labels>]
#       [--priority=<p>] [--defer=<duration>] [--silent] [--body=<b>]
# Output: new ID (unless --silent)
yft_create() {
  _yft_ensure_dirs

  local type="" title="" description="" design="" acceptance="" notes=""
  local parent="" labels="" priority="3" defer="" silent=false body=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type=*)       type="${1#--type=}"; shift ;;
      --type)         type="$2"; shift 2 ;;
      --title=*)      title="${1#--title=}"; shift ;;
      --title)        title="$2"; shift 2 ;;
      --description=*) description="${1#--description=}"; shift ;;
      --description)  description="$2"; shift 2 ;;
      --design=*)     design="${1#--design=}"; shift ;;
      --design)       design="$2"; shift 2 ;;
      --acceptance=*) acceptance="${1#--acceptance=}"; shift ;;
      --acceptance)   acceptance="$2"; shift 2 ;;
      --notes=*)      notes="${1#--notes=}"; shift ;;
      --notes)        notes="$2"; shift 2 ;;
      --parent=*)     parent="${1#--parent=}"; shift ;;
      --parent)       parent="$2"; shift 2 ;;
      -l|--labels)    labels="$2"; shift 2 ;;
      --labels=*)     labels="${1#--labels=}"; shift ;;
      --priority=*)   priority="${1#--priority=}"; shift ;;
      --priority)     priority="$2"; shift 2 ;;
      --defer=*)      defer="${1#--defer=}"; shift ;;
      --defer)        defer="$2"; shift 2 ;;
      --body=*)       body="${1#--body=}"; shift ;;
      --body)         body="$2"; shift 2 ;;
      --silent)       silent=true; shift ;;
      *)              shift ;;
    esac
  done

  [[ -z "$type" ]] && type="task"
  [[ -z "$title" ]] && { echo "Error: --title is required" >&2; return 1; }

  # Use body as description fallback
  [[ -z "$description" && -n "$body" ]] && description="$body"

  local dir prefix id
  dir=$(_yft_type_dir "$type")
  prefix=$(_yft_type_prefix "$type")

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Parse labels into JSON array
  local labels_json="[]"
  if [[ -n "$labels" ]]; then
    labels_json=$(echo "$labels" | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0))')
  fi

  local status="open"
  local deferred=false
  if [[ -n "$defer" && "$defer" != "" ]]; then
    deferred=true
    status="deferred"
  fi

  if [[ -n "$parent" ]]; then
    # Child task — goes inside parent's epic directory
    local epic_dir="$dir/$parent"
    mkdir -p "$epic_dir" 2>/dev/null || true

    # Ensure parent _epic.json exists
    if [[ ! -f "$epic_dir/_epic.json" ]]; then
      # Check if parent file exists as a flat file and promote it
      local parent_flat="$dir/${parent}.json"
      if [[ -f "$parent_flat" ]]; then
        mv "$parent_flat" "$epic_dir/_epic.json"
      fi
    fi

    local child_idx
    child_idx=$(_yft_next_child_idx "$epic_dir" "$parent")
    id="${parent}.${child_idx}"
    local filepath="$epic_dir/${id}.json"

    local json
    json=$(jq -n \
      --arg id "$id" \
      --arg type "$type" \
      --arg title "$title" \
      --arg status "$status" \
      --argjson priority "${priority:-3}" \
      --arg description "$description" \
      --arg design "$design" \
      --arg acceptance "$acceptance" \
      --arg notes "$notes" \
      --argjson labels "$labels_json" \
      --arg parent "$parent" \
      --argjson deferred "$deferred" \
      --arg created "$now" \
      --arg updated "$now" \
      '{
        id: $id, type: $type, title: $title, status: $status,
        priority: $priority, description: $description, design: $design,
        acceptance: $acceptance, notes: $notes, labels: $labels,
        parent: $parent, dependencies: [], deferred: $deferred,
        comments: [], created: $created, updated: $updated,
        closed_at: null, close_reason: null
      }')

    _yft_atomic_write "$filepath" "$json"
    $silent || echo "$id"
    return 0
  fi

  # Top-level epic
  if [[ "$type" == "epic" ]]; then
    id=$(yf_generate_id "$prefix" "$dir")
    local epic_dir="$dir/$id"
    mkdir -p "$epic_dir" 2>/dev/null || true

    local json
    json=$(jq -n \
      --arg id "$id" \
      --arg title "$title" \
      --arg status "$status" \
      --argjson priority "${priority:-3}" \
      --arg description "$description" \
      --arg design "$design" \
      --arg acceptance "$acceptance" \
      --arg notes "$notes" \
      --argjson labels "$labels_json" \
      --argjson deferred "$deferred" \
      --arg created "$now" \
      --arg updated "$now" \
      '{
        id: $id, type: "epic", title: $title, status: $status,
        priority: $priority, description: $description, design: $design,
        acceptance: $acceptance, notes: $notes, labels: $labels,
        parent: null, dependencies: [], deferred: $deferred,
        comments: [], created: $created, updated: $updated,
        closed_at: null, close_reason: null
      }')

    _yft_atomic_write "$epic_dir/_epic.json" "$json"
    $silent || echo "$id"
    return 0
  fi

  # Gate
  if [[ "$type" == "gate" ]]; then
    id=$(yf_generate_id "$prefix" "$dir")

    local json
    json=$(jq -n \
      --arg id "$id" \
      --arg title "$title" \
      --argjson priority "${priority:-3}" \
      --arg description "$description" \
      --argjson labels "$labels_json" \
      --arg parent "${parent:-}" \
      --arg created "$now" \
      --arg updated "$now" \
      '{
        id: $id, type: "gate", title: $title, status: "open",
        priority: $priority, description: $description,
        labels: $labels, parent: $parent, dependencies: [],
        deferred: false, comments: [], resolved: false,
        resolve_reason: null, created: $created, updated: $updated,
        closed_at: null, close_reason: null
      }')

    # If parent is an epic, put gate in its directory
    local filepath="$dir/${id}.json"
    if [[ -n "$parent" && -d "$dir/$parent" ]]; then
      filepath="$dir/$parent/${id}.json"
    fi

    _yft_atomic_write "$filepath" "$json"
    $silent || echo "$id"
    return 0
  fi

  # Regular entity (task, chronicle, archive, issue, todo)
  id=$(yf_generate_id "$prefix" "$dir")
  local filepath="$dir/${id}.json"

  local json
  json=$(jq -n \
    --arg id "$id" \
    --arg type "$type" \
    --arg title "$title" \
    --arg status "$status" \
    --argjson priority "${priority:-3}" \
    --arg description "$description" \
    --arg design "$design" \
    --arg acceptance "$acceptance" \
    --arg notes "$notes" \
    --argjson labels "$labels_json" \
    --argjson deferred "$deferred" \
    --arg created "$now" \
    --arg updated "$now" \
    '{
      id: $id, type: $type, title: $title, status: $status,
      priority: $priority, description: $description, design: $design,
      acceptance: $acceptance, notes: $notes, labels: $labels,
      parent: null, dependencies: [], deferred: $deferred,
      comments: [], created: $created, updated: $updated,
      closed_at: null, close_reason: null
    }')

  _yft_atomic_write "$filepath" "$json"
  $silent || echo "$id"
}

# --- yft_show ---
# Display entity details.
# Args: <id> [--json] [--comments]
yft_show() {
  local id="$1"; shift
  local json_mode=false comments_mode=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)     json_mode=true; shift ;;
      --comments) comments_mode=true; shift ;;
      *)          shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  if $json_mode; then
    cat "$file"
  elif $comments_mode; then
    jq -r '.comments[] | "\(.timestamp) [\(.protocol)]: \(.content)"' "$file" 2>/dev/null
  else
    jq -r '
      "ID: \(.id)",
      "Type: \(.type)",
      "Title: \(.title)",
      "Status: \(.status)",
      "Priority: \(.priority)",
      "Labels: \(.labels | join(", "))",
      "Parent: \(.parent // "none")",
      "Dependencies: \(.dependencies | join(", "))",
      "Deferred: \(.deferred)",
      "Created: \(.created)",
      "Updated: \(.updated)",
      "",
      "Description:",
      (.description // ""),
      "",
      if (.design // "") != "" then "Design:\n\(.design)\n" else "" end,
      if (.acceptance // "") != "" then "Acceptance:\n\(.acceptance)\n" else "" end,
      if (.notes // "") != "" then "Notes:\n\(.notes)\n" else "" end,
      if (.comments | length) > 0 then
        "Comments (\(.comments | length)):",
        (.comments[] | "  [\(.protocol)] \(.content)")
      else "" end
    ' "$file" 2>/dev/null
  fi
}

# --- yft_update ---
# Modify entity fields.
# Args: <id> [--status=<s>] [--defer=<duration>] [-l <labels>] [--claim]
yft_update() {
  local id="$1"; shift
  local status="" defer="" labels="" claim=false title="" description=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status=*)      status="${1#--status=}"; shift ;;
      --status)        status="$2"; shift 2 ;;
      --defer=*)       defer="${1#--defer=}"; shift ;;
      --defer)         defer="$2"; shift 2 ;;
      -l|--labels)     labels="$2"; shift 2 ;;
      --labels=*)      labels="${1#--labels=}"; shift ;;
      --claim)         claim=true; shift ;;
      --title=*)       title="${1#--title=}"; shift ;;
      --title)         title="$2"; shift 2 ;;
      --description=*) description="${1#--description=}"; shift ;;
      --description)   description="$2"; shift 2 ;;
      *)               shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  # Build a single jq filter + args array for all mutations
  local jq_filter=". "
  local jq_args=()

  if [[ -n "$status" ]]; then
    jq_args+=(--arg s "$status")
    jq_filter+='| .status = $s '
  fi

  if [[ "$claim" == "true" ]]; then
    jq_filter+='| .status = "in_progress" '
  fi

  if [[ -n "$defer" ]]; then
    if [[ "$defer" == "" || "$defer" == "false" || "$defer" == "null" ]]; then
      jq_filter+='| .deferred = false | .status = "open" '
    else
      jq_filter+='| .deferred = true | .status = "deferred" '
    fi
  fi

  if [[ -n "$labels" ]]; then
    local labels_json
    labels_json=$(echo "$labels" | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0))')
    jq_args+=(--argjson l "$labels_json")
    jq_filter+='| .labels = $l '
  fi

  if [[ -n "$title" ]]; then
    jq_args+=(--arg t "$title")
    jq_filter+='| .title = $t '
  fi

  if [[ -n "$description" ]]; then
    jq_args+=(--arg d "$description")
    jq_filter+='| .description = $d '
  fi

  jq_args+=(--arg now "$now")
  jq_filter+='| .updated = $now'

  jq "${jq_args[@]}" "$jq_filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_close ---
# Close an entity.
# Args: <id> [--reason=<r>] [-r <reason>]
yft_close() {
  local id="$1"; shift
  local reason=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason=*) reason="${1#--reason=}"; shift ;;
      --reason|-r) reason="$2"; shift 2 ;;
      *)          shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  jq --arg now "$now" --arg reason "$reason" '
    .status = "closed" |
    .updated = $now |
    .closed_at = $now |
    .close_reason = $reason
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_delete ---
# Remove entity file(s).
# Args: <id> [<id2> ...] [--force]
yft_delete() {
  local ids=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) shift ;;
      *)       ids+=("$1"); shift ;;
    esac
  done

  for id in "${ids[@]}"; do
    local file
    file=$(_yft_find_file "$id") || continue

    # If it's an _epic.json, remove the whole epic directory
    if [[ "$(basename "$file")" == "_epic.json" ]]; then
      rm -rf "$(dirname "$file")"
    else
      rm -f "$file"
    fi
  done
}

# --- yft_list ---
# List entities with filters.
# Args: [--type=<t>] [--status=<s>] [-l <labels>] [--ready] [--limit=<n>]
#       [--json] [--sort=<field>] [--reverse] [--format=json]
yft_list() {
  local type="" status="" label_arg="" ready=false limit="" json_mode=false
  local sort_field="created" reverse=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type=*)    type="${1#--type=}"; shift ;;
      --type)      type="$2"; shift 2 ;;
      --status=*)  status="${1#--status=}"; shift ;;
      --status)    status="$2"; shift 2 ;;
      -l|--label|--labels) label_arg="$2"; shift 2 ;;
      --label=*)   label_arg="${1#--label=}"; shift ;;
      --labels=*)  label_arg="${1#--labels=}"; shift ;;
      --ready)     ready=true; shift ;;
      --limit=*)   limit="${1#--limit=}"; shift ;;
      --limit)     limit="$2"; shift 2 ;;
      --json|--format=json) json_mode=true; shift ;;
      --format=*)  shift ;;
      --sort=*)    sort_field="${1#--sort=}"; shift ;;
      --sort)      sort_field="$2"; shift 2 ;;
      --reverse)   reverse=true; shift ;;
      *)           shift ;;
    esac
  done

  # Determine which directories to search
  local search_dirs=()
  if [[ -n "$type" ]]; then
    local tdir
    tdir=$(_yft_type_dir "$type")
    search_dirs=("$tdir")
  else
    search_dirs=("$_YFT_ROOT/tasks" "$_YFT_ROOT/chronicler" "$_YFT_ROOT/archivist"
                 "$_YFT_ROOT/issues" "$_YFT_ROOT/todos" "$_YFT_ROOT/molecules")
  fi

  # Collect all JSON files
  local all_files=""
  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    local found
    found=$(find "$dir" -name '*.json' -print 2>/dev/null)
    [[ -n "$found" ]] && all_files="$all_files"$'\n'"$found"
  done

  all_files=$(echo "$all_files" | sed '/^$/d')

  if [[ -z "$all_files" ]]; then
    $json_mode && echo "[]" || true
    return 0
  fi

  # Build jq filter
  local filter="."

  if [[ -n "$type" ]]; then
    filter="$filter | select(.type == \"$type\")"
  fi

  if [[ -n "$status" ]]; then
    filter="$filter | select(.status == \"$status\")"
  fi

  if [[ -n "$label_arg" ]]; then
    # Support comma-separated labels (all must match)
    local old_ifs="$IFS"
    IFS=','
    for lbl in $label_arg; do
      filter="$filter | select((.labels // []) | any(. == \"$lbl\"))"
    done
    IFS="$old_ifs"
  fi

  if $ready; then
    filter="$filter | select(.status == \"open\" and (.deferred == false or .deferred == null))"
  fi

  # Merge all files, apply filter, sort, limit
  local result
  result=$(
    echo "$all_files" | while IFS= read -r f; do
      [[ -n "$f" && -f "$f" ]] && cat "$f"
    done | jq -s "[ .[] | $filter ]" 2>/dev/null
  ) || result="[]"

  # Filter out items with unresolved dependencies if --ready
  if $ready; then
    result=$(echo "$result" | jq '
      . as $all |
      [ .[] | select(
        (.dependencies | length == 0) or
        (.dependencies | all(. as $dep |
          ($all | any(.id == $dep and .status == "closed"))
        ))
      )]
    ' 2>/dev/null) || true
  fi

  # Sort
  if [[ -n "$sort_field" ]]; then
    result=$(echo "$result" | jq --arg f "$sort_field" 'sort_by(.[$f])' 2>/dev/null) || true
  fi

  if $reverse; then
    result=$(echo "$result" | jq 'reverse' 2>/dev/null) || true
  fi

  # Limit (0 = unlimited)
  if [[ -n "$limit" && "$limit" != "0" ]]; then
    result=$(echo "$result" | jq --argjson n "$limit" '.[:$n]' 2>/dev/null) || true
  fi

  if $json_mode; then
    echo "$result"
  else
    echo "$result" | jq -r '.[] | "\(.id): \(.title) [\(.status)]"' 2>/dev/null
  fi
}

# --- yft_count ---
# Count matching entities.
# Args: [--type=<t>] [--status=<s>] [-l <labels>]
yft_count() {
  local result
  result=$(yft_list "$@" --json)
  echo "$result" | jq 'length' 2>/dev/null || echo "0"
}

# --- yft_label_list ---
# List labels for an entity.
# Args: <id> [--json]
yft_label_list() {
  local id="$1"; shift
  local json_mode=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode=true; shift ;;
      *)      shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  if $json_mode; then
    jq '.labels // []' "$file" 2>/dev/null || echo "[]"
  else
    jq -r '(.labels // [])[]' "$file" 2>/dev/null
  fi
}

# --- yft_label_add ---
# Add a label to an entity.
# Args: <id> <label>
yft_label_add() {
  local id="$1"
  local label="$2"

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  local tmp
  tmp=$(mktemp)
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq --arg lbl "$label" --arg now "$now" '
    .labels = ((.labels // []) + [$lbl] | unique) |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_label_remove ---
# Remove a label from an entity.
# Args: <id> <label>
yft_label_remove() {
  local id="$1"
  local label="$2"

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  local tmp
  tmp=$(mktemp)
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq --arg lbl "$label" --arg now "$now" '
    .labels = [(.labels // [])[] | select(. != $lbl)] |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_dep_add ---
# Add a dependency.
# Args: <dependent_id> <dependency_id>
yft_dep_add() {
  local dependent="$1"
  local dependency="$2"

  local file
  file=$(_yft_find_file "$dependent") || { echo "Error: entity $dependent not found" >&2; return 1; }

  local tmp
  tmp=$(mktemp)
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq --arg dep "$dependency" --arg now "$now" '
    .dependencies = ((.dependencies // []) + [$dep] | unique) |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_comment ---
# Add a comment to an entity.
# Args: <id> "<protocol>: <content>"
yft_comment() {
  local id="$1"
  local raw_comment="$2"

  local file
  file=$(_yft_find_file "$id") || { echo "Error: entity $id not found" >&2; return 1; }

  # Parse protocol and content from "PROTOCOL: content"
  local protocol content
  protocol="${raw_comment%%:*}"
  content="${raw_comment#*: }"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  jq --arg ts "$now" --arg proto "$protocol" --arg content "$content" --arg now "$now" '
    .comments = ((.comments // []) + [{
      timestamp: $ts,
      protocol: $proto,
      content: $content
    }]) |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_gate_list ---
# List open gates.
# Args: [--json]
yft_gate_list() {
  local json_mode=false
  [[ "${1:-}" == "--json" ]] && json_mode=true

  if $json_mode; then
    yft_list --type=gate --status=open --json
  else
    yft_list --type=gate --status=open
  fi
}

# --- yft_gate_resolve ---
# Resolve a gate.
# Args: <id> --reason=<r>
yft_gate_resolve() {
  local id="$1"; shift
  local reason=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason=*) reason="${1#--reason=}"; shift ;;
      --reason)   reason="$2"; shift 2 ;;
      *)          shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: gate $id not found" >&2; return 1; }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  jq --arg now "$now" --arg reason "$reason" '
    .resolved = true |
    .resolve_reason = $reason |
    .status = "closed" |
    .closed_at = $now |
    .close_reason = $reason |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_mol_wisp ---
# Create a molecule (swarm wisp).
# Args: <formula_path> --var key=val [--var key=val ...]
yft_mol_wisp() {
  _yft_ensure_dirs

  local formula_path="$1"; shift
  local vars=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --var)  vars+=("$2"); shift 2 ;;
      --var=*) vars+=("${1#--var=}"); shift ;;
      *)      shift ;;
    esac
  done

  local mol_dir="$_YFT_ROOT/molecules"
  local id
  id=$(yf_generate_id "mol" "$mol_dir")

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read formula file to get steps
  local formula_json="{}"
  if [[ -f "$formula_path" ]]; then
    formula_json=$(cat "$formula_path")
    if ! echo "$formula_json" | jq empty 2>/dev/null; then
      echo "Error: invalid formula JSON: $formula_path" >&2
      formula_json='{}'
    fi
  fi

  # Build vars object — single jq call with indexed args
  local vars_json="{}"
  if [[ ${#vars[@]} -gt 0 ]]; then
    local var_args=()
    local var_filter=". "
    local i=0
    for v in "${vars[@]}"; do
      local key="${v%%=*}"
      local val="${v#*=}"
      var_args+=(--arg "k${i}" "$key" --arg "v${i}" "$val")
      var_filter+="| . + {(\$k${i}): \$v${i}} "
      i=$((i + 1))
    done
    vars_json=$(echo '{}' | jq "${var_args[@]}" "$var_filter")
  fi

  # Build molecule JSON with steps from formula
  local steps_json
  steps_json=$(echo "$formula_json" | jq -c '.steps // []' 2>/dev/null)
  if [[ -z "$steps_json" ]]; then
    steps_json="[]"
  fi

  local json
  json=$(jq -n \
    --arg id "$id" \
    --argjson formula "$formula_json" \
    --argjson vars "$vars_json" \
    --argjson steps "$steps_json" \
    --arg created "$now" \
    --arg updated "$now" \
    '{
      id: $id, type: "molecule",
      formula: ($formula | .name // "unknown"),
      formula_def: $formula,
      vars: $vars,
      steps: [$steps[] | . + {status: "pending", started_at: null, closed_at: null}],
      status: "active", labels: [],
      squashed_at: null, squash_summary: null,
      created: $created, updated: $updated
    }')

  _yft_atomic_write "$mol_dir/${id}.json" "$json"
  echo "$id"
}

# --- yft_mol_step_close ---
# Close a step in a molecule.
# Args: <mol_id> <step_index_or_name>
yft_mol_step_close() {
  local mol_id="$1"
  local step="$2"

  local file
  file=$(_yft_find_file "$mol_id") || { echo "Error: molecule $mol_id not found" >&2; return 1; }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  if [[ "$step" =~ ^[0-9]+$ ]]; then
    jq --argjson idx "$step" --arg now "$now" '
      .steps[$idx].status = "closed" |
      .steps[$idx].closed_at = $now |
      .updated = $now
    ' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    jq --arg name "$step" --arg now "$now" '
      .steps = [.steps[] | if .name == $name then .status = "closed" | .closed_at = $now else . end] |
      .updated = $now
    ' "$file" > "$tmp" && mv "$tmp" "$file"
  fi
}

# --- yft_mol_squash ---
# Squash a molecule (mark complete with summary).
# Args: <id> --summary=<s>
yft_mol_squash() {
  local id="$1"; shift
  local summary=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --summary=*) summary="${1#--summary=}"; shift ;;
      --summary)   summary="$2"; shift 2 ;;
      *)           shift ;;
    esac
  done

  local file
  file=$(_yft_find_file "$id") || { echo "Error: molecule $id not found" >&2; return 1; }

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp
  tmp=$(mktemp)

  jq --arg now "$now" --arg summary "$summary" '
    .status = "squashed" |
    .squashed_at = $now |
    .squash_summary = $summary |
    .updated = $now
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- yft_cleanup ---
# Clean up old closed entities.
# Args: [--older-than <days>] [--ephemeral] [--dry-run] [--force]
yft_cleanup() {
  local days=7 ephemeral=false dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --older-than) days="$2"; shift 2 ;;
      --ephemeral)  ephemeral=true; shift ;;
      --dry-run)    dry_run=true; shift ;;
      --force)      shift ;;
      *)            shift ;;
    esac
  done

  local threshold_epoch
  threshold_epoch=$(date -v-"${days}"d +%s 2>/dev/null || date -d "-${days} days" +%s 2>/dev/null || echo "0")
  local cleaned=0

  if $ephemeral; then
    # Clean squashed molecules
    local mol_dir="$_YFT_ROOT/molecules"
    if [[ -d "$mol_dir" ]]; then
      for f in "$mol_dir"/*.json; do
        [[ -f "$f" ]] || continue
        local mol_status
        mol_status=$(jq -r '.status' "$f" 2>/dev/null)
        if [[ "$mol_status" == "squashed" ]]; then
          if $dry_run; then
            echo "Would remove: $(basename "$f")"
          else
            rm -f "$f"
          fi
          cleaned=$((cleaned + 1))
        fi
      done
    fi
  else
    # Clean closed entities older than threshold
    local dirs=("$_YFT_ROOT/tasks" "$_YFT_ROOT/chronicler" "$_YFT_ROOT/archivist"
                "$_YFT_ROOT/issues" "$_YFT_ROOT/todos")
    for dir in "${dirs[@]}"; do
      [[ -d "$dir" ]] || continue
      while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        local fstatus closed_at
        fstatus=$(jq -r '.status' "$f" 2>/dev/null)
        [[ "$fstatus" == "closed" ]] || continue
        closed_at=$(jq -r '.closed_at // empty' "$f" 2>/dev/null)
        [[ -n "$closed_at" ]] || continue

        local closed_epoch
        closed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${closed_at%%.*}" +%s 2>/dev/null \
          || date -d "$closed_at" +%s 2>/dev/null || echo "99999999999")

        if [[ "$closed_epoch" -lt "$threshold_epoch" ]]; then
          if $dry_run; then
            echo "Would remove: $f"
          else
            rm -f "$f"
          fi
          cleaned=$((cleaned + 1))
        fi
      done < <(find "$dir" -name '*.json' -print 2>/dev/null)
    done
  fi

  echo "$cleaned issues cleaned"
}
