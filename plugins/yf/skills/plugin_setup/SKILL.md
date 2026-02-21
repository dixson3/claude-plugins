---
name: yf:plugin_setup
description: Configure Yoshiko Flow for this project (zero-question setup)
user_invocable: true
arguments:
  - name: action
    description: "Optional: 'disable' to disable yf, or 'artifact_dir:<name>' to set artifact directory"
    required: false
---

# /yf:plugin_setup — Project Configuration

Zero-question setup. Enables yf with sensible defaults.

## Behavior

### Beads CLI Dependency Check

Before any setup action, verify that the bd CLI is available:

```bash
if ! command -v bd >/dev/null 2>&1; then
  BD_AVAILABLE=false
fi
```

If `BD_AVAILABLE` is `false`, tell the user:

> Yoshiko Flow requires beads-cli (bd). Install it first: `brew install dixson3/tap/beads-cli`

Then stop. Do not write any config or run preflight.

### Default (no arguments)

Enable yf with `artifact_dir: docs`. No questions asked.

```bash
YF_CONFIG="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/config.json"
mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow"

if [ -f "$YF_CONFIG" ]; then
  jq '. + {enabled: true, config: (.config // {} | {artifact_dir: (.artifact_dir // "docs")} )}' \
     "$YF_CONFIG" > "$YF_CONFIG.tmp" && mv "$YF_CONFIG.tmp" "$YF_CONFIG"
else
  jq -n '{enabled: true, config: {artifact_dir: "docs"}}' > "$YF_CONFIG"
fi
```

Then run preflight:

```bash
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-preflight.sh"
```

### `disable` argument

Disable yf and remove rules:

```bash
YF_CONFIG="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/config.json"
mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow"

if [ -f "$YF_CONFIG" ]; then
  jq '. + {enabled: false}' "$YF_CONFIG" > "$YF_CONFIG.tmp" && mv "$YF_CONFIG.tmp" "$YF_CONFIG"
else
  jq -n '{enabled: false, config: {artifact_dir: "docs"}}' > "$YF_CONFIG"
fi
```

Then run preflight (which removes all rules when disabled).

### `artifact_dir:<name>` argument

Set artifact directory to `<name>`:

```bash
YF_CONFIG="${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow/config.json"
mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.yoshiko-flow"

ARTIFACT_DIR="<name>"  # extracted from argument

if [ -f "$YF_CONFIG" ]; then
  jq --arg dir "$ARTIFACT_DIR" '. + {enabled: true, config: (.config // {} | . + {artifact_dir: $dir})}' \
     "$YF_CONFIG" > "$YF_CONFIG.tmp" && mv "$YF_CONFIG.tmp" "$YF_CONFIG"
else
  jq -n --arg dir "$ARTIFACT_DIR" '{enabled: true, config: {artifact_dir: $dir}}' > "$YF_CONFIG"
fi
```

Then run preflight.

## Important

- No `AskUserQuestion` calls — this is zero-question setup
- Config writes only `{enabled, config: {artifact_dir}}`
- The only way to disable yf is `/yf:plugin_setup disable`
