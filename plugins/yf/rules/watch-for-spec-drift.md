# Rule: Watch for Specification Drift

**Purpose**: Monitor context for changes that may cause specifications to become outdated.

## Instructions

When this rule is active, watch for events that may cause specification documents to drift from the actual codebase state.

### PRD Drift Triggers

Flag these events as potential PRD drift:

1. **New Functionality**
   - Implementing features not traced to a REQ-xxx
   - Adding user-facing capabilities
   - Creating new API endpoints or interfaces

2. **Requirement Contradictions**
   - Changes that conflict with documented requirements
   - Removing functionality described in a REQ
   - Changing behavior documented in the PRD

### EDD Drift Triggers

Flag these events as potential EDD drift:

1. **Technology Conflicts**
   - Using a library or tool that conflicts with a DD-xxx decision
   - Changing infrastructure or architecture
   - Introducing patterns not documented in design decisions

2. **NFR Violations**
   - Changes that may affect performance characteristics (NFR-xxx)
   - Security-related changes without NFR review
   - Scalability changes

### IG Drift Triggers

Flag these events as potential IG drift:

1. **Feature Changes**
   - Modifying a feature that has an Implementation Guide
   - Changing use case flows documented in a UC-xxx
   - Adding or removing steps from documented workflows

2. **Test Alignment**
   - Suggest test suite validation against IG use cases when features change
   - Suggest system tests validate PRD requirements when requirements change

### Behavior

When you notice a potential spec drift event:

1. Briefly note it in your response: "This change may affect specifications."
2. Suggest the appropriate action:
   - For PRD: "Consider running `/yf:engineer_update type:prd` to update requirements."
   - For EDD: "Consider running `/yf:engineer_update type:edd` to update design decisions."
   - For IG: "Consider running `/yf:engineer_update type:ig feature:<name>` to update the implementation guide."

**Do NOT auto-update specs.** Only flag and suggest. The operator decides when to update.

### Pre-Check

Before flagging, verify specs actually exist:

```bash
ARTIFACT_DIR=$(jq -r '.config.artifact_dir // "docs"' .yoshiko-flow/config.json 2>/dev/null || echo "docs")
SPEC_DIR="${ARTIFACT_DIR}/specifications"
```

If `$SPEC_DIR` does not exist or contains no files, do NOT flag anything. This rule is a no-op without specs.

### Example Suggestions

After implementing a new feature:
> "This new authentication feature may affect specifications. Consider running `/yf:engineer_update type:prd action:add` to add a requirement, and `/yf:engineer_update type:ig feature:authentication` to create an implementation guide."

After changing architecture:
> "This database migration may affect specifications. Consider running `/yf:engineer_update type:edd action:update id:DD-002` to update the storage design decision."

After modifying a documented feature:
> "This change affects the data export feature, which has an implementation guide. Consider running `/yf:engineer_update type:ig feature:data-export` to update the use cases."

### Non-Triggers

Do NOT flag these as spec drift:
- Trivial changes (typos, formatting, minor tweaks)
- Work on features without existing IG docs (unless creating new functionality)
- Configuration changes that don't affect architecture
- Test additions that don't change behavior
- Documentation-only changes
- Changes already reconciled via `/yf:engineer_reconcile`

### Frequency

- At most once per 15-20 minutes of active work
- Prioritize conflicts over additions
- If unsure, err on the side of not suggesting
