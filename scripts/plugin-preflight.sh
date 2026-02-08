#!/bin/bash
# plugin-preflight.sh — Declarative artifact sync engine for Claude plugins
#
# Reads each plugin's artifacts manifest from plugin.json, compares against
# a lock file (.claude/yf.json under the "preflight" key), and installs/
# updates/removes artifacts as needed.
#
# Compatible with bash 3.2+ (macOS default).
#
# Environment:
#   CLAUDE_PROJECT_DIR — project root (required)
#
# Exits 0 always (fail-open). Warnings go to stderr.
set -uo pipefail

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "preflight: warn: CLAUDE_PROJECT_DIR ($PROJECT_DIR) not found" >&2
  exit 0
fi

LOCK_FILE="$PROJECT_DIR/.claude/yf.json"
OLD_LOCK_FILE="$PROJECT_DIR/.claude/plugin-lock.json"
MARKETPLACE_JSON="$MARKETPLACE_ROOT/.claude-plugin/marketplace.json"

if [ ! -f "$MARKETPLACE_JSON" ]; then
  echo "preflight: warn: marketplace.json not found at $MARKETPLACE_JSON" >&2
  exit 0
fi

# --- Helpers ---
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print "sha256:" $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print "sha256:" $1}'
  else
    echo "sha256:unknown"
  fi
}

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
  echo "preflight: warn: jq not found, skipping preflight" >&2
  exit 0
fi

# --- Migration: plugin-lock.json → yf.json ---
if [ ! -f "$LOCK_FILE" ] && [ -f "$OLD_LOCK_FILE" ]; then
  echo "preflight: migrating plugin-lock.json → yf.json"
  OLD_DATA=$(cat "$OLD_LOCK_FILE")
  # Wrap existing data under "preflight" key
  MIGRATED=$(echo "$OLD_DATA" | jq '{version: 1, updated: .updated, preflight: {plugins: .plugins}}')
  mkdir -p "$(dirname "$LOCK_FILE")"
  echo "$MIGRATED" | jq '.' > "$LOCK_FILE"
  rm -f "$OLD_LOCK_FILE"
fi

# --- Read marketplace plugin list ---
PLUGIN_COUNT=$(jq -r '.plugins | length' "$MARKETPLACE_JSON" 2>/dev/null)
if [ -z "$PLUGIN_COUNT" ] || [ "$PLUGIN_COUNT" = "0" ] || [ "$PLUGIN_COUNT" = "null" ]; then
  exit 0
fi

# --- Read lock file (may not exist) ---
# Extract the preflight.plugins subtree for compatibility with existing logic
LOCK="{}"
if [ -f "$LOCK_FILE" ]; then
  LOCK=$(jq '.preflight // {}' "$LOCK_FILE" 2>/dev/null || echo "{}")
fi

# --- Build plugin metadata arrays (bash 3 compatible) ---
# Parallel arrays: PNAMES[i], PDIRS[i], PDEPS[i]
PNAMES=()
PDIRS=()
PDEPS=()

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
  NAME=$(jq -r ".plugins[$i].name" "$MARKETPLACE_JSON" 2>/dev/null)
  SOURCE=$(jq -r ".plugins[$i].source" "$MARKETPLACE_JSON" 2>/dev/null)
  PLUGIN_DIR="$MARKETPLACE_ROOT/$SOURCE"
  PNAMES+=("$NAME")
  PDIRS+=("$PLUGIN_DIR")

  PPRE="$PLUGIN_DIR/.claude-plugin/preflight.json"
  if [ -f "$PPRE" ]; then
    DEPS=$(jq -r '(.dependencies // []) | join(",")' "$PPRE" 2>/dev/null)
    PDEPS+=("$DEPS")
  else
    PDEPS+=("")
  fi
done

# --- Topological sort (bash 3 compatible) ---
ORDERED=""  # space-separated indices
ADDED=""    # space-separated names already added

is_added() {
  local name="$1"
  case " $ADDED " in
    *" $name "*) return 0 ;;
    *) return 1 ;;
  esac
}

count_ordered() {
  if [ -z "$ORDERED" ]; then echo 0; else echo "$ORDERED" | wc -w | tr -d ' '; fi
}

MAX_ITER=$((PLUGIN_COUNT * PLUGIN_COUNT + 1))
ITER=0
while [ "$(count_ordered)" -lt "$PLUGIN_COUNT" ] && [ $ITER -lt $MAX_ITER ]; do
  ITER=$((ITER + 1))
  for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
    NAME="${PNAMES[$i]}"
    is_added "$NAME" && continue

    DEPS="${PDEPS[$i]}"
    ALL_MET=true
    if [ -n "$DEPS" ]; then
      IFS=',' read -r -a DEP_ARR <<< "$DEPS"
      for dep in "${DEP_ARR[@]}"; do
        [ -z "$dep" ] && continue
        if ! is_added "$dep"; then
          ALL_MET=false
          break
        fi
      done
    fi

    if $ALL_MET; then
      ORDERED="$ORDERED $i"
      ADDED="$ADDED $NAME"
    fi
  done
done

# --- Fast path: check if all versions + checksums match ---
FAST_PATH=true
for idx in $ORDERED; do
  NAME="${PNAMES[$idx]}"
  PLUGIN_DIR="${PDIRS[$idx]}"
  PJSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
  [ ! -f "$PJSON" ] && { FAST_PATH=false; break; }

  CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)
  LOCK_VER=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".version // \"\"" 2>/dev/null)
  if [ "$CUR_VER" != "$LOCK_VER" ]; then
    FAST_PATH=false
    break
  fi

  PPRE="$PLUGIN_DIR/.claude-plugin/preflight.json"
  RULE_COUNT=0
  if [ -f "$PPRE" ]; then
    RULE_COUNT=$(jq -r '(.artifacts.rules // []) | length' "$PPRE" 2>/dev/null)
    [ -z "$RULE_COUNT" ] && RULE_COUNT=0
  fi
  LOCK_RULE_COUNT=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".artifacts.rules | length" 2>/dev/null)
  [ -z "$LOCK_RULE_COUNT" ] && LOCK_RULE_COUNT=0
  if [ "$RULE_COUNT" != "$LOCK_RULE_COUNT" ]; then
    FAST_PATH=false; break
  fi
  j=0; while [ $j -lt "$RULE_COUNT" ] && $FAST_PATH; do
    SOURCE_REL=$(jq -r ".artifacts.rules[$j].source" "$PPRE" 2>/dev/null)
    TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)
    SOURCE_ABS="$PLUGIN_DIR/$SOURCE_REL"
    TARGET_ABS="$PROJECT_DIR/$TARGET_REL"

    if [ ! -f "$SOURCE_ABS" ] || [ ! -f "$TARGET_ABS" ]; then
      FAST_PATH=false; break
    fi

    CUR_CKSUM=$(sha256_file "$SOURCE_ABS")
    LOCK_CKSUM=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".artifacts.rules[] | select(.target == \"$TARGET_REL\") | .checksum // \"\"" 2>/dev/null)
    INSTALLED_CKSUM=$(sha256_file "$TARGET_ABS")

    if [ "$CUR_CKSUM" != "$LOCK_CKSUM" ] || [ "$INSTALLED_CKSUM" != "$LOCK_CKSUM" ]; then
      FAST_PATH=false; break
    fi
  j=$((j + 1)); done
  $FAST_PATH || break
done

if $FAST_PATH; then
  # Check for removed plugins
  LOCK_PLUGINS=$(echo "$LOCK" | jq -r '.plugins // {} | keys[]' 2>/dev/null)
  for LP in $LOCK_PLUGINS; do
    FOUND=false
    for n in "${PNAMES[@]}"; do
      [ "$n" = "$LP" ] && { FOUND=true; break; }
    done
    $FOUND || { FAST_PATH=false; break; }
  done
fi

if $FAST_PATH; then
  echo "preflight: up to date"
  exit 0
fi

# --- Full sync ---
SUMMARY_INSTALL=0
SUMMARY_UPDATE=0
SUMMARY_REMOVE=0
SUMMARY_SKIP=0
SUMMARY_DIR=0
SUMMARY_SETUP=0

# New lock structure with preflight nesting
NEW_LOCK_PLUGINS=$(jq -n '{plugins: {}}')

for idx in $ORDERED; do
  NAME="${PNAMES[$idx]}"
  PLUGIN_DIR="${PDIRS[$idx]}"
  PJSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
  PPRE="$PLUGIN_DIR/.claude-plugin/preflight.json"
  if [ ! -f "$PJSON" ]; then
    echo "preflight: warn: $NAME — plugin.json not found, skipping" >&2
    continue
  fi
  if [ ! -f "$PPRE" ]; then
    echo "preflight: warn: $NAME — preflight.json not found, skipping artifacts" >&2
  fi

  CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)
  PLUGIN_LOCK="{\"version\":\"$CUR_VER\",\"artifacts\":{\"rules\":[],\"directories\":[],\"setup\":[]}}"

  # --- Directories ---
  DIR_COUNT=0
  if [ -f "$PPRE" ]; then
    DIR_COUNT=$(jq -r '(.artifacts.directories // []) | length' "$PPRE" 2>/dev/null)
    [ -z "$DIR_COUNT" ] && DIR_COUNT=0
  fi
  j=0; while [ $j -lt "$DIR_COUNT" ]; do
    DIR_REL=$(jq -r ".artifacts.directories[$j]" "$PPRE" 2>/dev/null)
    DIR_ABS="$PROJECT_DIR/$DIR_REL"
    if [ ! -d "$DIR_ABS" ]; then
      mkdir -p "$DIR_ABS"
      SUMMARY_DIR=$((SUMMARY_DIR + 1))
      echo "preflight: $NAME — created $DIR_REL/"
    fi
    PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.directories += [\"$DIR_REL\"]")
  j=$((j + 1)); done

  # --- Setup commands ---
  SETUP_COUNT=0
  if [ -f "$PPRE" ]; then
    SETUP_COUNT=$(jq -r '(.artifacts.setup // []) | length' "$PPRE" 2>/dev/null)
    [ -z "$SETUP_COUNT" ] && SETUP_COUNT=0
  fi
  j=0; while [ $j -lt "$SETUP_COUNT" ]; do
    SETUP_NAME=$(jq -r ".artifacts.setup[$j].name" "$PPRE" 2>/dev/null)
    SETUP_CHECK=$(jq -r ".artifacts.setup[$j].check" "$PPRE" 2>/dev/null)
    SETUP_RUN=$(jq -r ".artifacts.setup[$j].run" "$PPRE" 2>/dev/null)

    # Check if already completed in lock
    LOCK_COMPLETED=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".artifacts.setup[]? | select(.name == \"$SETUP_NAME\") | .completed // false" 2>/dev/null)

    COMPLETED=false
    if [ "$LOCK_COMPLETED" = "true" ]; then
      if (cd "$PROJECT_DIR" && eval "$SETUP_CHECK") >/dev/null 2>&1; then
        COMPLETED=true
      fi
    fi

    if ! $COMPLETED; then
      if ! (cd "$PROJECT_DIR" && eval "$SETUP_CHECK") >/dev/null 2>&1; then
        echo "preflight: $NAME — running setup: $SETUP_NAME"
        if (cd "$PROJECT_DIR" && eval "$SETUP_RUN") >/dev/null 2>&1; then
          COMPLETED=true
          SUMMARY_SETUP=$((SUMMARY_SETUP + 1))
        else
          echo "preflight: warn: $NAME — setup '$SETUP_NAME' failed" >&2
        fi
      else
        COMPLETED=true
      fi
    fi

    PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.setup += [{\"name\": \"$SETUP_NAME\", \"completed\": $COMPLETED}]")
  j=$((j + 1)); done

  # --- Rules: install/update ---
  RULE_COUNT=0
  MANIFEST_TARGETS=""  # newline-separated
  if [ -f "$PPRE" ]; then
    RULE_COUNT=$(jq -r '(.artifacts.rules // []) | length' "$PPRE" 2>/dev/null)
    [ -z "$RULE_COUNT" ] && RULE_COUNT=0
  fi

  j=0; while [ $j -lt "$RULE_COUNT" ]; do
    SOURCE_REL=$(jq -r ".artifacts.rules[$j].source" "$PPRE" 2>/dev/null)
    TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)
    SOURCE_ABS="$PLUGIN_DIR/$SOURCE_REL"
    TARGET_ABS="$PROJECT_DIR/$TARGET_REL"
    MANIFEST_TARGETS="$MANIFEST_TARGETS
$TARGET_REL"

    if [ ! -f "$SOURCE_ABS" ]; then
      echo "preflight: warn: $NAME — source not found: $SOURCE_REL" >&2
      continue
    fi

    SOURCE_CKSUM=$(sha256_file "$SOURCE_ABS")

    if [ ! -f "$TARGET_ABS" ]; then
      # Install: missing on disk
      mkdir -p "$(dirname "$TARGET_ABS")"
      cp "$SOURCE_ABS" "$TARGET_ABS"
      SUMMARY_INSTALL=$((SUMMARY_INSTALL + 1))
      echo "preflight: $NAME — installed $TARGET_REL"
    else
      # Check if update needed
      LOCK_CKSUM=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".artifacts.rules[]? | select(.target == \"$TARGET_REL\") | .checksum // \"\"" 2>/dev/null)
      INSTALLED_CKSUM=$(sha256_file "$TARGET_ABS")

      if [ "$INSTALLED_CKSUM" = "$SOURCE_CKSUM" ]; then
        # Already up to date
        :
      elif [ -n "$LOCK_CKSUM" ] && [ "$INSTALLED_CKSUM" != "$LOCK_CKSUM" ]; then
        # User modified the file
        echo "preflight: $NAME — CONFLICT: $TARGET_REL modified by user, skipping update"
        SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
        SOURCE_CKSUM="$INSTALLED_CKSUM"
      else
        # Source changed, user hasn't modified → overwrite
        cp "$SOURCE_ABS" "$TARGET_ABS"
        SUMMARY_UPDATE=$((SUMMARY_UPDATE + 1))
        echo "preflight: $NAME — updated $TARGET_REL"
      fi
    fi

    PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.rules += [{\"target\": \"$TARGET_REL\", \"checksum\": \"$SOURCE_CKSUM\"}]")
  j=$((j + 1)); done

  # --- Rules: remove stale ---
  LOCK_RULE_TARGETS=$(echo "$LOCK" | jq -r ".plugins.\"$NAME\".artifacts.rules[]?.target // empty" 2>/dev/null)
  for OLD_TARGET in $LOCK_RULE_TARGETS; do
    [ -z "$OLD_TARGET" ] && continue
    case "$MANIFEST_TARGETS" in
      *"$OLD_TARGET"*) ;; # still in manifest
      *)
        OLD_ABS="$PROJECT_DIR/$OLD_TARGET"
        if [ -f "$OLD_ABS" ]; then
          rm "$OLD_ABS"
          SUMMARY_REMOVE=$((SUMMARY_REMOVE + 1))
          echo "preflight: $NAME — removed stale $OLD_TARGET"
        fi
        ;;
    esac
  done

  # --- Chmod scripts and hooks ---
  if [ -d "$PLUGIN_DIR/scripts" ]; then
    find "$PLUGIN_DIR/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  fi
  if [ -d "$PLUGIN_DIR/hooks" ]; then
    find "$PLUGIN_DIR/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  fi

  # Add plugin to new lock
  NEW_LOCK_PLUGINS=$(echo "$NEW_LOCK_PLUGINS" | jq ".plugins.\"$NAME\" = $PLUGIN_LOCK")
done

# --- Removed plugins: clean up artifacts ---
LOCK_PLUGINS=$(echo "$LOCK" | jq -r '.plugins // {} | keys[]' 2>/dev/null)
for LP in $LOCK_PLUGINS; do
  [ -z "$LP" ] && continue
  FOUND=false
  for n in "${PNAMES[@]}"; do
    [ "$n" = "$LP" ] && { FOUND=true; break; }
  done
  if ! $FOUND; then
    OLD_RULES=$(echo "$LOCK" | jq -r ".plugins.\"$LP\".artifacts.rules[]?.target // empty" 2>/dev/null)
    for OLD_TARGET in $OLD_RULES; do
      [ -z "$OLD_TARGET" ] && continue
      OLD_ABS="$PROJECT_DIR/$OLD_TARGET"
      if [ -f "$OLD_ABS" ]; then
        rm "$OLD_ABS"
        SUMMARY_REMOVE=$((SUMMARY_REMOVE + 1))
        echo "preflight: $LP — removed (plugin removed) $OLD_TARGET"
      fi
    done
  fi
done

# --- Write lock file (nested under preflight) ---
mkdir -p "$(dirname "$LOCK_FILE")"
NEW_LOCK=$(jq -n --argjson plugins "$NEW_LOCK_PLUGINS" \
  '{version: 1, updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")), preflight: $plugins}')
echo "$NEW_LOCK" | jq '.' > "$LOCK_FILE"

# --- Summary ---
TOTAL=$((SUMMARY_INSTALL + SUMMARY_UPDATE + SUMMARY_REMOVE + SUMMARY_SKIP + SUMMARY_DIR + SUMMARY_SETUP))
if [ "$TOTAL" -eq 0 ]; then
  echo "preflight: up to date"
else
  echo "preflight: done — installed:$SUMMARY_INSTALL updated:$SUMMARY_UPDATE removed:$SUMMARY_REMOVE conflicts:$SUMMARY_SKIP dirs:$SUMMARY_DIR setup:$SUMMARY_SETUP"
fi
