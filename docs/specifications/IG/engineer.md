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
8. In gate mode with `blocking` config: presents conflicts via AskUserQuestion
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
3. Skill reads completed plan beads, CHANGES/FINDINGS/REVIEW comments
4. Skill compares completed work against current specs
5. Skill outputs advisory suggestions (new REQs, updated DDs, new UCs)
6. Operator reviews and manually applies via `/yf:engineer_update`

**Postconditions**: Suggestions displayed. No automatic modifications.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/engineer_suggest_updates/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/engineer-suggest-on-completion.md`
