#!/usr/bin/env bash
# BUT-1746: ban `isNotEqualTo: null` / `isEqualTo: null` in Firestore queries.
#
# The cloud_firestore query builder adds a condition only when the argument is
# non-null (`if (isNotEqualTo != null) addCondition(...)`, query.dart:659), so a
# LITERAL null adds no condition at all: the `.where(...)` call compiles, reads
# as a filter, and silently degrades the query into an unfiltered sweep of the
# whole collection. Four such sites shipped (BUT-1719/BUT-1732) across the
# shared-shopping-list reads, the group-weekly-menu participation probe and the
# GDPR export gateway. On collections whose read rule is scoped to owner/member
# the server then refuses the whole query, so the symptom is not an over-share
# but "my data mysteriously will not load" — with a whole Art. 15 export section
# collapsing into an error.
#
# `isNull: false` / `isNull: true` are the supported spellings of the same
# intent and DO build the condition (query.dart:676-682). Use them.
#
# Called from lefthook with the staged .dart files as arguments; with no
# arguments it scans every directory that ships Dart (the CI / manual shape).
#
# `--self-test` proves the guard's own DETECTION on a throwaway pair of files
# and exits. BUT-1746 shipped this guard wired to lefthook only, so a violation
# arriving by any non-hook path never failed a build, and nothing anywhere
# proved the pattern still matches — a guard whose regex silently stops matching
# is indistinguishable from a clean repo.
#
# This guard reads SOURCE TEXT. BUT-1746's AC1 also asked for tests that read
# the EMITTED query condition, which do not exist — the existing unit tests
# assert results and redden only because `fake_cloud_firestore` happens to throw
# on `isNotEqualTo: null`. That remaining half is BUT-1765; do not read this
# guard's presence as satisfying it. CI now runs `--self-test` immediately
# before the real scan, so the two fail together or not at all.
#
# Comment lines are skipped on purpose: several of those sites carry a
# WHY-comment naming the forbidden spelling, and a guard that flags its own
# rationale would be uninstallable. Only a construction site is an error.

set -uo pipefail

SELF_TEST=0
if [ "${1:-}" = "--self-test" ]; then
  SELF_TEST=1
  shift
fi

if [ $# -gt 0 ]; then
  TARGETS=("$@")
else
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$ROOT_DIR"
  # `tools` and `integration_test` also ship .dart and were outside the original
  # whole-tree scope; a violation there is the same unfiltered read.
  TARGETS=(lib test tools integration_test)
fi

# `isEqualTo: null` is banned for the same reason — it is a no-op filter, and
# `isNull: true` is what the SDK actually turns into a null comparison.
PATTERN='(isNotEqualTo|isEqualTo)[[:space:]]*:[[:space:]]*null'

# `-H` is load-bearing, not decoration: with a SINGLE file argument (the common
# lefthook case) grep omits the filename and prints `line:content`, so the
# comment filter below — which anchors past a `path:line:` prefix — would match
# nothing and every WHY-comment naming the spelling would be reported as a
# violation. Forcing the prefix keeps one output shape for both modes.
#
# grep prints `path:line:content`; a comment line has `//`, `///` or a doc-block
# `*` as its first non-space content AFTER that prefix.
# The guard's own detection test. Three cases, because each is a way this guard
# has already been observed to fail or could silently stop working:
#   1. a construction site is an ERROR (the pattern still matches at all)
#   2. a WHY-comment naming the spelling is NOT an error (the comment filter
#      still works — without it the four fixed sites would flag themselves and
#      the guard would be uninstallable)
#   3. `isNull: false`, the supported spelling, is NOT an error
if [ "$SELF_TEST" -eq 1 ]; then
  FIXTURE_DIR=$(mktemp -d)
  trap 'rm -rf "$FIXTURE_DIR"' EXIT

  printf 'final q = col.where("f", isNotEqualTo: null);\n' \
    > "$FIXTURE_DIR/violating.dart"
  printf '// Never write isNotEqualTo: null here — it builds no condition.\nfinal q = col.where("f", isNull: false);\n' \
    > "$FIXTURE_DIR/clean.dart"

  FAILURES=0

  if "${BASH_SOURCE[0]}" "$FIXTURE_DIR/violating.dart" >/dev/null 2>&1; then
    echo "SELF-TEST FAIL: a literal-null filter was NOT detected." >&2
    FAILURES=$((FAILURES + 1))
  fi

  if ! "${BASH_SOURCE[0]}" "$FIXTURE_DIR/clean.dart" >/dev/null 2>&1; then
    echo "SELF-TEST FAIL: a WHY-comment or isNull: false was flagged." >&2
    FAILURES=$((FAILURES + 1))
  fi

  if [ "$FAILURES" -ne 0 ]; then
    echo "check_null_filter.sh no longer detects what it claims to (BUT-1746)." >&2
    exit 1
  fi

  echo "check_null_filter.sh self-test: detection and comment-filter both OK."
  exit 0
fi

HITS=$(grep -RInH -E "$PATTERN" --include='*.dart' "${TARGETS[@]}" 2>/dev/null \
  | grep -vE '^[^:]*:[0-9]+:[[:space:]]*(//|\*)' || true)

if [ -n "$HITS" ]; then
  echo "$HITS"
  echo ""
  echo "Firestore filter builds NO condition from a literal null (BUT-1746):"
  echo "  .where(f, isNotEqualTo: null)  ->  .where(f, isNull: false)"
  echo "  .where(f, isEqualTo: null)     ->  .where(f, isNull: true)"
  echo "Left as-is the query becomes an UNFILTERED read of the whole collection."
  exit 1
fi

exit 0
