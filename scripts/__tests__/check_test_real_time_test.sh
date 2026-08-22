#!/usr/bin/env bash
# Fixture suite for scripts/check_test_real_time.sh (BUT-1894).
#
# Why this file exists. The guard had no test of any kind, and a rewrite of it
# was proposed claiming byte-identical behaviour while silently failing OPEN on
# two inputs. A gate that starts approving what it used to stop is worse than a
# slow one, so the guard is now only changeable against these fixtures.
#
# Each case builds a throwaway repo root, copies the REAL script into it, and
# asserts the exit code. Nothing here reads the script's source, so a rewrite
# that changes how it works but not what it decides still passes.
#
# Run: bash scripts/__tests__/check_test_real_time_test.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO_ROOT/scripts/check_test_real_time.sh"

pass=0
fail=0

# Build an empty throwaway root carrying a copy of the guard, and echo its path.
new_root() {
  local root
  root="$(mktemp -d)"
  mkdir -p "$root/scripts" "$root/test/unit" "$root/test/widget" \
           "$root/test/views" "$root/test/integration" "$root/test/e2e"
  cp "$GUARD" "$root/scripts/check_test_real_time.sh"
  printf '%s\n' "$root"
}

# assert_exit <expected> <label> <root> [args...]
assert_exit() {
  local expected="$1" label="$2" root="$3"
  shift 3
  local out rc
  out="$(cd "$root" && bash scripts/check_test_real_time.sh "$@" 2>&1)"
  rc=$?
  if [[ "$rc" -eq "$expected" ]]; then
    echo "  PASS  $label (exit $rc)"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label — expected exit $expected, got $rc"
    printf '%s\n' "$out" | sed 's/^/        | /'
    fail=$((fail + 1))
  fi
  rm -rf "$root"
}

echo "check_test_real_time.sh fixtures"

# (a) A *_test.dart committed as a binary blob. grep reports it as
#     "Binary file X matches" with no line number. The guard must still refuse:
#     a source file can land as a binary blob (that has happened in this repo),
#     and an unparseable grep line dropped silently is the fail-open shape.
root="$(new_root)"
printf 'DateTime.now()\n\000\001\002binary\377\376\n' > "$root/test/unit/binary_test.dart"
assert_exit 1 "binary *_test.dart is refused" "$root"

# (b1) A baseline that EXISTS but holds only comments and blank lines is an
#      EMPTY allow-list, not a universal one. The violation must still be
#      caught. This is the second case a previous rewrite let through.
root="$(new_root)"
printf '# only a comment\n\n   \n' > "$root/scripts/test_real_time_baseline.txt"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/plain_test.dart"
assert_exit 1 "comment-only baseline still enforces" "$root"

# (b2) The same baseline with nothing to catch must EXIT CLEAN. The old script
#      died here with exit 1 and no output — `grep -v` returning 1 under
#      `set -e` — so it also failed commits that had done nothing wrong.
root="$(new_root)"
printf '# only a comment\n\n' > "$root/scripts/test_real_time_baseline.txt"
printf 'void main() {}\n' > "$root/test/unit/clean_test.dart"
assert_exit 0 "comment-only baseline passes a clean tree" "$root"

# (c) Suppression, on the violating line and on the line above it.
root="$(new_root)"
printf 'void main() {\n  final a = DateTime.now(); // ignore: butlery_fake_time seed\n}\n' \
  > "$root/test/unit/same_line_test.dart"
printf 'void main() {\n  // ignore: butlery_fake_time seed\n  final b = DateTime.now();\n}\n' \
  > "$root/test/unit/line_above_test.dart"
assert_exit 0 "suppression comment is honoured on both lines" "$root"

# (d) An un-baselined DateTime.now() is refused; a baselined one is not.
root="$(new_root)"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/new_test.dart"
assert_exit 1 "un-baselined DateTime.now() is refused" "$root"

root="$(new_root)"
printf 'test/unit/seeded_test.dart\n' > "$root/scripts/test_real_time_baseline.txt"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/seeded_test.dart"
assert_exit 0 "baselined DateTime.now() is allowed" "$root"

# (e) A long Future.delayed is strict — refused in EVERY delayed scope, and a
#     baseline entry does not rescue it. The baseline governs DateTime.now()
#     only, and a rewrite that wires one mode's allow-list into the other
#     would pass every other case here.
for dir in unit widget views integration e2e; do
  root="$(new_root)"
  printf "test/$dir/slow_test.dart\n" > "$root/scripts/test_real_time_baseline.txt"
  printf 'void main() async {\n  await Future.delayed(const Duration(seconds: 2));\n}\n' \
    > "$root/test/$dir/slow_test.dart"
  assert_exit 1 "long Future.delayed refused in test/$dir despite baseline" "$root"
done

# A short delay is not the target of the rule and must not be caught.
root="$(new_root)"
printf 'void main() async {\n  await Future.delayed(const Duration(milliseconds: 10));\n}\n' \
  > "$root/test/unit/fast_test.dart"
assert_exit 0 "millisecond Future.delayed is allowed" "$root"

# Argument scoping (BUT-1894): a named file is checked, and a violation in a
# file NOT named is left to CI's full-tree run. Both directions, because
# scoping that silently checks nothing is the same fail-open in a new costume.
root="$(new_root)"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/named_test.dart"
assert_exit 1 "a named violating file is checked" "$root" test/unit/named_test.dart

root="$(new_root)"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/unnamed_test.dart"
printf 'void main() {}\n' > "$root/test/unit/named_test.dart"
assert_exit 0 "an unnamed violating file is out of scope" "$root" test/unit/named_test.dart

# A path outside every scope must not drag the whole tree back in.
root="$(new_root)"
printf 'void main() { final x = DateTime.now(); }\n' > "$root/test/unit/elsewhere_test.dart"
mkdir -p "$root/lib"
printf 'void main() {}\n' > "$root/lib/thing.dart"
assert_exit 0 "an out-of-scope argument checks nothing" "$root" lib/thing.dart

echo
echo "check_test_real_time fixtures: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
