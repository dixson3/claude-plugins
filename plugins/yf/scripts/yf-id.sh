#!/bin/bash
# yf-id.sh — Shared shell library for hash-based ID generation
#
# Provides yf_generate_id() for collision-safe IDs across parallel worktrees.
# Uses SHA-256 hash of timestamp + PID + $RANDOM, converted to base36,
# truncated to 5 characters. macOS compatible (uses shasum -a 256).
#
# Charset: lowercase base36 (a-z0-9) — case-insensitive safe for macOS HFS+.
# Collision space: 36^5 = 60M values.
#
# Usage:
#   . "$SCRIPT_DIR/yf-id.sh"
#   ID=$(yf_generate_id "plan")     # → "plan-a3x7m"
#   ID=$(yf_generate_id "TODO")     # → "TODO-b7rpz"
#   ID=$(yf_generate_id "REQ")      # → "REQ-k4m9q"
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

# yf_generate_id — generate a hash-based ID with prefix
# Args: $1 = prefix (e.g., "plan", "TODO", "REQ", "DD", "NFR", "UC", "DEC")
# Output: PREFIX-xxxxx (e.g., "plan-a3x7m", "TODO-b7rpz")
yf_generate_id() {
  local prefix="$1"
  local hash id

  # Increment sequence counter for uniqueness within same shell
  _YF_ID_SEQ=$((_YF_ID_SEQ + 1))

  # Hash timestamp + PID + RANDOM + sequence for entropy
  hash=$(printf '%s-%s-%s-%s' "$(date +%s)" "$$" "$RANDOM" "$_YF_ID_SEQ" | shasum -a 256 | cut -d' ' -f1)

  # Convert to 5-char base36
  id=$(_yf_base36 "$hash" 5)

  echo "${prefix}-${id}"
}
