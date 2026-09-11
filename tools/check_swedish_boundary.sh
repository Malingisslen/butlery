#!/usr/bin/env bash
# Lessons-digest mechanization (2026-07-16): Dart RegExp \b is ASCII-only, so a
# \b directly ADJACENT to å/ä/ö never matches a word boundary — the token
# silently stops matching (e.g. r'\btvå\b'). Use explicit lookarounds
# (?<![a-zåäö0-9]) / (?![a-zåäö0-9]) instead.
#
# Called from lefthook with the staged .dart files as arguments. Only \b
# TOUCHING a Swedish char is flagged — \b bordering ASCII on a line that merely
# contains å/ä/ö elsewhere is fine (baseline verified zero hits 2026-07-16).
#
# BUT-2061: grep's contract is 0 = matched, 1 = no match, >1 = it failed. This
# script used to test only `if grep …; then`, so a grep that could not run fell
# into the no-match branch and exited 0 — an outage indistinguishable from a
# clean diff, while still printing grep's error to stderr.
#
# Exit contract: 0 = clean, 1 = a violation was found or the scan could not run.

set -uo pipefail

SELF_TEST=0
if [ "${1:-}" = "--self-test" ]; then
  SELF_TEST=1
  shift
fi

# ERE: literal backslash + b adjacent to a Swedish character, either side.
PATTERN='\\b[åäöÅÄÖ]|[åäöÅÄÖ]\\b'

if [ "$SELF_TEST" -eq 1 ]; then
  FIXTURE_DIR=$(mktemp -d)
  trap 'rm -rf "$FIXTURE_DIR"' EXIT

  # Quoted heredoc delimiters keep the backslashes literal. Written any other
  # way — through printf or another language's string — `\b` risks becoming a
  # BACKSPACE byte, and the fixture would then contain nothing to detect.
  cat > "$FIXTURE_DIR/violating.dart" <<'DART'
final re = RegExp(r'\btvå\b');
DART
  cat > "$FIXTURE_DIR/clean.dart" <<'DART'
final re = RegExp(r'(?<![a-zåäö0-9])tvåa(?![a-zåäö0-9])');
final ascii = RegExp(r'\bcat\b');
DART

  GUARD="${BASH_SOURCE[0]}"
  FAILURES=0

  # `bash "$GUARD"`, never "$GUARD" directly: the file is committed mode 644,
  # so a direct call exits 126 on Linux before reading a line.
  bash "$GUARD" "$FIXTURE_DIR/violating.dart" >/dev/null 2>&1
  VIOLATING_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/clean.dart" >/dev/null 2>&1
  CLEAN_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/absent.dart" >/dev/null 2>&1
  ABSENT_RC=$?
  SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC=2 bash "$GUARD" "$FIXTURE_DIR/clean.dart" \
    >/dev/null 2>&1
  OUTAGE_RC=$?
  # The seam must not be usable to silence the guard.
  SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC=1 bash "$GUARD" \
    "$FIXTURE_DIR/violating.dart" >/dev/null 2>&1
  SEAM_ABUSE_RC=$?

  for rc in "$VIOLATING_RC" "$CLEAN_RC" "$ABSENT_RC" "$OUTAGE_RC" \
            "$SEAM_ABUSE_RC"; do
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
      echo "SELF-TEST FAIL: the guard could not be run (exit $rc)." >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [ "$FAILURES" -eq 0 ]; then
    if [ "$VIOLATING_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a \\b next to å/ä/ö was NOT detected." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$CLEAN_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: lookarounds or an ASCII \\b were flagged." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$ABSENT_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: a path that no longer exists was not skipped." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$OUTAGE_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a failed grep was reported as a clean scan." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$SEAM_ABUSE_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: the probe seam silenced a real detection." >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  if [ "$FAILURES" -ne 0 ]; then
    echo "check_swedish_boundary.sh no longer detects what it claims to." >&2
    exit 1
  fi

  echo "check_swedish_boundary.sh self-test: detection, skip and exit code all OK."
  exit 0
fi

[ $# -eq 0 ] && exit 0

# A path that no longer exists on disk is nothing to scan, not an outage. Only a
# grep that fails on a file that IS there is an outage.
TARGETS=()
for f in "$@"; do
  [ -f "$f" ] && TARGETS+=("$f")
done
[ "${#TARGETS[@]}" -eq 0 ] && exit 0

HITS=$(grep -nHE "$PATTERN" "${TARGETS[@]}")
GREP_RC=$?

# Test seam for the branch below, same shape and reason as
# tools/check_secret_scan.sh: no fixture can make grep fail portably. Accepted
# ONLY above 1, so it can force a failure and never silence one.
if [ "${SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC:-}" -gt 1 ] 2>/dev/null; then
  GREP_RC="$SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC"
fi

if [ "$GREP_RC" -gt 1 ]; then
  echo "❌ check_swedish_boundary.sh could NOT run (grep exit $GREP_RC)." >&2
  echo "   Treated as a failure, not as a clean scan." >&2
  exit 1
fi

if [ "$GREP_RC" -eq 0 ]; then
  echo "$HITS"
  echo ""
  echo "Dart \\b is ASCII-only and never matches next to å/ä/ö — replace with"
  echo "explicit lookarounds (?<![a-zåäö0-9]) / (?![a-zåäö0-9]). See lessons-digest."
  exit 1
fi
exit 0
