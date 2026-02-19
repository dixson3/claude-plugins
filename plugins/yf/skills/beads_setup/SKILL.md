---
name: yf:beads_setup
description: Initialize and validate beads-cli setup for this project (idempotent)
user_invocable: true
arguments:
  - name: mode
    description: "Optional: 'repair' to force full re-validation even if setup looks complete"
    required: false
---

# /yf:beads_setup — Beads Setup & Repair

Initialize and validate beads-cli configuration for this project. Doctor-driven repair with inactive fallback.

## Activation Guard

```bash
if ! command -v bd >/dev/null 2>&1; then
  echo "beads-setup requires bd CLI. Install: brew install dixson3/tap/beads-cli"
  # STOP — do not proceed
fi
```

## Behavior

Run the beads-setup script:

```bash
OUTPUT=$(CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/beads-setup.sh" ${mode:-} 2>&1)
echo "$OUTPUT"
```

### If output contains `BEADS_SETUP_FAILED`

Tell the operator:

> Beads setup could not achieve clean state. The plugin is inactive until these issues are resolved.

Show the specific unresolved issues from the output. Suggest manual steps:
- `bd doctor --verbose` to see full diagnostics
- Fix individual issues based on the doctor output
- Re-run `/yf:beads_setup` to re-validate

### If output contains `beads-setup: healthy`

Report success with the change count from the output. No further action needed.

### If output contains `beads-setup: skip`

Report why setup was skipped (bd not available or not a git repo).
