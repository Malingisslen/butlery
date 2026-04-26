#!/bin/bash
# Cloud Storage versioning + 30-day noncurrent-version lifecycle for Butlery
# (BUT-419). Run once per environment by an authenticated maintainer.
#
# Why: deleted recipe images, avatars, and OCR uploads need ~30-day
# recoverability. Object versioning preserves overwritten / deleted blobs as
# noncurrent versions; the lifecycle rule reaps them after 30 days so the
# bucket doesn't grow without bound.
#
# Prerequisites:
# - gcloud CLI installed and authenticated (`gcloud auth login`)
# - Project ID set: `gcloud config set project butlery-app-1`
# - STORAGE_BUCKET env var exported with the Firebase Storage bucket name
#   (looks like `butlery-app-1.appspot.com` — see Firebase Console → Storage)
#
# Usage:
#   export STORAGE_BUCKET=butlery-app-1.appspot.com
#   ./infrastructure/storage/setup-storage-versioning.sh
#
# Reference: docs/ops/storage-lifecycle-runbook.md

set -euo pipefail

# Bash parameter expansion `:?` aborts the script with a clear message if
# the variable is unset or empty — fail loudly rather than silently
# operating on the wrong (or no) bucket.
BUCKET="${STORAGE_BUCKET:?STORAGE_BUCKET is required — see docs/ops/storage-lifecycle-runbook.md}"

echo "Configuring versioning + lifecycle on gs://${BUCKET}"
echo

# ----------------------------------------------------------------------------
# STEP 1: Enable Object Versioning
# ----------------------------------------------------------------------------
echo "[1/3] Enabling object versioning..."
gcloud storage buckets update "gs://${BUCKET}" --versioning

# ----------------------------------------------------------------------------
# STEP 2: Apply 30-day noncurrent-version lifecycle policy
# ----------------------------------------------------------------------------
# `isLive: false` targets noncurrent versions only — live (current) objects
# are never auto-deleted by this rule. `age: 30` is days since the version
# became noncurrent. Matches the Firestore export retention window in
# docs/ops/backups.md so the operational story stays consistent.
LIFECYCLE_FILE="$(mktemp -t butlery-storage-lifecycle.XXXXXX.json)"
trap 'rm -f "$LIFECYCLE_FILE"' EXIT

cat > "$LIFECYCLE_FILE" << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF

echo "[2/3] Applying lifecycle policy from ${LIFECYCLE_FILE}..."
gcloud storage buckets update "gs://${BUCKET}" --lifecycle-file="${LIFECYCLE_FILE}"

# ----------------------------------------------------------------------------
# STEP 3: Verify both policies are in effect
# ----------------------------------------------------------------------------
# Typed field extraction via --format='value(...)' — schema-agnostic, so
# this survives gcloud's drift between nested-versioning-object and the flat
# versioning_enabled shape.
echo "[3/3] Verifying policies..."
VERSIONING="$(gcloud storage buckets describe "gs://${BUCKET}" \
  --format='value(versioning_enabled)' 2>/dev/null | tr '[:upper:]' '[:lower:]')"
LIFECYCLE_ACTION="$(gcloud storage buckets describe "gs://${BUCKET}" \
  --format='value(lifecycle_config.rule[0].action.type)' 2>/dev/null)"

if [[ "$VERSIONING" != "true" ]]; then
  echo "ERROR: versioning is NOT enabled on gs://${BUCKET}" >&2
  echo "  versioning_enabled=$VERSIONING" >&2
  exit 1
fi

if [[ "$LIFECYCLE_ACTION" != "Delete" ]]; then
  echo "ERROR: lifecycle delete rule is NOT present on gs://${BUCKET}" >&2
  echo "  rule[0].action.type=$LIFECYCLE_ACTION" >&2
  exit 1
fi

echo
echo "OK — gs://${BUCKET} has object versioning enabled and a 30-day"
echo "     noncurrent-version delete lifecycle rule."
echo
echo "Verify in console: https://console.cloud.google.com/storage/browser/${BUCKET}"
