#!/usr/bin/env bash
# Guards against flaky tests by refusing to land:
#   - `DateTime.now()` in NEW unit-test files (not in the baseline)
#   - `Future.delayed(Duration(seconds|minutes|hours: N))` in ANY unit/widget/
#     view/integration test, with no grandfathering
#
# Two enforcement tiers:
#
# 1. DateTime.now() — baseline mode. `scripts/test_real_time_baseline.txt`
#    lists files that currently use DateTime.now() (mostly fixture-seed
#    code, not flake-producing assertions). The guard fails if a
#    non-baselined file introduces DateTime.now(). If a new test file
#    legitimately needs it, add the path to the baseline in the same PR
#    — code review catches unjustified additions. This is the ticket-
#    endorsed "allow-list" approach from BUT-393.
#
# 2. long Future.delayed(...) — strict mode. The Phase 5 rescue already
#    got this count to zero; we hold the line. Any violation fails the
#    build.
#
# Suppress per-instance with `// ignore: butlery_fake_time` on the same
# line or the line immediately above the violation. Each suppression
# needs a one-line comment justifying it.
#
# ARGUMENTS (BUT-1894). With no arguments the whole scope is scanned — that is
# what CI does. With arguments, only those paths are scanned; lefthook passes
# the staged files, so a commit pays for the files it actually changes. The
# full-tree sweep still runs in CI, so scoping here narrows WHEN a violation is
# caught, never WHETHER.
#
# COST (BUT-1894). Grep was never the expensive part: the two searches finish
# in well under a second, while `DateTime.now()` alone matches over a thousand
# lines under test/unit. The old shape spawned an `awk` for the suppression
# check and an `echo|sed|sed|grep` pipeline for the baseline check ON EVERY
# MATCH — roughly four processes per hit, and process creation is the costly
# primitive on Windows. Measured at 646-859 s per commit across three commits
# on 2026-08-17. Each check is now ONE awk pass that reads the baseline once and
# each violating file once. Keep it that way: any per-match subprocess
# reintroduces the whole cost.
#
# Run locally: bash scripts/check_test_real_time.sh
# CI wires this in .github/workflows/test.yml before `flutter analyze`.

set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

DATETIME_SCOPE=("test/unit")
# BUT-813 INFRA7: e2e journey tests are the most timing-sensitive of all (full
# navigation flows) — a long Future.delayed there is the worst flake source, so
# they get the strict no-real-delay guard too. (Left out of DATETIME_SCOPE: e2e
# fixtures legitimately seed DateTime; only the long-delay rule applies here.)
DELAYED_SCOPE=("test/unit" "test/widget" "test/views" "test/integration" "test/e2e")

BASELINE_FILE="${BASELINE_FILE:-scripts/test_real_time_baseline.txt}"

# Caller-supplied paths, normalised to forward slashes with any leading ./
# stripped, so they compare against grep's output and the baseline in one form.
TARGETS=()
for arg in "$@"; do
  TARGETS+=("$(printf '%s' "$arg" | sed 's|\\|/|g; s|^\./||')")
done

# Emit the paths to search for one scope. With no caller-supplied targets this
# is the scope directories themselves (grep recurses). With targets it is the
# subset of them that is a *_test.dart file under one of those directories —
# printing nothing when the intersection is empty, which the caller reads as
# "this scope has nothing to check".
scope_paths() {
  local dirs=("$@")
  local dir target
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    for dir in "${dirs[@]}"; do
      [[ -d "$dir" ]] && printf '%s\n' "$dir"
    done
    return
  fi
  for target in "${TARGETS[@]}"; do
    [[ "$target" == *_test.dart ]] || continue
    [[ -f "$target" ]] || continue
    for dir in "${dirs[@]}"; do
      if [[ "$target" == "$dir"/* ]]; then
        printf '%s\n' "$target"
        break
      fi
    done
  done
}

check_pattern() {
  local label="$1"
  local pattern="$2"
  local hint="$3"
  local mode="$4"  # "baseline" or "strict"
  shift 4
  local dirs=("$@")

  echo "Checking ${label}..."

  local paths=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && paths+=("$p")
  done < <(scope_paths "${dirs[@]}")

  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "  OK (nothing in scope)"
    return
  fi

  local baseline_arg=""
  if [[ "$mode" == "baseline" && -f "$BASELINE_FILE" ]]; then
    baseline_arg="$BASELINE_FILE"
  fi

  # grep's exit codes are read explicitly rather than piped straight into awk.
  # Under `pipefail` a pipeline reports grep's 1 — "no matches", the success
  # case — as a failure, which would make the guard refuse every clean commit.
  # Reading the status here also separates that 1 from a real grep error (>1),
  # which must not pass for "nothing to see".
  #
  # stderr is MERGED into the parsed stream, not discarded, and that is what
  # makes the guard portable. grep reports a binary match as prose instead of a
  # `path:line:text` record, and which STREAM it writes that prose to depends on
  # the grep: measured on stdout with the 3.0 this repo's Git Bash ships and on
  # stderr with the 3.11 the CI runner ships (grep's own NEWS dates the move to
  # 3.5). Discarding stderr therefore left the guard blind to a binary
  # *_test.dart everywhere except the dev machine — green locally, fail-open in
  # CI. Nothing below matches the wording or the stream: the rule is that
  # anything grep emits carrying no `:<line>:` is refused.
  local grep_out grep_rc=0
  set +e
  # -H is load-bearing, not decorative: grep OMITS the filename when it is given
  # exactly one FILE, so with a single staged *_test.dart every line arrived as
  # "70:code" instead of "path:70:code". Such a line fails the `:[0-9]+:` parse
  # below and takes the unreadable-file branch — which is why the guard blamed a
  # binary blob. Found 2026-08-26 on a commit that staged one test file.
  grep_out="$(grep -rEnH --include='*_test.dart' "$pattern" "${paths[@]}" 2>&1)"
  grep_rc=$?
  set -e

  if [[ "$grep_rc" -gt 1 ]]; then
    echo "::error::${label}: grep failed (exit ${grep_rc}) — the guard could not read its own scope."
    if [[ -n "$grep_out" ]]; then printf '%s\n' "$grep_out"; fi
    fail=1
    return
  fi

  if [[ -z "$grep_out" ]]; then
    echo "  OK"
    return
  fi

  local rc=0
  printf '%s\n' "$grep_out" |
    awk -v hint="$hint" -v mode="$mode" -v baselinefile="$baseline_arg" '
      function norm(p) { gsub(/\\/, "/", p); sub(/^\.\//, "", p); return p }

      BEGIN {
        # A baseline holding nothing but comments and blank lines yields an
        # EMPTY set, and enforcement continues against it. It must never be
        # read as "everything is baselined": that is the fail-open shape this
        # rewrite exists to avoid. (The old code died here instead — `grep -v`
        # exiting 1 under `set -e` — which stopped the same hole by accident
        # and also killed the run when there was nothing wrong.)
        if (baselinefile != "") {
          while ((getline bl < baselinefile) > 0) {
            sub(/^[ \t]+/, "", bl); sub(/[ \t]+$/, "", bl)
            if (bl == "" || bl ~ /^#/) continue
            baseline[norm(bl)] = 1
          }
          close(baselinefile)
        }
      }

      {
        # grep prints `path:line:text`. For a binary blob it prints prose with
        # no line number instead; both the wording and the stream vary by grep
        # version, so neither is matched on — the missing line number is the
        # test. A *_test.dart that is not text is itself a defect (a source file
        # can land as a git binary blob), so it is reported rather than skipped.
        # Dropping an unparseable line is how a rewrite goes quietly fail-open.
        # The line is quoted whole and carries no `file=`: the path sits inside
        # prose whose shape differs per version, so any field built from it
        # names something that is not a file.
        if (!match($0, /:[0-9]+:/)) {
          printf "::error::Unreadable test file — grep reported no line number, which is what a *_test.dart committed as a binary blob does. grep said: %s\n", $0
          bad = 1
          next
        }
        f = norm(substr($0, 1, RSTART - 1))
        ln = substr($0, RSTART + 1, RLENGTH - 2) + 0
        if (!(f in seen)) { seen[f] = 1; files[++nf] = f }
        vline[f, ++count[f]] = ln
      }

      END {
        for (i = 1; i <= nf; i++) {
          f = files[i]
          if (mode == "baseline" && (f in baseline)) continue

          delete txt
          n = 0
          while ((getline l < f) > 0) txt[++n] = l
          close(f)

          for (c = 1; c <= count[f]; c++) {
            ln = vline[f, c]
            sup = ((ln in txt)     && txt[ln]     ~ /\/\/ *ignore: *butlery_fake_time/) ||
                  ((ln - 1 in txt) && txt[ln - 1] ~ /\/\/ *ignore: *butlery_fake_time/)
            if (sup) continue
            printf "::error file=%s,line=%d::%s\n", f, ln, hint
            bad = 1
          }
        }
        exit bad ? 1 : 0
      }
    ' || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    fail=1
  else
    echo "  OK"
  fi
}

check_pattern \
  "DateTime.now() in test/unit/**/*_test.dart (baselined)" \
  'DateTime\.now\(\)' \
  "DateTime.now() forbidden in new unit tests — use clock.now() with package:clock, pass an explicit DateTime, add // ignore: butlery_fake_time with a reason, or add the file path to scripts/test_real_time_baseline.txt if legitimate fixture-seed usage." \
  "baseline" \
  "${DATETIME_SCOPE[@]}"

check_pattern \
  "long Future.delayed(...) in test/**/*_test.dart (strict)" \
  'Future\.delayed\(\s*(const\s+)?Duration\(\s*(seconds|minutes|hours)\s*:' \
  "Future.delayed with long duration forbidden in tests — use fakeAsync + async.elapse() or tester.pump(), or add // ignore: butlery_fake_time with a reason." \
  "strict" \
  "${DELAYED_SCOPE[@]}"

if [[ "$fail" -eq 0 ]]; then
  echo "OK — no real-time regressions."
fi

exit "$fail"
