#!/usr/bin/env bash
# Prints `matrix=<json>` for the cross-os job in test.yml.
# Usage: cross_os_matrix.sh <event_name> <cron schedule>
# The full leg (Sunday cron or manual dispatch) adds macOS unit + widget.
set -euo pipefail
event="${1:?event}"
schedule="${2:-}"
full=false
if [ "$event" = "workflow_dispatch" ] || [ "$schedule" = "0 4 * * 0" ]; then full=true; fi

cells() { # os suite total
  local i
  for ((i = 0; i < $3; i++)); do
    printf '{"os":"%s","suite":"%s","shard":%d,"total":%d}\n' "$1" "$2" "$i" "$3"
  done
}

{
  cells windows-latest unit 8
  cells windows-latest widget 8
  cells windows-latest views 1
  cells macos-latest views 1
  cells macos-latest golden 1
  if [ "$full" = true ]; then
    cells macos-latest unit 16
    cells macos-latest widget 16
  fi
} | jq -sc '.' | sed 's/^/matrix=/'
