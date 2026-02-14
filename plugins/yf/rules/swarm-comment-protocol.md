# Rule: Swarm Comment Protocol

**Applies:** When working on beads with `ys:swarm` label or within a swarm dispatch

Agents within a swarm communicate through structured comments on the parent bead. This protocol ensures downstream steps have structured context from upstream steps, and that results survive wisp squashing.

## Comment Types

### FINDINGS:

Posted by research/analysis steps. Format:

```
FINDINGS:

## Purpose
<What was investigated and why>

## Sources
<Files, patterns, and references examined>

## Summary
<Key findings>

## Recommendations
<Suggested approach>
```

### CHANGES:

Posted by implementation steps. Format:

```
CHANGES:

## Files Modified
- path/to/file.ext — <what changed>

## Files Created
- path/to/new-file.ext — <purpose>

## Summary
<Brief description of the implementation>
```

### REVIEW:

Posted by review steps. Must include a verdict line.

```
REVIEW:PASS   (or REVIEW:BLOCK)

## Summary
<Overall assessment>

## Issues
- <Critical/suggestion/nit level issues>

## Files Reviewed
- path/to/file.ext
```

### TESTS:

Posted by test steps. Format:

```
TESTS:

## Results
- PASS: <N> tests passing
- FAIL: <N> tests failing

## Test Files
- tests/path/to/test.yaml — <what it tests>

## Coverage
<What is and isn't covered>
```

## How to Post

```bash
bd comment <parent-bead-id> "<PROTOCOL_PREFIX>:

<structured content>"
```

## How to Read Upstream

When starting a step, read prior comments for context:

```bash
bd show <parent-bead-id> --comments
```

Look for `FINDINGS:`, `CHANGES:`, etc. from completed upstream steps.

## Important

- Always use the exact prefix format (`FINDINGS:`, `CHANGES:`, `REVIEW:PASS`, `REVIEW:BLOCK`, `TESTS:`)
- These comments persist on the parent bead after wisp squashing
- The dispatch skill reads these comments to provide context to downstream steps
- The diary agent reads these comments to enrich swarm-tagged chronicles (E2)
