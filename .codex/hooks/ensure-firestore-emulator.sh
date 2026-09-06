#!/usr/bin/env bash
# Ensure the Firestore emulator is running on 127.0.0.1:8080.
# Idempotent: succeeds immediately if emulator already up, otherwise starts it
# in the background and waits up to 60s for the port to answer.
#
# Used by the firestore-rules-tester agent (and any rules-test workflow) so
# the user never needs to start the emulator manually.

set -euo pipefail

HOST=127.0.0.1
PORT=8080
STATE_DIR=".claude/state"
PID_FILE="${STATE_DIR}/firestore-emulator.pid"
LOG_FILE="${STATE_DIR}/firestore-emulator.log"

# Already up? Nothing to do.
if curl -sf "http://${HOST}:${PORT}" >/dev/null 2>&1; then
  exit 0
fi

# Sanity: firebase CLI must be installed.
if ! command -v firebase >/dev/null 2>&1; then
  echo "✗ firebase CLI not found on PATH — install with 'npm i -g firebase-tools'" >&2
  exit 1
fi

mkdir -p "${STATE_DIR}"

# Background-start. --project demo-test bypasses GCP auth.
# nohup so the emulator survives the hook process; redirect logs.
nohup firebase emulators:start --only firestore --project demo-test \
  > "${LOG_FILE}" 2>&1 &
echo $! > "${PID_FILE}"

# Wait up to 60s for the port.
for _ in $(seq 1 60); do
  if curl -sf "http://${HOST}:${PORT}" >/dev/null 2>&1; then
    echo "✓ Firestore emulator started (pid $(cat "${PID_FILE}"))" >&2
    exit 0
  fi
  sleep 1
done

echo "✗ Firestore emulator failed to start within 60s — last lines of ${LOG_FILE}:" >&2
tail -n 20 "${LOG_FILE}" >&2 || true
exit 1
