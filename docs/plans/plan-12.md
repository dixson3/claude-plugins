# Plan 12: Automatic Diary Generation at Lifecycle Boundaries

**Status:** Completed
**Date:** 2026-02-08

## Overview

Plan 11 added semi-automatic chronicle *capture* at three lifecycle boundaries (plan start, plan completion, session close). However, diary *generation* — converting those chronicle beads into consolidated markdown entries — still required a manual `/chronicler:diary` invocation. This plan closes the loop: at plan completion and session close, diary entries are automatically generated from open chronicles.

## Implementation Sequence

1. Add `/chronicler:diary plan:<idx>` invocation to `execute_plan` Step 4 (Completion), after chronicle capture
2. Add diary generation step 1.6 to BEADS.md Landing the Plane, after chronicle capture step 1.5
3. Sync installed copy of BEADS.md
4. Add test cases verifying diary references
5. Version bumps and CHANGELOG

## Completion Criteria

- [x] `execute_plan` auto-generates diary on plan completion (scoped to plan)
- [x] BEADS.md Landing the Plane auto-generates diary on session close (all open chronicles)
- [x] Tests verify both diary references
- [x] Version bumps and changelog
