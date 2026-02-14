---
name: yf:plan_select_agent
description: Match a task to the best available agent based on capabilities and assign an agent label
arguments:
  - name: task_id
    description: "Bead ID to evaluate for agent assignment"
    required: true
  - name: dry_run
    description: "If true, show match without applying label"
    required: false
---

# Select Agent Skill

Standalone skill for agent-to-task matching. Scans all available agents across the marketplace and assigns the best match to a task.

## When to Invoke

- Called by `/yf:plan_to_beads` for each created task
- Called by `/yf:breakdown_task` for each new child task
- Can be invoked directly: `/yf:select_agent <task_id>`

## Behavior

### Step 1: Discover Agents

Scan all plugin agent definitions:

```bash
# Find all agent markdown files across plugins
find plugins/*/agents/*.md -type f 2>/dev/null
```

Read each agent file's frontmatter (`name`, `description`) and body (role, specializations).

### Step 2: Build Agent Registry

For each discovered agent, extract:
- **Name**: From frontmatter `name` field
- **Plugin**: From directory path
- **Description**: From frontmatter `description` field
- **Specializations**: From the Role/Knowledge sections in the body
- **Keywords**: Key terms that indicate relevance

**Current known agents:**

| Agent | Plugin | Specialization |
|---|---|---|
| `yf_chronicle_recall` | yf | Context recovery from beads |
| `yf_chronicle_diary` | yf | Diary generation from chronicles |
| `yf_code_researcher` | yf | Read-only; researches technology standards and coding patterns |
| `yf_code_writer` | yf | Full-capability; implements code following standards |
| `yf_code_tester` | yf | Limited-write; creates and runs tests |
| `yf_code_reviewer` | yf | Read-only; reviews against IGs and coding standards |

### Step 3: Read Task Context

```bash
bd show <task_id>
```

Extract the task's title, description, notes, and labels.

### Step 4: Match Agent to Task

Compare task content against each agent's capabilities:

1. **Keyword matching**: Does the task mention concepts in the agent's domain?
2. **Type matching**: Does the task type align with the agent's role?
3. **Specificity**: Prefer the most specialized agent over general-purpose ones

**Matching rules:**
- If the task involves diary generation, chronicles -> `yf_chronicle_diary`
- If the task involves context recall, recovery -> `yf_chronicle_recall`
- If no agent specializes in this area -> no label (primary agent handles it)
- If multiple agents match -> prefer the most specific match

### Step 5: Apply Label

If a clear match is found:

```bash
bd label add <task_id> agent:<agent-name>
```

If `dry_run`, just report the match without applying.

### Step 6: Report

```
Agent Selection: <task_id>
  Task: "<task title>"
  Match: agent:<agent-name> (reason: <why this agent>)
  Applied: yes/no (dry_run)
```

Or if no match:
```
Agent Selection: <task_id>
  Task: "<task title>"
  Match: none (primary agent will handle)
```

## Extensibility

This skill auto-discovers agents. As new agents are added to marketplace plugins, they become available for matching without changes to this skill. Future enhancements could add:
- Capability manifests in agent frontmatter
- Workload balancing across agents
- Preference scoring with weighted criteria
