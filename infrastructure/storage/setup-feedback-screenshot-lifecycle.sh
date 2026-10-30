#!/bin/bash
# Delete feedback screenshots (feedback/<uid>/*.png) a year after upload, to
# match the 12-month expireAt on the feedback rows in Firestore.
#
# Applying a lifecycle file REPLACES the bucket's whole rule list, so this
# script reads the rules already on the bucket and adds one; it never starts
# from a blank list.
#
# Destructive on first activation: every feedback screenshot already older
# than 365 days is deleted at the next lifecycle sweep. The
# default run therefore only counts and prints; pass --apply to change the
# bucket. Show the printed count to Malin before using --apply.
#
# Usage:
#   export STORAGE_BUCKET=butlery-prod.firebasestorage.app
#   ./infrastructure/storage/setup-feedback-screenshot-lifecycle.sh          # count only
#   ./infrastructure/storage/setup-feedback-screenshot-lifecycle.sh --apply  # change the bucket
#
# Reference: docs/ops/storage-lifecycle-runbook.md

set -euo pipefail

BUCKET="${STORAGE_BUCKET:?STORAGE_BUCKET is required — see docs/ops/storage-lifecycle-runbook.md}"
APPLY="no"
[[ "${1:-}" == "--apply" ]] && APPLY="yes"

PROJECT="$(gcloud config get-value project 2>/dev/null)"
echo "Project: ${PROJECT:-<none set>}"
echo "Bucket:  gs://${BUCKET}"
echo

CUTOFF="$(date -u -d '365 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-365d +%Y-%m-%dT%H:%M:%SZ)"
LIST_FILE="$(mktemp -t butlery-feedback-list.XXXXXX)"
LIST_ERR="$(mktemp -t butlery-feedback-list-err.XXXXXX)"
if gcloud storage ls -l "gs://${BUCKET}/feedback/**" > "$LIST_FILE" 2> "$LIST_ERR"; then
  TOTAL="$(grep -c '^ *[0-9]' "$LIST_FILE" || true)"
  OLD="$(awk -v cutoff="$CUTOFF" '$3 ~ /^gs:/ && $2 < cutoff {n++} END {print n+0}' "$LIST_FILE")"
elif grep -qi 'matched no objects\|One or more URLs matched no objects' "$LIST_ERR"; then
  TOTAL=0
  OLD=0
else
  echo "Count unavailable: listing feedback/ failed:" >&2
  cat "$LIST_ERR" >&2
  rm -f "$LIST_FILE" "$LIST_ERR"
  exit 1
fi
rm -f "$LIST_FILE" "$LIST_ERR"
echo "Feedback screenshots now: ${TOTAL}"
echo "Older than 365 days (deleted at the next sweep once the rule is on): ${OLD}"
echo

WORK="$(mktemp -d -t butlery-feedback-lifecycle.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

gcloud storage buckets describe "gs://${BUCKET}" --format=json > "$WORK/bucket.json"
python3 - "$WORK/bucket.json" "$WORK/lifecycle.json" <<'PY'
import json, sys
bucket = json.load(open(sys.argv[1]))
found = bucket.get("lifecycle_config") or bucket.get("lifecycle")
rules = (found or {}).get("rule", [])
versioning = bool(bucket.get("versioning_enabled") or (bucket.get("versioning") or {}).get("enabled"))
print("Rules on the bucket now:")
print(json.dumps(rules, indent=2))
# The bucket is meant to carry the 30-day noncurrent-version rule; reading none
# means the key names changed, and applying would wipe whatever is there.
if versioning and not rules:
    sys.exit("Refusing: versioning is on but no lifecycle rules were read. Check the describe output.")
mine = {
    "action": {"type": "Delete"},
    "condition": {"age": 365, "matchesPrefix": ["feedback/"]},
}
if mine not in rules:
    rules = rules + [mine]
json.dump({"lifecycle": {"rule": rules}}, open(sys.argv[2], "w"), indent=2)
print("Rules after the change:")
print(json.dumps(rules, indent=2))
PY

if [[ "$APPLY" != "yes" ]]; then
  echo "Count only. Nothing was changed. Re-run with --apply to set the rule."
  exit 0
fi

gcloud storage buckets update "gs://${BUCKET}" --lifecycle-file="$WORK/lifecycle.json"
echo "Applied. Rules now on the bucket:"
gcloud storage buckets describe "gs://${BUCKET}" --format='json(lifecycle_config)'
