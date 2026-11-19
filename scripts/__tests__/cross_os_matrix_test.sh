#!/usr/bin/env bash
# Pins the nightly/full split of the cross-os matrix (BUT-2511): macOS unit and
# widget must stay out of the Monday-Saturday leg, or the nightly run times out
# again.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
plan="$here/../cross_os_matrix.sh"

count() { # event schedule jq-filter
  bash "$plan" "$1" "$2" | sed 's/^matrix=//' | jq "[.[] | select($3)] | length"
}
expect() { # label want got
  if [ "$2" != "$3" ]; then echo "FAIL $1: want $2, got $3"; exit 1; fi
}

mac_heavy='.os=="macos-latest" and (.suite=="unit" or .suite=="widget")'
expect "nightly has no macOS unit/widget" 0 "$(count schedule '0 4 * * 1-6' "$mac_heavy")"
expect "nightly keeps macOS views+golden" 2 "$(count schedule '0 4 * * 1-6' '.os=="macos-latest"')"
expect "nightly keeps all Windows cells" 17 "$(count schedule '0 4 * * 1-6' '.os=="windows-latest"')"
expect "Sunday adds 32 macOS unit/widget shards" 32 "$(count schedule '0 4 * * 0' "$mac_heavy")"
expect "manual dispatch is the full leg" 32 "$(count workflow_dispatch '' "$mac_heavy")"
expect "no Windows golden" 0 "$(count schedule '0 4 * * 0' '.os=="windows-latest" and .suite=="golden"')"
echo "cross_os_matrix_test: ok"
