# Plan: Reconcile GitHub Issues and TODO Register

## Context

GitHub issues and the TODO register at `docs/specifications/TODO.md` have drifted apart. Many issues describe features that have since been implemented, and most open TODOs lack GitHub issue references. This reconciliation establishes a single source of truth by closing resolved issues, pruning completed TODOs, and creating GitHub issues for remaining open work.

## Phase 1: Close Resolved/Defunct GitHub Issues (10 issues)

Close with a comment explaining the resolution:

| # | Title | Reason |
|---|-------|--------|
| 1 | Archivist topic-based layout | `yf_archive_process` implements `<slug>/SUMMARY.md` + `_index.md` master indexes |
| 3 | yf:setup .gitignore auto-configure | `plugin-preflight.sh` manages sentinel-bracketed `.gitignore` block + internal `.yoshiko-flow/.gitignore` |
| 5 | Stale chronicle dedup cleanup | `session-prune.sh do_ephemeral()` removes stale dated files on every SessionEnd |
| 7 | Chronicles not auto-captured at completion | `plan-exec.sh create_transition_chronicle` + Step 4 verification + fallback |
| 8 | Plan lifecycle not always triggering | `exit-plan-gate.sh` hook + code-gate backstop + rule 2.1 auto-chain |
| 10 | Improved Beads Orchestration | Full swarm dispatch with dependency-aware parallel execution, reactive bugfix, nesting |
| 13 | Factor PRD across spec docs | `yf_engineer_synthesizer` factors content across PRD/EDD/IG in one pass |
| 14 | yf:setup activation gate | Rule 1.0 + `yf-activation-check.sh` + preflight removes rules when inactive |
| 15 | yf:support skill | Close as duplicate of #2 |
| 17 | Subagent for plan-to-beads | `plan_breakdown` skill + rule 2.3 handle decomposition |

**Keep open (6 issues):**

| # | Title | Why still open |
|---|-------|---------------|
| 2 | Enhancement requests via gh | No support/feedback skill exists |
| 4 | PostToolUse ambient session log | No real-time tool capture; only retrospective chronicle-check |
| 6 | Archive auto-drafts at pre-push | Advisory only; auto-draft not implemented (P4 backlog by design) |
| 9 | Hybrid Teams usage | No TeamCreate/hybrid integration; swarm uses bare Task tool |
| 12 | Narrative diary entries | Partially addressed; needs stronger narrative voice/prose guidance |
| 16 | yf:todo skill | No todo skill exists |

## Phase 2: Prune Completed/Deprecated TODOs

**Move to Completed section** (already marked Resolved):
- TODO-008, TODO-010, TODO-011, TODO-014, TODO-017, TODO-027, TODO-028

**Resolve and move to Completed** (newly confirmed):
- TODO-033 — `plan_breakdown` skill exists; GH #17 being closed

## Phase 3: Link Existing TODOs to Existing GH Issues

- TODO-001 (PostToolUse ambient session log) → add reference to GH #4
- TODO-002 (Agent Teams hooks) → add reference to GH #9

## Phase 4: Create GH Issues for Open TODOs (12 new issues)

Group related testing items to avoid noise. Each group becomes one GH issue; all member TODOs reference it.

### Grouped Issues (4 issues)

**A. Swarm formula E2E validation** — TODO-003, 004, 005, 006
> Covers: auto-formula selection, nested composition, reactive bugfix triggers, formula cooking dry-run

**B. Code generation E2E tests** — TODO-023, 024, 025
> Covers: code-implement via plan pump, code-researcher IG pre-check, reactive bugfix in code-implement

**C. Specification behavioral tests** — TODO-019, 020, 021, 022
> Covers: UC-008 reactive bugfix eligibility, UC-018-021 engineer workflows, UC-014-017 archivist workflows, integration test refresh

**D. Plan lifecycle E2E tests** — TODO-026, 029, 030
> Covers: intake integrity gate, memory reconciliation, skill-level chronicle capture

### Individual Issues (8 issues)

| TODO | Title | Priority |
|------|-------|----------|
| TODO-009 | Validate automatic migration for legacy beads deployments | P2 |
| TODO-012 | Monitor symlink compatibility across platforms/CI | P3 |
| TODO-013 | Consider per-subsystem EDD files for complex projects | P3 |
| TODO-015 | `bd create --type=gate` validation errors; gate-as-task workaround | P2 |
| TODO-016 | Verify config pruning on existing installations with old toggle keys | P2 |
| TODO-018 | Confirm chronicle safety net fires without false positives | P2 |
| TODO-031 | Fix unit-chronicle-check.yaml relative path resolution | P2 |
| TODO-032 | code-gate.sh glob patterns require absolute path prefix | P3 |

## Phase 5: Rewrite TODO Register

Update `docs/specifications/TODO.md`:
1. Remove resolved items from Active section → move to Completed section
2. Add GH issue references (`GH #NN`) to every open TODO
3. Grouped TODOs reference their shared GH issue number

## Verification

- `gh issue list --repo dixson3/claude-plugins --state open` shows only the 6 kept + 12 new = 18 open issues
- `gh issue list --repo dixson3/claude-plugins --state closed` shows 10 newly closed + 1 previously closed = 11 closed
- Every Active TODO in `TODO.md` has a `GH #NN` reference
- No resolved/deprecated items remain in Active section

## Files Modified

- `docs/specifications/TODO.md` — pruned and updated with GH references
