# Plan: Remove stale `yf_beads_installed` alias and references

## Context

Plan 47 (v2.25.0) removed the beads Claude plugin (`steveyegge/beads`) as a runtime dependency. The `/beads:*` skill calls were removed, the `dependencies` array was removed from `preflight.json`, and DD-016 was marked as reversed. However, the backwards-compatible alias `yf_beads_installed()` was intentionally retained "to avoid breaking external references." No external references exist — the alias and its callers are stale naming artifacts that should be cleaned up.

The specifications (PRD, EDD, IG) are already updated: REQ-035 says "bd CLI", DD-016 is reversed, FS-041 says `command -v bd`. No spec changes needed.

## Changes

### 1. Remove alias from `yf-config.sh`

**File**: `plugins/yf/scripts/yf-config.sh:59-60`

Delete the alias:
```bash
# Backwards-compatible alias
yf_beads_installed() { yf_bd_available; }
```

### 2. Update callers in `plugin-preflight.sh`

**File**: `plugins/yf/scripts/plugin-preflight.sh`

- **Line 68-72**: Change `yf_beads_installed` → `yf_bd_available`
- **Line 131**: Update comment `# --- Inactive: beads not installed ---` → `# --- Inactive: bd CLI not available ---`
- **Line 132**: Change `yf_beads_installed` → `yf_bd_available`

### 3. Update test scenarios

**File**: `tests/scenarios/unit-yf-config.yaml:259`
- Change `yf_beads_installed` → `yf_bd_available`

**File**: `tests/scenarios/unit-activation.yaml:47`
- Update comment `beads installed` → `bd CLI available`

### 4. Update DEVELOPERS.md

**File**: `plugins/yf/DEVELOPERS.md:183`
- Remove mention of the backwards-compatible alias

## Verification

```bash
# 1. Confirm no remaining references to yf_beads_installed
grep -r "yf_beads_installed" plugins/ tests/

# 2. Run unit tests
bash tests/run-tests.sh --unit-only
```
