#!/bin/bash
# GCP Security Log Polling Script for Butlery
# Reference runbook for pulling security-relevant events from GCP Cloud Logging.
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Project set: gcloud config set project butlery-app-1
# - Cloud Logging API enabled
#
# Usage: ./gcp-security-check.sh [hours]
#   hours: lookback window in hours (default: 24)

set -e

PROJECT_ID="${GCP_PROJECT_ID:-butlery-app-1}"
HOURS="${1:-24}"
SINCE="$(date -u -d "${HOURS} hours ago" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-${HOURS}H '+%Y-%m-%dT%H:%M:%SZ')"

echo "=== Butlery GCP Security Check ==="
echo "Project: $PROJECT_ID"
echo "Window:  last $HOURS hours (since $SINCE)"
echo

# -----------------------------------------------------------------------------
# 1. Cloud Functions errors
# -----------------------------------------------------------------------------
# Catches: unhandled exceptions, rate limit violations (enforceRateLimit throws),
# SSRF blocks (url-safety.ts rejections), admin-only check failures.
echo "--- Cloud Functions errors (severity >= ERROR) ---"
gcloud logging read \
  "resource.type=cloud_function AND severity>=ERROR AND timestamp>=\"$SINCE\"" \
  --project="$PROJECT_ID" \
  --limit=50 \
  --format="table(timestamp,resource.labels.function_name,severity,textPayload)" \
  || echo "(no results or query failed)"
echo

# -----------------------------------------------------------------------------
# 2. Firestore security rule denials
# -----------------------------------------------------------------------------
# Every denied read/write surfaces here. A spike usually means either a bug in
# client code or an active probe.
echo "--- Firestore rule denials ---"
gcloud logging read \
  "resource.type=firestore_database AND protoPayload.status.code!=0 AND timestamp>=\"$SINCE\"" \
  --project="$PROJECT_ID" \
  --limit=50 \
  --format="table(timestamp,protoPayload.status.code,protoPayload.status.message)" \
  || echo "(no results or query failed)"
echo

# -----------------------------------------------------------------------------
# 3. Firebase Auth warnings/errors
# -----------------------------------------------------------------------------
# Repeated failures from a single IP = credential stuffing attempt.
echo "--- Firebase Auth warnings/errors ---"
gcloud logging read \
  "resource.type=firebase_auth AND severity>=WARNING AND timestamp>=\"$SINCE\"" \
  --project="$PROJECT_ID" \
  --limit=50 \
  --format="table(timestamp,severity,textPayload)" \
  || echo "(no results or query failed)"
echo

# -----------------------------------------------------------------------------
# 4. IAM policy changes
# -----------------------------------------------------------------------------
# Any unexpected setIamPolicy call = investigate immediately.
echo "--- IAM policy changes ---"
gcloud logging read \
  "protoPayload.methodName=SetIamPolicy AND timestamp>=\"$SINCE\"" \
  --project="$PROJECT_ID" \
  --limit=20 \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)" \
  || echo "(no results or query failed)"
echo

# -----------------------------------------------------------------------------
# 5. Cloud Functions cold-invocation spikes (sanity check)
# -----------------------------------------------------------------------------
# Useful to correlate with rate-limit alerts and cost anomalies.
echo "--- Cloud Functions invocation count (last $HOURS hours) ---"
gcloud logging read \
  "resource.type=cloud_function AND protoPayload.methodName=\"google.cloud.functions.v1.CloudFunctionsService.CallFunction\" AND timestamp>=\"$SINCE\"" \
  --project="$PROJECT_ID" \
  --limit=1 \
  --format="value(timestamp)" > /dev/null && echo "(ran successfully — check GCP Console for full count)" \
  || echo "(no results or query failed)"
echo

echo "=== Done ==="
echo "For deeper investigation, use:"
echo "  https://console.cloud.google.com/logs/query?project=$PROJECT_ID"
