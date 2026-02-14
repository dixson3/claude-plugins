# Rule: Swarm-to-Specification Bridge

**Applies:** After a feature-build or build-test swarm completes with REVIEW:PASS

## Detection

This rule fires when ALL of these are true:

1. A swarm just completed (wisp squashed)
2. The formula was `feature-build`, `build-test`, or `code-implement`
3. The final REVIEW verdict was `REVIEW:PASS`
4. Specification files exist under `<artifact_dir>/specifications/`

## Pre-Check

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"

HAS_SPECS=false
[ -f "$SPEC_DIR/PRD.md" ] && HAS_SPECS=true
[ -f "$SPEC_DIR/EDD/CORE.md" ] && HAS_SPECS=true
ls "$SPEC_DIR/IG/"*.md >/dev/null 2>&1 && HAS_SPECS=true
```

If no specs exist, this rule is a no-op.

## Behavior

When a qualifying swarm completes successfully, suggest:

> "This swarm implemented new functionality that passed review. Consider running `/yf:engineer_suggest_updates` to check if specifications need updating."

**This is advisory only** — it flags and suggests. The operator decides whether to update specs.

Do NOT auto-update specifications. Only suggest when the swarm produced CHANGES (new/modified files) and the review passed.

## When This Does NOT Fire

- Swarms that ended with REVIEW:BLOCK
- research-spike or code-review formulas (read-only, no implementation changes)
- bugfix formulas (fixes existing behavior, doesn't add new functionality)
- Projects without specification files
- Swarms that only touched test files

## Frequency

- At most once per swarm completion
- Do not suggest if the changes were trivial (e.g., only config edits)
