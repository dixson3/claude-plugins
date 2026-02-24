# Implementation Guide: Script Complexity Management

## Overview

The yf plugin relies on ~23 bash scripts and ~11 hooks. These scripts must remain efficient (minimal subshell forks), maintainable (no dead code, no copy-paste blocks), and compatible with bash 3.2 (macOS default — no associative arrays). This guide codifies patterns for keeping script complexity in check.

## Use Cases

### UC-042: Prefer Parameter Expansion Over External Commands

**Actor**: Developer (writing or modifying shell functions)

**Preconditions**: A function uses `sed`, `awk`, `cut`, or `tr` for simple string manipulation.

**Flow**:
1. Identify string operations that match bash parameter expansion capabilities:
   - Prefix removal: `${var#pattern}` (shortest), `${var##pattern}` (longest)
   - Suffix removal: `${var%pattern}` (shortest), `${var%%pattern}` (longest)
   - Substring: `${var:offset:length}`
   - Replacement: `${var/pattern/replacement}`
2. Replace external command pipelines with the equivalent parameter expansion
3. Verify edge cases: empty strings, strings containing the delimiter character multiple times

**Postconditions**: No `sed`/`awk` subshells for operations achievable with parameter expansion. Edge cases (e.g., colons in content after a `protocol: content` split) handled correctly.

**Key Files**:
- `plugins/yf/scripts/yf-tasks.sh` — `yft_comment()` uses `${raw_comment%%:*}` and `${raw_comment#*: }`

### UC-043: Batch jq Calls With Dynamic Filter Construction

**Actor**: Developer (writing or modifying functions that mutate JSON files)

**Preconditions**: A function calls `jq` multiple times in sequence, piping output from one call as input to the next.

**Flow**:
1. Declare a `jq_filter` string (initialized to `. `) and a `jq_args` array
2. For each conditional mutation, append `--arg`/`--argjson` to `jq_args` and a filter clause to `jq_filter`
3. Execute a single `jq "${jq_args[@]}" "$jq_filter" "$file" > "$tmp"` reading directly from the file
4. Exception: operations that require fundamentally different jq modes (e.g., `jq -R -s` for CSV-to-array) remain as separate calls
5. Net call count should be 1-2 per function invocation, not N per field

**Postconditions**: JSON mutation functions spawn at most 2 jq processes regardless of how many fields are updated.

**Key Files**:
- `plugins/yf/scripts/yf-tasks.sh` — `yft_update()` and `yft_mol_wisp()` use this pattern

### UC-044: Remove Dead Code Promptly

**Actor**: Developer (during any script modification)

**Preconditions**: A function or alias exists that delegates entirely to another function with no additional logic.

**Flow**:
1. Identify pure aliases: functions whose body is only `other_function "$@"`
2. Search for all call sites (scripts, hooks, CLI dispatchers, tests)
3. Replace call sites with the target function directly
4. Delete the alias function — do not leave a comment or backwards-compatibility shim
5. Update CLI dispatch tables (e.g., `yf-task-cli.sh` case statements) to call the target directly

**Postconditions**: No dead alias functions. No `# removed` comments. CLI dispatch calls target functions directly.

**Key Files**:
- `plugins/yf/scripts/yf-task-cli.sh` — dispatch table for mol subcommands

### UC-045: Consolidate Copy-Pasted Blocks With Loop-Over-Specs

**Actor**: Developer (when 3+ structurally identical blocks exist)

**Preconditions**: A script contains 3 or more blocks that differ only in parameter values (labels, titles, boundary names).

**Flow**:
1. Extract the varying parameters into a spec array: `SPECS=("param1a param1b" "param2a param2b" ...)`
2. Replace the repeated blocks with a single `for spec in "${SPECS[@]}"; do ... done`
3. Parse spec fields with parameter expansion: `field1="${spec%% *}"`, `field2="${spec#* }"`
4. For multi-value fields within a spec entry, use a delimiter (e.g., `|`) and split with `IFS='|' read -ra`
5. Constraint: under bash 3.2, avoid associative arrays — use positional fields in flat strings

**Postconditions**: Repeated blocks consolidated. Adding a new variant requires only appending to the spec array.

**Key Files**:
- `plugins/yf/scripts/chronicle-validate.sh` — boundary checks use `BOUNDARY_SPECS` array

### UC-046: Parametrize Boolean Flag Checkers

**Actor**: Developer (when multiple functions share identical structure differing only in a config path)

**Flow**:
1. Create a generic function that accepts the varying path segment as an argument
2. Keep named wrappers as one-line delegators for backward compatibility and discoverability
3. New flag checks should call the generic function directly rather than creating new wrappers

**Postconditions**: No duplicated `_yf_check_flag` calls with hardcoded paths. New flags add one line, not a full function.

**Key Files**:
- `plugins/yf/scripts/yf-config.sh` — `yf_is_prune()` delegates to `_yf_check_flag`
