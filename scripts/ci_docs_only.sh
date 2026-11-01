#!/usr/bin/env bash
# Reads changed file paths on stdin, prints "true" when every one is a
# documentation path and "false" otherwise. Empty input prints "false" so a
# failed file listing runs the full suite rather than skipping it.
#
# A required check cannot rely on `paths-ignore`: a workflow that never starts
# never reports, and the pull request waits on it forever.
set -uo pipefail

# Markdown under assets/, test/, lib/ or functions/ is read by tests, the app or
# the prompt-changelog guard, and docs/onboarding/ plus docs/feature_inventory.csv
# are what the workflow-map linter checks. Those are code for CI purposes.
docs_re='(\.md$|^docs/|^tasks/|^\.claude/|^memory/)'
code_re='(^assets/|^test/|^lib/|^functions/|^docs/onboarding/|^docs/analysis|^docs/feature_inventory\.csv$)'
seen=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  seen=1
  if printf '%s\n' "$path" | grep -qE "$code_re" \
    || ! printf '%s\n' "$path" | grep -qE "$docs_re"; then
    echo false
    exit 0
  fi
done

if [ "$seen" -eq 1 ]; then echo true; else echo false; fi
