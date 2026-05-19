#!/usr/bin/env bash
# BUT-776: prevent inline adoption-% drift in prompt + analysis docs.
#
# `tools/measure_adoption.dart` derives BaseService / BaseFirebaseRepository /
# BaseViewModel / ErrorHandlingMixin / SerializationUtils adoption percentages
# and writes them to docs/architecture/adoption-status.md. That file is the
# *only* place an adoption % is allowed to live — anywhere else, the number
# ages without a refresh trigger and contradicts itself within months
# (HIGH-DOC2/3/7 in the wave-4 audit).
#
# This guard fails CI when a `\d{1,3}%` token appears on the same line as an
# adoption-relevant keyword in docs/analysis/prompts/ or
# docs/analysis-historical/prompts/. It deliberately does NOT match generic
# percentages (score weights, crash-rate targets, test-type distributions) —
# those are not adoption metrics.
#
# To suppress a false positive, link to adoption-status.md by relative path
# instead of inlining the number, or rephrase to drop the adoption keyword.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SEARCH_PATHS=()
for p in docs/analysis/prompts docs/analysis-historical/prompts; do
  if [[ -d "$p" ]]; then
    SEARCH_PATHS+=("$p")
  fi
done

if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
  echo "OK: no scoped prompt directories present to scan."
  exit 0
fi

EXCLUDES=(
  "--exclude=adoption-status.md"
  "--exclude=check_no_inline_adoption_pct.sh"
)

# Lines must contain BOTH: (a) an adoption-relevant keyword and (b) a 1-3
# digit %. Order-agnostic — keyword can precede or follow the number on the
# same physical line.
KEYWORDS='(BaseService|BaseFirebaseRepository|BaseViewModel|ErrorHandlingMixin|PermissionValidationMixin|SerializationUtils|\bBFR\b|adoption)'
PERCENT='\b[0-9]{1,3}%'

HITS_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE"' EXIT

# Step 1: gather every line containing a 1-3 digit % under the search paths.
# Step 2: filter to lines that also mention an adoption-relevant keyword.
if grep -RInE "$PERCENT" "${EXCLUDES[@]}" "${SEARCH_PATHS[@]}" 2>/dev/null \
   | grep -E "$KEYWORDS" > "$HITS_FILE"
then
  if [[ -s "$HITS_FILE" ]]; then
    echo "::error::Inline adoption %% found in prompt/analysis docs (BUT-776)." >&2
    echo "Move the number to docs/architecture/adoption-status.md and cite that file by relative path." >&2
    echo >&2
    cat "$HITS_FILE" >&2
    exit 1
  fi
fi

echo "OK: no inline adoption %% in prompt/analysis docs."
