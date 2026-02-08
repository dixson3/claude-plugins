# Plan 11: Deterministic Plan Lifecycle & Chronicle Triggers

**Status:** Completed
**Date:** 2026-02-08

## Context

When implementing Plan 10, the entire auto-chain lifecycle was bypassed. The user had previously written the plan in plan mode (`.claude/plans/goofy-finding-stardust.md` created at 10:34), then exited plan mode with "clear context and bypass permissions." This created a new session where the user said "Implement the following plan:" with the plan pasted inline. In this new session:

1. **ExitPlanMode was never called** — the hook `exit-plan-gate.sh` never fired
2. **No "Auto-chaining" signal** appeared — `auto-chain-plan.md` rule never triggered
3. **No plan file was saved** to `docs/plans/` by the hook (plan-10.md was created manually at the end)
4. **No chronicle beads** were created — `plan-transition-chronicle.md` never fired
5. **No structured beads hierarchy** — ad-hoc `bd create` calls instead of `plan_to_beads`
6. **No task pump dispatch** — work done directly instead of through `execute_plan`
7. **`watch-for-chronicle-worthiness`** rule was passive and never suggested capture

Three root causes:

**A. The auto-chain depends on a single fragile trigger** — ExitPlanMode → hook → "Auto-chaining" string → rule chain. If any link breaks (context clear, pasted plan, manual execution), everything falls through silently.

**B. No fallback detection** — when a plan exists but the auto-chain didn't fire, nothing warns the agent. The agent just proceeds with implementation, creating ad-hoc beads instead of the structured hierarchy.

**C. Chronicle capture is entirely passive** — `watch-for-chronicle-worthiness` only suggests, never auto-captures. During a long implementation session, no chronicles were created.

## Approach

Fix at three levels:

1. **Add a `plan-intake` rule** that detects when an agent is about to implement a plan without the auto-chain having fired, and redirects to the proper lifecycle
2. **Add a `plan-lifecycle-guard` hook** that catches common bypass scenarios and warns
3. **Make chronicle capture semi-automatic** at key lifecycle boundaries (plan start, plan complete, session close)

## Implementation

### Phase 1: Plan Intake Rule

Create `.claude/rules/plan-intake.md` (source: `plugins/workflows/rules/plan-intake.md`).

This rule fires when:
- The user says "implement the/this plan" or provides plan content to execute
- The conversation contains plan-like content (headings like "## Implementation", "## Phases", completion criteria)
- But NO auto-chain signal has appeared in the conversation

**Behavior:**
```
When you're about to implement a plan and the auto-chain has NOT fired:

1. CHECK: Is there a plan file in docs/plans/ for this plan?
   - If no: Save the plan content to docs/plans/plan-<next-idx>.md

2. CHECK: Do beads exist for this plan?
   - Run: bd list -l plan:<idx> --type=epic
   - If no beads: Invoke /workflows:plan_to_beads docs/plans/plan-<idx>.md

3. CHECK: Is the plan in Executing state?
   - Check: .claude/.plan-gate should NOT exist (removed by plan-exec.sh start)
   - If gate exists or tasks are deferred: Run plan-exec.sh start <root-epic>

4. CHECK: Was a chronicle capture made for planning context?
   - If this is the start of implementation and planning discussion exists:
     Invoke /chronicler:capture topic:planning

5. Proceed with /workflows:execute_plan to dispatch via task pump
```

This is the **critical missing piece** — it catches the "pasted plan" scenario and routes it through the proper lifecycle.

### Phase 2: Plan Lifecycle Guard Hook

Create `plugins/workflows/hooks/plan-lifecycle-guard.sh` — a `PreToolUse` hook on `Edit` and `Write` (alongside code-gate.sh) that checks:

When there's NO `.plan-gate` file AND NO lock file entry for the current plan, AND the agent is about to write implementation files:

Output a warning (not a block):
```
⚠ No active plan lifecycle detected. If you're implementing a plan,
  consider running the plan lifecycle first:
  /workflows:plan_to_beads → plan-exec.sh start → /workflows:execute_plan
```

This is advisory (exit 0), not blocking (exit 2). It fires once per session (creates a `.claude/.plan-lifecycle-warned` sentinel).

**However** — this adds latency to every Edit/Write. Alternative: make it a rule instead of a hook (no performance cost, relies on agent compliance).

Decision: **Rule only** (Phase 1 covers this). Skip the hook to avoid Edit/Write latency.

### Phase 3: Semi-Automatic Chronicle Capture

Modify `watch-for-chronicle-worthiness.md` to be more assertive at lifecycle boundaries:

**Current behavior:** "Suggest and let user decide" (always passive)

**New behavior at boundaries:**
- **Plan execution start** → Auto-capture planning context (rule in `plan-intake.md` handles this)
- **Plan execution complete** → Auto-capture completion summary (add to `execute_plan` skill)
- **Session close** → The `BEADS.md` "Landing the Plane" protocol already exists. Add a chronicle capture step.

Specific changes:

1. **`execute_plan` skill**: Add a step at the end that invokes `/chronicler:capture topic:completion` when all plan tasks are done, before marking the plan complete.

2. **`BEADS.md` rule** (the "Landing the Plane" section): Add chronicle capture as step 1.5 (after filing issues, before running quality gates):
   ```
   1.5 **Capture context** (if significant work was done):
       /chronicler:capture topic:session-close
   ```

3. **`plan-intake.md` rule** (from Phase 1): Already captures planning context at plan start.

This gives us automatic chronicle capture at the three key lifecycle points: plan start, plan complete, and session close.

### Phase 4: Add to Artifact Manifests

Add new files to `plugin.json` artifacts so preflight installs them:

**workflows plugin.json** — add to `artifacts.rules`:
```json
{ "source": "rules/plan-intake.md", "target": ".claude/rules/plan-intake.md" }
```

**workflows rules/BEADS.md** — update source with chronicle step.

### Phase 5: Tests & Version Bumps

- Add `tests/scenarios/unit-plan-intake.yaml` — test that plan-intake rule content is correct
- Update `unit-preflight.yaml` — verify new rule is synced
- Bump workflows to 1.6.0, marketplace to 1.8.0
- Update CHANGELOG.md

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `plugins/workflows/rules/plan-intake.md` | **Create** | Catch pasted/manual plans, redirect to lifecycle |
| `plugins/workflows/rules/BEADS.md` | **Modify** | Add chronicle capture to Landing the Plane |
| `plugins/workflows/skills/execute_plan/SKILL.md` | **Modify** | Add chronicle capture on plan completion |
| `plugins/workflows/.claude-plugin/plugin.json` | **Modify** | Add plan-intake.md to artifacts, bump version |
| `.claude-plugin/marketplace.json` | **Modify** | Bump version |
| `CHANGELOG.md` | **Modify** | Document changes |
| `tests/scenarios/unit-plan-intake.yaml` | **Create** | Verify rule content |

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass
2. Manual test: Start a new session, paste a plan with "implement this plan", verify the plan-intake rule fires and routes through lifecycle
3. Verify chronicle capture happens at plan start and plan end
4. Verify BEADS.md Landing the Plane includes chronicle step

## Completion Criteria

- [ ] `plan-intake.md` rule catches pasted/manual plans
- [ ] Planning context auto-captured as chronicle bead at plan start
- [ ] Completion context auto-captured at plan end (in execute_plan)
- [ ] Session close includes chronicle capture (in BEADS.md)
- [ ] New rule in artifact manifest and synced by preflight
- [ ] Tests pass
- [ ] Version bumps and changelog
