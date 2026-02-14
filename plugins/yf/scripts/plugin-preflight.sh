#!/bin/bash
# plugin-preflight.sh — Self-contained artifact sync for the yf plugin
#
# Creates symlinks in .claude/rules/ pointing back to plugin source rules.
# Single source of truth: edits to plugin rules are immediately active.
#
# Config model:
#   .yoshiko-flow/config.json — committed config (enabled, artifact_dir, etc.)
#   .yoshiko-flow/lock.json — gitignored preflight lock state
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

YF_DIR="$PROJECT_DIR/.yoshiko-flow"
CONFIG_FILE="$YF_DIR/config.json"
LOCK_FILE="$YF_DIR/lock.json"

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

# --- Migration: yf.json → config.json within .yoshiko-flow/ ---
if [ ! -d "$YF_DIR" ]; then
  mkdir -p "$YF_DIR"
fi
OLD_YF_JSON="$YF_DIR/yf.json"
if [ -f "$OLD_YF_JSON" ] && [ ! -f "$CONFIG_FILE" ]; then
  mv "$OLD_YF_JSON" "$CONFIG_FILE"
  echo "preflight: renamed .yoshiko-flow/yf.json → config.json"
elif [ -f "$OLD_YF_JSON" ] && [ -f "$CONFIG_FILE" ]; then
  rm -f "$OLD_YF_JSON"
  echo "preflight: removed stale .yoshiko-flow/yf.json"
fi
# --- Ensure .yoshiko-flow/.gitignore has correct content ---
EXPECTED_GI_MARKER='!config.json'
if [ ! -f "$YF_DIR/.gitignore" ] || ! grep -qF "$EXPECTED_GI_MARKER" "$YF_DIR/.gitignore"; then
  cat > "$YF_DIR/.gitignore" <<'GITIGNORE_EOF'
# Ignore everything except config.json
*
!.gitignore
!config.json
GITIGNORE_EOF
fi
# --- Migration: .claude/ → .yoshiko-flow/ ---
OLD_CONFIG="$PROJECT_DIR/.claude/yf.json"
# Migrate old .claude/yf.json → split config + lock
if [ -f "$OLD_CONFIG" ] && [ ! -f "$CONFIG_FILE" ]; then
  # Extract config-only keys → yf.json
  jq '{enabled, config}' "$OLD_CONFIG" > "$CONFIG_FILE" 2>/dev/null || cp "$OLD_CONFIG" "$CONFIG_FILE"
  # Extract lock keys → lock.json
  jq '{updated, preflight}' "$OLD_CONFIG" > "$LOCK_FILE" 2>/dev/null || echo '{}' > "$LOCK_FILE"
  rm -f "$OLD_CONFIG"
  echo "preflight: migrated .claude/yf.json → .yoshiko-flow/"
elif [ -f "$OLD_CONFIG" ] && [ -f "$CONFIG_FILE" ]; then
  # Destination already exists — just remove the orphaned old config
  rm -f "$OLD_CONFIG"
  echo "preflight: removed orphaned .claude/yf.json"
fi
# Migrate state files (move if destination missing, delete if destination exists)
for OLD_STATE in .task-pump.json .plan-gate .plan-intake-ok; do
  OLD_PATH="$PROJECT_DIR/.claude/$OLD_STATE"
  NEW_NAME="${OLD_STATE#.}"
  NEW_PATH="$YF_DIR/$NEW_NAME"
  if [ -e "$OLD_PATH" ] && [ ! -e "$NEW_PATH" ]; then
    mv "$OLD_PATH" "$NEW_PATH"
    echo "preflight: migrated .claude/$OLD_STATE → .yoshiko-flow/$NEW_NAME"
  elif [ -e "$OLD_PATH" ] && [ -e "$NEW_PATH" ]; then
    rm -f "$OLD_PATH"
    echo "preflight: removed orphaned .claude/$OLD_STATE"
  fi
done
# Clean up .claude/.gitignore if it only contains yf-era entries
OLD_CLAUDE_GI="$PROJECT_DIR/.claude/.gitignore"
if [ -f "$OLD_CLAUDE_GI" ]; then
  # Check if every non-empty, non-comment line is a known yf artifact
  NON_YF_LINES=$(grep -v '^$' "$OLD_CLAUDE_GI" | grep -v '^#' | grep -vE '^(yf\.local\.json|yf\.json)$' || true)
  if [ -z "$NON_YF_LINES" ]; then
    rm -f "$OLD_CLAUDE_GI"
    echo "preflight: removed stale .claude/.gitignore"
  fi
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

if yf_config_exists; then
  MERGED=$(yf_merged_config)
  YF_ENABLED=$(echo "$MERGED" | jq -r 'if .enabled == null then true else .enabled end' 2>/dev/null)
  ARTIFACT_DIR=$(echo "$MERGED" | jq -r '.config.artifact_dir // "docs"' 2>/dev/null)

  # --- Prune deprecated config fields ---
  NEEDS_PRUNE=false
  if echo "$MERGED" | jq -e '.config.chronicler_enabled' >/dev/null 2>&1; then
    NEEDS_PRUNE=true
  fi
  if echo "$MERGED" | jq -e '.config.archivist_enabled' >/dev/null 2>&1; then
    NEEDS_PRUNE=true
  fi
  if $NEEDS_PRUNE; then
    jq 'del(.config.chronicler_enabled, .config.archivist_enabled)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
      && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "preflight: pruned deprecated chronicler_enabled/archivist_enabled from config"
    MERGED=$(yf_merged_config)
  fi
fi

# --- Disabled: remove all yf symlinks/files ---
if [ "$YF_ENABLED" = "false" ]; then
  REMOVED=0
  # Remove rules from yf/ subdirectory
  for F in "$PROJECT_DIR/.claude/rules/yf"/*.md; do
    [ -e "$F" ] || [ -L "$F" ] || continue
    rm -f "$F"
    REMOVED=$((REMOVED + 1))
    echo "preflight: yf — removed (disabled) .claude/rules/yf/$(basename "$F")"
  done
  # Also remove legacy flat yf-* rules from pre-subdirectory era
  for F in "$PROJECT_DIR/.claude/rules"/yf-*.md; do
    [ -e "$F" ] || [ -L "$F" ] || continue
    rm -f "$F"
    REMOVED=$((REMOVED + 1))
    echo "preflight: yf — removed (disabled) .claude/rules/$(basename "$F")"
  done
  rmdir "$PROJECT_DIR/.claude/rules/yf" 2>/dev/null || true
  # Write minimal preflight state to lock file
  CUR_VER=$(jq -r '.version' "$PJSON" 2>/dev/null)
  NEW_LOCK_DISABLED=$(jq -n --arg ver "$CUR_VER" '{
    updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    preflight: {plugins: {yf: {version: $ver, mode: "symlink", artifacts: {rules: [], directories: [], setup: []}}}}
  }')
  mkdir -p "$YF_DIR"
  echo "$NEW_LOCK_DISABLED" | jq '.' > "$LOCK_FILE"
  if [ "$REMOVED" -gt 0 ]; then
    echo "preflight: disabled — removed $REMOVED rules"
  else
    echo "preflight: disabled — no rules to remove"
  fi
  exit 0
fi

# --- Compute symlink target for a rule ---
# Uses relative path when plugin is inside the project tree, absolute otherwise
compute_link_target() {
  local source_rel="$1"
  local target_rel="$2"
  case "$PLUGIN_ROOT" in
    "$PROJECT_DIR"/*)
      # Plugin is in project tree — relative symlink
      local plugin_rel="${PLUGIN_ROOT#$PROJECT_DIR/}"
      # Compute depth: count directories in target path
      local target_dir depth=""
      target_dir=$(dirname "$target_rel")
      local d="$target_dir"
      while [ "$d" != "." ] && [ -n "$d" ]; do
        depth="../$depth"
        d=$(dirname "$d")
      done
      echo "${depth}$plugin_rel/$source_rel"
      ;;
    *)
      # Plugin loaded from cache — absolute symlink
      echo "$PLUGIN_ROOT/$source_rel"
      ;;
  esac
}

# --- Read lock for preflight section ---
LOCK="{}"
if [ -f "$LOCK_FILE" ]; then
  LOCK=$(jq '.preflight // {}' "$LOCK_FILE" 2>/dev/null || echo "{}")
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

  if [ "$RULE_COUNT" != "$LOCK_RULE_COUNT" ]; then
    FAST_PATH=false
  fi

  j=0; while [ $j -lt "$RULE_COUNT" ] && $FAST_PATH; do
    SOURCE_REL=$(jq -r ".artifacts.rules[$j].source" "$PPRE" 2>/dev/null)
    TARGET_REL=$(jq -r ".artifacts.rules[$j].target" "$PPRE" 2>/dev/null)

    TARGET_ABS="$PROJECT_DIR/$TARGET_REL"
    EXPECTED_LINK=$(compute_link_target "$SOURCE_REL" "$TARGET_REL")

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
  # Check gitignore sentinel
  if [ -f "$PROJECT_DIR/.gitignore" ]; then
    grep -qF "# >>> yf-managed >>>" "$PROJECT_DIR/.gitignore" || FAST_PATH=false
  else
    FAST_PATH=false
  fi
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

# --- Beads git workflow migration ---
BEADS_MIGRATION_COMPLETE=$(jq -r '.preflight.plugins.yf.beads_migration_complete // false' "$LOCK_FILE" 2>/dev/null || echo "false")

if [ -d "$PROJECT_DIR/.beads" ] && [ "$BEADS_MIGRATION_COMPLETE" != "true" ]; then
  # Check if .beads/ is in the yf-managed gitignore block (legacy local-only)
  NEEDS_MIGRATION=false
  if [ -f "$PROJECT_DIR/.gitignore" ] && grep -qF "# >>> yf-managed >>>" "$PROJECT_DIR/.gitignore"; then
    if awk '/# >>> yf-managed >>>/,/# <<< yf-managed <<</' "$PROJECT_DIR/.gitignore" | grep -q '\.beads/'; then
      NEEDS_MIGRATION=true
    fi
  fi

  if $NEEDS_MIGRATION; then
    echo "preflight: migrating beads to git-tracked model..."

    # Configure sync branch
    (cd "$PROJECT_DIR" && bd config set sync.branch beads-sync) 2>&1 || echo "preflight: warn: failed to set sync.branch" >&2

    # Enable mass-delete protection
    (cd "$PROJECT_DIR" && bd config set sync.require_confirmation_on_mass_delete true) 2>&1 || echo "preflight: warn: failed to set mass-delete protection" >&2

    # Install beads git hooks
    (cd "$PROJECT_DIR" && bd hooks install) 2>&1 || echo "preflight: warn: failed to install beads hooks" >&2

    # Install pre-push hook for beads-sync auto-push
    bash "$SCRIPT_DIR/install-beads-push-hook.sh" "$PROJECT_DIR" 2>&1 || echo "preflight: warn: failed to install beads push hook" >&2

    # Run doctor to verify
    (cd "$PROJECT_DIR" && bd doctor) 2>&1 || echo "preflight: warn: bd doctor reported issues" >&2

    # Record migration complete in lock
    PLUGIN_LOCK=$(echo "$PLUGIN_LOCK" | jq '.beads_migration_complete = true')

    echo "preflight: beads git workflow migration complete"
    echo ""
    echo "preflight: ACTION REQUIRED — To enable beads git tracking, run:"
    echo "  git add .beads/"
    echo "  git commit -m \"chore: enable beads git-tracking\""
    echo "  git push  # pre-push hook will create beads-sync branch"
  fi
fi

# Install beads pre-push hook unconditionally (idempotent)
if [ -d "$PROJECT_DIR/.beads" ]; then
  bash "$SCRIPT_DIR/install-beads-push-hook.sh" "$PROJECT_DIR" 2>&1 || echo "preflight: warn: failed to install beads push hook" >&2
fi

# --- Project setup (gitignore + AGENTS.md cleanup) ---
bash "$SCRIPT_DIR/setup-project.sh" all 2>&1 || true

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

  MANIFEST_TARGETS="$MANIFEST_TARGETS
$TARGET_REL"

  if [ ! -f "$SOURCE_ABS" ]; then
    echo "preflight: warn: $PLUGIN_NAME — source not found: $SOURCE_REL" >&2
    j=$((j + 1)); continue
  fi

  LINK_TARGET=$(compute_link_target "$SOURCE_REL" "$TARGET_REL")

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

# --- Rules: remove stale symlinks/files not in current manifest ---
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

# --- Remove legacy flat yf-* rules from pre-subdirectory era ---
for F in "$PROJECT_DIR/.claude/rules"/yf-*.md; do
    [ -e "$F" ] || [ -L "$F" ] || continue
    rm -f "$F"
    SUMMARY_REMOVE=$((SUMMARY_REMOVE + 1))
    echo "preflight: $PLUGIN_NAME — removed legacy flat rule $(basename "$F")"
done

# --- Chmod scripts and hooks ---
if [ -d "$PLUGIN_ROOT/scripts" ]; then
  find "$PLUGIN_ROOT/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi
if [ -d "$PLUGIN_ROOT/hooks" ]; then
  find "$PLUGIN_ROOT/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# --- Write lock to lock.json ---
mkdir -p "$YF_DIR"

NEW_LOCK=$(jq -n --argjson plugin "$PLUGIN_LOCK" '{
  updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
  preflight: {plugins: {yf: $plugin}}
}')
echo "$NEW_LOCK" | jq '.' > "$LOCK_FILE"

# --- Summary ---
TOTAL=$((SUMMARY_INSTALL + SUMMARY_UPDATE + SUMMARY_REMOVE + SUMMARY_DIR + SUMMARY_SETUP))
if [ "$TOTAL" -eq 0 ]; then
  echo "preflight: up to date"
else
  echo "preflight: done — installed:$SUMMARY_INSTALL updated:$SUMMARY_UPDATE removed:$SUMMARY_REMOVE dirs:$SUMMARY_DIR setup:$SUMMARY_SETUP"
fi
