#!/bin/bash
# plugin-preflight.sh — Self-contained artifact sync for the yf plugin
#
# Resolves its own plugin root via BASH_SOURCE (works from both source tree
# and Claude Code plugin cache). Reads preflight.json directly — no
# marketplace.json iteration or topological sort needed.
#
# Two-file config model:
#   .claude/yf.json       — committable shared config (version, enabled, config)
#   .claude/yf.local.json — gitignored local overrides + preflight lock state
#
# Config-aware: reads merged config via yf-config.sh library.
# Outputs YF_SETUP_NEEDED signal when no config files exist and no old lock
# to migrate.
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

LOCK_FILE="$PROJECT_DIR/.claude/yf.json"
LOCAL_FILE="$PROJECT_DIR/.claude/yf.local.json"
OLD_LOCK_FILE="$PROJECT_DIR/.claude/plugin-lock.json"

PLUGIN_NAME="yf"
PJSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
PPRE="$PLUGIN_ROOT/.claude-plugin/preflight.json"

if [ ! -f "$PJSON" ]; then
  echo "preflight: warn: plugin.json not found at $PJSON" >&2
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

# --- Source the config library ---
. "$SCRIPT_DIR/yf-config.sh"

# --- Migration: plugin-lock.json → yf.json (v0 → v1) ---
if [ ! -f "$LOCK_FILE" ] && [ -f "$OLD_LOCK_FILE" ]; then
  echo "preflight: migrating plugin-lock.json → yf.json"
  OLD_DATA=$(cat "$OLD_LOCK_FILE")
  # Create v1 format (all-in-one) — v1→v2 migration below will split it
  MIGRATED=$(echo "$OLD_DATA" | jq '{version: 1, enabled: true, config: {artifact_dir: "docs", chronicler_enabled: true}, updated: .updated, preflight: {plugins: .plugins}}')
  mkdir -p "$(dirname "$LOCK_FILE")"
  echo "$MIGRATED" | jq '.' > "$LOCK_FILE"
  rm -f "$OLD_LOCK_FILE"
fi

# --- Migration: v1 → v2 (split yf.json into yf.json + yf.local.json) ---
if [ -f "$LOCK_FILE" ]; then
  LOCK_VERSION=$(jq -r '.version // 1' "$LOCK_FILE" 2>/dev/null)
  if [ "$LOCK_VERSION" = "1" ] && jq -e '.preflight' "$LOCK_FILE" >/dev/null 2>&1; then
    echo "preflight: migrating yf.json v1 → v2 (splitting config + local)"
    # Extract local state (updated + preflight) → yf.local.json
    jq '{updated: .updated, preflight: .preflight}' "$LOCK_FILE" > "$LOCAL_FILE"
    # Keep shared config (version 2 + enabled + config) → yf.json
    jq '{version: 2, enabled: .enabled, config: .config}' "$LOCK_FILE" > "$LOCK_FILE.tmp"
    mv "$LOCK_FILE.tmp" "$LOCK_FILE"
  fi
fi

# --- Setup needed signal ---
if ! yf_config_exists; then
  echo "YF_SETUP_NEEDED"
  echo "preflight: no config found — run /yf:setup to configure"
  # Continue with defaults to install artifacts on first run
fi

# --- Read config from merged config ---
YF_ENABLED=true
ARTIFACT_DIR="docs"
CHRONICLER_ENABLED=true

if yf_config_exists; then
  MERGED=$(yf_merged_config)
  YF_ENABLED=$(echo "$MERGED" | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
  ARTIFACT_DIR=$(echo "$MERGED" | jq -r '.config.artifact_dir // "docs"' 2>/dev/null)
  CHRONICLER_ENABLED=$(echo "$MERGED" | jq -r 'if .config.chronicler_enabled == null then true else .config.chronicler_enabled end' 2>/dev/null)
fi

# --- Disabled: remove all yf rules and write minimal lock ---
if [ "$YF_ENABLED" = "false" ]; then
  # Read existing lock to find installed rules (from local file)
  LOCK_RULES=""
  if [ -f "$LOCAL_FILE" ]; then
    LOCK_RULES=$(jq -r '.preflight.plugins.yf.artifacts.rules[]?.target // empty' "$LOCAL_FILE" 2>/dev/null)
  elif [ -f "$LOCK_FILE" ]; then
    # Fallback: check main file in case migration hasn't happened yet
    LOCK_RULES=$(jq -r '.preflight.plugins.yf.artifacts.rules[]?.target // empty' "$LOCK_FILE" 2>/dev/null)
  fi
  REMOVED=0
  for TARGET in $LOCK_RULES; do
    [ -z "$TARGET" ] && continue
    TARGET_ABS="$PROJECT_DIR/$TARGET"
    if [ -f "$TARGET_ABS" ]; then
      rm "$TARGET_ABS"
      REMOVED=$((REMOVED + 1))
      echo "preflight: yf — removed (disabled) $TARGET"
    fi
  done
  # Write minimal preflight state to local file (preserve any local overrides)
  CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)
  NEW_LOCAL_DISABLED=$(jq -n --arg ver "$CUR_VER" '{
    updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    preflight: {plugins: {yf: {version: $ver, artifacts: {rules: [], directories: [], setup: []}}}}
  }')
  if [ -f "$LOCAL_FILE" ]; then
    cat "$LOCAL_FILE" | jq --argjson new "$NEW_LOCAL_DISABLED" '. * $new' > "$LOCAL_FILE.tmp"
  else
    echo "$NEW_LOCAL_DISABLED" | jq '.' > "$LOCAL_FILE.tmp"
  fi
  mv "$LOCAL_FILE.tmp" "$LOCAL_FILE"
  # Ensure yf.json exists with v2 structure
  if [ ! -f "$LOCK_FILE" ]; then
    mkdir -p "$(dirname "$LOCK_FILE")"
    echo '{"version":2,"enabled":false,"config":{"artifact_dir":"docs","chronicler_enabled":true}}' | jq '.' > "$LOCK_FILE"
  fi
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
  local basename
  basename=$(basename "$target")
  case " $CHRONICLE_RULES " in
    *" $basename "*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Read lock file for preflight section (from local file) ---
LOCK="{}"
if [ -f "$LOCAL_FILE" ]; then
  LOCK=$(jq '.preflight // {}' "$LOCAL_FILE" 2>/dev/null || echo "{}")
elif [ -f "$LOCK_FILE" ]; then
  # Fallback: v1 format where preflight is still in yf.json
  LOCK=$(jq '.preflight // {}' "$LOCK_FILE" 2>/dev/null || echo "{}")
fi

# --- Plugin version ---
CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)

# --- Fast path: check if version + checksums match ---
FAST_PATH=true

LOCK_VER=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".version // \"\"" 2>/dev/null)
if [ "$CUR_VER" != "$LOCK_VER" ]; then
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

    SOURCE_ABS="$PLUGIN_ROOT/$SOURCE_REL"
    TARGET_ABS="$PROJECT_DIR/$TARGET_REL"

    if [ ! -f "$SOURCE_ABS" ] || [ ! -f "$TARGET_ABS" ]; then
      FAST_PATH=false; break
    fi

    CUR_CKSUM=$(sha256_file "$SOURCE_ABS")
    LOCK_CKSUM=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.rules[] | select(.target == \"$TARGET_REL\") | .checksum // \"\"" 2>/dev/null)
    INSTALLED_CKSUM=$(sha256_file "$TARGET_ABS")

    if [ "$CUR_CKSUM" != "$LOCK_CKSUM" ] || [ "$INSTALLED_CKSUM" != "$LOCK_CKSUM" ]; then
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
SUMMARY_SKIP=0
SUMMARY_DIR=0
SUMMARY_SETUP=0

PLUGIN_LOCK="{\"version\":\"$CUR_VER\",\"artifacts\":{\"rules\":[],\"directories\":[],\"setup\":[]}}"

# --- Directories ---
DIR_COUNT=0
if [ -f "$PPRE" ]; then
  DIR_COUNT=$(jq -r '(.artifacts.directories // []) | length' "$PPRE" 2>/dev/null)
  [ -z "$DIR_COUNT" ] && DIR_COUNT=0
fi
j=0; while [ $j -lt "$DIR_COUNT" ]; do
  DIR_REL=$(jq -r ".artifacts.directories[$j]" "$PPRE" 2>/dev/null)
  # Resolve artifact_dir: replace leading "docs" with configured dir
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

# --- Rules: install/update ---
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

  SOURCE_CKSUM=$(sha256_file "$SOURCE_ABS")

  if [ ! -f "$TARGET_ABS" ]; then
    mkdir -p "$(dirname "$TARGET_ABS")"
    cp "$SOURCE_ABS" "$TARGET_ABS"
    SUMMARY_INSTALL=$((SUMMARY_INSTALL + 1))
    echo "preflight: $PLUGIN_NAME — installed $TARGET_REL"
  else
    LOCK_CKSUM=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.rules[]? | select(.target == \"$TARGET_REL\") | .checksum // \"\"" 2>/dev/null)
    INSTALLED_CKSUM=$(sha256_file "$TARGET_ABS")

    if [ "$INSTALLED_CKSUM" = "$SOURCE_CKSUM" ]; then
      :
    elif [ -n "$LOCK_CKSUM" ] && [ "$INSTALLED_CKSUM" != "$LOCK_CKSUM" ]; then
      echo "preflight: $PLUGIN_NAME — CONFLICT: $TARGET_REL modified by user, skipping update"
      SUMMARY_SKIP=$((SUMMARY_SKIP + 1))
      SOURCE_CKSUM="$INSTALLED_CKSUM"
    else
      cp "$SOURCE_ABS" "$TARGET_ABS"
      SUMMARY_UPDATE=$((SUMMARY_UPDATE + 1))
      echo "preflight: $PLUGIN_NAME — updated $TARGET_REL"
    fi
  fi

  PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq ".artifacts.rules += [{\"target\": \"$TARGET_REL\", \"checksum\": \"$SOURCE_CKSUM\"}]")
j=$((j + 1)); done

# --- Rules: remove stale (was in lock but not in current manifest) ---
LOCK_RULE_TARGETS=$(echo "$LOCK" | jq -r ".plugins.\"$PLUGIN_NAME\".artifacts.rules[]?.target // empty" 2>/dev/null)
for OLD_TARGET in $LOCK_RULE_TARGETS; do
  [ -z "$OLD_TARGET" ] && continue
  case "$MANIFEST_TARGETS" in
    *"$OLD_TARGET"*) ;; # still in manifest
    *)
      OLD_ABS="$PROJECT_DIR/$OLD_TARGET"
      if [ -f "$OLD_ABS" ]; then
        rm "$OLD_ABS"
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
    if [ -f "$CHRON_ABS" ]; then
      rm "$CHRON_ABS"
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

# --- Write lock: split into yf.json (config) + yf.local.json (preflight) ---
mkdir -p "$(dirname "$LOCK_FILE")"

# Read existing config for defaults
EXISTING_ENABLED="true"
EXISTING_ARTIFACT_DIR="docs"
EXISTING_CHRONICLER="true"
if yf_config_exists; then
  MERGED=$(yf_merged_config)
  EXISTING_ENABLED=$(echo "$MERGED" | jq -r 'if .enabled == null then "true" else (.enabled | tostring) end' 2>/dev/null)
  EXISTING_ARTIFACT_DIR=$(echo "$MERGED" | jq -r '.config.artifact_dir // "docs"' 2>/dev/null)
  EXISTING_CHRONICLER=$(echo "$MERGED" | jq -r 'if .config.chronicler_enabled == null then "true" else (.config.chronicler_enabled | tostring) end' 2>/dev/null)
fi

# Write yf.json (committable shared config) — only if it doesn't exist or is v1
if [ ! -f "$LOCK_FILE" ]; then
  jq -n --arg enabled "$EXISTING_ENABLED" \
        --arg artifact_dir "$EXISTING_ARTIFACT_DIR" \
        --arg chronicler "$EXISTING_CHRONICLER" \
    '{
      version: 2,
      enabled: ($enabled | if . == "true" then true elif . == "false" then false else true end),
      config: {
        artifact_dir: $artifact_dir,
        chronicler_enabled: ($chronicler | if . == "true" then true elif . == "false" then false else true end)
      }
    }' > "$LOCK_FILE"
else
  # If still v1 (shouldn't happen after migration, but defensive), upgrade
  CURRENT_V=$(jq -r '.version // 1' "$LOCK_FILE" 2>/dev/null)
  if [ "$CURRENT_V" = "1" ]; then
    jq '{version: 2, enabled: .enabled, config: .config}' "$LOCK_FILE" > "$LOCK_FILE.tmp"
    mv "$LOCK_FILE.tmp" "$LOCK_FILE"
  fi
fi

# Write yf.local.json (preflight lock state) — preserve any existing local overrides
NEW_LOCAL=$(jq -n --argjson plugin "$PLUGIN_LOCK" '{
  updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
  preflight: {plugins: {yf: $plugin}}
}')
if [ -f "$LOCAL_FILE" ]; then
  # Preserve existing local overrides (enabled, config, etc.) but update preflight + timestamp
  EXISTING_LOCAL=$(cat "$LOCAL_FILE")
  echo "$EXISTING_LOCAL" | jq --argjson new "$NEW_LOCAL" '. * $new' > "$LOCAL_FILE.tmp"
  mv "$LOCAL_FILE.tmp" "$LOCAL_FILE"
else
  echo "$NEW_LOCAL" | jq '.' > "$LOCAL_FILE"
fi

# --- Summary ---
TOTAL=$((SUMMARY_INSTALL + SUMMARY_UPDATE + SUMMARY_REMOVE + SUMMARY_SKIP + SUMMARY_DIR + SUMMARY_SETUP))
if [ "$TOTAL" -eq 0 ]; then
  echo "preflight: up to date"
else
  echo "preflight: done — installed:$SUMMARY_INSTALL updated:$SUMMARY_UPDATE removed:$SUMMARY_REMOVE conflicts:$SUMMARY_SKIP dirs:$SUMMARY_DIR setup:$SUMMARY_SETUP"
fi
