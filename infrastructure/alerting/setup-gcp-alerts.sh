#!/bin/bash
# GCP Alerting Setup Script for Butlery Application
# Run this script once to configure alerting policies in GCP Cloud Monitoring
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Project ID set: gcloud config set project butlery-app-1
# - Cloud Monitoring API enabled
#
# Usage: ./setup-gcp-alerts.sh

set -e

PROJECT_ID="${GCP_PROJECT_ID:-butlery-app-1}"
NOTIFICATION_CHANNEL="${NOTIFICATION_CHANNEL_ID:-}" # Set after creating channel

echo "Setting up GCP alerting for project: $PROJECT_ID"

# =============================================================================
# STEP 1: Create Notification Channel (Email)
# =============================================================================
# First, create a notification channel manually in GCP Console or use:
# gcloud alpha monitoring channels create --type=email --display-name="Butlery Alerts" \
#   --channel-labels=email_address=alerts@butlery.app

# After creating, get the channel ID:
# CHANNEL_ID=$(gcloud alpha monitoring channels list --format='value(name)' | head -1)

# =============================================================================
# STEP 2: Cloud Functions Error Rate Alert
# =============================================================================
echo "Creating Cloud Functions error rate alert..."

cat > /tmp/cf-error-policy.json << 'EOF'
{
  "displayName": "Cloud Functions - High Error Rate",
  "documentation": {
    "content": "Cloud Functions error rate exceeded 5% over 5 minutes. Check Cloud Functions logs for details.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "CF Error Rate > 5%",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.05,
        "duration": "300s"
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR"
}
EOF

# Uncomment when notification channel is configured:
# gcloud alpha monitoring policies create --policy-from-file=/tmp/cf-error-policy.json

# =============================================================================
# STEP 3: Cloud Functions Execution Time Alert
# =============================================================================
echo "Creating Cloud Functions latency alert..."

cat > /tmp/cf-latency-policy.json << 'EOF'
{
  "displayName": "Cloud Functions - High Latency",
  "documentation": {
    "content": "Cloud Functions execution time exceeded 10 seconds. This may indicate performance issues or cold starts.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "CF Execution Time > 10s",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_times\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_PERCENTILE_99",
            "crossSeriesReducer": "REDUCE_MEAN"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 10000000000,
        "duration": "300s"
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR"
}
EOF

# =============================================================================
# STEP 4: Firestore Read/Write Rate Alert (Cost Protection)
# =============================================================================
echo "Creating Firestore operations alert..."

cat > /tmp/firestore-ops-policy.json << 'EOF'
{
  "displayName": "Firestore - High Operation Rate",
  "documentation": {
    "content": "Firestore operations exceeded 10,000/minute. This may indicate a runaway query or cost issue.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Firestore Ops > 10k/min",
      "conditionThreshold": {
        "filter": "resource.type=\"firestore_database\" AND metric.type=\"firestore.googleapis.com/document/read_count\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 166.67,
        "duration": "300s"
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR"
}
EOF

# =============================================================================
# STEP 5: Firebase Authentication Alert
# =============================================================================
echo "Creating Firebase Auth failure alert..."

cat > /tmp/auth-failure-policy.json << 'EOF'
{
  "displayName": "Firebase Auth - High Failure Rate",
  "documentation": {
    "content": "Firebase Authentication failures exceeded 10% over 5 minutes. May indicate brute force attack or service issues.",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Auth Failures > 10%",
      "conditionThreshold": {
        "filter": "resource.type=\"firebase_auth\" AND metric.type=\"firebaseauth.googleapis.com/api/response_count\" AND metric.labels.response_code!=\"200\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.1,
        "duration": "300s"
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR"
}
EOF

# =============================================================================
# STEP 6: Budget Alert (via GCP Billing)
# =============================================================================
echo "Note: Budget alerts should be configured in GCP Console > Billing > Budgets"
echo "Recommended budget thresholds:"
echo "  - 50% of monthly budget: Email notification"
echo "  - 80% of monthly budget: Email + Slack notification"
echo "  - 100% of monthly budget: Email + Slack + PagerDuty"

# =============================================================================
# STEP 7: Uptime Check (Optional - for web hosting)
# =============================================================================
echo "Creating uptime check for web hosting..."

cat > /tmp/uptime-check.json << 'EOF'
{
  "displayName": "Butlery Web App Uptime",
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "host": "butlery-app-1.web.app"
    }
  },
  "httpCheck": {
    "path": "/",
    "useSsl": true,
    "validateSsl": true,
    "requestMethod": "GET"
  },
  "period": "300s",
  "timeout": "10s"
}
EOF

# =============================================================================
# APPLY POLICIES
# =============================================================================
echo ""
echo "Policy JSON files created in /tmp/"
echo ""
echo "To apply these policies, run:"
echo "  gcloud alpha monitoring policies create --policy-from-file=/tmp/cf-error-policy.json"
echo "  gcloud alpha monitoring policies create --policy-from-file=/tmp/cf-latency-policy.json"
echo "  gcloud alpha monitoring policies create --policy-from-file=/tmp/firestore-ops-policy.json"
echo "  gcloud alpha monitoring policies create --policy-from-file=/tmp/auth-failure-policy.json"
echo ""
echo "For uptime checks:"
echo "  gcloud alpha monitoring uptime-check-configs create butlery-web-uptime --config-from-file=/tmp/uptime-check.json"
echo ""
echo "NOTE: You must first create a notification channel and update the policies with the channel ID."
echo "See: https://cloud.google.com/monitoring/alerts/notification-channels"
