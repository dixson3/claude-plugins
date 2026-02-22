# Resolve Three Open Issue Beads: Gate Bypass, Version Staleness, Targeted Testing

## Context

Three deferred issue beads represent real friction points: (1) agents bypass the plan lifecycle by dismissing the gate when a user says "implement the following plan," (2) version references drift on every bump because there's no consistency enforcement, and (3) the full test suite (~49 unit scenarios) runs on every verification when only a handful are relevant to the change. This plan addresses all three as independent workstreams.

---

## Issue 1: yf-3w5 — Plan Gate Bypass

**Problem**: When a user says "implement the following plan," the agent interprets "implement" as a directive to edit immediately. `code-gate.sh` blocks the edit, but the block message suggests `/yf:dismiss_gate` as an escape hatch. The agent uses it, and the plan never enters the bead lifecycle.

**Root causes**: (a) block message offers the escape hatch as a peer option, (b) block message references old skill names (`/yf:dismiss_gate`, `/yf:plan_to_beads`), (c) `plan_dismiss_gate` SKILL.md lacks a guard against auto-chain misuse, (d) `plan_engage/SKILL.md` also references old skill names.

### Changes

1. **`plugins/yf/hooks/code-gate.sh` line 178-181** — Rewrite the active-gate block message:
   - Remove escape-hatch suggestion entirely
   - Fix stale skill names
   - New message: "BLOCKED: Plan {idx} is gated — the auto-chain lifecycle is in progress. Wait for it to complete, or re-run /yf:plan_intake if auto-chain failed."

2. **`plugins/yf/hooks/code-gate.sh` line 114-117** — Refine beads safety net message:
   - Keep `/yf:plan_intake` as primary action
   - Keep `/yf:plan_dismiss_gate` but qualify it: "to deliberately abandon this plan"

3. **`plugins/yf/skills/plan_dismiss_gate/SKILL.md`** — Add guard at top of Workflow section:
   - "Do NOT use this skill to work around a code-gate block during auto-chain. If auto-chain is in progress, wait for it to complete or diagnose the failure. This skill is for deliberately abandoning a plan you do not intend to implement."

4. **`plugins/yf/skills/plan_engage/SKILL.md` lines 80 and 91** — Fix `/yf:dismiss_gate` → `/yf:plan_dismiss_gate`

5. **`plugins/yf/rules/yf-rules.md` Rule 1.2** — Add after "Does not apply if auto-chain has already fired":
   - "If `.yoshiko-flow/plan-gate` exists, the plan is gated. Never dismiss the gate to bypass the lifecycle — if auto-chain failed, diagnose and re-run `/yf:plan_intake`."

6. **`tests/scenarios/unit-code-gate.yaml`** — Add negative assertion to the active-gate block test case: `output_not_contains: "dismiss_gate"` to prevent regression of the escape-hatch suggestion.

---

## Issue 2: yf-hkd — Auto-Update Hardcoded Version in Tests

**Problem**: Version references in `marketplace.json` (2.27.0), `README.md` (2.27.0) are 3 releases behind `plugin.json` (2.30.0). The test in `unit-swarm-qualify.yaml` Case 8 hardcodes "2.30.0" and will break on every future bump.

### Changes

1. **Fix stale references now**:
   - `.claude-plugin/marketplace.json` — Update both `metadata.version` and `plugins[0].version` from "2.27.0" to "2.30.0"
   - `README.md` line 18 — Update table cell from "2.27.0" to "2.30.0"

2. **Create `scripts/bump-version.sh`** — Version bump automation:
   - Accept new version as required argument
   - Read current version from `plugins/yf/.claude-plugin/plugin.json`
   - Update all downstream files: `marketplace.json` (version fields via jq), `README.md` (table cell via sed), `CLAUDE.md` (parenthetical via sed), `plugins/yf/README.md` (title line via sed), `plugins/yf/.claude-plugin/plugin.json` (source of truth via jq)
   - Print summary of changes
   - Warn about manual steps: CHANGELOG.md entry, marketplace.json description sync
   - Do NOT touch `CHANGELOG.md` or `lock.json`

3. **Replace `unit-swarm-qualify.yaml` Case 8** — Change from hardcoded version check to consistency check:
   - Read version from `plugin.json` (source of truth)
   - Read version from `marketplace.json`
   - Extract version from `README.md` table cell (use sed, not grep -P, for macOS compat)
   - Extract version from `CLAUDE.md` parenthetical
   - Compare all to source of truth; output "OK" if consistent, "MISMATCH" details if not
   - Assertion: `output_contains: "OK"`

4. **Document** `scripts/bump-version.sh` in `DEVELOPERS.md` version management section.

---

## Issue 3: yf-wpc — Targeted Regression Testing

**Problem**: Every test verification runs all ~49 unit scenarios. During development, only the scenarios related to changed files are relevant. The full suite should be mandatory only at session landing.

### Changes

1. **Add `--scenarios` flag to `tests/run-tests.sh`** — Accept specific scenario file paths instead of the `unit-*.yaml` glob. This is the minimum useful feature: agents and developers can pass exactly the scenarios they want.

2. **Add `--changed` flag to `tests/run-tests.sh`** — Auto-discover relevant scenarios:
   - Get changed files: `git diff --name-only HEAD` + `git diff --name-only --cached`
   - For each changed file basename, grep all `unit-*.yaml` files for references
   - Deduplicate matches
   - If matches found: pass only those to the harness
   - If no matches found: fall back to all unit tests (safe default)
   - Print which scenarios were selected and why (for transparency)

3. **Do NOT change `session_land` Step 5** — Keep the full `--unit-only` suite at landing time. The targeted mode is for mid-development verification, not for the quality gate.

4. **Update `CLAUDE.md`** build/test section — Document new flags:
   ```bash
   # Run only tests relevant to changed files
   bash tests/run-tests.sh --unit-only --changed

   # Run specific scenarios
   bash tests/run-tests.sh --unit-only --scenarios tests/scenarios/unit-code-gate.yaml
   ```

5. **Add `tests/scenarios/unit-run-tests.yaml`** — Test the new flags work correctly (at least: `--scenarios` selects only named files, `--changed` with no changes falls back to all).

---

## Implementation Order

All three are independent (no code overlap). Suggested sequence:

1. **Issue 1 (gate bypass)** — Highest severity; agents are actively hitting this
2. **Issue 2 (version staleness)** — Fixes embarrassing drift and prevents recurrence
3. **Issue 3 (targeted testing)** — Developer experience improvement

## Verification

- **Issue 1**: Run `bash tests/run-tests.sh --unit-only --scenarios tests/scenarios/unit-code-gate.yaml tests/scenarios/unit-code-gate-intake.yaml` (after Issue 3 lands, or pass files directly to harness). Verify the gate block message no longer mentions `dismiss_gate`.
- **Issue 2**: Run `bash tests/run-tests.sh --unit-only --scenarios tests/scenarios/unit-swarm-qualify.yaml`. Verify the consistency check passes with all versions at 2.30.0.
- **Issue 3**: Run `bash tests/run-tests.sh --unit-only --changed` with a known dirty file; confirm only relevant scenarios execute. Run with clean tree; confirm fallback to all.
- **Full suite**: `bash tests/run-tests.sh --unit-only` — all scenarios pass.

## Files Modified

| File | Issue |
|------|-------|
| `plugins/yf/hooks/code-gate.sh` | 1 |
| `plugins/yf/skills/plan_dismiss_gate/SKILL.md` | 1 |
| `plugins/yf/skills/plan_engage/SKILL.md` | 1 |
| `plugins/yf/rules/yf-rules.md` | 1 |
| `tests/scenarios/unit-code-gate.yaml` | 1 |
| `.claude-plugin/marketplace.json` | 2 |
| `README.md` | 2 |
| `tests/scenarios/unit-swarm-qualify.yaml` | 2 |
| `scripts/bump-version.sh` (new) | 2 |
| `DEVELOPERS.md` | 2 |
| `tests/run-tests.sh` | 3 |
| `CLAUDE.md` | 3 |
| `tests/scenarios/unit-run-tests.yaml` (new) | 3 |
