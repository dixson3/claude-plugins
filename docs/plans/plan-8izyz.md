# Workflow Dispatch Model — Comprehensive Reference

## Context

This document maps the complete decision tree for how work is dispatched in the yf plugin: when subagents launch, when swarms execute, and when actions run inline. This is a reference document, not an implementation plan.

---

## Three Dispatch Modes

| Mode | Mechanism | When Used |
|------|-----------|-----------|
| **Inline** | Lead agent executes directly | Bead creation, state transitions, validation, spec updates |
| **Bare Subagent** | Single `Task()` call | Atomic tasks (single file/concern), batch processing of beads |
| **Swarm** | `/yf:swarm_run` → multi-step formula | Complex tasks needing research + implement + review phases |

---

## Decision Flowchart

```
New work item
    │
    ├─ Is it a bead from a plan?
    │   │
    │   ├─ Has formula:<name> label? ──YES──► SWARM dispatch
    │   │                                     /yf:swarm_run formula:<name>
    │   │                                     Multi-agent, structured comments,
    │   │                                     reactive bugfix, worktree isolation
    │   │
    │   ├─ Has agent:<name> label? ───YES──► BARE SUBAGENT dispatch
    │   │                                    Task(subagent_type=<agent>)
    │   │                                    Single agent, caller closes bead
    │   │
    │   └─ Neither label ─────────────────► BARE SUBAGENT dispatch
    │                                        Task(subagent_type=general-purpose)
    │
    └─ Is it a skill invocation?
        │
        ├─ Capture skill ─────────────────► INLINE (create bead directly)
        │   chronicle_capture, archive_capture, issue_capture
        │
        ├─ Process skill ─────────────────► BARE SUBAGENT (batch transform)
        │   chronicle_diary, archive_process, issue_process
        │
        ├─ Validation skill ──────────────► INLINE (direct analysis)
        │   engineer_reconcile, engineer_suggest_updates
        │
        ├─ Synthesis skill ───────────────► BARE SUBAGENT (complex generation)
        │   engineer_analyze_project
        │
        └─ Lifecycle skill ───────────────► INLINE orchestrator (calls other skills)
            session_land, plan_intake, plan_engage, plan_execute
```

---

## Swarm Dispatch in Detail

### How beads get formula labels

During `/yf:plan_create_beads`, the system runs `/yf:swarm_select_formula` on each bead:

| Task Keywords | Formula Assigned | Steps |
|---------------|-----------------|-------|
| create, build, implement, design | `feature-build` | research → implement(→build-test) → review |
| code, write + technology context | `code-implement` | research-standards → implement → test → review |
| fix, debug, bugfix | `bugfix` | diagnose → fix → verify |
| research, investigate, spike | `research-spike` | investigate → synthesize → archive |
| test, spec, coverage | `build-test` | implement → test → review |
| review, audit, inspect | `code-review` | analyze → report |
| no keyword match | *no label* | bare agent dispatch |

Atomic tasks (single file, single concern) skip formula assignment entirely.

### Inside a swarm: step-level agent routing

Each formula step declares `SUBAGENT:<type>` in its description. The dispatch loop parses this to select the agent:

| Agent Type | Capability | Worktree Isolated? |
|------------|-----------|-------------------|
| `Explore` | Read-only codebase search | No |
| `yf:yf_swarm_researcher` | Read-only research | No |
| `yf:yf_swarm_reviewer` | Read-only review | No |
| `yf:yf_code_researcher` | Read-only standards research | No |
| `yf:yf_code_reviewer` | Read-only code review | No |
| `general-purpose` | Full read/write/bash | **Yes** |
| `yf:yf_code_writer` | Full code implementation | **Yes** |
| `yf:yf_swarm_tester` | Test creation and execution | **Yes** |
| `yf:yf_code_tester` | Test creation and execution | **Yes** |

**Rule**: Read-only agents run without isolation. Write-capable agents always get `isolation: "worktree"`.

### Nested swarms (compose)

Formula steps can have a `compose` field triggering a nested formula:

```
feature-build (depth 0)
  └─ implement step has compose: "build-test"
       └─ build-test (depth 1)
            ├─ implement
            ├─ test
            └─ review
```

- Max nesting depth: **2**
- At depth 2, compose fields are ignored
- Nested swarms post comments on the **outermost** parent bead

### Reactive bugfix

When a swarm step posts `REVIEW:BLOCK` or `TESTS:` with failures:
1. `/yf:swarm_react` spawns a `bugfix` formula at depth+1
2. Original step is marked for retry
3. Budget: 1 retry per step
4. Design-level BLOCKs are excluded (require human judgment)

---

## Bare Subagent Dispatch in Detail

### From plan execution

Beads without formula labels dispatch as single Task calls:
- `agent:<name>` label → `Task(subagent_type=<name>)`
- No label → `Task(subagent_type=general-purpose)`
- Write-capable agents get `isolation: "worktree"`
- Caller (plan_execute loop) is responsible for bead closure

### From skills (batch processing)

Five skills launch dedicated subagents for batch work:

| Skill | Agent Launched | Purpose |
|-------|---------------|---------|
| `chronicle_diary` | `yf_chronicle_diary` | Consolidate open chronicles into diary markdown |
| `chronicle_recall` | `yf_chronicle_recall` | Synthesize open chronicles for context recovery |
| `archive_process` | `yf_archive_process` | Transform archive beads into permanent docs |
| `engineer_analyze_project` | `yf_engineer_synthesizer` | Generate spec artifacts from project context |
| `issue_process` | `yf_issue_triage` | Evaluate and triage staged issue beads |

---

## Inline Execution in Detail

### Capture skills (immediate recording)

| Skill | What It Does Inline |
|-------|-------------------|
| `chronicle_capture` | Analyze context → create `ys:chronicle` bead |
| `archive_capture` | Validate type → generate ID → create `ys:archive` bead |
| `issue_capture` | Disambiguate destination → create `ys:issue` bead |

### Validation/advisory skills

| Skill | What It Does Inline |
|-------|-------------------|
| `engineer_reconcile` | Parse specs + plan → check PRD/EDD/IG compliance → verdict |
| `engineer_suggest_updates` | Query completed work → compare against specs → suggest diffs |
| `engineer_update` | Locate spec file → add/update/deprecate entry → chronicle |

### Lifecycle orchestrators (inline but call other skills)

| Skill | Key Delegations |
|-------|----------------|
| `session_land` | → `chronicle_capture` (if context worth saving) → `chronicle_diary` (if open chronicles) |
| `plan_intake` | → `engineer_reconcile` → `plan_create_beads` → `plan_execute` |
| `plan_engage` | State machine: Ready → `plan_create_beads`, Executing → `plan_execute` |
| `plan_execute` | Loop: `plan_pump` → classify beads → dispatch (swarm or bare agent) |

---

## Complete Skill Taxonomy

| Category | Skills | Dispatch Mode |
|----------|--------|--------------|
| **Capture** | chronicle_capture, archive_capture, issue_capture | Inline |
| **Process** | chronicle_diary, chronicle_recall, archive_process, issue_process | Bare subagent |
| **Engineer** | engineer_reconcile, engineer_suggest_updates, engineer_update | Inline |
| **Engineer** | engineer_analyze_project | Bare subagent |
| **Lifecycle** | session_land, plan_intake, plan_engage | Inline orchestrator |
| **Plan Execution** | plan_execute, plan_pump | Inline loop → swarm or bare subagent |
| **Swarm** | swarm_run, swarm_dispatch, swarm_react | Swarm (multi-agent) |
| **Selection** | plan_select_agent, swarm_select_formula | Inline (labeling only) |

---

## Inter-Step Communication

Swarm agents communicate via structured comments on the parent bead:

| Comment Type | Posted By | Consumed By |
|-------------|-----------|-------------|
| `FINDINGS:` | Research/analysis agents | Implementation agents (downstream) |
| `CHANGES:` | Implementation agents | Review and test agents |
| `REVIEW:PASS` / `REVIEW:BLOCK` | Review agents | Dispatch loop (reactive bugfix) |
| `TESTS:` (pass/fail counts) | Test agents | Dispatch loop (reactive bugfix) |
| `CHRONICLE-SIGNAL:` | Any agent | Dispatch loop (auto-chronicle) |
