#!/usr/bin/env bash
# Nightly mutation probe: plants one small fault at a time in recently changed
# code in the areas where an untested fault costs most, runs that file's unit
# test, and reports every fault the test did NOT catch.
#
# Coverage says a line ran; this says whether a test would notice the line
# being wrong. A surviving mutant is a test that looks like protection and is
# not. Report-only: it never fails a build, it names files for a person or a
# session to strengthen. It runs only each file's mirror unit test, never the
# suite: three mutants of rate_limiter.dart took 30 s locally on 2026-10-10,
# where a suite run per mutant pays the ~12 min compile test.yml describes.
#
# Usage:
#   mutation_probe.sh [--since <git-date>] [--max <n>] [--report <file>] [files...]
#   mutation_probe.sh --self-test
# With no files, takes lib/ files under SENSITIVE_RE changed since --since
# (default "1 day ago") on the current branch.

set -uo pipefail

SENSITIVE_RE='^lib/(services/auth|repositories/|core/rate_limiting/|services/tagging/|services/(gdpr|account_deletion|data_export))'
SINCE="1 day ago"
MAX_TOTAL=30
MAX_PER_FILE=5
REPORT=""
TEST_TIMEOUT=600

# Each entry: a literal "from@to" pair, applied to one line at a time.
MUTATIONS=(
  ' == @ != '
  ' != @ == '
  ' && @ || '
  ' || @ && '
  ' >= @ > '
  ' <= @ < '
  ' > @ >= '
  ' < @ <= '
  'return true;@return false;'
  'return false;@return true;'
)

# Prints "<line>\t<index>" candidates for a file: code lines (not comments,
# imports or asserts) where a mutation applies.
candidates() {
  local file="$1" i from
  for i in "${!MUTATIONS[@]}"; do
    from="${MUTATIONS[$i]%%@*}"
    grep -nF -- "$from" "$file" \
      | grep -vE '^[0-9]+:[[:space:]]*(//|\*|/\*|import |export |part |assert\()' \
      | cut -d: -f1 \
      | sed "s/\$/\t$i/"
  done | sort -n -u -k1,1
}

# Picks up to MAX_PER_FILE candidates spread across the file.
pick() {
  local all n step
  all=$(cat)
  n=$(printf '%s\n' "$all" | grep -c . || true)
  [ "$n" -eq 0 ] && return
  step=$(( (n + MAX_PER_FILE - 1) / MAX_PER_FILE ))
  printf '%s\n' "$all" | awk -v s="$step" 'NF && (NR-1) % s == 0'
}

apply_mutation() { # <file> <line> <index>
  local file="$1" line="$2" from to
  from="${MUTATIONS[$3]%%@*}"
  to="${MUTATIONS[$3]#*@}"
  local pat rep
  pat=$(printf '%s' "$from" | sed 's/[][\.*^$/]/\\&/g')
  rep=$(printf '%s' "$to" | sed 's/[\/&]/\\&/g')
  sed -i "${line}s/${pat}/${rep}/" "$file"
}

mirror_test() { # lib/a/b.dart -> test/unit/a/b_test.dart
  local rel="${1#lib/}"
  local t="test/unit/${rel%.dart}_test.dart"
  [ -f "$t" ] && echo "$t"
}

self_test() {
  local dir f fails=0
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' RETURN
  f="$dir/x.dart"
  cat > "$f" <<'EOF'
import 'a.dart';
// if (a == b) comment
bool ok(int a, int b) {
  if (a == b && b > 0) return true;
  return false;
}
EOF
  local got
  got=$(candidates "$f" | cut -f1 | sort -u | tr '\n' ' ')
  [ "$got" = "4 5 " ] || { echo "FAIL candidates: got '$got', want '4 5 '"; fails=1; }

  cp "$f" "$f.orig"
  apply_mutation "$f" 4 0
  grep -q 'if (a != b && b > 0)' "$f" || { echo "FAIL == mutation: $(sed -n 4p "$f")"; fails=1; }
  cp "$f.orig" "$f"
  apply_mutation "$f" 4 2
  grep -q 'if (a == b || b > 0)' "$f" || { echo "FAIL && mutation: $(sed -n 4p "$f")"; fails=1; }
  cp "$f.orig" "$f"
  apply_mutation "$f" 5 9
  grep -q 'return true;' <(sed -n 5p "$f") || { echo "FAIL return mutation: $(sed -n 5p "$f")"; fails=1; }
  cmp -s <(sed '5d' "$f") <(sed '5d' "$f.orig") || { echo "FAIL mutation touched other lines"; fails=1; }

  [ $fails -eq 0 ] && echo "mutation_probe self-test: all cases pass"
  return $fails
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --max) MAX_TOTAL="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [ ${#FILES[@]} -eq 0 ]; then
  mapfile -t FILES < <(git log --since="$SINCE" --name-only --format= -- lib \
    | sort -u | grep -E "$SENSITIVE_RE" | grep -E '\.dart$' \
    | grep -vE '\.(g|freezed)\.dart$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
fi

out() { if [ -n "$REPORT" ]; then echo "$*" >> "$REPORT"; else echo "$*"; fi; }
[ -n "$REPORT" ] && : > "$REPORT"

out "## Mutation probe"
out ""
if [ ${#FILES[@]} -eq 0 ]; then
  out "No changed files in the probed areas since $SINCE."
  exit 0
fi

# A probe writes to lib/; an interrupted run must not leave a mutant behind.
PROBING=""
restore() { [ -n "$PROBING" ] && [ -f "$PROBING.probe-orig" ] && mv "$PROBING.probe-orig" "$PROBING"; }
trap 'restore; exit 130' INT TERM HUP
trap restore EXIT

total=0 killed=0 survived=0 untested=()
rows=()
for f in "${FILES[@]}"; do
  [ "$total" -ge "$MAX_TOTAL" ] && break
  t=$(mirror_test "$f")
  if [ -z "$t" ]; then untested+=("$f"); continue; fi
  while IFS=$'\t' read -r line idx; do
    [ -z "$line" ] && continue
    [ "$total" -ge "$MAX_TOTAL" ] && break
    cp "$f" "$f.probe-orig"
    PROBING="$f"
    apply_mutation "$f" "$line" "$idx"
    if cmp -s "$f" "$f.probe-orig"; then mv "$f.probe-orig" "$f"; continue; fi
    total=$((total + 1))
    desc="${MUTATIONS[$idx]//@/→}"
    # After rapid file swaps flutter test can serve a stale kernel and report
    # a live mutant green (lessons-digest-testing, BUT-1971); a red result
    # cannot be stale, so only the green side needs the clean build.
    rm -rf .dart_tool/flutter_build
    if timeout "$TEST_TIMEOUT" flutter test "$t" >/dev/null 2>&1; then
      survived=$((survived + 1))
      rows+=("| \`$f:$line\` | \`$desc\` | \`$t\` |")
    else
      killed=$((killed + 1))
    fi
    mv "$f.probe-orig" "$f"
    PROBING=""
  done < <(candidates "$f" | pick)
done

out "$total faults planted, $killed caught, $survived not caught."
out ""
if [ ${#rows[@]} -gt 0 ]; then
  out "Faults the tests did not catch (strengthen the named test so it fails on this change):"
  out ""
  out "| Where | Change | Test that stayed green |"
  out "| --- | --- | --- |"
  for r in "${rows[@]}"; do out "$r"; done
  out ""
fi
if [ ${#untested[@]} -gt 0 ]; then
  out "Changed files with no mirror unit test (not probed):"
  for u in "${untested[@]}"; do out "- \`$u\`"; done
fi
exit 0
