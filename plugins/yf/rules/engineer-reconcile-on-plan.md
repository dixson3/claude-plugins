# Rule: Reconcile Specifications on Plan Save

**Applies:** During auto-chain, after plan file is saved to `docs/plans/` and before beads creation

## Detection

This rule fires when ALL of these are true:

1. The auto-chain is active (you see "Auto-chaining plan lifecycle..." or "Plan saved to docs/plans/")
2. Specification files exist under `<artifact_dir>/specifications/`
3. The `engineer.reconciliation_mode` config is not `"disabled"`

## Check for Specs

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"

HAS_SPECS=false
[ -f "$SPEC_DIR/PRD.md" ] && HAS_SPECS=true
[ -f "$SPEC_DIR/EDD/CORE.md" ] && HAS_SPECS=true
ls "$SPEC_DIR/IG/"*.md >/dev/null 2>&1 && HAS_SPECS=true
```

## Behavior

**If no specs exist**: Skip silently. No enforcement without specs.

**If specs exist**: Invoke `/yf:engineer_reconcile plan_file:<path> mode:gate` between the plan format step and beads creation step of the auto-chain.

- If `PASS`: Proceed with auto-chain (beads creation).
- If `NEEDS-RECONCILIATION` and mode is `blocking`: Present conflicts to operator via AskUserQuestion. Await decision before continuing.
- If `NEEDS-RECONCILIATION` and mode is `advisory`: Output the report as a note, proceed with auto-chain.

## Timing in Auto-Chain

This fires at step 1.5 of the auto-chain sequence:

1. Format the plan file
1.5. **Reconcile with specifications** ← this rule
2. Update MEMORY.md
3. Create beads
4. Start execution
5. Begin dispatch

## When This Does NOT Fire

- No specification files exist (zero-cost for projects without specs)
- `engineer.reconciliation_mode` is `"disabled"` in config
- Manual plan transitions (not auto-chain) — the `watch-for-spec-drift` rule handles those
- The user explicitly skipped reconciliation

## Configuration

`.yoshiko-flow/config.json`:
```json
{
  "config": {
    "engineer": {
      "reconciliation_mode": "blocking"
    }
  }
}
```

Values: `"blocking"` (default), `"advisory"`, `"disabled"`
