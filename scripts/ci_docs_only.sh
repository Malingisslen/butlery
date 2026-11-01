#!/usr/bin/env bash
# Reads changed file paths on stdin, prints "true" when every one is a
# documentation path and "false" otherwise. Empty input prints "false" so a
# failed file listing runs the full suite rather than skipping it.
#
# The pattern list mirrors the `paths-ignore` the push triggers still carry.
# A required check cannot rely on `paths-ignore`: a workflow that never starts
# never reports, and the pull request waits on it forever.
set -uo pipefail

docs_re='(\.md$|^docs/|^tasks/|^\.claude/|^memory/)'
seen=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  seen=1
  if ! printf '%s\n' "$path" | grep -qE "$docs_re"; then
    echo false
    exit 0
  fi
done

if [ "$seen" -eq 1 ]; then echo true; else echo false; fi
