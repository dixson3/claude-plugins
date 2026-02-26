#!/bin/bash
# session-prune.sh — Dynamic cleanup of stale artifacts at session close
#
# Usage:
#   session-prune.sh tasks [--dry-run]            # Clean stale closed tasks
#   session-prune.sh ephemeral [--dry-run]        # Remove stale .yoshiko-flow/ files
#   session-prune.sh drafts [--dry-run]           # Close stale auto-generated drafts
#   session-prune.sh completed-plans [--dry-run]  # Close orphaned gates, completed epics, remove closed chronicles
#   session-prune.sh all [--dry-run]              # Run all in sequence
#
# Fail-open (exit 0 always). Config-gated via auto_prune.on_session_close.
# Compatible with bash 3.2+ (macOS default).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"
. "$SCRIPT_DIR/yf-tasks.sh"

COMMAND="${1:-}"
DRY_RUN=false

# Parse --dry-run from any position
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ -z "$COMMAND" ]; then
  echo "Usage: session-prune.sh <tasks|ephemeral|drafts|completed-plans|all> [--dry-run]" >&2
  exit 0
fi

# Config guard
yf_is_prune_on_session_close 2>/dev/null || { echo "Session prune disabled by config"; exit 0; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
YF_DIR="$PROJECT_DIR/.yoshiko-flow"
TODAY=$(date +%Y%m%d)

# Read older_than_days from config (default: 7)
get_older_than_days() {
  local days
  days=$(yf_read_field '.config.auto_prune.older_than_days' 2>/dev/null)
  if [ -z "$days" ] || [ "$days" = "null" ]; then
    echo "7"
  else
    echo "$days"
  fi
}

do_tasks() {
  DAYS=$(get_older_than_days)

  if [ "$DRY_RUN" = "true" ]; then
    echo "Dry run: would run tasks cleanup (older than $DAYS days):"
    yft_cleanup --older-than "$DAYS" --dry-run 2>/dev/null || true
    echo ""
    echo "Dry run: would clean ephemeral wisps:"
    yft_cleanup --ephemeral --dry-run 2>/dev/null || true
    return 0
  fi

  RESULT=$(yft_cleanup --older-than "$DAYS" 2>&1 || true)
  CLEANED=$(echo "$RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

  WISP_RESULT=$(yft_cleanup --ephemeral 2>&1 || true)
  WISPS=$(echo "$WISP_RESULT" | grep -oE '[0-9]+ issue' | head -1 | grep -oE '[0-9]+' || echo "0")

  echo "session-prune tasks: $CLEANED tasks cleaned, $WISPS ephemeral cleaned (threshold: ${DAYS}d)"
}

do_ephemeral() {
  if [ ! -d "$YF_DIR" ]; then
    echo "session-prune ephemeral: no .yoshiko-flow directory, skipping"
    return 0
  fi

  # Protected files — never remove these
  # config.json, .gitignore, lock.json, plan-gate, task-pump.json, formula-state.json

  local removed=0

  # Remove date-stamped files where date != today
  for pattern in ".chronicle-drafted-" ".chronicle-staleness-" ".chronicle-transition-" ".chronicle-plan-"; do
    for f in "$YF_DIR"/${pattern}*; do
      [ -f "$f" ] || continue
      local basename
      basename=$(basename "$f")
      # Extract date suffix (last 8 chars should be YYYYMMDD)
      local date_suffix="${basename##*-}"
      if [ "$date_suffix" != "$TODAY" ]; then
        if [ "$DRY_RUN" = "true" ]; then
          echo "Dry run: would remove $basename (stale date: $date_suffix)"
        else
          rm -f "$f"
        fi
        removed=$((removed + 1))
      fi
    done
  done

  # Remove session sentinels (always, regardless of date)
  for sentinel in ".chronicle-nudge" ".tasks-check-cache" "plan-chronicle-ok" "plan-intake-ok" "plan-intake-skip"; do
    if [ -f "$YF_DIR/$sentinel" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run: would remove $sentinel (session sentinel)"
      else
        rm -f "$YF_DIR/$sentinel"
      fi
      removed=$((removed + 1))
    fi
  done

  echo "session-prune ephemeral: $removed files cleaned"
}

do_drafts() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "session-prune drafts: jq not available, skipping"
    return 0
  fi

  # Query open chronicle drafts
  local drafts
  drafts=$(yft_list -l "ys:chronicle,ys:chronicle:draft" --status=open --json 2>/dev/null || echo "[]")

  local now_epoch
  now_epoch=$(date +%s)
  local threshold=$((24 * 60 * 60))  # 24 hours in seconds
  local closed=0

  # Iterate over drafts, close any older than 24 hours
  local ids
  ids=$(echo "$drafts" | jq -r '.[] | .id' 2>/dev/null || true)
  if [ -z "$ids" ]; then
    echo "session-prune drafts: no stale drafts found"
    return 0
  fi

  echo "$ids" | while IFS= read -r id; do
    [ -z "$id" ] && continue
    local created
    created=$(echo "$drafts" | jq -r --arg id "$id" '.[] | select(.id == $id) | .created // empty' 2>/dev/null || true)
    if [ -z "$created" ]; then
      continue
    fi

    # Parse ISO timestamp to epoch (portable: try date -d first, fallback to date -j)
    local created_epoch
    created_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${created%%.*}" +%s 2>/dev/null || \
                    date -d "$created" +%s 2>/dev/null || echo "0")

    local age=$((now_epoch - created_epoch))
    if [ "$age" -gt "$threshold" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run: would close $id (age: $((age / 3600))h)"
      else
        yft_close "$id" --reason="session-prune: stale auto-generated draft (>24h)" 2>/dev/null || true
      fi
      closed=$((closed + 1))
    fi
  done

  echo "session-prune drafts: $closed stale drafts closed"
}

do_completed_plans() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "session-prune completed-plans: jq not available, skipping"
    return 0
  fi

  local cleaned=0

  # 1. Close orphaned gates (ys:chronicle-gate or ys:qualification-gate)
  #    whose sibling work tasks (same parent epic) are all closed
  local gates
  gates=$(yft_list --type=gate --status=open --json 2>/dev/null || echo "[]")
  local gate_ids
  gate_ids=$(echo "$gates" | jq -r '.[] | select((.labels // []) | any(. == "ys:chronicle-gate" or . == "ys:qualification-gate")) | .id' 2>/dev/null || true)

  local gid
  for gid in $gate_ids; do
    [ -z "$gid" ] && continue
    # Find the gate's parent epic
    local parent
    parent=$(echo "$gates" | jq -r --arg id "$gid" '.[] | select(.id == $id) | .parent // empty' 2>/dev/null || true)
    [ -z "$parent" ] && continue

    # Check if all non-gate siblings in this epic are closed
    local epic_dir="$YF_DIR/tasks/$parent"
    [ -d "$epic_dir" ] || continue

    local has_open_sibling=false
    for f in "$epic_dir"/*.json; do
      [ -f "$f" ] || continue
      [ "$(basename "$f")" = "_epic.json" ] && continue
      local fid fstatus ftype
      fid=$(jq -r '.id // empty' "$f" 2>/dev/null || true)
      [ "$fid" = "$gid" ] && continue
      fstatus=$(jq -r '.status // "open"' "$f" 2>/dev/null || true)
      ftype=$(jq -r '.type // "task"' "$f" 2>/dev/null || true)
      # Skip gates (by type or by label)
      [ "$ftype" = "gate" ] && continue
      local is_gate_task
      is_gate_task=$(jq -r '(.labels // []) | any(. == "ys:chronicle-gate" or . == "ys:qualification-gate")' "$f" 2>/dev/null || echo "false")
      [ "$is_gate_task" = "true" ] && continue
      if [ "$fstatus" != "closed" ]; then
        has_open_sibling=true
        break
      fi
    done

    if [ "$has_open_sibling" = "false" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run: would close orphaned gate $gid"
      else
        yft_close "$gid" --reason="session-prune: all sibling work tasks closed" 2>/dev/null || true
      fi
      cleaned=$((cleaned + 1))
    fi
  done

  # 2. Close completed plan epics (open epics with plan:* label, all children closed)
  local epics_dir="$YF_DIR/tasks"
  if [ -d "$epics_dir" ]; then
    for epic_dir in "$epics_dir"/*/; do
      [ -d "$epic_dir" ] || continue
      [ -f "$epic_dir/_epic.json" ] || continue

      local epic_status
      epic_status=$(jq -r '.status // "open"' "$epic_dir/_epic.json" 2>/dev/null || true)
      [ "$epic_status" != "open" ] && continue

      # Check for plan:* label
      local has_plan_label
      has_plan_label=$(jq -r '(.labels // []) | any(startswith("plan:"))' "$epic_dir/_epic.json" 2>/dev/null || echo "false")
      [ "$has_plan_label" != "true" ] && continue

      # Check if all child tasks are closed
      local has_open_child=false
      for f in "$epic_dir"/*.json; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "_epic.json" ] && continue
        local cstatus
        cstatus=$(jq -r '.status // "open"' "$f" 2>/dev/null || true)
        if [ "$cstatus" != "closed" ]; then
          has_open_child=true
          break
        fi
      done

      if [ "$has_open_child" = "false" ]; then
        local epic_id
        epic_id=$(jq -r '.id // empty' "$epic_dir/_epic.json" 2>/dev/null || true)
        if [ "$DRY_RUN" = "true" ]; then
          echo "Dry run: would close completed plan epic $epic_id"
        else
          yft_close "$epic_id" --reason="session-prune: all tasks completed" 2>/dev/null || true
        fi
        cleaned=$((cleaned + 1))
      fi
    done
  fi

  # 3. Remove closed chronicle files
  local chron_dir="$YF_DIR/chronicler"
  if [ -d "$chron_dir" ]; then
    for f in "$chron_dir"/*.json; do
      [ -f "$f" ] || continue
      local cstatus
      cstatus=$(jq -r '.status // "open"' "$f" 2>/dev/null || true)
      if [ "$cstatus" = "closed" ]; then
        if [ "$DRY_RUN" = "true" ]; then
          echo "Dry run: would remove closed chronicle $(basename "$f")"
        else
          rm -f "$f"
        fi
        cleaned=$((cleaned + 1))
      fi
    done
  fi

  echo "session-prune completed-plans: $cleaned artifacts cleaned"
}

case "$COMMAND" in
  tasks)
    do_tasks
    ;;
  ephemeral)
    do_ephemeral
    ;;
  drafts)
    do_drafts
    ;;
  completed-plans)
    do_completed_plans
    ;;
  all)
    "$0" tasks "$@" || true
    "$0" ephemeral "$@" || true
    "$0" drafts "$@" || true
    "$0" completed-plans "$@" || true
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Usage: session-prune.sh <tasks|ephemeral|drafts|completed-plans|all> [--dry-run]" >&2
    ;;
esac

exit 0
