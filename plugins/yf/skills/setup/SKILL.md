---
name: yf:setup
description: Configure Yoshiko Flow for this project (idempotent — works for initial setup and reconfiguration)
user_invocable: true
---

# /yf:setup — Project Configuration Wizard

Idempotent setup skill. Works for both first-run and reconfiguration.

## Behavior

### 1. Read existing config

Check if `.claude/yf.json` exists. If it does, load current values:

```bash
cat .claude/yf.json 2>/dev/null || echo "{}"
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

### 3. Merge config into yf.json

Use `jq` to merge answers into yf.json without wiping the `preflight` section:

```bash
# If yf.json exists, merge; otherwise create fresh
YF_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/yf.json"
if [ -f "$YF_JSON" ]; then
  jq --argjson enabled ENABLED_BOOL \
     --arg artifact_dir "ARTIFACT_DIR" \
     --argjson chronicler CHRONICLER_BOOL \
     '. + {enabled: $enabled, config: {artifact_dir: $artifact_dir, chronicler_enabled: $chronicler}, updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}' \
     "$YF_JSON" > "$YF_JSON.tmp" && mv "$YF_JSON.tmp" "$YF_JSON"
else
  mkdir -p "$(dirname "$YF_JSON")"
  jq -n --argjson enabled ENABLED_BOOL \
        --arg artifact_dir "ARTIFACT_DIR" \
        --argjson chronicler CHRONICLER_BOOL \
        '{version: 1, enabled: $enabled, config: {artifact_dir: $artifact_dir, chronicler_enabled: $chronicler}, updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")), preflight: {plugins: {}}}' \
        > "$YF_JSON"
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
  Rules installed: 9
```

**Reconfiguration with changes:**
```
Configuration updated.
  Enabled: true → false
  Chronicler: enabled → disabled
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
