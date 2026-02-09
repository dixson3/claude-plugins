#!/bin/bash
# plugin-preflight.sh — Self-contained artifact sync for the yf plugin
#
# Creates symlinks in .claude/rules/ pointing back to plugin source rules.
# Single source of truth: edits to plugin rules are immediately active.
#
# Config model:
#   .claude/yf.json — gitignored config + preflight lock state
#
# Config-aware: reads config via yf-config.sh library.
# Outputs YF_SETUP_NEEDED signal when no config file exists.
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
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "preflight: warn: CLAUDE_PROJECT_DIR ($PROJECT_DIR) not found" >&2
  exit 0
fi

CONFIG_FILE="$PROJECT_DIR/.claude/yf.json"

PLUGIN_NAME="yf"
PJSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
PPRE="$PLUGIN_ROOT/.claude-plugin/preflight.json"

if [ ! -f "$PJSON" ]; then
  echo "preflight: warn: plugin.json not found at $PJSON" >&2
  exit 0
fi

# Check jq availability
if ! command -v jq >/dev/null 2>&1; then
  echo "preflight: warn: jq not found, skipping preflight" >&2
  exit 0
fi

# --- Source the config library ---
. "$SCRIPT_DIR/yf-config.sh"

# --- Setup needed signal ---
if ! yf_config_exists; then
  echo "YF_SETUP_NEEDED"
  echo "preflight: no config found — run /yf:setup to configure"
  # Continue with defaults to install artifacts on first run
fi

# --- Read config ---
YF_ENABLED=true
ARTIFACT_DIR="docs"
CHRONICLER_ENABLED=true

if yf_config_exists; then
  MERGED=$(yf_merged_config)
  YF_ENABLED=$(echo "$MERGED" | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
  ARTIFACT_DIR=$(echo "$MERGED" | jq -r '.config.artifact_dir // "docs"' 2>/dev/null)
  CHRONICLER_ENABLED=$(echo "$MERGED" | jq -r 'if .config.chronicler_enabled == null then true else .config.chronicler_enabled end' 2>/dev/null)
fi

# --- Disabled: remove all yf symlinks/files ---
if [ "$YF_ENABLED" = "false" ]; then
  REMOVED=0
  # Remove any yf-* rules (symlinks or regular files)
  for F in "$PROJECT_DIR/.claude/rules"/yf-*.md; do
    [ -e "$F" ] || [ -L "$F" ] || continue
    rm -f "$F"
    REMOVED=$((REMOVED + 1))
    echo "preflight: yf — removed (disabled) .claude/rules/$(basename "$F")"
  done
  # Write minimal preflight state to local file
  CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)
  NEW_LOCAL_DISABLED=$(jq -n --arg ver "$CUR_VER" '{
    updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    preflight: {plugins: {yf: {version: $ver, mode: "symlink", artifacts: {rules: [], directories: [], setup: []}}}}
  }')
  if [ -f "$CONFIG_FILE" ]; then
    cat "$CONFIG_FILE" | jq --argjson new "$NEW_LOCAL_DISABLED" '. * $new' > "$CONFIG_FILE.tmp"
  else
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$NEW_LOCAL_DISABLED" | jq '.' > "$CONFIG_FILE.tmp"
  fi
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  if [ "$REMOVED" -gt 0 ]; then
    echo "preflight: disabled — removed $REMOVED rules"
  else
    echo "preflight: disabled — no rules to remove"
  fi
  exit 0
fi

# --- Chronicle rules to conditionally skip ---
CHRONICLE_RULES="yf-watch-for-chronicle-worthiness.md yf-plan-transition-chronicle.md"

is_chronicle_rule() {
  local target="$1"
  local base
  base=$(basename "$target")
  case " $CHRONICLE_RULES " in
    *" $base "*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Compute symlink target for a rule ---
# Uses relative path when plugin is inside the project tree, absolute otherwise
compute_link_target() {
  local source_rel="$1"
  case "$PLUGIN_ROOT" in
    "$PROJECT_DIR"/*)
      # Plugin is in project tree — relative symlink (from .claude/rules/)
      local plugin_rel="${PLUGIN_ROOT#$PROJECT_DIR/}"
      echo "../../$plugin_rel/$source_rel"
      ;;
    *)
      # Plugin loaded from cache — absolute symlink
      echo "$PLUGIN_ROOT/$source_rel"
      ;;
  esac
}

# --- Read lock for preflight section ---
LOCK="{}"
if [ -f "$CONFIG_FILE" ]; then
  LOCK=$(jq '.preflight // {}' "$CONFIG_FILE" 2>/dev/null || echo "{}")
fi

# --- Plugin version ---
CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)

# --- Fast path: check version + symlink targets match ---
FAST_PATH=true

LOCK_VER=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".version // \"\"" 2>/dev/null)
if [ "$CUR_VER" != "$LOCK_VER" ]; then
  FAST_PATH=false
fi

LOCK_MODE=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".mode // \"\"" 2>/dev/null)
if [ "$LOCK_MODE" != "symlink" ]; then
  FAST_PATH=false
fi

if $FAST_PATH && [ -f "$PPRE" ]; then
  RULE_COUNT=$(jq -r '(.artifacts.rules // []) | length' "$PPRE" 2>/dev/null)
  [ -z "$RULE_COUNT" ] && RULE_COUNT=0
  LOCK_RULE_COUNT=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.rules | length" 2>/dev/null)
  [ -z "$LOCK_RULE_COUNT" ] && LOCK_RULE_COUNT=0

  # Account for chronicle rules being skipped when chronicler disabled
  EXPECTED_COUNT=$RULE_COUNT
  if [ "$CHRONICLER_ENABLED" = "false" ]; then
    j=0; while [ $j -lt "$RULE_COUNT" ]; do
      TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)
      if is_chronicle_rule "$TARGET_REL"; then
        EXPECTED_COUNT=$((EXPECTED_COUNT - 1))
      fi
    j=$((j + 1)); done
  fi

  if [ "$EXPECTED_COUNT" != "$LOCK_RULE_COUNT" ]; then
    FAST_PATH=false
  fi

  j=0; while [ $j -lt "$RULE_COUNT" ] && $FAST_PATH; do
    SOURCE_REL=$(jq -r ".artifacts.rules[$j].source" "$PPRE" 2>/dev/null)
    TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)

    # Skip chronicle rules when chronicler disabled
    if [ "$CHRONICLER_ENABLED" = "false" ] && is_chronicle_rule "$TARGET_REL"; then
      j=$((j + 1)); continue
    fi

    TARGET_ABS="$PROJECT_DIR/$TARGET_REL"
    EXPECTED_LINK=$(compute_link_target "$SOURCE_REL")

    # Check symlink exists and points to correct target
    if [ ! -L "$TARGET_ABS" ]; then
      FAST_PATH=false; break
    fi
    CURRENT_LINK=$(readlink "$TARGET_ABS" 2>/dev/null || echo "")
    if [ "$CURRENT_LINK" != "$EXPECTED_LINK" ]; then
      FAST_PATH=false; break
    fi
  j=$((j + 1)); done
fi

if $FAST_PATH; then
  echo "preflight: up to date"
  exit 0
fi

# --- Full sync ---
SUMMARY_INSTALL=0
SUMMARY_UPDATE=0
SUMMARY_REMOVE=0
SUMMARY_DIR=0
SUMMARY_SETUP=0

PLUGIN_LOCK="{\"version\":\"$CUR_VER\",\"mode\":\"symlink\",\"artifacts\":{\"rules\":[],\"directories\":[],\"setup\":[]}}"

# --- Directories ---
DIR_COUNT=0
if [ -f "$PPRE" ]; then
  DIR_COUNT=$(jq -r '(.artifacts.directories // []) | length' "$PPRE" 2>/dev/null)
  [ -z "$DIR_COUNT" ] && DIR_COUNT=0
fi
j=0; while [ $j -lt "$DIR_COUNT" ]; do
  DIR_REL=$(jq -r ".artifacts.directories[$j]" "$PPRE" 2>/dev/null)
  RESOLVED_DIR=$(echo "$DIR_REL" | sed "s|^docs|$ARTIFACT_DIR|")
  DIR_ABS="$PROJECT_DIR/$RESOLVED_DIR"
  if [ ! -d "$DIR_ABS" ]; then
    mkdir -p "$DIR_ABS"
    SUMMARY_DIR=$((SUMMARY_DIR + 1))
    echo "preflight: $PLUGIN_NAME — created $RESOLVED_DIR/"
  fi
  PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.directories += [\"$RESOLVED_DIR\"]")
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

  LOCK_COMPLETED=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.setup[]? | select(.name == \"$SETUP_NAME\") | .completed // false" 2>/dev/null)

  COMPLETED=false
  if [ "$LOCK_COMPLETED" = "true" ]; then
    if (cd "$PROJECT_DIR" && eval "$SETUP_CHECK") >/dev/null 2>&1; then
      COMPLETED=true
    fi
  fi

  if ! $COMPLETED; then
    if ! (cd "$PROJECT_DIR" && eval "$SETUP_CHECK") >/dev/null 2>&1; then
      echo "preflight: $PLUGIN_NAME — running setup: $SETUP_NAME"
      if (cd "$PROJECT_DIR" && eval "$SETUP_RUN") >/dev/null 2>&1; then
        COMPLETED=true
        SUMMARY_SETUP=$((SUMMARY_SETUP + 1))
      else
        echo "preflight: warn: $PLUGIN_NAME — setup '$SETUP_NAME' failed" >&2
      fi
    else
      COMPLETED=true
    fi
  fi

  PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.setup += [{\"name\": \"$SETUP_NAME\", \"completed\": $COMPLETED}]")
j=$((j + 1)); done

# --- Rules: create symlinks ---
RULE_COUNT=0
MANIFEST_TARGETS=""
if [ -f "$PPRE" ]; then
  RULE_COUNT=$(jq -r '(.artifacts.rules // []) | length' "$PPRE" 2>/dev/null)
  [ -z "$RULE_COUNT" ] && RULE_COUNT=0
fi

j=0; while [ $j -lt "$RULE_COUNT" ]; do
  SOURCE_REL=$(jq -r ".artifacts.rules[$j].source" "$PPRE" 2>/dev/null)
  TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)
  SOURCE_ABS="$PLUGIN_ROOT/$SOURCE_REL"
  TARGET_ABS="$PROJECT_DIR/$TARGET_REL"

  # Skip chronicle rules when chronicler disabled
  if [ "$CHRONICLER_ENABLED" = "false" ] && is_chronicle_rule "$TARGET_REL"; then
    j=$((j + 1)); continue
  fi

  MANIFEST_TARGETS="$MANIFEST_TARGETS
$TARGET_REL"

  if [ ! -f "$SOURCE_ABS" ]; then
    echo "preflight: warn: $PLUGIN_NAME — source not found: $SOURCE_REL" >&2
    j=$((j + 1)); continue
  fi

  LINK_TARGET=$(compute_link_target "$SOURCE_REL")

  if [ -L "$TARGET_ABS" ]; then
    # Existing symlink — check if it points to the right place
    CURRENT_LINK=$(readlink "$TARGET_ABS" 2>/dev/null || echo "")
    if [ "$CURRENT_LINK" = "$LINK_TARGET" ]; then
      : # correct symlink, no action needed
    else
      # Wrong target — recreate
      ln -sf "$LINK_TARGET" "$TARGET_ABS"
      SUMMARY_UPDATE=$((SUMMARY_UPDATE + 1))
      echo "preflight: $PLUGIN_NAME — updated symlink $TARGET_REL"
    fi
  elif [ -f "$TARGET_ABS" ]; then
    # Regular file (old copy) — replace with symlink
    rm "$TARGET_ABS"
    ln -sf "$LINK_TARGET" "$TARGET_ABS"
    SUMMARY_UPDATE=$((SUMMARY_UPDATE + 1))
    echo "preflight: $PLUGIN_NAME — migrated to symlink $TARGET_REL"
  else
    # Missing — create symlink
    mkdir -p "$(dirname "$TARGET_ABS")"
    ln -sf "$LINK_TARGET" "$TARGET_ABS"
    SUMMARY_INSTALL=$((SUMMARY_INSTALL + 1))
    echo "preflight: $PLUGIN_NAME — installed $TARGET_REL"
  fi

  PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq --arg t "$TARGET_REL" --arg l "$LINK_TARGET" '.artifacts.rules += [{"target": $t, "link": $l}]')
j=$((j + 1)); done

# --- Rules: remove stale (yf-* symlinks/files not in current manifest) ---
LOCK_RULE_TARGETS=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.rules[]?.target // empty" 2>/dev/null)
for OLD_TARGET in $LOCK_RULE_TARGETS; do
  [ -z "$OLD_TARGET" ] && continue
  case "$MANIFEST_TARGETS" in
    *"$OLD_TARGET"*) ;; # still in manifest
    *)
      OLD_ABS="$PROJECT_DIR/$OLD_TARGET"
      if [ -e "$OLD_ABS" ] || [ -L "$OLD_ABS" ]; then
        rm -f "$OLD_ABS"
        SUMMARY_REMOVE=$((SUMMARY_REMOVE + 1))
        echo "preflight: $PLUGIN_NAME — removed stale $OLD_TARGET"
      fi
      ;;
  esac
done

# --- Remove chronicle rules if chronicler disabled and they exist ---
if [ "$CHRONICLER_ENABLED" = "false" ]; then
  for CHRON_RULE in $CHRONICLE_RULES; do
    CHRON_TARGET=".claude/rules/$CHRON_RULE"
    CHRON_ABS="$PROJECT_DIR/$CHRON_TARGET"
    if [ -e "$CHRON_ABS" ] || [ -L "$CHRON_ABS" ]; then
      rm -f "$CHRON_ABS"
      SUMMARY_REMOVE=$((SUMMARY_REMOVE + 1))
      echo "preflight: $PLUGIN_NAME — removed (chronicler disabled) $CHRON_TARGET"
    fi
  done
fi

# --- Chmod scripts and hooks ---
if [ -d "$PLUGIN_ROOT/scripts" ]; then
  find "$PLUGIN_ROOT/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi
if [ -d "$PLUGIN_ROOT/hooks" ]; then
  find "$PLUGIN_ROOT/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# --- Write lock to yf.json ---
mkdir -p "$(dirname "$CONFIG_FILE")"

NEW_LOCAL=$(jq -n --argjson plugin "$PLUGIN_LOCK" '{
  updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
  preflight: {plugins: {yf: $plugin}}
}')
if [ -f "$CONFIG_FILE" ]; then
  EXISTING_LOCAL=$(cat "$CONFIG_FILE")
  echo "$EXISTING_LOCAL" | jq --argjson new "$NEW_LOCAL" '. * $new' > "$CONFIG_FILE.tmp"
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
else
  echo "$NEW_LOCAL" | jq '.' > "$CONFIG_FILE"
fi

# --- Summary ---
TOTAL=$((SUMMARY_INSTALL + SUMMARY_UPDATE + SUMMARY_REMOVE + SUMMARY_DIR + SUMMARY_SETUP))
if [ "$TOTAL" -eq 0 ]; then
  echo "preflight: up to date"
else
  echo "preflight: done — installed:$SUMMARY_INSTALL updated:$SUMMARY_UPDATE removed:$SUMMARY_REMOVE dirs:$SUMMARY_DIR setup:$SUMMARY_SETUP"
fi
