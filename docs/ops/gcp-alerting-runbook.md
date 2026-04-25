# GCP Alerting Setup Runbook

**Status: PENDING — runbook ready, requires user action to execute (gcloud auth + channel creation).**

Operational runbook for wiring Google Cloud Monitoring alerts in
`butlery-app-1`. Companion to `infrastructure/alerting/setup-gcp-alerts.sh`,
which generates the alert policy JSON and applies it via `gcloud`.

---

## Why this matters

Without alerting, a runaway Cloud Function, a Firestore read storm, or an
auth-endpoint brute-force attack can burn through quota and budget for
hours before anyone notices. The script in
`infrastructure/alerting/setup-gcp-alerts.sh` codifies five baseline
policies (CF error rate, CF latency, Firestore ops, auth failures, web
uptime) but cannot run without a notification channel and an authenticated
gcloud session.

After this runbook is executed:

- **MTTD** (mean time to detect) for incidents covered by these policies
  drops from "next time the founder logs in" to ~5 minutes.
- All five policies fire to a single email channel that you control.
- The script becomes safe to re-run idempotently — if anyone tries to run
  it without `GCP_NOTIFICATION_CHANNEL_ID` set, it aborts loudly instead
  of silently creating broken policies.

---

## Current status (as of 2026-04-25)

| Control | Status | Evidence |
|---|---|---|
| Alert policy script | EXISTS | `infrastructure/alerting/setup-gcp-alerts.sh` |
| Notification channel | NOT CREATED | runbook section 3 below |
| Policies applied to project | NONE | runbook section 4 below |
| gcloud CLI installed locally | UNKNOWN — verify with `gcloud --version` |
| Budget alerts (separate flow) | NOT CONFIGURED | GCP Console > Billing > Budgets |

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
unset, by design — better than silently applying alert policies that
can never page anyone.

```bash
export GCP_NOTIFICATION_CHANNEL_ID="projects/butlery-app-1/notificationChannels/1234567890123456789"
export GCP_PROJECT_ID="butlery-app-1"

cd infrastructure/alerting
bash setup-gcp-alerts.sh
```

The script writes policy JSON to `/tmp/` and prints the `gcloud alpha
monitoring policies create` commands to apply each one. Currently the
script stops short of applying — finish with:

```bash
gcloud alpha monitoring policies create \
  --project=butlery-app-1 \
  --policy-from-file=/tmp/cf-error-policy.json
gcloud alpha monitoring policies create \
  --project=butlery-app-1 \
  --policy-from-file=/tmp/cf-latency-policy.json
gcloud alpha monitoring policies create \
  --project=butlery-app-1 \
  --policy-from-file=/tmp/firestore-ops-policy.json
gcloud alpha monitoring policies create \
  --project=butlery-app-1 \
  --policy-from-file=/tmp/auth-failure-policy.json

# Uptime check (optional — only useful once web hosting is live).
gcloud alpha monitoring uptime-check-configs create butlery-web-uptime \
  --project=butlery-app-1 \
  --config-from-file=/tmp/uptime-check.json
```

> Note: each `policies create` command currently creates the policy
> without attaching it to a notification channel. After section 5
> verifies the policy IDs, attach the channel using
> `gcloud alpha monitoring policies update --add-notification-channels`.
> A follow-up commit can fold this into the script once the JSON
> generators are extended to embed the channel.

### 5. Verify the policies are live

```bash
gcloud alpha monitoring policies list \
  --project=butlery-app-1 \
  --format='table(displayName, name, enabled)'
```

You should see four (or five with uptime) policies, all `enabled=True`.

Trigger a test alert to confirm the channel works — easiest is to lower
one threshold temporarily and let it fire:

```bash
# Or simply send a test notification through the channel directly:
gcloud alpha monitoring channels verify \
  "$GCP_NOTIFICATION_CHANNEL_ID" \
  --project=butlery-app-1
```

Confirm the email lands in your inbox before considering the runbook
complete.

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

### 7. Update this document

After running the above, replace the "Current status" table with real
timestamps and channel IDs (or just the last 4 chars of the channel ID
to avoid leaking the full resource name in git), and set the document
header to "Status: ACTIVE".

---

## Re-running the script

The script is safe to re-run as long as `GCP_NOTIFICATION_CHANNEL_ID` is
exported. Re-applying a policy that already exists creates a duplicate —
delete the old one first:

```bash
gcloud alpha monitoring policies list \
  --project=butlery-app-1 \
  --filter="displayName='Cloud Functions - High Error Rate'" \
  --format='value(name)'
# Then:
gcloud alpha monitoring policies delete <policy-resource-name> \
  --project=butlery-app-1
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
- **Firestore ops > 10k/min** — tied to user count. Raise as the user
  base grows; this is primarily a runaway-query guard, not a load alarm.
- **Auth failures > 10%** — keep tight. A spike here usually means
  credential stuffing.

---

## Related runbooks and tickets

- `docs/ops/backups.md` — Firestore PITR and weekly exports (BUT-418)
- `docs/ops/moderation-runbook.md` — admin actioning of reports
- BUT-450 — this runbook's parent ticket
- `infrastructure/alerting/setup-gcp-alerts.sh` — script applied here
