# Rule: Watch for Archive-Worthiness

**Purpose**: Monitor context for research findings and design decisions worth preserving as permanent documentation.

## Instructions

When this rule is active, watch for archive-worthy moments during your work. The archivist captures the "why" — research topics with references and design decisions with alternatives — as permanent docs under `docs/research/` and `docs/decisions/`.

### Research Triggers

Flag these events as archive-worthy research:

1. **Web Searches**
   - Searching for libraries, tools, or services
   - Looking up API documentation or specifications
   - Investigating technical approaches or patterns

2. **External Documentation**
   - Reading API docs, specs, or papers
   - Referencing third-party tool documentation
   - Consulting language/framework references

3. **Tool Evaluations**
   - Comparing libraries, services, or tools
   - Benchmarking or testing alternatives
   - Evaluating trade-offs between options

4. **Technical Investigations**
   - Deep-diving into how something works
   - Debugging with external research
   - Investigating root causes with external sources

### Decision Triggers

Flag these events as archive-worthy decisions:

1. **Architecture Choices**
   - Choosing system structure or patterns
   - Defining component boundaries
   - Selecting communication patterns

2. **Tool/Technology Selections**
   - Choosing libraries or frameworks
   - Selecting services or platforms
   - Picking languages or runtimes

3. **Approval/Rejection Language**
   - "Let's go with X", "We'll use Y"
   - "Rejected Z because...", "Approved the approach"
   - "Changed direction to..."

4. **Scope Changes**
   - Priority shifts or feature additions/removals
   - Changing requirements or constraints
   - Adjusting project boundaries

### Behavior

When you notice an archive-worthy event:

1. Briefly note it in your response: "This seems archive-worthy."
2. For research: Suggest: "Consider running `/yf:archive type:research` to document this research."
3. For decisions: Suggest: "Consider running `/yf:archive type:decision` to document this decision."

**Do NOT auto-capture.** Only flag and suggest. The user decides when to archive.

### Example Suggestions

After researching libraries:
> "This research seems archive-worthy — you've evaluated multiple GraphQL clients. Consider running `/yf:archive type:research area:tooling` to document the findings."

After a design decision:
> "This architecture decision seems archive-worthy. Consider running `/yf:archive type:decision area:architecture` to document the choice and alternatives considered."

After investigating an API:
> "This API investigation seems archive-worthy. Consider running `/yf:archive type:research area:api` to preserve the findings."

### Non-Triggers

Do NOT flag these as archive-worthy:
- Routine task decisions (that's for beads/issues)
- Implementation details without strategic significance
- Temporary debugging notes
- Insights and patterns (that's for the chronicler)
- Simple Q&A that doesn't involve external research
- Reading/exploring internal code without external sources

### Frequency

- Don't over-suggest — at most once every 15-20 minutes of active work
- Prioritize research with multiple sources over single lookups
- Prioritize decisions with alternatives considered over obvious choices
- If unsure, err on the side of not suggesting
