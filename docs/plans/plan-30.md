# Plan 30: Beads Database Pruning

**Status:** Completed
**Date:** 2026-02-13

## Overview

Nuclear prune of the beads database — delete ALL 278 closed beads after verifying documentation coverage. The database had grown to 288 issues (238KB JSONL) with 278 closed and only 10 active. ~80% of closed beads were ephemeral implementation artifacts that duplicate information already captured in 21 diary entries, 30 plan documents, and CHANGELOG.md.

## Approach

Delete all closed beads with tombstones (no `--hard` deletes) after gap analysis confirms no content loss. Safety net export before deletion.

## Implementation Sequence

1. **Gap Analysis** — Extract content from all closed beads, cross-reference against docs/diary, docs/plans, CHANGELOG
2. **Backfill Gaps** — Create diary/archive entries for any uncaptured content (none found)
3. **Export Safety Net** — Full JSON export to /tmp/beads-archive-20260213.json
4. **Execute Deletion** — `bd delete --from-file` with tombstones and reason annotation
5. **Post-Prune Verification** — Stats, list, tests, docs integrity
6. **Forward-Looking Retention Policy** — Document zero-retention convention (not codified as script)

## Results

- **Before:** 288 beads (238KB), 278 closed
- **After:** 10 beads, 0 closed, 278 tombstones
- **Gap analysis:** No content gaps — all chronicles processed, all plan content in plan docs
- **Tests:** 477 passed, 0 failed
- **Safety net:** /tmp/beads-archive-20260213.json (357KB, 278 beads)

## Protected Beads

- `marketplace-atu` (in-progress, Plan 29 epic)
- `marketplace-gow.1` through `.7` (open Plan 24 phase epics)
- `marketplace-bj4`, `marketplace-7rt` (open draft chronicles)

## Retention Policy (Forward-Looking)

1. **Tasks** — Delete immediately upon closing
2. **Chronicles** — Delete after diary entry is generated
3. **Plan tasks/phases** — Delete after plan completes and diary is written
4. **Plan root epics** — Delete after plan completes
5. **Gates** — Delete immediately

## Completion Criteria

- [x] `bd stats` shows 0 closed beads
- [x] `bd list --all` shows only active beads
- [x] `marketplace-atu` works correctly
- [x] All tests pass
- [x] `bd sync` succeeds
- [x] All diary entries, plan docs, and CHANGELOG intact
