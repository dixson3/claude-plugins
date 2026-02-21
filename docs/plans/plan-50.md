# Plan: Plugin Issue Reporting & Project Issue Tracking

**Addresses**: Issues #2, #16, #31
**Capabilities added**: `plugin` (replaces Core; issue reporting + setup) and `issue` (full lifecycle tracking)

## Context

The yf plugin has no way to report bugs/enhancements against itself, and no mechanism for capturing and tracking project issues through an external tracker. Users currently manage issues manually outside the plugin workflow, losing the context-preservation benefits that beads provide for chronicles and archives.

This plan introduces two new capabilities that mirror the existing capture-then-process pattern (chronicle/diary, archive/process) while adding a disambiguation guard to prevent cross-routing between plugin and project issue destinations.

---

## Design Decisions

**Merge Core into `plugin` prefix**: The existing "Core" capability (prefix-less, contains only `setup`) is merged into the new `plugin` capability. `setup` is renamed to `yf:plugin_setup` and `plugin_issue` joins it. This groups all plugin-level concerns (activation, reporting) under one prefix. The rename touches ~56 references across ~25 files (skills, agents, rules, scripts, specs, docs, tests, READMEs, CHANGELOG). Historical docs (plans, diary entries) are left as-is since they document past state.

**`issue` prefix for project tracking**: Follows the user's suggestion of `yf:issue_*`. Bead label: `ys:issue`.

**No agent for issue processing**: Unlike chronicle processing (narrative synthesis) or archive processing (structured documentation), issue processing is mechanical — read bead, call tracker API, close bead. Inline skill logic is sufficient.

**No tracker state caching in v1**: Tracker API calls are lightweight single CLI invocations. The deferred staging workflow naturally batches operations. Caching can be added later if needed.

**Disambiguation in `yf-rules.md`**: Add sections to the existing rules file (Rule 1.5 hard enforcement + Rule 5.6 advisory) rather than a separate rule file, keeping the single-rule-file pattern.

---

## Config Schema Extensions

```json
{
  "config": {
    "plugin_repo": "dixson3/d3-claude-plugins",
    "project_tracking": {
      "tracker": "github",
      "project": "owner/repo",
      "tracker_tool": "gh"
    }
  }
}
```

- `plugin_repo`: Override for plugin issue destination. Default resolved programmatically (hardcoded `dixson3/d3-claude-plugins` for now; future plugin.json `repository` field can replace this).
- `project_tracking.tracker`: `"github"` | `"gitlab"` | `"auto"` (default: `"auto"` — detect from git remote)
- `project_tracking.project`: Owner/repo slug override
- `project_tracking.tracker_tool`: CLI tool override (e.g. `"gh"`, `"glab"`)

---

## New Files

### Scripts (foundation)

| File | Purpose |
|------|---------|
| `plugins/yf/scripts/tracker-detect.sh` | Detect project tracker from config override or git remote origin. Outputs JSON: `{"tracker":"github","project":"owner/repo","tool":"gh"}` |
| `plugins/yf/scripts/tracker-api.sh` | Tracker abstraction layer — uniform interface for `create`, `list`, `view`, `transition` across GitHub/GitLab |

### Skills

| File | Purpose |
|------|---------|
| `plugins/yf/skills/plugin_setup/SKILL.md` | Renamed from `skills/setup/SKILL.md` — `name: yf:plugin_setup` |
| `plugins/yf/skills/plugin_issue/SKILL.md` | Report/comment on issues against the yf plugin repo via `gh` |
| `plugins/yf/skills/issue_capture/SKILL.md` | Stage a project issue as a `ys:issue` bead (deferred submission) |
| `plugins/yf/skills/issue_process/SKILL.md` | Evaluate, consolidate, and submit staged beads to remote tracker |
| `plugins/yf/skills/issue_disable/SKILL.md` | Close all open issue beads without submitting |
| `plugins/yf/skills/issue_list/SKILL.md` | List remote issues + staged beads in a combined view |
| `plugins/yf/skills/issue_plan/SKILL.md` | Pull a remote issue into a yf planning session, transition it to in-progress |

### Tests

| File | Purpose |
|------|---------|
| `tests/scenarios/unit-tracker-detect.yaml` | Git remote parsing, config override, tool availability |
| `tests/scenarios/unit-tracker-api.yaml` | Action routing, error handling |
| `tests/scenarios/unit-issue-disambiguation.yaml` | Plugin repo vs project tracker isolation |

---

## Modified Files

| File | Change |
|------|--------|
| `plugins/yf/scripts/yf-config.sh` | Add `yf_plugin_repo`, `yf_project_tracker`, `yf_project_slug`, `yf_tracker_tool` accessors |
| `plugins/yf/scripts/yf-activation-check.sh` | Rename `/yf:setup` -> `/yf:plugin_setup` in action messages |
| `plugins/yf/scripts/plugin-preflight.sh` | Rename `/yf:setup` reference |
| `plugins/yf/hooks/pre-push-diary.sh` | Add `warn_open_beads "ys:issue"` call (one line) |
| `plugins/yf/rules/yf-rules.md` | Rename `/yf:setup` refs + add Rule 1.5 (disambiguation) + Rule 5.6 (issue worthiness) |
| `plugins/yf/agents/yf_chronicle_diary.md` | Rename `/yf:setup` in error message |
| `plugins/yf/agents/yf_chronicle_recall.md` | Rename `/yf:setup` in error message |
| `plugins/yf/skills/chronicle_recall/SKILL.md` | Rename `/yf:setup` reference |
| `plugins/yf/DEVELOPERS.md` | Rename Core->Plugin in capability table, add `issue` row, update references |
| `plugins/yf/README.md` | Rename `/yf:setup` refs + add Plugin Reporting and Issue Tracking sections |
| `README.md` | Rename `/yf:setup` refs + update plugin overview with new capabilities |
| `CLAUDE.md` | Rename `/yf:setup` if referenced |
| `plugins/yf/.claude-plugin/plugin.json` | Version bump 2.25.0 -> 2.26.0 |
| `CHANGELOG.md` | New version entry |
| `docs/specifications/PRD.md` | Rename `/yf:setup` references (3 occurrences) |
| `docs/specifications/EDD/CORE.md` | Rename `/yf:setup` references (3 occurrences) + consider renaming file to `PLUGIN.md` |
| `docs/specifications/IG/marketplace.md` | Rename `/yf:setup` references (2 occurrences) |
| `docs/specifications/test-coverage.md` | Rename `/yf:setup` reference |
| `tests/scenarios/integ-activation-gate.yaml` | Rename `/yf:setup` in comments |

**Not modified** (historical records): `docs/plans/plan-*.md`, `docs/diary/*.md` — these document past state and should not be rewritten.

**Deleted**: `plugins/yf/skills/setup/` directory (replaced by `plugins/yf/skills/plugin_setup/`)

---

## Key Skill Behaviors

### `yf:plugin_issue` (one-way reporting)

1. Activation guard
2. Check `gh` availability + `gh auth status`
3. **Disambiguation**: Verify issue is about yf/beads/plugin. If project-specific, redirect to `/yf:issue_capture`
4. Resolve target: `yf_plugin_repo` from config (default `dixson3/d3-claude-plugins`)
5. **Cross-route guard**: Compare plugin repo against project tracker slug — error if they match
6. If `issue` arg: comment on existing issue (`gh issue comment`)
7. If new: synthesize title/body from context, confirm via AskUserQuestion, auto-include metadata footer (yf version, OS), create via `gh issue create`

### `yf:issue_capture` (deferred staging)

Mirrors `chronicle_capture` exactly:

1. Activation guard
2. **Disambiguation**: Verify issue is about user's project. If about yf/plugin, redirect to `/yf:plugin_issue`
3. Analyze conversation context for issue details
4. Create bead: `bd create --title "Issue: <summary>" --labels "ys:issue,ys:issue:<type>[,plan:<idx>]" --body "<template>"`
5. Auto-detect executing plan for `plan:<idx>` label

### `yf:issue_process` (batch submission)

Mirrors `chronicle_diary` pattern:

1. Activation guard
2. Query: `bd list --label=ys:issue --status=open --format=json`
3. If no beads: report clean state
4. Detect tracker via `tracker-detect.sh`. If none available, offer `/yf:issue_disable`
5. **Consolidation pass**: Present all staged issues, identify duplicates/overlaps, confirm consolidation with operator via AskUserQuestion
6. **Disambiguation check**: Verify each bead is project-scoped (not about yf plugin)
7. Submit via `tracker-api.sh create`, close processed beads
8. Report created issues with URLs

### `yf:issue_plan` (pull remote issue into planning)

1. Activation guard
2. Detect tracker, fetch issue via `tracker-api.sh view --issue <num>`
3. Transition issue to in-progress: `tracker-api.sh transition --issue <num> --state in_progress`
4. Present issue summary to operator, instruct to enter plan mode
5. Write marker `.yoshiko-flow/plan-issue-link` so `plan_create_beads` can apply `issue:<num>` label to the root epic

---

## Tracker Detection Logic (`tracker-detect.sh`)

Priority order:
1. Explicit config (`config.project_tracking`) — if present, use it
2. Auto-detect from `git remote get-url origin`:
   - `*github.com*` -> `{"tracker":"github","project":"<slug>","tool":"gh"}`
   - `*gitlab.com*` -> `{"tracker":"gitlab","project":"<slug>","tool":"glab"}`
   - Other -> `{"tracker":"none","reason":"Unrecognized remote host"}`
3. Validate CLI tool availability before returning

Handles SSH (`git@github.com:owner/repo.git`) and HTTPS (`https://github.com/owner/repo.git`) URL formats.

---

## Pre-push Integration

Add to `hooks/pre-push-diary.sh` (after existing archive warning, before `exit 0`):

```bash
warn_open_beads "ys:issue" \
    "ISSUE TRACKER: Staged issues detected" \
    "/yf:issue_process" "/yf:issue_disable"
```

Advisory only — does not block push.

---

## Disambiguation Guard

**Rule 1.5 (hard enforcement)** in `yf-rules.md`:
- Plugin issues -> `/yf:plugin_issue` (targets plugin repo)
- Project issues -> `/yf:issue_capture` (stages bead for project tracker)
- Never cross-route. When ambiguous, ask the user.

**Skill-level guards** (in each skill):
- `plugin_issue`: If title/body references project-specific code, warn and redirect
- `issue_capture`: If title/body references yf/beads/plugin internals, warn and redirect
- `issue_process`: Cross-check before submission — plugin repo slug must differ from project tracker slug

---

## Implementation Sequence

| Phase | Steps | Deliverables |
|-------|-------|------------|
| 0. Rename | Move `skills/setup/` -> `skills/plugin_setup/`, update `name: yf:plugin_setup`, rename all `/yf:setup` refs across active files (not historical docs) | Renamed skill + updated refs |
| 1. Foundation | Config accessors in `yf-config.sh`, `tracker-detect.sh`, `tracker-api.sh` | Scripts + unit tests |
| 2. Plugin Reporting | `plugin_issue` skill | Skill |
| 3. Project Tracking | `issue_capture`, `issue_process`, `issue_disable`, `issue_list`, `issue_plan` skills | Skills + tests |
| 4. Guards & Hooks | Rules update (1.5 + 5.6), pre-push hook update | Modified files |
| 5. Documentation | DEVELOPERS.md, README.md, CHANGELOG.md, version bump | Docs + release |

---

## Verification

1. **Unit tests**: `bash tests/run-tests.sh --unit-only` — all new scenarios pass
2. **Tracker detection**: In this repo, `tracker-detect.sh` should auto-detect `dixson3/d3-claude-plugins` as a GitHub project
3. **Plugin issue flow**: `/yf:plugin_issue type:enhancement title:"Test issue"` creates issue on `dixson3/d3-claude-plugins`
4. **Issue staging flow**: `/yf:issue_capture` creates `ys:issue` bead, visible in `bd list --label=ys:issue`
5. **Pre-push advisory**: `git push` shows "ISSUE TRACKER: Staged issues detected" when issue beads are open
6. **Issue processing**: `/yf:issue_process` submits staged beads and closes them
7. **Disambiguation**: `/yf:plugin_issue` about project code triggers redirect warning; `/yf:issue_capture` about yf plugin triggers redirect warning
8. **issue_plan**: `/yf:issue_plan #33` fetches issue, transitions to in-progress, sets up plan context
