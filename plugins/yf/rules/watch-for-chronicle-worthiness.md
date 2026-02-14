# Rule: Watch for Chronicle-Worthiness

**Purpose**: Monitor context for events worth recording in the project diary.

## Instructions

When this rule is active, watch for and flag chronicle-worthy moments during your work.

### Capture Triggers

Flag these events as chronicle-worthy:

1. **Significant Progress**
   - Feature complete or major milestone reached
   - Bug fixed after investigation
   - Successful refactoring

2. **Important Decisions**
   - Architecture choices
   - Technology/library selections
   - Design pattern decisions
   - Trade-off resolutions

3. **Context Switches**
   - Before taking a break
   - Switching to a different task
   - End of a work session

4. **Blockers or Questions**
   - Stuck on a problem
   - Need external input
   - Waiting on dependencies

5. **Session Boundaries**
   - End of productive session
   - Before a long break
   - When conversation is getting long

6. **Database or Infrastructure Operations**
   - Bulk bead deletions or modifications
   - Database migrations or schema changes
   - Configuration changes affecting system behavior

7. **Implementation Adjustments**
   - Code modified to comply with REQ-xxx requirements
   - Rework after review feedback (REVIEW:BLOCK resolution)
   - Implementation adjusted for plan constraints or spec alignment
   - Changes driven by specification reconciliation results

8. **Swarm Execution Events**
   - Reactive bugfix triggered (TESTS failure or REVIEW:BLOCK)
   - Formula step retried after bugfix
   - Swarm completed with mixed results (some steps BLOCK, final PASS)
   - Test failures requiring implementation adjustments

9. **Plan Compliance Adjustments**
   - Implementation deviating from plan (scope change during execution)
   - Dependency ordering changed mid-execution
   - Task scope expanded or split during execution
   - Plan constraints requiring approach changes

### Behavior

When you notice a chronicle-worthy event:

1. Briefly note it in your response: "This seems chronicle-worthy."
2. Suggest: "Consider running `/yf:chronicle_capture` to save this context."

**Do NOT auto-capture.** Only flag and suggest. The user decides when to capture.

### Example Suggestions

After completing a feature:
> "This seems chronicle-worthy - you've completed the authentication flow. Consider running `/yf:chronicle_capture topic:feature` to save this context."

Before a context switch:
> "Before switching tasks, this seems chronicle-worthy. Consider running `/yf:chronicle_capture` to preserve where you left off."

After a key decision:
> "This architecture decision seems chronicle-worthy. Consider running `/yf:chronicle_capture topic:planning` to document the rationale."

### Non-Triggers

Do NOT flag these as chronicle-worthy:
- Trivial changes (typos, formatting, minor tweaks)
- Already-committed work with good commit messages
- Simple Q&A that doesn't affect project state
- Routine operations (running tests, building) — unless tests fail and trigger rework
- Reading/exploring code without changes

### Frequency

- Don't over-suggest — at most once every 15-20 minutes of active work for categories 1-6
- For categories 7-9 (implementation adjustments, swarm events, plan compliance): at most once every 10-15 minutes, since these are high-context moments worth preserving
- Prioritize major milestones over minor progress
- If unsure, err on the side of not suggesting
