#!/usr/bin/env bash
# BUT-793: ensure security-primitive deps stay pinned to exact versions.
# These three packages affect attestation, RASP, and cert-pinning behavior;
# silent minor bumps via `pub upgrade` can change security semantics without
# review. Pinning forces an explicit upgrade decision.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT_DIR/pubspec.yaml"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "::error::pubspec.yaml not found at $PUBSPEC" >&2
  exit 2
fi

# Each line must match: `<name>: <semver>` with no caret/tilde/range marker.
DEPS=(firebase_app_check freerasp http_certificate_pinning)
EXIT=0

for dep in "${DEPS[@]}"; do
  line=$(grep -E "^[[:space:]]+${dep}:[[:space:]]" "$PUBSPEC" || true)
  if [[ -z "$line" ]]; then
    echo "::error::$dep not declared in pubspec.yaml (BUT-793 pin missing?)" >&2
    EXIT=1
    continue
  fi
  # Extract value: everything between `:` and the first `#` or end of line.
  value=$(echo "$line" | sed -E "s/^[[:space:]]+${dep}:[[:space:]]*([^#[:space:]]+).*/\1/")
  case "$value" in
    [\^~]*|*\>*|*\<*)
      echo "::error::$dep is not pinned exactly (got '$value'). BUT-793 requires no ^, ~, or range. Pin to a single version." >&2
      EXIT=1
      ;;
    *)
      ;;
  esac
done

if [[ $EXIT -ne 0 ]]; then
  exit $EXIT
fi
echo "OK: security-primitive deps pinned exactly (firebase_app_check, freerasp, http_certificate_pinning)"
