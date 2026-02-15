# Rule: Auto-Chain Plan Lifecycle After ExitPlanMode

**Applies:** Immediately after ExitPlanMode completes

When ExitPlanMode completes and you see "Auto-chaining plan lifecycle..." in the hook output, execute the following steps automatically without waiting for user input:

## Auto-Chain Sequence

> **Note:** A plan-save chronicle stub was already created deterministically by `exit-plan-gate.sh` via `plan-chronicle.sh`. You do not need to create one. If the planning discussion had significant design rationale beyond the plan file, you may optionally invoke `/yf:chronicle_capture topic:planning` for enrichment — but the stub is guaranteed.

1. **Format the plan file**: Open the saved plan file (path in `PLAN_FILE=` output) and ensure it has the standard structure:

   ```markdown
   # Plan <idx>: <Title>

   **Status:** Draft
   **Date:** YYYY-MM-DD

   ## Overview
   <consolidated plan content>

   ## Implementation Sequence
   <ordered list of phases/steps>

   ## Completion Criteria
   - [ ] Criterion 1
   - [ ] Criterion 2
   ```

   The plan file is in `docs/plans/` which is exempt from the plan gate.

1.5. **Reconcile with specifications**: If `<artifact_dir>/specifications/` exists and contains spec files, invoke `/yf:engineer_reconcile plan_file:<path> mode:gate`. If conflicts are detected, present to operator and await decision. If no specs, skip.

2. **Update MEMORY.md**: Add the plan reference under "Current Plans" in the project MEMORY.md.

3. **Create beads**: Invoke `/yf:plan_create_beads` with the plan file. This creates the epic/task hierarchy, gates, labels, dependencies, and defers all tasks.

4. **Start execution**: Run the plan execution start:
   ```bash
   ROOT_EPIC=$(bd list -l plan:<idx> --type=epic --status=open --limit=1 --json 2>/dev/null \
     | jq -r '.[0].id // empty')
   bash plugins/yf/scripts/plan-exec.sh start "$ROOT_EPIC"
   ```
   This resolves the gate, undefers tasks, and removes `.yoshiko-flow/plan-gate`.

5. **Begin dispatch**: Invoke `/yf:plan_execute` to start the task pump and dispatch work.

## Abort

If any step fails, stop the chain and report the error. The user can:
- Retry the failed step manually
- Run `/yf:plan_dismiss_gate` to abandon the plan lifecycle

## Important

- Do NOT wait for user confirmation between steps — this is an automatic chain
- The plan gate blocks Edit/Write on implementation files, but all auto-chain operations use Bash (`bd` commands) and exempt paths (`docs/plans/`), so the gate does not interfere
- If the user said "engage the plan" explicitly (gate already existed before ExitPlanMode), the hook exits silently with no "Auto-chaining" output — this rule does NOT fire in that case
- Legacy manual triggers ("the plan is ready", "execute the plan") still work via `/yf:plan_engage`
- Chronicle creation is handled deterministically by the hook — do not duplicate it in the chain
