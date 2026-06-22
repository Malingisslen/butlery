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

BASELINE_FILE="scripts/test_real_time_baseline.txt"

# Normalize baseline paths to forward-slash, no leading ./, one per line.
BASELINE_SET=""
if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE_SET=$(grep -v '^\s*$\|^\s*#' "$BASELINE_FILE" | sed 's|\\|/|g' | sed 's|^\./||' | sort -u)
fi

is_baselined() {
  local file="$1"
  # Normalize incoming path the same way.
  local norm
  norm=$(echo "$file" | sed 's|\\|/|g' | sed 's|^\./||')
  grep -qxF "$norm" <<< "$BASELINE_SET"
}

is_suppressed() {
  local file="$1"
  local line="$2"
  awk -v target="$line" '
    NR == target - 1 || NR == target { print }
  ' "$file" | grep -qE '// *ignore: *butlery_fake_time'
}

check_pattern() {
  local label="$1"
  local pattern="$2"
  local hint="$3"
  local mode="$4"  # "baseline" or "strict"
  shift 4
  local dirs=("$@")

  echo "Checking ${label}..."
  local violations=0
  while IFS=: read -r file line match; do
    [[ -z "$file" ]] && continue
    if is_suppressed "$file" "$line"; then
      continue
    fi
    if [[ "$mode" == "baseline" ]] && is_baselined "$file"; then
      continue
    fi
    echo "::error file=$file,line=$line::${hint}"
    fail=1
    violations=$((violations + 1))
  done < <(
    for dir in "${dirs[@]}"; do
      [[ -d "$dir" ]] || continue
      grep -rEn --include='*_test.dart' "$pattern" "$dir" 2>/dev/null || true
    done
  )
  if [[ "$violations" -eq 0 ]]; then
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
