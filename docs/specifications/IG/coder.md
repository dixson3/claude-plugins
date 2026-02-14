# Implementation Guide: Coder (Code Generation)

## Overview

The coder capability provides standards-driven code generation through the `code-implement` formula. Four specialized agents handle research, implementation, testing, and review, ensuring implementations follow technology-specific standards and existing Implementation Guide guidelines.

## Use Cases

### UC-029: Standards-Driven Code Implementation

**Actor**: System (swarm dispatch) or Operator

**Preconditions**: Task with `formula:code-implement` label exists. Task involves creating or modifying code with technology/language context.

**Flow**:
1. Plan pump detects `formula:code-implement` label on a ready bead
2. Pump invokes `/yf:swarm_run formula:code-implement feature:"<title>" parent_bead:<id>`
3. Swarm instantiates formula as wisp with 4 steps:
   - `research-standards` (yf_code_researcher) -- read-only
   - `implement` (code-writer) -- full-capability
   - `test` (yf_code_tester) -- limited-write
   - `review` (yf_code_reviewer) -- read-only
4. Research step checks `docs/specifications/IG/` for relevant guides, researches best practices, posts FINDINGS with Standards section
5. Implement step reads FINDINGS, follows standards, posts CHANGES with Standards Applied section
6. Test step reads CHANGES, writes tests, runs them, posts TESTS with pass/fail results
7. Review step reads all upstream comments, reviews against IGs and standards, posts REVIEW:PASS or REVIEW:BLOCK
8. On REVIEW:PASS: wisp squashed, parent bead closed, chronicle captured
9. On REVIEW:BLOCK or TESTS failure: reactive bugfix triggers via `swarm_react`

**Postconditions**: Code implemented following standards, tests passing, review passed. Structured comments on parent bead document the full workflow.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/formulas/code-implement.formula.json`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_researcher.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_writer.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_tester.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_reviewer.md`

### UC-030: Code-Implement Formula Selection

**Actor**: System (plan_create_beads Step 8b)

**Preconditions**: Task bead created during plan-to-beads conversion.

**Flow**:
1. `/yf:swarm_select_formula` evaluates task title and description
2. Matches code/write/program/develop verbs WITH technology/language context
3. Distinguishes from feature-build: code-implement requires language/technology signals (e.g., "implement auth in Python", "write Go tests"), feature-build matches general implement verbs
4. If match: applies `formula:code-implement` label
5. Atomic tasks (single file, config changes) are skipped

**Postconditions**: Task labeled with `formula:code-implement` for swarm dispatch.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/skills/swarm_select_formula/SKILL.md`
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/rules/swarm-formula-select.md`

### UC-031: IG-First Standards Research

**Actor**: yf_code_researcher agent

**Preconditions**: Research-standards step dispatched within code-implement formula.

**Flow**:
1. Agent receives task context (title, description, parent bead comments)
2. Checks `docs/specifications/IG/` for existing guides relevant to the target technology
3. If relevant IG exists: extracts coding standards and patterns from it
4. If no relevant IG: researches best practices for the target technology
5. Posts FINDINGS with:
   - Internal sources (existing IGs, codebase patterns)
   - External sources (documentation, best practices)
   - Standards section (coding standards to follow)
   - Recommendations (suggested approach)

**Postconditions**: FINDINGS comment on parent bead with standards for downstream steps.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_researcher.md`

### UC-032: Standards Compliance Review

**Actor**: yf_code_reviewer agent

**Preconditions**: Review step dispatched within code-implement formula. CHANGES and TESTS comments exist from upstream steps.

**Flow**:
1. Agent receives task context and reads all upstream comments (FINDINGS, CHANGES, TESTS)
2. Reads standards from FINDINGS
3. Checks `docs/specifications/IG/` for relevant implementation guides
4. Reviews implementation against:
   - Standards from FINDINGS (technology-specific best practices)
   - IG compliance (documented patterns and conventions)
   - Code quality (readability, maintainability, security)
   - Test coverage (adequate for the changes made)
5. Posts REVIEW:PASS or REVIEW:BLOCK with:
   - Standards Compliance section (which standards followed/violated)
   - IG Alignment section (divergence from documented guides)
   - Issues list (critical/suggestion/nit level)

**Postconditions**: REVIEW comment on parent bead. REVIEW:BLOCK triggers reactive bugfix if eligible.

**Key Files**:
- `/Users/james/workspace/dixson3/d3-claude-plugins/plugins/yf/agents/yf_code_reviewer.md`
