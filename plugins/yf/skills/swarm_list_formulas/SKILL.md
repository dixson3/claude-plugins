---
name: yf:swarm_list_formulas
description: List available swarm formulas with their descriptions and step counts
---

## Activation Guard

Before proceeding, check that yf is active:

```bash
ACTIVATION=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/yf-activation-check.sh")
IS_ACTIVE=$(echo "$ACTIVATION" | jq -r '.active')
```

If `IS_ACTIVE` is not `true`, read the `reason` and `action` fields from `$ACTIVATION` and tell the user:

> Yoshiko Flow is not active: {reason}. {action}

Then stop. Do not execute the remaining steps.


# List Swarm Formulas

Lists all available swarm formulas shipped with the yf plugin.

## Behavior

1. **Scan formula directory**:
   ```bash
   ls plugins/yf/formulas/*.formula.json 2>/dev/null
   ```

2. **For each formula**, extract metadata:
   ```bash
   jq '{name: .name, description: .description, steps: (.steps | length), step_ids: [.steps[].id]}' plugins/yf/formulas/<name>.formula.json
   ```

3. **Display results** in a formatted table:

   ```
   Available Swarm Formulas
   ========================

   feature-build    Research -> Implement -> Review           (3 steps)
   research-spike   Investigate -> Synthesize -> Archive      (3 steps)
   code-review      Analyze -> Report                         (2 steps)
   bugfix           Diagnose -> Fix -> Verify                 (3 steps)
   build-test       Implement -> Test -> Review               (3 steps)
   ```

4. **For each formula**, show the step pipeline with agent annotations:
   ```bash
   jq -r '.steps[] | "  \(.id): \(.title) [\(.description | capture("SUBAGENT:(?<agent>[a-zA-Z-]+)") | .agent // "general-purpose")]"' plugins/yf/formulas/<name>.formula.json
   ```

## Usage

```
/yf:swarm_list_formulas
```

## Output Format

For each formula: name, description, step count, and step pipeline with agent types.
