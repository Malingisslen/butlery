#!/usr/bin/env bash
# Lessons-digest mechanization (2026-07-16): Dart RegExp \b is ASCII-only, so a
# \b directly ADJACENT to å/ä/ö never matches a word boundary — the token
# silently stops matching (e.g. r'\btvå\b'). Use explicit lookarounds
# (?<![a-zåäö0-9]) / (?![a-zåäö0-9]) instead.
#
# Called from lefthook with the staged .dart files as arguments. Only \b
# TOUCHING a Swedish char is flagged — \b bordering ASCII on a line that merely
# contains å/ä/ö elsewhere is fine (baseline verified zero hits 2026-07-16).

[ $# -eq 0 ] && exit 0

# ERE: literal backslash + b adjacent to a Swedish character, either side.
PATTERN='\\b[åäöÅÄÖ]|[åäöÅÄÖ]\\b'

if grep -nE "$PATTERN" "$@"; then
  echo ""
  echo "Dart \\b is ASCII-only and never matches next to å/ä/ö — replace with"
  echo "explicit lookarounds (?<![a-zåäö0-9]) / (?![a-zåäö0-9]). See lessons-digest."
  exit 1
fi
exit 0
