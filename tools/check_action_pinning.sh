#!/usr/bin/env bash
# BUT-790: ensure high-blast-radius GitHub Actions stay SHA-pinned.
#
# Tag-only refs (`@v2`, `@v0.36.0`) re-resolve at run time to whatever commit
# currently lives at that tag — so a hijacked or force-pushed tag can swap our
# build infrastructure. SHA pinning forces an explicit upgrade decision.
#
# Scope: this guard checks the four highest-blast-radius actions only.
# Other actions (actions/checkout, actions/setup-node, etc.) are tag-pinned
# by official-org policy and out of scope for this guard.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOWS_DIR="$ROOT_DIR/.github/workflows"

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "::error::workflows dir not found at $WORKFLOWS_DIR" >&2
  exit 2
fi

# Each line that uses one of these actions must reference a 40-char hex SHA.
HIGH_BLAST_RADIUS=(
  "subosito/flutter-action"
  "aquasecurity/trivy-action"
  "codecov/codecov-action"
  "trufflesecurity/trufflehog"
)

EXIT=0
for action in "${HIGH_BLAST_RADIUS[@]}"; do
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Skip comments inside YAML.
    if echo "$line" | grep -qE "^[[:space:]]*#"; then
      continue
    fi
    # Extract the @ref portion (everything between @ and the first space or # comment).
    ref=$(echo "$line" | sed -E "s|.*${action}@([^[:space:]#]+).*|\1|")
    if [[ ! "$ref" =~ ^[0-9a-f]{40}$ ]]; then
      echo "::error::$action is not SHA-pinned (got '$ref'). BUT-790 requires a 40-char hex commit SHA." >&2
      echo "  $line" >&2
      EXIT=1
    fi
  done < <(grep -RHnE "uses:[[:space:]]*${action}@" "$WORKFLOWS_DIR" || true)
done

if [[ $EXIT -ne 0 ]]; then
  exit $EXIT
fi
echo "OK: high-blast-radius actions are SHA-pinned"
