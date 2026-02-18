# Plan: Strengthen Chronicle Worthiness Detection

## Context

Chronicle capture during plan execution consistently misses important events. The root causes:

1. **Rule 5.3 is vague** — Categories like "significant progress" and "important decisions" give agents no actionable triggers.
2. **Subagents never see Rule 5.3** — Rules load into the main agent context only. Swarm agents and Task-dispatched subagents operate without chronicle awareness.
3. **Decision-making skills have zero chronicle hooks** — `engineer_reconcile`, `engineer_update`, `swarm_qualify`, and `plan_intake` produce high-value verdicts and spec mutations but never create chronicle beads.
4. **Formula chronicle flags are unused** — `swarm_dispatch` Step 6c supports `"chronicle": true` per formula step, but all 6 formulas ship without it.

## "What to Chronicle" — Concrete Definition

Replace vague categories with this taxonomy. An event is chronicle-worthy when it produces **context that would be lost** and **would be needed to understand future work**.

| Trigger | Why It Matters | Detection |
|---------|---------------|-----------|
| **Verdict at a gate** — PASS/BLOCK/NEEDS-RECONCILIATION | The reasoning behind the verdict informs future decisions | Skill auto-captures after verdict |
| **Spec mutation** — REQ/DD/NFR/UC/TODO added, updated, or deprecated | Contract changes that alter what the software should do | Skill auto-captures after write |
| **Failure before recovery** — test failures, review blocks, build errors | The failure context explains why the fix was needed | Formula flag + agent protocol |
| **Plan deviation** — implementation diverges from task description | The gap between plan and reality reveals invalid assumptions | Agent behavioral (write-capable agents) |
| **Unexpected discovery** — constraint or behavior not in upstream FINDINGS | New knowledge that future work depends on | Agent behavioral (write-capable agents) |
| **Scope change** — decomposition into 3+ children, dependency rewiring | Changes the shape of work and affects downstream tasks | Skill auto-captures after breakdown |

**NOT chronicle-worthy**: routine task completion matching the plan, config tweaks, formatting, typo fixes, intermediate pipeline steps (the terminal step captures the outcome).

## Files to Modify

| File | Change |
|------|--------|
| **Rules** | |
| `plugins/yf/rules/yf-rules.md` | Rewrite Rule 5.3 with concrete trigger table and taxonomy |
| **Skills (add chronicle steps)** | |
| `plugins/yf/skills/engineer_reconcile/SKILL.md` | Add Step 7.5: chronicle on NEEDS-RECONCILIATION + operator decision |
| `plugins/yf/skills/engineer_update/SKILL.md` | Add Step 3.5: chronicle on add/update/deprecate actions |
| `plugins/yf/skills/swarm_qualify/SKILL.md` | Add Step 6.5: chronicle on PASS and BLOCK verdicts |
| `plugins/yf/skills/plan_breakdown/SKILL.md` | Add Step 5.5: chronicle on non-trivial decomposition (3+ children) |
| `plugins/yf/skills/plan_intake/SKILL.md` | Add Step 1.5g: chronicle reconciliation verdict from Step 1.5f |
| **Formulas (enable chronicle flags)** | |
| `plugins/yf/formulas/feature-build.formula.json` | `"chronicle": true` on `review` step |
| `plugins/yf/formulas/code-implement.formula.json` | `"chronicle": true` on `review` step |
| `plugins/yf/formulas/build-test.formula.json` | `"chronicle": true` on `review` step |
| `plugins/yf/formulas/code-review.formula.json` | `"chronicle": true` on `report` step |
| `plugins/yf/formulas/bugfix.formula.json` | `"chronicle": true` on `verify` step |
| **Agents (chronicle protocol)** | |
| `plugins/yf/agents/yf_code_writer.md` | Add Chronicle Protocol section (can `bd create`) |
| `plugins/yf/agents/yf_code_tester.md` | Add Chronicle Protocol section (can `bd create`) |
| `plugins/yf/agents/yf_swarm_tester.md` | Add Chronicle Protocol section (can `bd create`) |
| `plugins/yf/agents/yf_swarm_researcher.md` | Add Chronicle Signal guidance (read-only; flag in FINDINGS) |
| `plugins/yf/agents/yf_swarm_reviewer.md` | Add Chronicle Signal guidance (read-only; flag in REVIEW) |
| `plugins/yf/agents/yf_code_researcher.md` | Add Chronicle Signal guidance (read-only; flag in FINDINGS) |
| `plugins/yf/agents/yf_code_reviewer.md` | Add Chronicle Signal guidance (read-only; flag in REVIEW) |
| **Specifications** | |
| `docs/specifications/PRD.md` | Add REQ-038 (skill-level chronicle capture), FS-043 |
| `docs/specifications/IG/chronicler.md` | Add UC-038 (skill-level auto-chronicle at decision points) |
| `docs/specifications/test-coverage.md` | Add REQ-038, UC-038 rows; update counts |
| `docs/specifications/TODO.md` | Add TODO-030 (E2E validation) |
| **Tests** | |
| `tests/scenarios/unit-chronicle-worthiness.yaml` | **New** — existence checks for chronicle hooks in skills, formula flags, agent protocols |
| **Documentation** | |
| `CHANGELOG.md` | Append to v2.21.0 |
| `plugins/yf/README.md` | Update Chronicler section |

## Implementation

### Step 0: Specification Additions

**PRD.md** — Add after REQ-037:
```
| REQ-038 | Chronicle beads must be auto-created at skill decision points (gate verdicts, spec mutations, qualification outcomes, scope changes) and at swarm step completion when formula flags are enabled. | P1 | Chronicler | Plan 44 | `plugins/yf/rules/yf-rules.md` (Rule 5.3) |
```

Add after FS-042:
```
- FS-043: Skill-level chronicle capture fires deterministically at decision points — verdicts, spec mutations, scope changes. Formula-level chronicle capture fires via `"chronicle": true` step flag on terminal swarm steps. Write-capable swarm agents capture plan deviations and unexpected discoveries directly via `bd create`. Read-only agents signal chronicle-worthy content via `CHRONICLE-SIGNAL:` lines in structured comments, consumed by `swarm_dispatch` Step 6c.
```

**IG/chronicler.md** — Add UC-038 after UC-037.

**test-coverage.md** — Add REQ-038, UC-038 rows. Update counts.

**TODO.md** — Add TODO-030: "E2E validation of skill-level chronicle capture during real plan execution."

### Step 1: Rewrite Rule 5.3

Replace the current Rule 5.3 in `yf-rules.md` with a concrete trigger table. The new rule has three tiers:

**Tier 1 — Auto-capture (deterministic, no suggestion needed):**
These fire within skills. The agent does NOT need to watch for them.

| Event | Skill | Captures |
|-------|-------|----------|
| Reconciliation conflict | `engineer_reconcile` Step 7.5 | Verdict, conflicts, operator decision |
| Spec mutation | `engineer_update` Step 3.5 | Action, entry ID, rationale |
| Qualification verdict | `swarm_qualify` Step 6.5 | PASS/BLOCK, scope, issues |
| Scope change (3+ children) | `plan_breakdown` Step 5.5 | Parent task, child count, decomposition rationale |
| Intake reconciliation | `plan_intake` Step 1.5g | Reconciliation verdict, spec changes approved |
| Swarm step completion | `swarm_dispatch` Step 6c | Step comment content (when formula `"chronicle": true`) |

**Tier 2 — Agent-initiated (behavioral, write-capable agents):**
Write-capable swarm agents (`yf_code_writer`, `yf_code_tester`, `yf_swarm_tester`) create chronicle beads when they encounter:

- **Plan deviation**: implementation diverges from task description or upstream FINDINGS
- **Unexpected discovery**: constraint, dependency, or behavior not anticipated
- **Test failure with non-obvious cause**: failure whose root cause is not the code under test

Using: `bd create --type task --title "Chronicle: <summary>" -l ys:chronicle,ys:topic:swarm --description "<what, why, impact>"`

**Tier 3 — Advisory (main agent watches):**
The main orchestrating agent suggests `/yf:chronicle_capture` for:

- Context switches between plan tasks (at most once per switch)
- Significant blockers requiring human input
- Session boundaries (already in Rule 4.2 step 2)

Cadence: at most once every 15 minutes. Categories 1 and 2 above are NOT advisory — they fire automatically.

### Step 2: Add Chronicle Steps to Skills

Each skill gets a new step that creates a chronicle bead using `bd create`. The pattern:

```bash
bd create --type task \
  --title "Chronicle: <skill-name> — <brief outcome>" \
  -l ys:chronicle,ys:chronicle:auto,ys:topic:<topic>[,plan:<idx>] \
  --description "<structured context>"
```

**`engineer_reconcile/SKILL.md`** — Add Step 7.5 after verdict, before report:
- Trigger: verdict is NEEDS-RECONCILIATION (skip on PASS — routine compliance is not chronicle-worthy)
- Captures: PRD/EDD/IG individual verdicts, specific conflicts, operator choice (update specs / modify plan / acknowledge)
- Labels: `ys:topic:engineer`

**`engineer_update/SKILL.md`** — Add Step 3.5 after executing the action:
- Trigger: always on add/update/deprecate (every spec mutation is a contract change)
- Captures: action type, entry ID, file modified, rationale
- Labels: `ys:topic:engineer`

**`swarm_qualify/SKILL.md`** — Add Step 6.5 after processing verdict:
- Trigger: always (both PASS and BLOCK are chronicle-worthy — PASS captures the quality checkpoint, BLOCK captures what needs fixing)
- Captures: verdict, review scope (start SHA, files), issues found
- Labels: `ys:topic:qualification`

**`plan_breakdown/SKILL.md`** — Add Step 5.5 after agent selection:
- Trigger: 3+ child beads created (trivial 1-2 child splits are routine)
- Captures: parent task title, child count, decomposition rationale, dependency graph summary
- Labels: `ys:topic:planning`

**`plan_intake/SKILL.md`** — Add Step 1.5g after Step 1.5f reconciliation:
- Trigger: reconciliation ran and produced a result (skip if no specs exist)
- Captures: reconciliation verdict, any spec changes approved in Steps 1.5a-d, structural consistency result
- Labels: `ys:topic:planning`

### Step 3: Enable Formula Chronicle Flags

Add `"chronicle": true` to terminal verdict/verification steps in 5 formulas:

| Formula | Step | Why |
|---------|------|-----|
| `feature-build` | `review` | Captures the full build cycle outcome |
| `code-implement` | `review` | Captures standards-driven review verdict |
| `build-test` | `review` | Captures test+review cycle outcome |
| `code-review` | `report` | Captures standalone review verdict |
| `bugfix` | `verify` | Captures fix confirmation (root cause + test proof) |

Skip `research-spike` — its `archive` step already creates an archive bead.

The existing `swarm_dispatch` Step 6c mechanism handles these: when a step with `"chronicle": true` completes, the dispatch loop auto-creates a `ys:chronicle,ys:chronicle:auto,ys:topic:swarm` bead with the step's structured comment content.

### Step 4: Agent Chronicle Protocol

**Write-capable agents** (`yf_code_writer`, `yf_code_tester`, `yf_swarm_tester`) — Add a "Chronicle Protocol" section:

```markdown
## Chronicle Protocol

If you encounter any of the following during your work, create a chronicle bead BEFORE posting your structured comment:

- **Plan deviation**: Your implementation diverges from the task description or upstream FINDINGS
- **Unexpected discovery**: A constraint, dependency, or behavior not anticipated in the task
- **Non-obvious failure**: A test failure whose root cause is not the code under test (e.g., environment issue, dependency conflict, spec gap)

To create:
\`\`\`bash
bd create --type task \
  --title "Chronicle: <brief summary>" \
  -l ys:chronicle,ys:topic:swarm \
  --description "<what happened, why it matters, impact on task>"
\`\`\`

Do NOT chronicle routine completions, expected test passes, or standard implementations matching the plan.
```

**Read-only agents** (`yf_swarm_researcher`, `yf_swarm_reviewer`, `yf_code_researcher`, `yf_code_reviewer`) — Add a "Chronicle Signal" section:

```markdown
## Chronicle Signal

If your analysis reveals something the orchestrator should chronicle — an unexpected constraint, a significant finding that changes the implementation approach, or a blocking issue with design implications — include a `CHRONICLE-SIGNAL:` line at the end of your structured comment:

\`\`\`
CHRONICLE-SIGNAL: <one-line summary of what should be chronicled and why>
\`\`\`

The dispatch loop reads this signal and auto-creates a chronicle bead. Only include this line for genuinely significant discoveries, not routine findings.
```

Update `swarm_dispatch` Step 6c to also check for `CHRONICLE-SIGNAL:` in step comments (in addition to the existing `"chronicle": true` flag). This gives read-only agents a path to trigger chronicles without needing `bd create` access.

### Step 5: Tests

**New: `tests/scenarios/unit-chronicle-worthiness.yaml`** — Existence checks:

1. Rule 5.3 contains "Auto-capture" tier with trigger table
2. Rule 5.3 contains "Agent-initiated" tier referencing write-capable agents
3. `engineer_reconcile/SKILL.md` references `ys:chronicle` (Step 7.5)
4. `engineer_update/SKILL.md` references `ys:chronicle` (Step 3.5)
5. `swarm_qualify/SKILL.md` references `ys:chronicle` (Step 6.5)
6. `plan_breakdown/SKILL.md` references `ys:chronicle` (Step 5.5)
7. `plan_intake/SKILL.md` references chronicle in Step 1.5g
8. `feature-build.formula.json` contains `"chronicle": true`
9. `code-implement.formula.json` contains `"chronicle": true`
10. `bugfix.formula.json` contains `"chronicle": true`
11. `yf_code_writer.md` contains "Chronicle Protocol"
12. `yf_swarm_reviewer.md` contains "CHRONICLE-SIGNAL"
13. `swarm_dispatch/SKILL.md` references "CHRONICLE-SIGNAL"

### Step 6: Documentation

- **CHANGELOG.md**: Append to v2.21.0 Added/Changed
- **README.md**: Update Chronicler section to mention skill-level auto-capture and agent protocol

## Verification

1. `bash tests/run-tests.sh --unit-only` — all tests pass including new chronicle-worthiness tests
2. `bash plugins/yf/scripts/spec-sanity-check.sh all` — 6/6 pass with updated counts
3. Manual spot-check: read `engineer_reconcile/SKILL.md` and verify Step 7.5 creates a chronicle bead on NEEDS-RECONCILIATION
4. Manual spot-check: read `code-implement.formula.json` and verify `review` step has `"chronicle": true`
5. Manual spot-check: read `yf_code_writer.md` and verify Chronicle Protocol section exists

## Execution Order

1. Step 0 — Specs first
2. Step 1 — Rule 5.3 rewrite
3. Step 2 — Skill chronicle steps (5 skills, parallel)
4. Step 3 — Formula flags (5 files, parallel)
5. Step 4 — Agent protocols (7 files, parallel)
6. Step 5 — Tests
7. Step 6 — Documentation
