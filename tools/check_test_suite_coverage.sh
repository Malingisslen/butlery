#!/usr/bin/env bash
# BUT-1676: every test/<dir>/ holding a *_test.dart must be run by a workflow
# or excused in tools/test_suite_allowlist.txt with a ticket and a reason.
# A new directory otherwise escapes CI silently and for good.
#
# "Run by a workflow" means the directory name appears as `test/<dir>` in a
# workflow file or inside a `suite: [...]` matrix list there.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
allowlist="tools/test_suite_allowlist.txt"

covered="$( {
  grep -ohE 'test/[A-Za-z0-9_]+' .github/workflows/*.yml | sed 's#^test/##'
  grep -ohE 'suite: *\[[^]]*\]' .github/workflows/*.yml \
    | sed -E 's/.*\[(.*)\]/\1/' | tr ',' '\n' | tr -d ' '
} | sort -u )"

status=0
while IFS='|' read -r dir ticket reason; do
  dir="$(echo "$dir" | xargs)"
  [ -z "$dir" ] || [[ "$dir" == \#* ]] && continue
  if ! echo "$ticket" | grep -qE 'BUT-[0-9]+' || [ -z "$(echo "$reason" | xargs)" ]; then
    echo "::error::$allowlist: '$dir' needs both a BUT-ticket and a reason"
    status=1
  fi
done < "$allowlist"

allowed="$(grep -vE '^\s*(#|$)' "$allowlist" | cut -d'|' -f1 | xargs -n1 | sort -u)"

for d in test/*/; do
  name="$(basename "$d")"
  [ -n "$(find "$d" -name '*_test.dart' -print -quit)" ] || continue
  if ! grep -qxF "$name" <<<"$covered" && ! grep -qxF "$name" <<<"$allowed"; then
    echo "::error::test/$name/ has *_test.dart files but no workflow runs it. Add it to CI or to $allowlist with a ticket and a reason."
    status=1
  fi
done

[ "$status" -eq 0 ] && echo "Every test/ directory with tests is in CI or allowlisted."
exit "$status"
