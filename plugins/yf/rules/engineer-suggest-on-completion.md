# Rule: Suggest Specification Updates on Plan Completion

**Applies:** After plan execution completes (after plan-completion-report fires)

## Detection

This rule fires when ALL of these are true:

1. `plan-exec.sh status` returns `completed`
2. Specification files exist under `<artifact_dir>/specifications/`

## Check for Specs

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"

HAS_SPECS=false
[ -f "$SPEC_DIR/PRD.md" ] && HAS_SPECS=true
[ -f "$SPEC_DIR/EDD/CORE.md" ] && HAS_SPECS=true
ls "$SPEC_DIR/IG/"*.md >/dev/null 2>&1 && HAS_SPECS=true
[ -f "$SPEC_DIR/TODO.md" ] && HAS_SPECS=true
```

## Behavior

**If no specs exist**: Skip silently. No suggestions without specs.

**If specs exist**: Invoke `/yf:engineer_suggest_updates plan_idx:<idx>` to generate advisory update suggestions.

The suggestions are displayed to the operator as part of the completion report. The operator decides which suggestions to apply via `/yf:engineer_update`.

## When This Does NOT Fire

- No specification files exist
- Plan is still executing (not yet completed)
- Mid-execution progress reports
- Individual task completion (only full plan completion)

## Advisory Only

This rule produces suggestions, not actions. It does NOT:
- Modify specification files
- Create beads for spec updates
- Block plan completion

The operator reviews suggestions and applies them manually if desired.
