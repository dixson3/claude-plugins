# Plan: Consolidate Rules & Optimize Agent/Skill/Rule Text

## Context

The yf plugin loads two separate rule files via preflight symlinks, but the second (`yf-worktree-lifecycle.md`, 15 lines) is a single hard-enforcement rule that belongs inline in `yf-rules.md`. Additionally, agent and skill text carries non-impactful exposition: duplicated blocks (Chronicle Signal 8 lines x 5 agents, Chronicle Protocol 15 lines x 3 agents), verbose Personality/Error Handling sections, full markdown templates where section names suffice, and oversized JSON examples. This plan consolidates the rules and compresses all agent/skill text for action and effectiveness.

## Phase 1: Rules Consolidation

### 1a. Merge worktree rule into yf-rules.md

**File:** `plugins/yf/rules/yf-rules.md`

Add as section **1.6 Worktree Lifecycle** after 1.5 (Issue Disambiguation), compressed from 15 lines to ~9:

```markdown
### 1.6 Worktree Lifecycle

Use yf worktree skills for epic worktrees — never raw `git worktree` commands.
- **Create**: `/yf:worktree_create epic_name:<name>` (not `git worktree add`)
- **Land**: `/yf:worktree_land` (not `git merge` + `git worktree remove`)

Skills handle beads redirect, validation, rebasing, and cleanup atomically. Raw git commands leave beads inconsistent.
Does NOT apply to Claude Code's implicit `isolation: "worktree"` on Task tool calls.
```

### 1b. Tighten advisory monitoring (Section 5)

- **5.3**: Remove "NOT chronicle-worthy" line (positive criteria suffice)
- **5.6**: Remove explanatory sub-text under bold labels; remove "NOT issue-worthy" line
- **4.2**: Remove "This is the authoritative session close protocol." (exposition)

### 1c. Update preflight.json

**File:** `plugins/yf/.claude-plugin/preflight.json`

Remove: `{ "source": "rules/yf-worktree-lifecycle.md", "target": ".claude/rules/yf/yf-worktree-lifecycle.md" }`

### 1d. Delete the separate file

**Delete:** `plugins/yf/rules/yf-worktree-lifecycle.md`

---

## Phase 2: Agent Optimization (12 files)

### Principles
- Each agent is self-contained (no include mechanism) — compress inline
- Remove all `## Personality` sections (flavor text, no behavioral impact)
- Compress `## Error Handling` to 2-3 lines
- Compress shared blocks: Chronicle Signal (8 -> 3 lines), Chronicle Protocol (15 -> 7 lines), Tools (8-10 -> 2-3 lines)
- Compress markdown templates to section-name lists; compress JSON examples to minimal structure
- Preserve: frontmatter, comment protocol formats, process steps, bd commands

### High-impact agents

| Agent | Current | Target | Key Cuts |
|-------|---------|--------|----------|
| `yf_archive_process.md` | 246 | ~165 | Research template 36->5, decision template 34->5, output JSON 33->12, index mgmt 24->8, remove Personality, compress Error Handling |
| `yf_chronicle_diary.md` | 186 | ~130 | Writing guidelines 17->5, draft triage 37->20, remove Personality, compress Error Handling |
| `yf_engineer_synthesizer.md` | 121 | ~90 | JSON example 32->15, synthesis guidelines 28->18 |

### Cross-agent compression (all 12 agents)

**Tools sections** — compress to 2-3 lines per agent:
- Read-only: "Read-only agent. May read files, search (Glob/Grep), run non-destructive Bash (`bd show`, `bd comment`, `git diff`). No edits/writes."
- Full-capability: "Full-capability agent. May read, edit, write, create files and run Bash including `bd` commands."
- Test: "May read, search, create/edit test files, and run Bash (test runners, `bd`). Do not modify implementation files."

**Chronicle Signal** (in swarm_reviewer, code_reviewer, code_researcher, swarm_researcher) — compress to 3 lines:
"For significant discoveries (unexpected constraints, approach-changing findings, design-impacting blocks), append `CHRONICLE-SIGNAL: <one-line summary>` to your structured comment. Dispatch loop auto-creates a chronicle bead. Skip for routine findings."

**Chronicle Protocol** (in code_writer, code_tester, swarm_tester) — compress to 7 lines:
Keep the three trigger types (plan deviation, unexpected discovery, non-obvious failure) as a single sentence, the `bd create` command, and the "Do NOT chronicle routine" line.

### Agent-specific cuts

- `yf_swarm_reviewer.md`: Inline the IG Reference section (15 lines) as a single bullet in Review Criteria
- `yf_code_reviewer.md`: Compress Process steps 3-5 into one step
- `yf_chronicle_recall.md`: Remove Personality (6 lines), compress Error Handling (12->3)
- `yf_issue_triage.md`: Compress JSON example (27->15 by removing skip/redirect examples, noting as options)

---

## Phase 3: Skill Optimization

### Do NOT touch
- Activation guards (functional gate, must remain verbatim)
- Comment protocol format strings (FINDINGS, CHANGES, REVIEW, TESTS)
- `bd` command syntax
- Frontmatter
- Process step numbering and order

### Top 6 verbose skills (deep pass)

| Skill | Current | Target | Key Cuts |
|-------|---------|--------|----------|
| `swarm_dispatch/SKILL.md` | 323 | ~260 | Dispatch prompt template -8, merge-back explanation -8, progressive chronicle bash blocks -12, archive findings -6 |
| `plan_execute/SKILL.md` | 250 | ~200 | Architecture diagram -5, dispatch examples -15, completion report template -12, parallel dispatch rules -4 |
| `plan_create_beads/SKILL.md` | 243 | ~195 | Steps 5-6 compressed to reference Step 4 pattern -18, gate creation 3 -> 1 canonical + variants -15 |
| `plan_intake/SKILL.md` | 222 | ~180 | File classification -6, plan template -10, spec integrity sub-steps compressed -20 |
| `engineer_analyze_project/SKILL.md` | 219 | ~170 | Existing specs check -8, four spec templates compressed to header-only -40 |
| `swarm_run/SKILL.md` | 212 | ~175 | Auto-chronicle bash -8, usage examples -6, depth tracking -4, report template -6 |

### Remaining 33 skills (light pass)

- Remove redundant "When to Invoke" sections where frontmatter description already covers it (~15 skills, ~3 lines each)
- Compress verbose "Expected Output" / report template blocks (~10 skills, ~5 lines each)

---

## Phase 4: Peripheral Updates

- `plugins/yf/.claude-plugin/plugin.json`: Bump version to 2.28.0
- `CHANGELOG.md`: Add entry for rules consolidation and text optimization
- `plugins/yf/README.md`: Update version reference
- `DEVELOPERS.md`: No changes needed (doesn't reference individual rule files)

---

## Implementation Order

1. Rules (Phase 1) — smallest scope, sets pattern
2. Agents (Phase 2) — high-impact first, then cross-agent compression
3. Top 6 skills (Phase 3 deep)
4. Remaining skills (Phase 3 light)
5. Peripheral updates (Phase 4)

## Verification

1. `bash tests/run-tests.sh --unit-only` after each phase
2. `ls -la .claude/rules/yf/` — confirm single symlink after Phase 1
3. Spot-check: every agent retains frontmatter, comment protocols, process steps
4. `wc -l` audit on all modified files vs targets

## Estimated Impact

| Category | Before | After | Savings |
|----------|--------|-------|---------|
| Rules | 194 | ~173 | ~21 |
| Agents (12) | 1,433 | ~1,121 | ~312 |
| Skills (39) | ~5,339 | ~4,955 | ~384 |
| **Total** | **~6,966** | **~6,249** | **~717 (~10%)** |
