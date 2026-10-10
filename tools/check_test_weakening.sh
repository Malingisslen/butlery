#!/usr/bin/env bash
# Refuses a change that deletes a test file, lowers the number of assertions in
# one, or adds a skip/only marker that silences tests — unless a commit message
# in the change says why with a `Tests-removed: <reason>` line.
#
# Why this exists: Claude writes both the code and the tests here, and nobody
# reads the diff. The failure mode research on coding agents keeps finding
# (EvilGenie, ImpossibleBench) is an agent turning a red test green by editing
# the test rather than the code. The review agents can catch it; this makes the
# common shapes of it impossible to commit silently. It is deliberately dumb:
# it counts, it does not judge, and the trailer is the escape hatch for a
# legitimate removal (a dead feature, a test moved to a better file).
#
# Usage:
#   check_test_weakening.sh --staged <commit-msg-file>   lefthook commit-msg stage
#   check_test_weakening.sh --range <base> <head>        CI, over a PR's commits
#   check_test_weakening.sh --self-test

set -uo pipefail

TEST_PATH_RE='(_test\.dart|\.test\.(ts|js))$'
DART_ASSERT_RE='(^|[^A-Za-z0-9_])(expect|expectLater|verify|verifyNever|verifyInOrder|verifyZeroInteractions)[[:space:]]*\('
TS_ASSERT_RE='(^|[^A-Za-z0-9_])(expect|assert)[[:space:]]*[(.]'
# `skip: 'reason'` and `skip: someCondition` stay allowed: they name a reason
# or a lane. A bare `true`, an argument-less @Skip(), `solo`/`.only` (which
# silently skips every other test in the file) and Jest's skip forms do not.
MARKER_RE='skip:[[:space:]]*true|@Skip\([[:space:]]*\)|solo:[[:space:]]*true|(^|[^A-Za-z0-9_])(it|test|describe)\.(skip|only)\(|(^|[^A-Za-z0-9_])x(it|test|describe)\('
TRAILER_RE='^Tests-removed:[[:space:]]*.{10,}'

count_asserts() { # <path> ; reads file content on stdin
  if [[ "$1" == *.dart ]]; then
    grep -Ec "$DART_ASSERT_RE" || true
  else
    grep -Ec "$TS_ASSERT_RE" || true
  fi
}

# Prints one line per finding. $1/$2 are git revisions ("" for the index).
scan() {
  local base="$1" head="$2" diff_args
  if [ -z "$head" ]; then
    diff_args=(--cached "$base")
  else
    diff_args=("$base" "$head")
  fi

  local status old new rest
  while IFS=$'\t' read -r status old rest; do
    new="${rest:-$old}"
    case "$status" in
      D)
        [[ "$old" =~ $TEST_PATH_RE ]] && echo "deleted test file: $old"
        ;;
      M|R*)
        [[ "$new" =~ $TEST_PATH_RE ]] || continue
        local before after
        before=$(git show "$base:$old" 2>/dev/null | count_asserts "$old")
        if [ -z "$head" ]; then
          after=$(git show ":$new" 2>/dev/null | count_asserts "$new")
        else
          after=$(git show "$head:$new" 2>/dev/null | count_asserts "$new")
        fi
        if [ "${after:-0}" -lt "${before:-0}" ]; then
          echo "fewer assertions in $new: $before -> $after"
        fi
        ;;
    esac
  done < <(git diff "${diff_args[@]}" --name-status -M)

  local file
  while IFS= read -r file; do
    [[ "$file" =~ $TEST_PATH_RE ]] || continue
    git diff "${diff_args[@]}" -U0 -- "$file" \
      | grep -E '^\+[^+]' \
      | grep -E "$MARKER_RE" \
      | sed "s|^+|silencing marker added in $file: |"
  done < <(git diff "${diff_args[@]}" --name-only --diff-filter=AMR)
}

report() { # <findings> <messages>
  local findings="$1" messages="$2"
  [ -z "$findings" ] && return 0
  if printf '%s\n' "$messages" | grep -Eq "$TRAILER_RE"; then
    echo "Test weakening allowed by a Tests-removed: line:"
    printf '  %s\n' "$findings"
    return 0
  fi
  echo "This change weakens tests:"
  printf '%s\n' "$findings" | sed 's/^/  /'
  echo
  echo "Fix the code, not the test. If the removal is genuinely right (the feature"
  echo "is gone, the test moved), add a line to the commit message:"
  echo "  Tests-removed: <why, at least 10 characters>"
  return 1
}

self_test() {
  local dir fails=0
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' RETURN
  (
    cd "$dir" || exit 1
    git init -q && git config user.email t@t && git config user.name t
    mkdir -p test functions
    printf "void main() {\n  test('a', () {\n    expect(1, 1);\n    expect(2, 2);\n  });\n}\n" > test/a_test.dart
    printf "void main() {\n  test('b', () { expect(1, 1); });\n}\n" > test/b_test.dart
    printf "it('c', () => { expect(1).toBe(1); });\n" > functions/c.test.ts
    git add -A && git commit -qm base
  ) || return 1

  run_case() { # <name> <expect: pass|fail> <msg> <setup-cmd>
    local name="$1" want="$2" msg="$3" setup="$4" out rc
    (cd "$dir" && git reset -q --hard && git clean -qfd && eval "$setup" && git add -A) || { echo "FAIL setup: $name"; return 1; }
    out=$(cd "$dir" && report "$(scan HEAD "")" "$msg"); rc=$?
    if { [ "$want" = pass ] && [ $rc -ne 0 ]; } || { [ "$want" = fail ] && [ $rc -eq 0 ]; }; then
      echo "FAIL $name (wanted $want, got rc=$rc): $out"
      return 1
    fi
    echo "ok   $name"
  }

  run_case "adding an assertion passes" pass "" \
    "sed -i 's/expect(2, 2);/expect(2, 2);\n    expect(3, 3);/' test/a_test.dart" || fails=1
  run_case "removing an assertion fails" fail "" \
    "sed -i '/expect(2, 2);/d' test/a_test.dart" || fails=1
  run_case "trailer allows removal" pass $'chore: x\n\nTests-removed: feature was deleted in this change' \
    "sed -i '/expect(2, 2);/d' test/a_test.dart" || fails=1
  run_case "short trailer does not count" fail $'chore: x\n\nTests-removed: gone' \
    "sed -i '/expect(2, 2);/d' test/a_test.dart" || fails=1
  run_case "deleting a test file fails" fail "" "git rm -q test/b_test.dart" || fails=1
  run_case "renaming a test file passes" pass "" "git mv test/b_test.dart test/bb_test.dart" || fails=1
  run_case "skip: true fails" fail "" \
    "sed -i \"s/test('b', () {/test('b', skip: true, () {/\" test/b_test.dart" || fails=1
  run_case "skip with a reason passes" pass "" \
    "sed -i \"s/test('b', () {/test('b', skip: 'needs emulator', () {/\" test/b_test.dart" || fails=1
  run_case "jest it.only fails" fail "" "sed -i 's/^it(/it.only(/' functions/c.test.ts" || fails=1
  run_case "jest xit fails" fail "" "sed -i 's/^it(/xit(/' functions/c.test.ts" || fails=1
  run_case "jest assertion removed fails" fail "" \
    "printf \"it('c', () => {});\n\" > functions/c.test.ts" || fails=1
  run_case "non-test file is ignored" pass "" "printf 'x' > notes.txt" || fails=1

  [ $fails -eq 0 ] && echo "check_test_weakening self-test: all cases pass"
  return $fails
}

case "${1:-}" in
  --self-test)
    self_test
    ;;
  --staged)
    msg_file="${2:?commit message file required}"
    report "$(scan HEAD "")" "$(cat "$msg_file")"
    ;;
  --range)
    base="${2:?base required}" head="${3:?head required}"
    merge_base=$(git merge-base "$base" "$head") || exit 2
    report "$(scan "$merge_base" "$head")" "$(git log --format=%B "$merge_base..$head")"
    ;;
  *)
    echo "usage: $0 --staged <msg-file> | --range <base> <head> | --self-test" >&2
    exit 2
    ;;
esac
