#!/usr/bin/env bash
# BUT-768: fail CI if Python artifacts (site-packages, __pycache__, *.pyc)
# land under `lib/`. Pillow / pip side-loads here have polluted every audit
# script's grep-based percentages in the past — this guard catches a
# re-introduction at PR time instead of after the fact.
#
# Run from repo root:
#
#   bash tools/check_no_python_artifacts.sh
#
# Exits non-zero with a `::error` annotation when any artifact is found
# UNDER VERSION CONTROL. Untracked artifacts on a developer machine
# (gitignored locally) are not flagged — only what would land in a commit.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# Patterns we never want under lib/. Match git-tracked files only — we don't
# care about untracked dev-machine dirt; we care about commits.
patterns=(
  'lib/site-packages/'
  'lib/.*/__pycache__/'
  'lib/.*\.pyc$'
  'lib/.*\.py$'
)

found=0
for pat in "${patterns[@]}"; do
  while IFS= read -r match; do
    [[ -z "${match}" ]] && continue
    echo "::error file=${match}::Python artifact under lib/ — see BUT-768. Move it to scripts/ or tools/, or add to .gitignore + scrub from history."
    found=1
  done < <(git ls-files | grep -E "${pat}" || true)
done

if [[ "${found}" -ne 0 ]]; then
  exit 1
fi

echo "No Python artifacts under lib/."
