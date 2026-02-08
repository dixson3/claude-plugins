# Plan 06: Test Suite with Go Harness for Plan Lifecycle Enforcement

**Status:** Completed

## Overview

Added a Go test harness and YAML-based test scenarios for plan lifecycle gate enforcement. The harness supports both unit tests (shell-only, no API calls) and integration tests (multi-turn Claude sessions via `--resume`).

## Architecture

```
tests/
├── harness/           # Go test harness
│   ├── main.go        # CLI entry, scenario loading
│   ├── scenario.go    # Type definitions
│   ├── runner.go      # Scenario executor (setup/steps/teardown)
│   ├── session.go     # Claude --resume session management
│   ├── assertions.go  # File/output/exit-code assertions
│   ├── go.mod
│   └── go.sum
├── scenarios/         # YAML test scenarios
│   ├── unit-code-gate.yaml        # 12 unit tests
│   ├── unit-exit-plan-gate.yaml   # 14 unit tests
│   ├── unit-plan-exec-gate.yaml   # 3 unit tests
│   ├── gate-enforcement.yaml      # Integration: session gate test
│   ├── dismiss-gate.yaml          # Integration: escape hatch
│   └── full-lifecycle.yaml        # Integration: end-to-end
├── bin/               # Built harness binary
└── run-tests.sh       # Convenience wrapper
```

## Findings

- `exit-plan-gate.sh` has a known bug: exits 1 when `.claude/plans/` exists but is empty (due to `set -o pipefail` + `ls *.md` failing with no matches). Test documents actual behavior.

## Usage

```bash
# Unit tests only (fast, free)
bash tests/run-tests.sh --unit-only

# Full suite (integration tests cost API calls)
bash tests/run-tests.sh

# Single scenario with verbose output
tests/bin/test-harness --plugin-dir . --verbose tests/scenarios/unit-code-gate.yaml
```
