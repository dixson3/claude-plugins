# Rule: Breakdown Before Building

**Applies:** When starting work on any bead (all agents)

Before writing code on a claimed task, review its scope. If the task is non-trivial, decompose it first.

## When This Fires

Every time you claim a task (`bd update <id> --status=in_progress`), before writing any code:

1. **Read the task**: `bd show <task-id>`
2. **Assess scope**: Is this atomic (single file, single concern) or non-trivial (multiple files, multiple concerns)?
3. **If non-trivial**: Invoke `/yf:plan_breakdown <task-id>` before coding
4. **If atomic**: Proceed directly with implementation

## What Counts as Non-Trivial

- Multiple files need to be created or modified
- Multiple independent concerns (e.g., backend + frontend, implementation + tests)
- Work that has distinct sequential phases
- Task description mentions "and" between unrelated items

## What Counts as Atomic

- Single file creation or modification
- One logical change across tightly-coupled files
- A focused fix or addition

## Why

- Smaller tasks are easier to track, parallelize, and resume
- Dependencies between sub-tasks are made explicit
- Agent selection can be more precise on smaller tasks
- Progress is visible at finer granularity

## This Rule Applies to ALL Agents

Whether you're the primary agent or a subagent, always assess scope before coding. Subagents that receive non-trivial tasks should decompose them further — the recursion stops when all work is genuinely atomic.
