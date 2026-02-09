---
name: yf:setup
description: Configure Yoshiko Flow for this project (idempotent — works for initial setup and reconfiguration)
user_invocable: true
---

# /yf:setup — Project Configuration Wizard

Idempotent setup skill. Works for both first-run and reconfiguration.

## Behavior

### 1. Read existing config

Check if `.claude/yf.json` or `.claude/yf.local.json` exist. Load merged config:

```bash
# Source the config library for merged reads
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$SCRIPT_DIR/scripts/yf-config.sh" 2>/dev/null || true
# Or read directly:
cat .claude/yf.json 2>/dev/null || echo "{}"
cat .claude/yf.local.json 2>/dev/null || echo "{}"
```

Extract current values (defaults shown):
- `enabled` → `true`
- `config.artifact_dir` → `"docs"`
- `config.chronicler_enabled` → `true`

If reconfiguring, show a summary:
```
Current configuration:
  Enabled: true
  Artifact directory: docs
  Chronicler: enabled
```

### 2. Ask questions

Use AskUserQuestion with these questions (pre-populate descriptions with current values when reconfiguring):

**Question 1**: "Do you want to enable Yoshiko Flow on this project?"
- Options: "Yes" (enabled=true), "No" (enabled=false)
- Header: "Enable YF"

**Question 2**: "Where should artifacts (plans, diary) be stored?"
- Options: "docs/ (Recommended)", "project root", custom
- Header: "Artifact dir"

**Question 3**: "Should the chronicler (context capture & diary generation) be enabled?"
- Options: "Yes (Recommended)", "No"
- Header: "Chronicler"

**Question 4**: "Should this config be committed to git (shared with team)?"
- Options: "Yes (Recommended)" — write config to yf.json, "No (local only)" — write config to yf.local.json
- Header: "Share config"

### 3. Write config

Use `jq` to write config to the appropriate file based on Question 4:

**If sharing (committed to git):**
```bash
YF_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.json"
YF_LOCAL="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.local.json"
mkdir -p "$(dirname "$YF_JSON")"

# Write shared config to yf.json
jq -n --argjson enabled ENABLED_BOOL \
   --arg artifact_dir "ARTIFACT_DIR" \
   --argjson chronicler CHRONICLER_BOOL \
   '{version: 2, enabled: $enabled, config: {artifact_dir: $artifact_dir, chronicler_enabled: $chronicler}}' \
   > "$YF_JSON"

# Remove config overrides from local file (if any), keep preflight
if [ -f "$YF_LOCAL" ]; then
  jq 'del(.enabled, .config)' "$YF_LOCAL" > "$YF_LOCAL.tmp" && mv "$YF_LOCAL.tmp" "$YF_LOCAL"
fi
```

**If local only:**
```bash
YF_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.json"
YF_LOCAL="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.local.json"
mkdir -p "$(dirname "$YF_JSON")"

# Ensure yf.json exists with minimal v2 structure
if [ ! -f "$YF_JSON" ]; then
  echo '{"version": 2}' | jq '.' > "$YF_JSON"
fi

# Write config to local file, preserving preflight
if [ -f "$YF_LOCAL" ]; then
  jq --argjson enabled ENABLED_BOOL \
     --arg artifact_dir "ARTIFACT_DIR" \
     --argjson chronicler CHRONICLER_BOOL \
     '. + {enabled: $enabled, config: {artifact_dir: $artifact_dir, chronicler_enabled: $chronicler}}' \
     "$YF_LOCAL" > "$YF_LOCAL.tmp" && mv "$YF_LOCAL.tmp" "$YF_LOCAL"
else
  jq -n --argjson enabled ENABLED_BOOL \
        --arg artifact_dir "ARTIFACT_DIR" \
        --argjson chronicler CHRONICLER_BOOL \
        '{enabled: $enabled, config: {artifact_dir: $artifact_dir, chronicler_enabled: $chronicler}}' \
        > "$YF_LOCAL"
fi
```

Replace `ENABLED_BOOL`, `ARTIFACT_DIR`, `CHRONICLER_BOOL` with actual values from the user's answers.

### 4. Run preflight

Execute the preflight script to reconcile artifacts with the new config:

```bash
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-preflight.sh"
```

This will install/remove rules based on the new settings.

### 5. Report results

Show what changed. Examples:

**First run:**
```
Initial setup complete.
  Enabled: true
  Artifact directory: docs
  Chronicler: enabled
  Config: committed to git (shared)
  Rules installed: 9
```

**Reconfiguration with changes:**
```
Configuration updated.
  Enabled: true → false
  Chronicler: enabled → disabled
  Config: local only
  Rules removed: 9
```

**No changes:**
```
No changes — configuration unchanged.
```

## Answer Mapping

| Answer | Field | Value |
|--------|-------|-------|
| Enable YF: Yes | `enabled` | `true` |
| Enable YF: No | `enabled` | `false` |
| Artifact dir: docs/ | `config.artifact_dir` | `"docs"` |
| Artifact dir: project root | `config.artifact_dir` | `"."` |
| Artifact dir: (custom) | `config.artifact_dir` | user-provided path |
| Chronicler: Yes | `config.chronicler_enabled` | `true` |
| Chronicler: No | `config.chronicler_enabled` | `false` |
| Share config: Yes | write to `yf.json` | committed |
| Share config: No | write to `yf.local.json` | local only |
