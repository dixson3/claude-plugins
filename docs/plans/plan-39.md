# Plan: Session Prune — Dynamic Cleanup at "Land the Plane"

## Context

The `.yoshiko-flow/` directory accumulates ephemeral dedup files (one set per calendar day of use) with zero cleanup. Closed beads accumulate in the database — currently 235 closed out of 244 total. Stale auto-generated chronicle drafts linger as open beads. None of this is cleaned up during normal session close.

This plan adds a `session-prune.sh` script that runs automatically at SessionEnd as part of the "land the plane" protocol, dynamically identifying and removing stale artifacts.

## Implementation Sequence

### Step 1: Add config helper to `yf-config.sh`

**File**: `plugins/yf/scripts/yf-config.sh`

Add one line after line 61, following the exact pattern of `yf_is_prune_on_complete`:

```bash
yf_is_prune_on_session_close() { _yf_check_flag '.config.auto_prune.on_session_close'; }
```

Fail-open: defaults to enabled when key is absent or null.

### Step 2: Create `session-prune.sh`

**File**: `plugins/yf/scripts/session-prune.sh` (new)

Bash 3.2 compatible, fail-open (exit 0 always). Sources `yf-config.sh`. Config-gated via `yf_is_prune_on_session_close`.

Four subcommands:

| Subcommand | What it does |
|---|---|
| `beads` | `bd admin cleanup --older-than <days> --force` + `bd admin cleanup --ephemeral --force`. Reads `older_than_days` from config (default 7). Guards on `bd` availability. |
| `ephemeral` | Removes stale `.yoshiko-flow/` files. Date-stamped files (`.chronicle-drafted-*`, `.chronicle-staleness-*`, `.chronicle-transition-*`, `.chronicle-plan-*`) removed if date != today. Session sentinels (`.chronicle-nudge`, `.beads-check-cache`, `plan-chronicle-ok`, `plan-intake-ok`, `plan-intake-skip`) always removed. Never touches `config.json`, `.gitignore`, `lock.json`, `plan-gate`, `task-pump.json`, `swarm-state.json`. |
| `drafts` | Queries open beads with labels `ys:chronicle,ys:chronicle:draft`. Closes any older than 24 hours with `bd close <id> --reason="session-prune: stale auto-generated draft (>24h)"`. Guards on `bd` + `jq`. |
| `all` | Runs `beads`, `ephemeral`, `drafts` in sequence (via self-invocation, `|| true` between each). |

All subcommands support `--dry-run`. Follows structural patterns from `plan-prune.sh` (argument parsing, config guard, `get_older_than_days()`, case dispatch, fail-open exit).

### Step 3: Wire into `session-end.sh`

**File**: `plugins/yf/hooks/session-end.sh`

Insert after the staleness check (line 36) and before the open chronicles query (line 38):

```bash
# --- Session prune: clean stale beads, ephemeral files, stale drafts ---
bash "$SCRIPT_DIR/scripts/session-prune.sh" all 2>/dev/null || true
```

Ordering: chronicle-check creates final drafts → staleness check runs → **session-prune cleans stale artifacts** → open chronicles query reflects the cleaned state → pending-diary marker written.

### Step 4: Update rule 4.2 "Landing the Plane"

**File**: `plugins/yf/rules/yf-rules.md`

Insert new step 6 between current steps 5 and 6, renumbering subsequent steps:

```
6. Session prune (automatic via SessionEnd hook; manual: `bash plugins/yf/scripts/session-prune.sh all`)
```

### Step 5: Unit tests

**File**: `tests/scenarios/unit-session-prune.yaml` (new)

10 test cases:

1. `ephemeral_removes_stale_datefiles` — yesterday's date-stamped files removed, today's preserved
2. `ephemeral_removes_sentinels` — all 5 session sentinels removed
3. `ephemeral_preserves_protected` — config.json, .gitignore, lock.json, plan-gate, task-pump.json, swarm-state.json untouched
4. `config_gate_disabled` — `on_session_close: false` → "disabled by config", files untouched
5. `config_default_enabled` — no `auto_prune` key → defaults to enabled
6. `dry_run_no_delete` — `--dry-run` outputs preview, files remain
7. `always_exit_zero` — all subcommands (beads, ephemeral, drafts, all, invalid) exit 0
8. `beads_runs_cleanup` — beads subcommand emits expected output with configurable threshold
9. `drafts_closes_stale` — drafts subcommand runs (tests "no stale" path since freshly created beads aren't >24h)
10. `ephemeral_no_yf_dir` — handles missing .yoshiko-flow directory gracefully

### Step 6: Run tests

```bash
bash tests/run-tests.sh --unit-only
```

## Verification

1. Run tests: `bash tests/run-tests.sh --unit-only` — all pass
2. Manual dry-run: `bash plugins/yf/scripts/session-prune.sh all --dry-run` from project root
3. Manual execution: `bash plugins/yf/scripts/session-prune.sh all` from project root
4. Config disable: set `"auto_prune": {"on_session_close": false}` in `.yoshiko-flow/config.json`, verify script skips

## Files Modified

- `plugins/yf/scripts/yf-config.sh` — add 1 function (1 line)
- `plugins/yf/hooks/session-end.sh` — add 2 lines (comment + invocation)
- `plugins/yf/rules/yf-rules.md` — update step numbering in rule 4.2

## Files Created

- `plugins/yf/scripts/session-prune.sh` — new script (~120 lines)
- `tests/scenarios/unit-session-prune.yaml` — new test file (10 cases)
