# Implementation Guide: Engineer (Specification Artifacts)

## Overview

The engineer capability synthesizes and maintains specification documents -- PRD, EDD, Implementation Guides, and TODO register -- from existing project context. When specs exist, plans are reconciled against them before execution, creating a feedback loop between specification and implementation.

## Use Cases

### UC-018: Synthesize Specifications from Project Context

**Actor**: Operator

**Preconditions**: Project has plans, diary entries, research, and/or decisions to synthesize from.

**Flow**:
1. Operator invokes `/yf:engineer_analyze_project scope:all`
2. Skill checks which specs already exist in `<artifact_dir>/specifications/`
3. For missing specs (unless `force`): launches `yf_engineer_synthesizer` agent
4. Agent reads plans, diary, research, decisions, and codebase structure
5. Agent returns JSON with spec content for each document type
6. Skill writes files:
   - `specifications/PRD.md` -- REQ-xxx requirement matrix
   - `specifications/EDD/CORE.md` -- DD-xxx decisions, NFR-xxx requirements
   - `specifications/IG/<feature>.md` -- UC-xxx use cases per feature
   - `specifications/TODO.md` -- TODO-xxx deferred items
7. For existing specs with `force`: skill shows diff and confirms before overwriting

**Postconditions**: Specification files generated in `<artifact_dir>/specifications/`.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_analyze_project/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_engineer_synthesizer.md`

### UC-019: Reconcile Plan Against Specifications

**Actor**: System (auto-chain step 1.5) or Operator

**Preconditions**: Specification files exist. A plan has been saved.

**Flow**:
1. `/yf:engineer_reconcile plan_file:<path>` invoked
2. Skill reads all spec files under `<artifact_dir>/specifications/`
3. If no specs exist: returns PASS silently
4. PRD check: plan tasks vs REQ-xxx IDs -- flags untraced functionality and contradictions
5. EDD check: plan approach vs DD-xxx/NFR-xxx -- flags technology/architecture conflicts
6. IG check: plan tasks vs UC-xxx use cases -- flags affected features
7. Output: structured report with `PASS` or `NEEDS-RECONCILIATION`
8. In gate mode with `blocking` config (default — see DD-009): presents conflicts via AskUserQuestion
9. In gate mode with `advisory` config: outputs report, proceeds
10. In gate mode with `disabled` config: skips entirely

**Postconditions**: Reconciliation report generated. Auto-chain proceeds or blocks based on config.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_reconcile/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/engineer-reconcile-on-plan.md`

### UC-020: Update Individual Spec Entry

**Actor**: Operator

**Preconditions**: Specification files exist.

**Flow**:
1. Operator invokes `/yf:engineer_update type:prd action:add`
2. Skill reads current spec file
3. Skill auto-generates next sequential ID (e.g., REQ-032)
4. Skill adds new entry with provided content
5. Skill suggests cross-references (e.g., if PRD change affects architecture, suggests EDD update)
6. Skill writes updated spec file

**Postconditions**: Spec entry added/updated/deprecated with correct ID.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_update/SKILL.md`

### UC-021: Suggest Spec Updates After Plan Completion

**Actor**: System (plan completion)

**Preconditions**: Plan execution completed. Specification files exist.

**Flow**:
1. `engineer-suggest-on-completion` rule fires after plan completion
2. Rule invokes `/yf:engineer_suggest_updates plan_idx:<idx>`
3. Skill reads completed plan tasks, CHANGES/FINDINGS/REVIEW comments
4. Skill compares completed work against current specs
5. Skill outputs advisory suggestions (new REQs, updated DDs, new UCs)
6. Operator reviews and manually applies via `/yf:engineer_update`

**Postconditions**: Suggestions displayed. No automatic modifications.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_suggest_updates/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/engineer-suggest-on-completion.md`

### UC-033: Plan Intake Specification Integrity Gate

**Actor**: System (auto-chain step 1.5) or Manual intake

**Preconditions**: Specification files exist. A plan has been saved.

**Flow**:
1. Check specs exist: `test -d "${ARTIFACT_DIR}/specifications"`
2. **1.5a** Contradiction check: compare plan against PRD/EDD/IG items; if contradictions found, present to operator via AskUserQuestion
3. **1.5b** New capability check: identify untraced functionality; if found, propose spec additions with operator approval
4. **1.5c** Test-spec alignment check: verify test plan references spec items (REQ-xxx, UC-xxx, DD-xxx) not just implementation
5. **1.5d** Test deprecation check: identify tests that would become invalid from proposed changes
6. **1.5e** Chronicle changes: create chronicle entries for spec and capability changes
7. **1.5f** Structural consistency: run `spec-sanity-check.sh all`; in blocking mode present issues, in advisory mode report and proceed
8. Run spec reconciliation: `/yf:engineer_reconcile plan_file:<path> mode:gate`

**Postconditions**: Plan validated against specs. Operator approved any spec changes. Chronicle entries created for changes.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_intake/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/spec-sanity-check.sh`

### UC-034: Plan Completion Spec Self-Reconciliation

**Actor**: System (plan completion)

**Preconditions**: Plan execution completed. Specification files exist.

**Flow**:
1. Generate diary from plan chronicles (`/yf:chronicle_diary plan:<idx>`)
2. Process archives (`/yf:archive_process plan:<idx>`)
3. Run structural staleness check: `spec-sanity-check.sh all` — include results in completion report
4. Reconcile specs with themselves: verify PRD→EDD→IG traceability, test-coverage consistency, no orphaned/stale entries
5. Use `/yf:engineer_suggest_updates plan_idx:<idx>` for advisory suggestions
6. Verify deprecated artifacts (identified at intake 1.5d) were removed; flag any remaining as open items

**Postconditions**: Completion report includes sanity check results, self-reconciliation verdict, and deprecated artifact status.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/plan_execute/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/scripts/spec-sanity-check.sh`
