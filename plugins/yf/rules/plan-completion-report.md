# Rule: Plan Completion Report

**Applies:** When `plan-exec.sh status` returns "completed" or you detect that all plan tasks are closed

When reporting plan completion, the report MUST include a structured summary of what the plan produced — not just task counts. This is the mirror of plan intake: intake ensures everything is set up before work begins; completion ensures everything is wrapped up and visible.

## Required Report Sections

### 1. Task Summary

Query the plan's task breakdown:

```bash
PLAN_LABEL="plan:<idx>"
CLOSED=$(bd count -l "$PLAN_LABEL" --status=closed --type=task 2>/dev/null || echo "0")
TOTAL=$(bd list -l "$PLAN_LABEL" --type=task --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
```

### 2. Chronicle Summary

Query chronicle beads created during this plan:

```bash
# All chronicles for this plan
ALL_CHRON=$(bd list -l ys:chronicle,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Open (not yet processed into diary)
OPEN_CHRON=$(bd list -l ys:chronicle,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
# Closed (processed)
CLOSED_CHRON=$((ALL_CHRON - OPEN_CHRON))
```

### 3. Diary Entries

List diary files generated for this plan. Check `docs/diary/` (or the configured artifact directory) for files created during this session or referenced by chronicle beads.

### 4. Archive Summary

Query archive beads for this plan:

```bash
ALL_ARCH=$(bd list -l ys:archive,"$PLAN_LABEL" --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN_ARCH=$(bd list -l ys:archive,"$PLAN_LABEL" --status=open --limit=0 --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
CLOSED_ARCH=$((ALL_ARCH - OPEN_ARCH))
```

List generated files in `docs/research/` and `docs/decisions/` if any were produced.

### 5. Qualification Summary

If a qualification gate was run for this plan, include the result:

```bash
QUAL_GATE=$(bd list -l ys:qualification-gate,"$PLAN_LABEL" --limit=1 --json 2>/dev/null | jq -r '.[0].id // empty')
```

If the gate exists, read its comments for the REVIEW verdict and report:
- Gate bead ID
- Verdict (PASS/BLOCK)
- Config mode (blocking/advisory/disabled)
- If advisory BLOCK: note the issues found

### 7. Specification Status

Check for specification documents and report their state:

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"

HAS_PRD="no"; [ -f "$SPEC_DIR/PRD.md" ] && HAS_PRD="yes"
EDD_COUNT=$(ls "$SPEC_DIR/EDD/"*.md 2>/dev/null | wc -l | tr -d ' ')
IG_COUNT=$(ls "$SPEC_DIR/IG/"*.md 2>/dev/null | wc -l | tr -d ' ')
HAS_TODO="no"; [ -f "$SPEC_DIR/TODO.md" ] && HAS_TODO="yes"
```

If any specs exist, report:
- PRD: yes/no
- EDD: N documents
- IG: N documents
- TODO: yes/no
- Reconciliation verdict (from plan epic's `ys:engineer:reconciliation` label or "not run")
- Pending update suggestions count (from `/yf:engineer_suggest_updates` output)

If no specs exist, report: "No specification documents found"

### 6. Open Items Warning

If any chronicles or archives remain open after the completion steps have run, warn:

```
⚠ N chronicle beads still open — run /yf:chronicle_diary to process
⚠ N archive beads still open — run /yf:archive_process to process
```

## Report Format

```
Plan Execution Complete
=======================
Plan: plan-<idx> — <Title>
Tasks: <closed>/<total> completed

Chronicles: <total> captured, <closed> processed into diary, <open> still open
Diary entries:
  - docs/diary/<file1>.md
  - docs/diary/<file2>.md
  (or: No diary entries generated)

Archives: <total> captured, <closed> processed, <open> still open
  - docs/research/<topic>/SUMMARY.md
  - docs/decisions/<slug>/SUMMARY.md
  (or: No archive docs generated)

Qualification: REVIEW:<PASS|BLOCK> (<blocking|advisory|disabled>)
  (or: Qualification gate disabled)
  (or: Qualification: REVIEW:BLOCK (advisory) — <N> issues noted)

Specifications: <PRD: yes/no> | <EDD: N docs> | <IG: N docs> | <TODO: yes/no>
  Reconciliation: <PASS|NEEDS-RECONCILIATION|not run>
  Pending update suggestions: <N>
  (or: No specification documents found)

[If open items remain:]
⚠ <N> chronicle beads still open — run /yf:chronicle_diary to process
⚠ <N> archive beads still open — run /yf:archive_process to process
```

## When This Rule Fires

- After `plan-exec.sh status` returns `completed`
- After the `/yf:plan_execute` Step 4 completion sequence runs (chronicle_diary, archive_process, plan file update)
- When the agent is about to report "plan complete" or "done" to the user

## When This Rule Does NOT Fire

- Session-end / "landing the plane" — that's a different protocol (see `yf-beads.md`)
- Mid-execution progress reports
- Individual task completion
