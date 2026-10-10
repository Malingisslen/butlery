#!/usr/bin/env bash
# Starts the local Firebase emulator suite for the app's local test mode and
# seeds it. Run book: docs/ops/local-emulator.md.
#
#   bash scripts/emulator/start.sh            # start, seed, keep running
#   bash scripts/emulator/start.sh --no-seed  # start only
set -euo pipefail

PROJECT=demo-butlery
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Functions read these at load time. Dummy values: nothing local reaches the
# services they unlock (feedback e-mail, MFA recovery, Identity Toolkit REST).
[ -f functions/.secret.local ] || printf '%s\n' \
  'FEEDBACK_EMAIL_API_KEY=local-emulator-dummy' \
  'MFA_RECOVERY_PEPPER=local-emulator-dummy' \
  'IDENTITY_TOOLKIT_API_KEY=local-emulator-dummy' > functions/.secret.local
grep -q '^IDENTITY_TOOLKIT_API_KEY=' functions/.secret.local ||
  echo 'IDENTITY_TOOLKIT_API_KEY=local-emulator-dummy' >> functions/.secret.local

if [ ! -d functions/node_modules ]; then npm --prefix functions ci; fi
npm --prefix functions run build

NODE_OPTIONS="--require $ROOT/scripts/emulator/admin-namespace-shim.js ${NODE_OPTIONS:-}" \
  firebase emulators:start --project "$PROJECT" \
  --only auth,firestore,functions,storage,database &
EMULATORS=$!
trap 'kill "$EMULATORS" 2>/dev/null || true' INT TERM

for _ in $(seq 1 90); do
  if curl -s -o /dev/null "http://localhost:8080" && curl -s -o /dev/null "http://localhost:5001"; then
    break
  fi
  sleep 2
done

if [ "${1:-}" != "--no-seed" ]; then
  FIRESTORE_EMULATOR_HOST=localhost:8080 \
  FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
  GCLOUD_PROJECT="$PROJECT" \
    node functions/scripts/seed-emulator.js
fi

echo "Emulators running (UI: http://localhost:4000). Start the app with:"
echo "  flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true"
wait "$EMULATORS"
