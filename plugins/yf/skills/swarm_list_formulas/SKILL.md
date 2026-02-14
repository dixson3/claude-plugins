---
name: yf:swarm_list_formulas
description: List available swarm formulas with their descriptions and step counts
---

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

For each formula show:
- Name
- Description
- Step count
- Step pipeline with agent types
