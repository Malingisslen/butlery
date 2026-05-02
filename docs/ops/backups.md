# Firestore Backups & Disaster Recovery

**Status: ACTIVE — PITR enabled, weekly GCS exports scheduled.**

Operational runbook for Firestore data protection in `butlery-app-1`.

---

## Why this matters

Without PITR (Point-in-Time Recovery) or scheduled exports, any accidental delete, bad
Cloud Function, or malicious write is permanent. Recovery Point Objective (RPO) is
effectively **infinite** — we cannot restore yesterday's state.

After the runbook is executed:
- **RPO:** 7 days (PITR window) for accidental data loss up to 7 days old
- **RPO:** 7 days (weekly export) for anything older than the PITR window
- **RTO:** < 1 hour for PITR restore to a sibling database, < 4 hours for full GCS import

---

## Current status (as of 2026-04-24)

| Control | Status | Evidence |
|---|---|---|
| PITR enabled | ENABLED — 7-day window | `versionRetentionPeriod: 604800s` |
| Weekly GCS export | SCHEDULED — Sundays 03:00 UTC | Cloud Scheduler job `firestore-weekly-export` (europe-west3) |
| Backup bucket | CREATED — `gs://butlery-firestore-backups` | europe-west3, uniform bucket-level access |
| Retention policy | 30 days auto-delete | lifecycle rule applied via `docs/ops/lifecycle.json` |
| Firestore region | europe-west3 (Frankfurt, EU) | — |
| Restore drill | NEVER PERFORMED | schedule one after first successful export |

---

## One-time setup (run once by an authenticated maintainer)

### 1. Verify current state

```bash
gcloud firestore databases describe \
  --database='(default)' \
  --project=butlery-app-1
```

Look for `pointInTimeRecoveryEnablement`. If it reads `POINT_IN_TIME_RECOVERY_DISABLED`,
continue to step 2.

### 2. Enable PITR

```bash
gcloud firestore databases update \
  --enable-pitr \
  --database='(default)' \
  --project=butlery-app-1
```

PITR window is 7 days. Cost: ~$0.10/GB-month of PITR data. Immediate effect.

### 3. Create the backup bucket

```bash
# Bucket must live in the same region as Firestore (verify with describe above).
# Butlery Firestore region is europe-west3 — keep exports in-region for GDPR.
gcloud storage buckets create gs://butlery-firestore-backups \
  --project=butlery-app-1 \
  --location=europe-west3 \
  --uniform-bucket-level-access \
  --public-access-prevention
```

### 4. Apply 30-day lifecycle retention

Save as `lifecycle.json`:

```json
{
  "lifecycle": {
    "rule": [
      {
        "action": { "type": "Delete" },
        "condition": { "age": 30 }
      }
    ]
  }
}
```

Apply:

```bash
gcloud storage buckets update gs://butlery-firestore-backups \
  --lifecycle-file=lifecycle.json
```

### 5. Grant the Firestore service account write access

```bash
# Firestore uses a Google-managed service account for exports.
# Project number is visible in the GCP console; replace PROJECT_NUMBER below.
PROJECT_NUMBER=$(gcloud projects describe butlery-app-1 --format='value(projectNumber)')

gcloud storage buckets add-iam-policy-binding gs://butlery-firestore-backups \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firestore.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### 6. Create the weekly scheduled export

Option A — Cloud Scheduler invoking the Firestore export API (simplest, no Function needed):

```bash
# Sundays 03:00 UTC = Sundays 04:00 / 05:00 Stockholm depending on DST.
# Off-peak for a Swedish consumer app.
gcloud scheduler jobs create http firestore-weekly-export \
  --project=butlery-app-1 \
  --location=europe-west3 \
  --schedule="0 3 * * 0" \
  --time-zone="UTC" \
  --uri="https://firestore.googleapis.com/v1/projects/butlery-app-1/databases/(default):exportDocuments" \
  --http-method=POST \
  --oauth-service-account-email="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --oauth-token-scope="https://www.googleapis.com/auth/datastore" \
  --message-body='{"outputUriPrefix":"gs://butlery-firestore-backups/weekly"}' \
  --headers="Content-Type=application/json"
```

The invoking service account needs `roles/datastore.importExportAdmin` on the project:

```bash
gcloud projects add-iam-policy-binding butlery-app-1 \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/datastore.importExportAdmin"
```

### 7. Verify the job runs

Force an immediate run to confirm the pipeline works:

```bash
gcloud scheduler jobs run firestore-weekly-export \
  --project=butlery-app-1 \
  --location=europe-west3

# Wait ~2 minutes, then confirm an export folder landed:
gcloud storage ls gs://butlery-firestore-backups/weekly/
```

### 8. Update this document

After running the above, replace the "Current status" table with real timestamps and set
the document header to "Status: ACTIVE".

---

## Restore procedure

### Scenario 1: Accidental delete discovered within 7 days (use PITR)

```bash
# Restore to a NEW database — never overwrite (default).
gcloud firestore databases restore \
  --source-database='(default)' \
  --destination-database='recovery-YYYYMMDD' \
  --snapshot-time='2026-04-20T10:30:00Z' \
  --project=butlery-app-1
```

Then use the Firebase console or a one-off migration script to copy the affected
collections/documents back into the live database. Never repoint the production app at
the recovery database — import the data instead.

### Scenario 2: Older than 7 days (use weekly GCS export)

```bash
# Identify the export to restore from:
gcloud storage ls gs://butlery-firestore-backups/weekly/

# Import to a recovery database (never into production):
gcloud firestore databases create \
  --database=recovery-YYYYMMDD \
  --location=europe-west3 \
  --project=butlery-app-1

gcloud firestore import \
  gs://butlery-firestore-backups/weekly/EXPORT_FOLDER/ \
  --database=recovery-YYYYMMDD \
  --project=butlery-app-1
```

Then migrate the affected data back into `(default)` via a controlled script.

### Scenario 3: Catastrophic loss

Full database import into a new default database is the last resort. Coordinate with the
user before doing this — it requires app downtime and communicating with users about
data losses between the export snapshot and the incident.

---

## Retention policy

- **PITR:** 7 days (Firestore default, not configurable)
- **Weekly GCS exports:** 30 days (lifecycle rule in step 4)
- **Incident-specific exports:** copy to a separate non-lifecycle bucket before the 30d
  window expires if the incident is still under investigation

---

## Incident notification

On any data-loss event (accidental delete, ransomware, bad migration):

1. Notify the product owner (info@butlery.se) within 1 hour of detection
2. Snapshot the current state immediately — run a manual export before attempting fixes:
   ```bash
   gcloud firestore export gs://butlery-firestore-backups/incidents/INCIDENT_ID/ \
     --database='(default)' --project=butlery-app-1
   ```
3. GDPR: if user personal data was lost or exposed, this is potentially a Chapter III
   Art 33 notifiable breach. 72-hour clock to Datainspektionen starts on discovery.
4. Document the timeline in `docs/ops/incidents/INCIDENT_ID.md` (create the directory on
   first incident).

---

## Cost estimate

Rough figures for a database with a few GB of active data:

| Line item | Monthly cost |
|---|---|
| PITR storage (7-day window, ~5GB) | ~$0.50 |
| Weekly GCS export (~1GB/week × 4 weeks retained) | ~$0.10 |
| Scheduler job (1 exec/week) | $0 (free tier) |
| **Total** | **< $1/month** |

This is negligible and vastly below the cost of a single lost user's trust.

---

## Storage versioning

Firestore PITR + weekly exports cover the structured-data DR tier. Cloud
Storage (recipe images, avatars, OCR uploads) has its own independent
recovery story — object versioning + a 30-day noncurrent-version lifecycle —
documented in `docs/ops/storage-lifecycle-runbook.md` (BUT-419). Same
30-day retention window as the weekly Firestore export so the operational
story is uniform across data tiers.

---

## Related Linear tickets

- BUT-418 — this runbook's parent ticket (Urgent, launch-readiness)
- BUT-419 — sibling Cloud Storage versioning + lifecycle (`storage-lifecycle-runbook.md`)
- BUT-607 — EU data residency verification (shares the region decision in step 3)
