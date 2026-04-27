# GCP Alerting Setup Runbook

**Status: ACTIVE — 2 alert policies live in `butlery-app-1` as of 2026-04-26.**

Operational runbook for Google Cloud Monitoring alerts in `butlery-app-1`.
Companion to `infrastructure/alerting/setup-gcp-alerts.sh`, which is
idempotent and applies the policies directly via `gcloud`.

---

## Why this matters

Without alerting, a runaway Cloud Function or a downstream incident can
burn through quota and budget for hours before anyone notices. After
activation:

- **MTTD** (mean time to detect) for CF errors and CF latency regressions
  drops from "next time the founder logs in" to ~5 minutes.
- Both policies fire to `malin.gisslen1@gmail.com` (the project's ops mailbox).
- Re-running the script is safe — it skips policies whose `displayName`
  already exists.

---

## Current status (as of 2026-04-26)

| Control | Status | Evidence |
|---|---|---|
| Alert policy script | ACTIVE + IDEMPOTENT | `infrastructure/alerting/setup-gcp-alerts.sh` |
| Notification channel | LIVE | `projects/butlery-app-1/notificationChannels/11860390942781239556` (email: malin.gisslen1@gmail.com) |
| `Cloud Functions - High Error Rate` | LIVE, enabled, routed to channel | verified via `gcloud alpha monitoring policies list` |
| `Cloud Functions - High Latency` | LIVE, enabled, routed to channel | verified via `gcloud alpha monitoring policies list` |
| Firestore read-rate alert | NOT SHIPPED | metric/resource-type schema churn — see "Deferred policies" below |
| Firebase Auth failure-rate alert | NOT SHIPPED | legacy metric retired — see "Deferred policies" below |
| Budget alerts (separate flow) | TODO | GCP Console > Billing > Budgets |

---

## Deferred policies (intentional gaps)

Two policies originally scoped were dropped because their underlying
metrics moved between schemas faster than gcloud's filter validator
caught up. Details so future maintainers don't re-fight this:

- **Firestore read-rate**: `firestore.googleapis.com/document/read_count`
  was rejected with every reasonable `resource.type` filter
  (`firestore_database`, `firestore.googleapis.com/Database`, omitting
  it entirely). Cost protection is better served by GCP Billing budget
  alerts, which fire on the actual signal (€/day spend) rather than a
  metric proxy. See section 6 below.
- **Firebase Auth failure-rate**:
  `firebaseauth.googleapis.com/api/response_count` no longer exists —
  Firebase Auth metrics moved under Identity Platform and require
  project enablement. Firebase Auth has built-in throttling, so this is
  a nice-to-have rather than a must-have.

If either is needed later, add them via GCP Console
(<https://console.cloud.google.com/monitoring/alerting>) — the metric
picker resolves resource types automatically. Capture the resulting
policy JSON via `gcloud alpha monitoring policies describe` and fold it
back into the script.

---

## One-time setup (run once by an authenticated maintainer)

### 1. Install gcloud CLI

If `gcloud --version` errors, install it. macOS:

```bash
# Homebrew (recommended on macOS)
brew install --cask google-cloud-sdk

# Verify
gcloud --version
```

Linux / Windows / scripted installs: see
<https://cloud.google.com/sdk/docs/install>. Pick the package for your
platform; do not install the snap version on Linux — it sandboxes the
config dir and breaks `gcloud auth application-default login`.

### 2. Authenticate and select the project

```bash
gcloud auth login
gcloud config set project butlery-app-1

# Verify you can see the project — should print "butlery-app-1".
gcloud config get-value project
```

If `gcloud auth login` fails with a quota project warning, also run:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project butlery-app-1
```

### 3. Create the email notification channel

Pick the email address that should receive alerts. For Butlery this is
the founder address (`malin.gisslen@kommerskollegium.se`) until the team
grows.

```bash
gcloud alpha monitoring channels create \
  --project=butlery-app-1 \
  --type=email \
  --display-name="Butlery Alerts" \
  --channel-labels=email_address=malin.gisslen@kommerskollegium.se
```

Capture the channel resource name from the output — it looks like
`projects/butlery-app-1/notificationChannels/1234567890123456789`. If you
miss it, list and pick:

```bash
gcloud alpha monitoring channels list \
  --project=butlery-app-1 \
  --format='value(name)'
```

GCP sends a verification email. **Click the link before continuing** — an
unverified channel silently drops alerts.

### 4. Export the channel ID and run the script

The script aborts with a clear error if `GCP_NOTIFICATION_CHANNEL_ID` is
unset — fail-loud, never silently apply alerts that can't page anyone.

```bash
export GCP_NOTIFICATION_CHANNEL_ID="projects/butlery-app-1/notificationChannels/11860390942781239556"

bash infrastructure/alerting/setup-gcp-alerts.sh
```

The script writes policy JSON to a temp dir, applies each policy via
`gcloud alpha monitoring policies create`, and verifies all expected
display names exist afterwards. It is idempotent — re-running skips
policies whose `displayName` already exists.

### 5. Verify the policies are live

```bash
gcloud alpha monitoring policies list \
  --format='value(displayName, enabled, notificationChannels[0])'
```

You should see two rows, both `enabled=True` and routed to the
notification channel from step 3.

GCP normally sends a verification email when the channel is created
(step 3) — clicking it confirms the channel works. If no email arrives,
re-issue verification:

```bash
gcloud alpha monitoring channels verify "$GCP_NOTIFICATION_CHANNEL_ID"
```

### 6. Configure budget alerts (separate flow — manual)

Cloud Monitoring policies do not cover billing. Add budget alerts via
the GCP Console:

1. <https://console.cloud.google.com/billing> — pick the Butlery billing
   account.
2. Budgets & alerts > Create budget.
3. Scope: `butlery-app-1`. Amount: a monthly figure you can absorb if
   things go wrong (a few hundred SEK is usually enough at this stage).
4. Thresholds: 50% (email), 80% (email), 100% (email). Add Slack /
   PagerDuty later if the team grows.

---

## Re-running the script

Safe to re-run as long as `GCP_NOTIFICATION_CHANNEL_ID` is exported. The
`create_policy_if_missing` helper checks `displayName` against existing
policies and skips matches — no duplicates.

To delete and re-create a policy (e.g. to change the threshold):

```bash
gcloud alpha monitoring policies list \
  --filter="displayName='Cloud Functions - High Error Rate'" \
  --format='value(name)'
# Then:
gcloud alpha monitoring policies delete <policy-resource-name>
# Then re-run the script.
```

---

## Tuning thresholds

The starting thresholds in the script are conservative — a small consumer
app at low traffic can trip the Firestore-ops policy on a single bulk
import. After two weeks of steady-state data, review:

- **CF error rate > 5%** — fine if traffic is steady; raise to 10% if
  cold-start blips dominate the signal.
- **CF latency p99 > 10s** — generous; lower to 5s once cold starts are
  warmed.

---

## Related runbooks and tickets

- `docs/ops/backups.md` — Firestore PITR and weekly exports (BUT-418)
- `docs/ops/storage-lifecycle-runbook.md` — Cloud Storage versioning + 30-day lifecycle (BUT-419)
- `docs/ops/moderation-runbook.md` — admin actioning of reports
- BUT-450 — this runbook's parent ticket. **Activated 2026-04-26.**
- `infrastructure/alerting/setup-gcp-alerts.sh` — idempotent setup script
