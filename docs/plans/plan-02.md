# Plan 02: Chronicler Plugin Suite

**Status:** Completed
**Date:** 2026-02-04

## Overview

Create three plugins for the Yoshiko Studios Claude Marketplace:
1. **roles** - Selective role loading infrastructure
2. **workflows** - Beads initialization and workflow utilities
3. **chronicler** - Context persistence using beads and diary generation

## Execution Order

Execute each part in order. Clear context between parts if needed.

### Part 1: Roles Plugin
```
Implement: docs/plans/plan-02-part1-roles.md
```
Creates the roles infrastructure with `/roles:apply`, `/roles:assign`, `/roles:unassign`, `/roles:list`.

**Verification:**
- `ls plugins/roles/` shows expected structure
- `/roles:list` runs without error

---

### Part 2: Workflows Plugin
```
Implement: docs/plans/plan-02-part2-workflows.md
```
Creates the workflows plugin with `/workflows:init_beads`.

**Verification:**
- `ls plugins/workflows/` shows expected structure
- `/workflows:init_beads` can initialize beads

---

### Part 3: Chronicler Plugin
```
Implement: docs/plans/plan-02-part3-chronicler.md
```
Creates the chronicler plugin with all skills, agents, roles, and hooks.

**Verification:**
- `ls plugins/chronicler/` shows expected structure
- `/chronicler:init` initializes the system
- `/chronicler:capture`, `/chronicler:recall`, `/chronicler:diary`, `/chronicler:disable` all work

---

## Final Verification

After all parts complete:

```bash
# Verify marketplace structure
ls plugins/

# Verify marketplace.json includes all plugins
cat .claude-plugin/marketplace.json

# End-to-end test
/chronicler:init
/chronicler:capture topic:test
/chronicler:recall
/chronicler:diary
ls docs/diary/
```

## Design Decisions

1. **Auto-recall trigger**: Yes - `/chronicler:init` configures SessionStart hook
2. **Default role assignments**: Assign to ALL agents by default
3. **Roles plugin scope**: Included in this marketplace

## Dependencies

- **beads-cli** >= 0.44.0
- **jq** (for JSON processing in hooks)

## Part Files

| Part | File | Description |
|------|------|-------------|
| 1 | `plan-02-part1-roles.md` | Roles plugin infrastructure |
| 2 | `plan-02-part2-workflows.md` | Workflows plugin with beads init |
| 3 | `plan-02-part3-chronicler.md` | Chronicler plugin (main feature) |
