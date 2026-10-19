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
# BUT-1717: the literal check above cannot see a pattern ASSEMBLED at runtime —
# `'\\b(${words.join('|')})\\b'` puts \b next to whatever the list holds, and one
# entry starting or ending in å/ä/ö silently stops matching. A line carrying \b
# together with an interpolation or a ` + ` join is therefore flagged unless it
# says why it is safe: `// swedish-boundary-ok: <reason>` on that line or within
# the three above it (a bare marker with no reason does not count). Lines that use
# SwedishWordBoundary, and comment lines, are not flagged. A statement split so
# that the \b line and its join are two lines apart is only seen when the join
# ends the line before or after it. Files under test/ are not scanned for this
# half: they build patterns from repo identifiers, not from user text.
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

# Runtime-assembled \b. `index(line, "\\b")` finds the two characters \ b, which is
# both the raw-string \b and the tail of the escaped \\b.
DYNAMIC_AWK='
FILENAME ~ /(^|\/)test\// { next }
FNR == 1 { prev_join = 0; hist1 = hist2 = hist3 = "" }
{
  line = $0
  is_comment = (line ~ /^[[:space:]]*\/\//)
  joins = (line ~ /[[:space:]]\+[[:space:]]/ || line ~ /[[:space:]]\+[[:space:]]*$/ \
           || line ~ /^[[:space:]]*\+[[:space:]]/ || line ~ /(^|[^\\])\$\{/ \
           || line ~ /(^|[^\\])\$[A-Za-z_]/)
  ends_join = (line ~ /[[:space:]]\+[[:space:]]*$/)
  marked = (line ~ /swedish-boundary-ok:[[:space:]]*[^[:space:]]/ \
            || hist1 ~ /swedish-boundary-ok:[[:space:]]*[^[:space:]]/ \
            || hist2 ~ /swedish-boundary-ok:[[:space:]]*[^[:space:]]/ \
            || hist3 ~ /swedish-boundary-ok:[[:space:]]*[^[:space:]]/)
  if (!is_comment && index(line, "\\b") > 0 && line !~ /SwedishWordBoundary/ \
      && (joins || prev_join || ends_join) && !marked) {
    print FILENAME ":" FNR ":" line
  }
  prev_join = ends_join
  hist3 = hist2; hist2 = hist1; hist1 = line
}'

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

  # BUT-1717: runtime-assembled \b. Same quoted-heredoc rule as above.
  cat > "$FIXTURE_DIR/dynamic_interp.dart" <<'DART'
final re = RegExp('\\b(${words.join('|')})\\b');
DART
  cat > "$FIXTURE_DIR/dynamic_concat.dart" <<'DART'
final re = RegExp(r'\b(' + words.join('|') + r')\b');
DART
  cat > "$FIXTURE_DIR/dynamic_bare_marker.dart" <<'DART'
// swedish-boundary-ok:
final re = RegExp('\\b(${words.join('|')})\\b');
DART
  cat > "$FIXTURE_DIR/dynamic_clean.dart" <<'DART'
// swedish-boundary-ok: every word is ASCII, pinned by a test
final marked = RegExp('\\b(${words.join('|')})\\b');
final bounded = RegExp('${SwedishWordBoundary.before}$word');
final escaped = RegExp(r'(\$conversationId\b');
final plain = RegExp(r'\bcat\s+dog\b');
// A comment about '\\b' + ${x} is not code.
DART
  mkdir "$FIXTURE_DIR/test"
  cp "$FIXTURE_DIR/dynamic_interp.dart" "$FIXTURE_DIR/test/in_test.dart"

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
  bash "$GUARD" "$FIXTURE_DIR/dynamic_interp.dart" >/dev/null 2>&1
  DYN_INTERP_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/dynamic_concat.dart" >/dev/null 2>&1
  DYN_CONCAT_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/dynamic_bare_marker.dart" >/dev/null 2>&1
  DYN_BARE_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/dynamic_clean.dart" >/dev/null 2>&1
  DYN_CLEAN_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/test/in_test.dart" >/dev/null 2>&1
  DYN_TESTDIR_RC=$?
  SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC=2 bash "$GUARD" "$FIXTURE_DIR/clean.dart" \
    >/dev/null 2>&1
  OUTAGE_RC=$?
  # The seam must not be usable to silence the guard.
  SWEDISH_BOUNDARY_PROBE_FORCE_GREP_RC=1 bash "$GUARD" \
    "$FIXTURE_DIR/violating.dart" >/dev/null 2>&1
  SEAM_ABUSE_RC=$?

  for rc in "$VIOLATING_RC" "$CLEAN_RC" "$ABSENT_RC" "$OUTAGE_RC" \
            "$SEAM_ABUSE_RC" "$DYN_INTERP_RC" "$DYN_CONCAT_RC" "$DYN_BARE_RC" \
            "$DYN_CLEAN_RC" "$DYN_TESTDIR_RC"; do
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
    if [ "$DYN_INTERP_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: an interpolated \\b was NOT detected." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$DYN_CONCAT_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a \\b joined with + was NOT detected." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$DYN_BARE_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a marker with no reason silenced a detection." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$DYN_CLEAN_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: a marked, SwedishWordBoundary, escaped-\$ or ASCII line was flagged." >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "$DYN_TESTDIR_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: a file under test/ was scanned for assembled patterns." >&2
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

# awk's contract is 0 = ran, >0 = failed; a scan that could not run is not clean.
DYNAMIC_HITS=$(awk "$DYNAMIC_AWK" "${TARGETS[@]}")
AWK_RC=$?
if [ "$AWK_RC" -ne 0 ]; then
  echo "❌ check_swedish_boundary.sh could NOT run (awk exit $AWK_RC)." >&2
  echo "   Treated as a failure, not as a clean scan." >&2
  exit 1
fi

FAILED=0
if [ "$GREP_RC" -eq 0 ]; then
  echo "$HITS"
  echo ""
  echo "Dart \\b is ASCII-only and never matches next to å/ä/ö — replace with"
  echo "explicit lookarounds (?<![a-zåäö0-9]) / (?![a-zåäö0-9]). See lessons-digest."
  FAILED=1
fi
if [ -n "$DYNAMIC_HITS" ]; then
  echo "$DYNAMIC_HITS"
  echo ""
  echo "A \\b in a pattern assembled at runtime sits next to whatever the value holds,"
  echo "and å/ä/ö there never matches. Bound it with SwedishWordBoundary, or — if every"
  echo "value is ASCII — add '// swedish-boundary-ok: <why>' on or above the line."
  FAILED=1
fi
exit "$FAILED"
