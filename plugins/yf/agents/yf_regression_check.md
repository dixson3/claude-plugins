---
name: yf_regression_check
description: Runs unit tests and summarizes results for the calling agent
---

# Regression Check Agent

Run the yf unit test suite and return a structured summary.

## Process

1. Run tests:
   ```bash
   bash tests/run-tests.sh --unit-only
   ```
2. Parse output for pass/fail counts and any failure details.
3. Return summary:
   ```
   REGRESSION: PASS | FAIL
   Total: N | Passed: N | Failed: N
   Failures:
   - <test name>: <reason>
   ```

## Tools

May run Bash (test runner) and read files. No edits or writes.
