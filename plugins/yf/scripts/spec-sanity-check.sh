#!/bin/bash
# spec-sanity-check.sh — Mechanical consistency checks for specification files
#
# Usage:
#   spec-sanity-check.sh all          # Run all checks
#   spec-sanity-check.sh counts       # Count parity only
#   spec-sanity-check.sh contiguity   # ID contiguity only
#   spec-sanity-check.sh arithmetic   # Coverage arithmetic only
#   spec-sanity-check.sh uc-ranges    # UC range alignment only
#   spec-sanity-check.sh test-refs    # Test file existence only
#   spec-sanity-check.sh formulas     # Formula count only
#
# Exit 0 always (fail-open). Output: structured report with [PASS]/[FAIL]
# per check, trailing SANITY_ISSUES=N for machine parsing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/yf-config.sh"

COMMAND="${1:-all}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# --- Guards ---

# jq required
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not available"
  echo "SANITY_ISSUES=0"
  exit 0
fi

# yf must be enabled
if ! yf_is_enabled 2>/dev/null; then
  exit 0
fi

# Config disabled → exit
MODE=$(yf_sanity_check_mode 2>/dev/null)
if [ "$MODE" = "disabled" ]; then
  exit 0
fi

# Resolve spec dir
ARTIFACT_DIR=$(yf_read_field '.config.artifact_dir' 2>/dev/null)
if [ -z "$ARTIFACT_DIR" ] || [ "$ARTIFACT_DIR" = "null" ]; then
  ARTIFACT_DIR="docs"
fi
SPEC_DIR="$PROJECT_DIR/$ARTIFACT_DIR/specifications"

if [ ! -d "$SPEC_DIR" ]; then
  echo "SKIP: No specification directory at $SPEC_DIR"
  echo "SANITY_ISSUES=0"
  exit 0
fi

# --- Helpers ---

ISSUES=0
PASSED=0
CHECKS_RUN=0

pass() {
  echo "[PASS] $1"
  PASSED=$((PASSED + 1))
  CHECKS_RUN=$((CHECKS_RUN + 1))
}

fail() {
  echo "[FAIL] $1"
  ISSUES=$((ISSUES + 1))
  CHECKS_RUN=$((CHECKS_RUN + 1))
}

skip() {
  echo "[SKIP] $1"
}

# Count IDs matching pattern in a file
count_ids_in_file() {
  local file="$1" pattern="$2"
  if [ ! -f "$file" ]; then
    echo "0"
    return
  fi
  grep -cE "$pattern" "$file" 2>/dev/null || echo "0"
}

# Extract numeric suffixes of IDs matching pattern, sorted (leading zeros stripped)
extract_id_numbers() {
  local file="$1" pattern="$2"
  if [ ! -f "$file" ]; then
    return
  fi
  grep -oE "$pattern" "$file" 2>/dev/null | grep -oE '[0-9]+$' | awk '{print $1+0}' | sort -n
}

# --- Checks ---

# Check 1: Count parity — REQ/DD/NFR/UC counts match across source and coverage
check_counts() {
  local prd_file="$SPEC_DIR/PRD.md"
  local edd_file="$SPEC_DIR/EDD/CORE.md"
  local coverage_file="$SPEC_DIR/test-coverage.md"

  if [ ! -f "$coverage_file" ]; then
    skip "Count parity: no test-coverage.md"
    return
  fi

  local all_ok=true
  local details=""

  # REQ: count in PRD vs coverage table rows vs summary
  local req_prd=0 req_cov_rows=0 req_summary=0
  if [ -f "$prd_file" ]; then
    req_prd=$(count_ids_in_file "$prd_file" '^\| REQ-[0-9]+')
  fi
  req_cov_rows=$(count_ids_in_file "$coverage_file" '^\| REQ-[0-9]+')
  req_summary=$(awk '/^\| REQ \|/ { split($0, a, "|"); gsub(/[^0-9]/, "", a[3]); print a[3] }' "$coverage_file" 2>/dev/null)
  if [ -z "$req_summary" ]; then req_summary=0; fi
  details="${details}REQ=$req_prd/$req_cov_rows/$req_summary"

  if [ "$req_prd" -ne "$req_cov_rows" ] || [ "$req_cov_rows" -ne "$req_summary" ]; then
    all_ok=false
  fi

  # DD: count in EDD vs coverage rows vs summary
  local dd_edd=0 dd_cov_rows=0 dd_summary=0
  if [ -f "$edd_file" ]; then
    dd_edd=$(count_ids_in_file "$edd_file" '^### DD-[0-9]+')
  fi
  dd_cov_rows=$(count_ids_in_file "$coverage_file" '^\| DD-[0-9]+')
  dd_summary=$(awk '/^\| DD \|/ { split($0, a, "|"); gsub(/[^0-9]/, "", a[3]); print a[3] }' "$coverage_file" 2>/dev/null)
  if [ -z "$dd_summary" ]; then dd_summary=0; fi
  details="${details}, DD=$dd_edd/$dd_cov_rows/$dd_summary"

  if [ "$dd_edd" -ne "$dd_cov_rows" ] || [ "$dd_cov_rows" -ne "$dd_summary" ]; then
    all_ok=false
  fi

  # NFR: count in EDD vs coverage rows vs summary
  local nfr_edd=0 nfr_cov_rows=0 nfr_summary=0
  if [ -f "$edd_file" ]; then
    nfr_edd=$(count_ids_in_file "$edd_file" '^### NFR-[0-9]+')
  fi
  nfr_cov_rows=$(count_ids_in_file "$coverage_file" '^\| NFR-[0-9]+')
  nfr_summary=$(awk '/^\| NFR \|/ { split($0, a, "|"); gsub(/[^0-9]/, "", a[3]); print a[3] }' "$coverage_file" 2>/dev/null)
  if [ -z "$nfr_summary" ]; then nfr_summary=0; fi
  details="${details}, NFR=$nfr_edd/$nfr_cov_rows/$nfr_summary"

  if [ "$nfr_edd" -ne "$nfr_cov_rows" ] || [ "$nfr_cov_rows" -ne "$nfr_summary" ]; then
    all_ok=false
  fi

  # UC: count across all IG files vs coverage rows vs summary
  local uc_ig=0 uc_cov_rows=0 uc_summary=0
  if [ -d "$SPEC_DIR/IG" ]; then
    for ig_file in "$SPEC_DIR"/IG/*.md; do
      [ -f "$ig_file" ] || continue
      local c
      c=$(count_ids_in_file "$ig_file" '^### UC-[0-9]+')
      uc_ig=$((uc_ig + c))
    done
  fi
  uc_cov_rows=$(count_ids_in_file "$coverage_file" '^\| UC-[0-9]+')
  uc_summary=$(awk '/^\| UC \|/ { split($0, a, "|"); gsub(/[^0-9]/, "", a[3]); print a[3] }' "$coverage_file" 2>/dev/null)
  if [ -z "$uc_summary" ]; then uc_summary=0; fi
  details="${details}, UC=$uc_ig/$uc_cov_rows/$uc_summary"

  if [ "$uc_ig" -ne "$uc_cov_rows" ] || [ "$uc_cov_rows" -ne "$uc_summary" ]; then
    all_ok=false
  fi

  if $all_ok; then
    pass "Count parity: $details"
  else
    fail "Count parity: $details"
  fi
}

# Check 2: ID uniqueness — no duplicate IDs (replaces contiguity check for hash-based IDs)
check_contiguity() {
  local prd_file="$SPEC_DIR/PRD.md"
  local edd_file="$SPEC_DIR/EDD/CORE.md"
  local all_ok=true
  local detail_parts=""

  # REQ uniqueness from PRD
  if [ -f "$prd_file" ]; then
    local ids
    ids=$(grep -oE 'REQ-[a-z0-9-]+' "$prd_file" 2>/dev/null | sort)
    if [ -n "$ids" ]; then
      local dupes
      dupes=$(echo "$ids" | uniq -d)
      if [ -n "$dupes" ]; then
        all_ok=false
        detail_parts="${detail_parts}Duplicate REQ IDs: $(echo "$dupes" | tr '\n' ' '). "
      fi
    fi
  fi

  # DD uniqueness from EDD
  if [ -f "$edd_file" ]; then
    local ids
    ids=$(grep -oE 'DD-[a-z0-9-]+' "$edd_file" 2>/dev/null | grep -v 'NFR-' | sort)
    if [ -n "$ids" ]; then
      local dupes
      dupes=$(echo "$ids" | uniq -d)
      if [ -n "$dupes" ]; then
        all_ok=false
        detail_parts="${detail_parts}Duplicate DD IDs: $(echo "$dupes" | tr '\n' ' '). "
      fi
    fi
  fi

  # NFR uniqueness from EDD
  if [ -f "$edd_file" ]; then
    local ids
    ids=$(grep -oE 'NFR-[a-z0-9-]+' "$edd_file" 2>/dev/null | sort)
    if [ -n "$ids" ]; then
      local dupes
      dupes=$(echo "$ids" | uniq -d)
      if [ -n "$dupes" ]; then
        all_ok=false
        detail_parts="${detail_parts}Duplicate NFR IDs: $(echo "$dupes" | tr '\n' ' '). "
      fi
    fi
  fi

  # UC uniqueness — global across all IG files
  if [ -d "$SPEC_DIR/IG" ]; then
    local all_uc_ids=""
    for ig_file in "$SPEC_DIR"/IG/*.md; do
      [ -f "$ig_file" ] || continue
      local ids
      ids=$(grep -oE 'UC-[a-z0-9-]+' "$ig_file" 2>/dev/null)
      if [ -n "$ids" ]; then
        all_uc_ids="${all_uc_ids}${all_uc_ids:+
}${ids}"
      fi
    done
    if [ -n "$all_uc_ids" ]; then
      local dupes
      dupes=$(echo "$all_uc_ids" | sort | uniq -d)
      if [ -n "$dupes" ]; then
        all_ok=false
        detail_parts="${detail_parts}Duplicate UC IDs: $(echo "$dupes" | tr '\n' ' '). "
      fi
    fi
  fi

  if $all_ok; then
    pass "ID uniqueness: no duplicates found"
  else
    fail "ID uniqueness: ${detail_parts}"
  fi
}

# Check 3: Coverage summary arithmetic
check_arithmetic() {
  local coverage_file="$SPEC_DIR/test-coverage.md"

  if [ ! -f "$coverage_file" ]; then
    skip "Coverage arithmetic: no test-coverage.md"
    return
  fi

  local all_ok=true
  local details=""

  # Parse Coverage Summary table rows
  local grand_total=0 grand_tested=0 grand_existence=0 grand_untested=0
  local in_summary=false

  while IFS= read -r line; do
    # Detect summary section
    if echo "$line" | grep -q '^## Coverage Summary'; then
      in_summary=true
      continue
    fi
    if $in_summary && echo "$line" | grep -qE '^## '; then
      break
    fi
    if ! $in_summary; then continue; fi

    # Skip header and separator lines
    echo "$line" | grep -qE '^\|[-]+' && continue
    echo "$line" | grep -qE '^\| Category' && continue

    # Parse data rows: | Category | Total | Tested | Existence-Only | Untested |
    if echo "$line" | grep -qE '^\| \*\*Total\*\*'; then
      # Grand total row
      grand_total=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $3); print $3 }')
      grand_tested=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $4); print $4 }')
      grand_existence=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $5); print $5 }')
      grand_untested=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $6); print $6 }')
      continue
    fi

    if echo "$line" | grep -qE '^\| (REQ|DD|NFR|UC) '; then
      local cat total tested existence untested
      cat=$(echo "$line" | awk -F'|' '{ gsub(/^ +| +$/, "", $2); print $2 }')
      total=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $3); print $3 }')
      tested=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $4); print $4 }')
      existence=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $5); print $5 }')
      untested=$(echo "$line" | awk -F'|' '{ gsub(/[^0-9]/, "", $6); print $6 }')

      # Verify row: Total = Tested + Existence-Only + Untested
      local expected=$((tested + existence + untested))
      if [ "$total" -ne "$expected" ]; then
        all_ok=false
        details="${details}$cat: $total != $tested+$existence+$untested. "
      fi
    fi
  done < "$coverage_file"

  # Verify grand total = sum
  if [ "$grand_total" -gt 0 ]; then
    local expected_grand=$((grand_tested + grand_existence + grand_untested))
    if [ "$grand_total" -ne "$expected_grand" ]; then
      all_ok=false
      details="${details}Grand total: $grand_total != $grand_tested+$grand_existence+$grand_untested. "
    fi
  fi

  if $all_ok; then
    pass "Coverage arithmetic: all rows balance"
  else
    fail "Coverage arithmetic: ${details}"
  fi
}

# Check 4: UC range alignment — UC IDs in IG files match declared ranges in test-coverage.md
check_uc_ranges() {
  local coverage_file="$SPEC_DIR/test-coverage.md"

  if [ ! -f "$coverage_file" ]; then
    skip "UC range alignment: no test-coverage.md"
    return
  fi

  if [ ! -d "$SPEC_DIR/IG" ]; then
    skip "UC range alignment: no IG directory"
    return
  fi

  # Parse the UC section header for declared ranges
  # Format: "engineer (UC-018–021, UC-033–034)" or "plan-lifecycle (UC-001–005)"
  local range_line
  range_line=$(grep -E '^\| UC-[0-9]+' "$coverage_file" | head -1)
  if [ -z "$range_line" ]; then
    skip "UC range alignment: no UC entries in coverage"
    return
  fi

  # Extract the header line that declares ranges
  local header_line
  header_line=$(grep -E 'Aligned to IG files:' "$coverage_file" 2>/dev/null || true)
  if [ -z "$header_line" ]; then
    skip "UC range alignment: no range header found"
    return
  fi

  local all_ok=true
  local details=""

  # For each IG file, extract actual UC IDs and compare against coverage
  for ig_file in "$SPEC_DIR"/IG/*.md; do
    [ -f "$ig_file" ] || continue
    local fname
    fname=$(basename "$ig_file" .md)

    # Count UCs in this IG file
    local uc_count
    uc_count=$(count_ids_in_file "$ig_file" '^### UC-[0-9]+')
    if [ "$uc_count" -eq 0 ]; then continue; fi

    # Get first and last UC numbers
    local first_uc last_uc
    first_uc=$(extract_id_numbers "$ig_file" '^### UC-[0-9]+' | head -1)
    last_uc=$(extract_id_numbers "$ig_file" '^### UC-[0-9]+' | tail -1)

    if [ -z "$first_uc" ] || [ -z "$last_uc" ]; then continue; fi

    # Check that the header mentions this range
    local range_str
    range_str=$(printf '%03d' "$first_uc")
    if ! echo "$header_line" | grep -qE "UC-0*${first_uc}"; then
      # Try without leading zeros
      if ! echo "$header_line" | grep -q "$fname"; then
        all_ok=false
        details="${details}$fname UC-${range_str}..$(printf '%03d' "$last_uc") not declared in header. "
      fi
    fi

    # Verify each UC in the IG file has a matching row in coverage
    while IFS= read -r num; do
      [ -z "$num" ] && continue
      local padded
      padded=$(printf '%03d' "$num")
      if ! grep -q "^| UC-$padded" "$coverage_file" 2>/dev/null; then
        all_ok=false
        details="${details}UC-$padded from $fname missing in coverage. "
      fi
    done <<EOF
$(extract_id_numbers "$ig_file" '^### UC-[0-9]+')
EOF
  done

  if $all_ok; then
    pass "UC range alignment: all IG UCs present in coverage"
  else
    fail "UC range alignment: ${details}"
  fi
}

# Check 5: Test file existence — referenced unit-*.yaml files exist
check_test_refs() {
  local coverage_file="$SPEC_DIR/test-coverage.md"

  if [ ! -f "$coverage_file" ]; then
    skip "Test file existence: no test-coverage.md"
    return
  fi

  local test_dir="$PROJECT_DIR/tests/scenarios"
  local all_ok=true
  local details=""
  local checked=0

  # Extract all unit-*.yaml references from coverage file
  local refs
  refs=$(grep -oE 'unit-[a-zA-Z0-9_-]+\.yaml' "$coverage_file" 2>/dev/null | sort -u)

  for ref in $refs; do
    checked=$((checked + 1))
    if [ ! -f "$test_dir/$ref" ]; then
      all_ok=false
      details="${details}Missing: $ref. "
    fi
  done

  if [ "$checked" -eq 0 ]; then
    skip "Test file existence: no test file references found"
    return
  fi

  if $all_ok; then
    pass "Test file existence: all $checked referenced files exist"
  else
    fail "Test file existence: ${details}"
  fi
}

# Check 6: Formula count — formula names in PRD FS-011 match files on disk
check_formulas() {
  local prd_file="$SPEC_DIR/PRD.md"

  if [ ! -f "$prd_file" ]; then
    skip "Formula count: no PRD.md"
    return
  fi

  local formula_dir="$PROJECT_DIR/plugins/yf/formulas"
  if [ ! -d "$formula_dir" ]; then
    skip "Formula count: no formulas directory"
    return
  fi

  # Extract formula names from FS-011 line
  local fs011_line
  fs011_line=$(grep -E 'FS-011' "$prd_file" 2>/dev/null || true)
  if [ -z "$fs011_line" ]; then
    skip "Formula count: FS-011 not found in PRD"
    return
  fi

  # Count formula names in FS-011 (comma-separated list after "shipped:")
  # "Six formula templates shipped: feature-build, research-spike, code-review, bugfix, build-test, code-implement"
  local spec_names spec_count
  spec_names=$(echo "$fs011_line" | sed 's/.*shipped: *//' | sed 's/ *(see .*//' | sed 's/ *([^)]*) *//g')
  spec_count=$(echo "$spec_names" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -c '.' || echo "0")

  # Count actual formula files
  local disk_count
  disk_count=$(ls "$formula_dir"/*.formula.json 2>/dev/null | wc -l | tr -d ' ')

  if [ "$spec_count" -eq "$disk_count" ]; then
    pass "Formula count: spec=$spec_count, disk=$disk_count"
  else
    fail "Formula count: spec=$spec_count, disk=$disk_count"
  fi
}

# --- Main ---

echo "Specification Sanity Check"
echo "=========================="
echo ""

case "$COMMAND" in
  all)
    check_counts
    check_contiguity
    check_arithmetic
    check_uc_ranges
    check_test_refs
    check_formulas
    ;;
  counts)
    check_counts
    ;;
  contiguity)
    check_contiguity
    ;;
  arithmetic)
    check_arithmetic
    ;;
  uc-ranges)
    check_uc_ranges
    ;;
  test-refs)
    check_test_refs
    ;;
  formulas)
    check_formulas
    ;;
  *)
    echo "Usage: spec-sanity-check.sh <all|counts|contiguity|arithmetic|uc-ranges|test-refs|formulas>" >&2
    exit 0
    ;;
esac

echo ""
echo "Summary: $PASSED passed, $ISSUES failed"
echo "SANITY_ISSUES=$ISSUES"

exit 0
