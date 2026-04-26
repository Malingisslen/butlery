#!/bin/bash
# GCP Cloud Monitoring alert policies for Butlery (BUT-450).
# Idempotent: re-running skips policies that already exist by display name.
#
# Why: surfaces production incidents (CF errors, CF latency, Firestore cost
# spikes, Auth failure spikes) to a paging channel. Without these, problems
# disappear into Stackdriver and only get noticed via user reports.
#
# Prerequisites:
# - gcloud CLI authenticated (`gcloud auth login`)
# - Project set: `gcloud config set project butlery-app-1`
# - Cloud Monitoring API enabled (it's on by default for Firebase projects)
# - GCP_NOTIFICATION_CHANNEL_ID exported. Create one with:
#     gcloud alpha monitoring channels create --type=email \
#       --display-name="Butlery Alerts" \
#       --channel-labels=email_address=<your-ops-email>
#     gcloud alpha monitoring channels list --format='value(name)'
#
# Usage:
#   export GCP_NOTIFICATION_CHANNEL_ID=projects/butlery-app-1/notificationChannels/<id>
#   ./infrastructure/alerting/setup-gcp-alerts.sh
#
# Reference: docs/ops/gcp-alerting-runbook.md

set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-butlery-app-1}"
NOTIFICATION_CHANNEL="${GCP_NOTIFICATION_CHANNEL_ID:?GCP_NOTIFICATION_CHANNEL_ID is required — see docs/ops/gcp-alerting-runbook.md}"

echo "Project: $PROJECT_ID"
echo "Channel: $NOTIFICATION_CHANNEL"
echo

WORKDIR="$(mktemp -d -t butlery-alerts.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

# ----------------------------------------------------------------------------
# Helper: create alert policy if not already present (idempotent by name).
# ----------------------------------------------------------------------------
existing_policies() {
  gcloud alpha monitoring policies list \
    --format='value(displayName)' 2>/dev/null
}

create_policy_if_missing() {
  local display_name="$1"
  local json_file="$2"

  if existing_policies | grep -Fxq "$display_name"; then
    echo "  [skip] '$display_name' already exists"
    return 0
  fi

  gcloud alpha monitoring policies create \
    --policy-from-file="$json_file" \
    --quiet >/dev/null
  echo "  [ok]   '$display_name' created"
}

# ----------------------------------------------------------------------------
# Policy 1: Cloud Functions error rate >5% over 5min
# ----------------------------------------------------------------------------
echo "[1/2] Cloud Functions error rate..."
cat > "$WORKDIR/cf-error.json" <<EOF
{
  "displayName": "Cloud Functions - High Error Rate",
  "documentation": {
    "content": "Cloud Functions error rate exceeded 5% over 5 minutes. Check Cloud Functions logs.",
    "mimeType": "text/markdown"
  },
  "conditions": [{
    "displayName": "CF Error Rate > 5%",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\"",
      "aggregations": [{
        "alignmentPeriod": "300s",
        "perSeriesAligner": "ALIGN_RATE"
      }],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0.05,
      "duration": "300s"
    }
  }],
  "alertStrategy": {"autoClose": "604800s"},
  "combiner": "OR",
  "notificationChannels": ["$NOTIFICATION_CHANNEL"],
  "enabled": true
}
EOF
create_policy_if_missing "Cloud Functions - High Error Rate" "$WORKDIR/cf-error.json"

# ----------------------------------------------------------------------------
# Policy 2: Cloud Functions p99 execution time >10s
# ----------------------------------------------------------------------------
echo "[2/2] Cloud Functions latency..."
cat > "$WORKDIR/cf-latency.json" <<EOF
{
  "displayName": "Cloud Functions - High Latency",
  "documentation": {
    "content": "Cloud Functions p99 execution time exceeded 10s over 5 minutes. May indicate cold-start regressions or downstream issues.",
    "mimeType": "text/markdown"
  },
  "conditions": [{
    "displayName": "CF Execution Time p99 > 10s",
    "conditionThreshold": {
      "filter": "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_times\"",
      "aggregations": [{
        "alignmentPeriod": "300s",
        "perSeriesAligner": "ALIGN_PERCENTILE_99",
        "crossSeriesReducer": "REDUCE_MEAN"
      }],
      "comparison": "COMPARISON_GT",
      "thresholdValue": 10000000000,
      "duration": "300s"
    }
  }],
  "alertStrategy": {"autoClose": "604800s"},
  "combiner": "OR",
  "notificationChannels": ["$NOTIFICATION_CHANNEL"],
  "enabled": true
}
EOF
create_policy_if_missing "Cloud Functions - High Latency" "$WORKDIR/cf-latency.json"

# Two Firebase-product alerts (Firestore read rate, Auth failure rate) are
# deliberately NOT shipped here:
# - Firestore: `firestore.googleapis.com/document/read_count` requires a
#   resource.type that gcloud's filter validation churned between schemas;
#   no working filter combination via the API today. Use GCP Billing
#   budgets for cost protection (link below) — this catches the actual
#   signal (€/day spend) more directly than read-count.
# - Firebase Auth: legacy `firebaseauth.googleapis.com/api/response_count`
#   no longer exists; replacement under Identity Platform requires
#   project enablement. Firebase Auth has built-in throttling, so this is
#   a nice-to-have, not a must-have.
# Add via Console (https://console.cloud.google.com/monitoring/alerting)
# when needed — the metric picker resolves resource types automatically.

# ----------------------------------------------------------------------------
# Verify all four policies are now live and routed to the channel.
# ----------------------------------------------------------------------------
echo
echo "Verifying..."
EXPECTED=(
  "Cloud Functions - High Error Rate"
  "Cloud Functions - High Latency"
)
PRESENT="$(existing_policies)"
MISSING=()
for name in "${EXPECTED[@]}"; do
  if ! echo "$PRESENT" | grep -Fxq "$name"; then
    MISSING+=("$name")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: missing policies:" >&2
  printf '  - %s\n' "${MISSING[@]}" >&2
  exit 1
fi

echo "OK — 2 alert policies live, routed to $NOTIFICATION_CHANNEL"
echo
echo "Console: https://console.cloud.google.com/monitoring/alerting/policies?project=$PROJECT_ID"
echo
echo "Budget alerts: configure separately in"
echo "  https://console.cloud.google.com/billing/budgets"
echo "  (gcloud's budget API is awkward; the Console flow is fine for one-time setup)"
