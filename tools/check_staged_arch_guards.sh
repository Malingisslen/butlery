#!/usr/bin/env bash
# BUT-1217: fast pre-commit guard for the BUT-581 raw `?? ''` ban.
#
# `dart analyze` (the lefthook `analyze` step) does NOT enforce this — it lives
# only in CI's `test/architecture/architecture_test.dart`, so an analyze-clean
# commit can still turn the Architecture & Code Quality Validation job RED on
# main (3× incidents: BUT-1049, BUT-1203, BUT-901). This catches it at commit
# time instead.
#
# Diff-scoped: it inspects only the ADDED lines of the staged diff under lib/,
# so it can't false-positive on the ~40 pre-existing allow-listed `?? ''` — it
# fires solely on NEW violations. Grep-only, no `flutter test` → sub-second.
#
# Fix: use `.orEmpty()` (lib/core/extensions/default_value_extensions.dart).
# Genuinely-dynamic receivers / chained `??` that must stay raw go in the
# architecture_test.dart allowList with justification (rare).

set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Added lines (leading '+', excluding the '+++ b/...' file header) in staged
# files under lib/. Track the current file via the '+++' headers for a useful
# message.
violations="$(git diff --cached -U0 --no-color -- lib/ | awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+\+\+/     { next }
  /^\+/ {
    line = $0
    sub(/\/\/.*$/, "", line)          # strip line comments
    if (line ~ /\?\?[[:space:]]+'"'"''"'"'/) {
      sub(/^\+/, "", $0)
      printf "  %s:  %s\n", file, $0
    }
  }
')"

if [ -n "$violations" ]; then
  echo "❌ BUT-581 (pre-commit): raw \`?? ''\` added under lib/ — use .orEmpty()."
  echo "   This is enforced only by CI's architecture_test.dart otherwise, which"
  echo "   means a red-main fix-forward. See lib/core/extensions/default_value_extensions.dart."
  echo ""
  echo "$violations"
  exit 1
fi

exit 0
