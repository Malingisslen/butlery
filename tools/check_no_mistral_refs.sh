#!/usr/bin/env bash
# BUT-809: prevent re-introduction of `mistral` (case-insensitive) in active
# code. The app migrated from Mistral to Vertex AI / Gemini in 2025; lingering
# references mislead future readers and (per legal review) imply data flows
# to a processor that no longer receives it.
#
# Allow-listed paths (historical / external):
#   - PROMPT_CHANGELOG.md           — historical commit-by-commit log
#   - docs/analysis/**              — frozen forensic-audit corpus
#   - docs/analysis-historical/**   — same, future tense
#   - tools/check_no_mistral_refs.sh (this guard)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

# Search active code only.
SEARCH_PATHS=(lib functions/src test .claude/hooks)
EXCLUDES=(
  "--exclude-dir=node_modules"
  "--exclude-dir=.dart_tool"
  "--exclude-dir=.git"
  "--exclude=PROMPT_CHANGELOG.md"
  "--exclude=*.lock"
)

if grep -RInE "mistral" "${EXCLUDES[@]}" "${SEARCH_PATHS[@]}" \
     > /tmp/mistral_hits.txt 2>/dev/null
then
  if [[ -s /tmp/mistral_hits.txt ]]; then
    echo "::error::Stale 'mistral' references found in active code (BUT-809)" >&2
    echo "Replace with 'Vertex' / 'Gemini' / 'Vertex AI'. Historical CHANGELOG entries are allow-listed." >&2
    echo >&2
    cat /tmp/mistral_hits.txt >&2
    exit 1
  fi
fi

echo "OK: no 'mistral' references in active code"
