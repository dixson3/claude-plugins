# Plan 20: Automatic Chronicle Creation at Pre-Push

**Status:** Completed
**Date:** 2026-02-08

## Overview

Create a `chronicle-check.sh` script that auto-creates draft chronicle beads by analyzing git commits for keywords, significant file changes, and activity volume. Integrate it into `pre-push-diary.sh` so it fires automatically before every push. Update the `yf_diary` agent to handle draft beads (enrich worthy ones, close unworthy ones, consolidate duplicates). Version bump to 2.7.0.

## Implementation Sequence

1. **Phase 1**: `chronicle-check.sh` script — keyword/file/volume analysis, draft bead creation, daily dedup, plan context detection
2. **Phase 2**: `pre-push-diary.sh` integration — call chronicle-check before advisory
3. **Phase 3**: `yf_diary` agent — draft triage (enrich/close/consolidate)
4. **Phase 4**: Tests — `unit-chronicle-check.yaml` (7 cases), `unit-pre-push-chronicle-check.yaml` (3 cases)
5. **Phase 5**: Version bump to 2.7.0, CHANGELOG, README, MEMORY updates

## Completion Criteria

- [x] `chronicle-check.sh` detects significant file changes and keyword commits
- [x] `chronicle-check.sh` creates draft chronicle beads with proper labels
- [x] `chronicle-check.sh` deduplicates within a day (no duplicate drafts)
- [x] `chronicle-check.sh` auto-tags with plan context when plan is executing
- [x] `pre-push-diary.sh` calls chronicle-check before advisory
- [x] `yf_diary` agent handles draft beads (enrich/close/consolidate)
- [x] All new and existing unit tests pass
- [x] Version bumped to 2.7.0, CHANGELOG updated
