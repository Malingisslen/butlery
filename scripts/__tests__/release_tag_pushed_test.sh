#!/usr/bin/env bash
# Run: bash scripts/__tests__/release_tag_pushed_test.sh
# --follow-tags only carries annotated tags, so release.yml must create the
# tag with -a or the release tag never reaches GitHub.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WF="$ROOT/.github/workflows/release.yml"
fail=0

if grep -nE '^[[:space:]]*git tag[[:space:]]+"' "$WF"; then
  echo "FAIL: release.yml creates a lightweight tag"
  fail=1
fi
grep -qE 'git tag -a ' "$WF" || { echo "FAIL: release.yml has no annotated tag"; fail=1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q --bare "$work/remote.git"
git init -q "$work/clone" && cd "$work/clone" || exit 1
git config user.email t@example.com && git config user.name t
git commit -q --allow-empty -m init
git remote add origin "$work/remote.git"
git tag light
git tag -a annotated -m annotated
git push -q origin HEAD --follow-tags
remote=$(git ls-remote --tags "$work/remote.git" | grep -v '\^{}')
echo "$remote" | grep -q 'refs/tags/annotated' || { echo "FAIL: annotated tag not pushed"; fail=1; }
echo "$remote" | grep -q 'refs/tags/light' && { echo "FAIL: premise changed, lightweight tag now pushed"; fail=1; }

[ "$fail" -eq 0 ] && echo "ok"
exit "$fail"
