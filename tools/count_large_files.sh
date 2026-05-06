#!/usr/bin/env bash
# BUT-807: report the count of `.dart` files in `lib/` exceeding 500 lines.
#
# Usage:
#   bash tools/count_large_files.sh             # just the count
#   bash tools/count_large_files.sh --list      # count + sorted list (LOC desc)
#
# When CLAUDE.md / code-style.md / ACCEPTED_LARGE_FILES.md cite a count, run
# this and update the doc if the number drifts. The list view is also useful
# for spotting newly-large files that haven't been added to ACCEPTED_LARGE_FILES.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

threshold=500
mode="${1:-count}"

# Walk lib/ once. Skip the (gitignored) site-packages dir so a re-introduction
# of the Pillow side-load doesn't suddenly inflate the count again.
files=$(
  find lib -name '*.dart' -not -path '*/site-packages/*' \
    | xargs wc -l 2>/dev/null \
    | awk -v t="${threshold}" '$1 > t && $2 != "total" {print $1"\t"$2}'
)

count=$(printf '%s\n' "${files}" | grep -c $'\t' || true)

case "${mode}" in
  --list)
    printf '%s\n' "${files}" | sort -rn
    echo "---"
    echo "${count} files >${threshold} lines under lib/."
    ;;
  count|*)
    echo "${count}"
    ;;
esac
