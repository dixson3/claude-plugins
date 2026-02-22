#!/bin/bash
# yf-id.sh — Shared shell library for hybrid idx-hash ID generation
#
# Provides yf_generate_id() for collision-safe IDs across parallel worktrees.
# Uses SHA-256 hash of timestamp + PID + $RANDOM, converted to base36,
# truncated to 5 characters. macOS compatible (uses shasum -a 256).
#
# With optional scope argument, produces hybrid IDs: PREFIX-NNNN-xxxxx
# where NNNN is a zero-padded sequential index derived from existing IDs.
# Without scope, produces legacy PREFIX-xxxxx for backward compatibility.
#
# Charset: lowercase base36 (a-z0-9) — case-insensitive safe for macOS HFS+.
# Collision space: 36^5 = 60M values.
#
# Usage:
#   . "$SCRIPT_DIR/yf-id.sh"
#   ID=$(yf_generate_id "plan")                    # → "plan-a3x7m"       (legacy)
#   ID=$(yf_generate_id "plan" "$PLANS_DIR")       # → "plan-0054-a3x7m"  (hybrid)
#   ID=$(yf_generate_id "REQ" "$SPEC_DIR/PRD.md")  # → "REQ-0005-k4m9q"   (hybrid)
#   ID=$(yf_generate_id "UC" "$SPEC_DIR/IG/")      # → "UC-0012-b7rpz"    (hybrid)
#
# Compatible with bash 3.2+ (macOS default).

# _yf_base36 — convert hex string to base36 (a-z0-9), output N chars
# Args: $1 = hex string, $2 = output length (default 5)
_yf_base36() {
  local hex="$1"
  local len="${2:-5}"
  # Use awk for portable big-number hex-to-base36 conversion
  echo "$hex" | awk -v outlen="$len" '
  BEGIN {
    chars = "0123456789abcdefghijklmnopqrstuvwxyz"
  }
  {
    # Convert hex to decimal array (big number math via digit array)
    n = length($0)
    # Work with first 16 hex chars (64 bits — enough entropy for 5 base36 chars)
    if (n > 16) n = 16
    hex_str = substr($0, 1, n)

    # Convert hex to base-10 digits array
    split("", dec)
    dec_len = 1
    dec[1] = 0

    for (i = 1; i <= n; i++) {
      c = substr(hex_str, i, 1)
      if (c >= "0" && c <= "9") h = c + 0
      else if (c == "a" || c == "A") h = 10
      else if (c == "b" || c == "B") h = 11
      else if (c == "c" || c == "C") h = 12
      else if (c == "d" || c == "D") h = 13
      else if (c == "e" || c == "E") h = 14
      else if (c == "f" || c == "F") h = 15
      else h = 0

      # Multiply dec by 16 and add h
      carry = h
      for (j = dec_len; j >= 1; j--) {
        val = dec[j] * 16 + carry
        dec[j] = val % 10000
        carry = int(val / 10000)
      }
      while (carry > 0) {
        for (j = dec_len; j >= 1; j--) dec[j+1] = dec[j]
        dec[1] = carry % 10000
        carry = int(carry / 10000)
        dec_len++
      }
    }

    # Convert decimal to base36
    result = ""
    for (iter = 0; iter < outlen; iter++) {
      rem = 0
      for (j = 1; j <= dec_len; j++) {
        val = rem * 10000 + dec[j]
        dec[j] = int(val / 36)
        rem = val % 36
      }
      result = substr(chars, rem + 1, 1) result
      # Trim leading zeros in dec
      while (dec_len > 1 && dec[1] == 0) {
        for (j = 1; j < dec_len; j++) dec[j] = dec[j+1]
        dec_len--
      }
    }

    print result
  }'
}

# Internal counter for uniqueness within a single shell session
_YF_ID_SEQ=0

# _yf_next_idx — count existing IDs to determine next sequential index
# Args: $1 = prefix (e.g., "plan", "REQ"), $2 = scope (file or directory path)
# Output: zero-padded 4-digit index (e.g., "0001", "0054")
_yf_next_idx() {
  local prefix="$1"
  local scope="$2"
  local count=0

  if [[ -d "$scope" ]]; then
    if [[ "$prefix" == "plan" ]]; then
      # Directory scope for plans: count plan-*.md files (exclude part files)
      count=$(ls "$scope"/plan-*.md 2>/dev/null | grep -cvE -- '-part[0-9]' 2>/dev/null) || count=0
    else
      # Directory scope (e.g., IG UCs): count PREFIX- occurrences across all .md files
      count=0
      for f in "$scope"/*.md; do
        [[ -f "$f" ]] || continue
        local c
        c=$(grep -cE "${prefix}-" "$f" 2>/dev/null) || c=0
        count=$((count + c))
      done
    fi
  elif [[ -f "$scope" ]]; then
    # File scope: count occurrences of PREFIX- pattern in the file
    count=$(grep -cE "${prefix}-" "$scope" 2>/dev/null) || count=0
  fi
  # count is 0 if scope doesn't exist yet

  # Next index = count + 1
  printf '%04d' $((count + 1))
}

# yf_generate_id — generate an ID with prefix, optionally hybrid with scope
# Args: $1 = prefix (e.g., "plan", "TODO", "REQ", "DD", "NFR", "UC", "DEC")
#        $2 = scope (optional — file or directory path for hybrid idx-hash IDs)
# Output: PREFIX-xxxxx (legacy) or PREFIX-NNNN-xxxxx (hybrid when scope given)
yf_generate_id() {
  local prefix="$1"
  local scope="${2:-}"
  local hash id idx

  # Increment sequence counter for uniqueness within same shell
  _YF_ID_SEQ=$((_YF_ID_SEQ + 1))

  # Hash timestamp + PID + RANDOM + sequence for entropy
  hash=$(printf '%s-%s-%s-%s' "$(date +%s)" "$$" "$RANDOM" "$_YF_ID_SEQ" | shasum -a 256 | cut -d' ' -f1)

  # Convert to 5-char base36
  id=$(_yf_base36 "$hash" 5)

  if [[ -n "$scope" ]]; then
    idx=$(_yf_next_idx "$prefix" "$scope")
    echo "${prefix}-${idx}-${id}"
  else
    echo "${prefix}-${id}"
  fi
}
