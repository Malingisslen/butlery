# Firestore Backups & Disaster Recovery

**Status: ACTIVE — PITR enabled, managed daily backups (7-day retention), weekly GCS exports.**

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

## Current status (verified against live GCP 2026-08-13)

Every row below was read off the live project on 2026-08-13; the command that proves it is
in the Evidence column. Do not edit a row without re-running its command.

| Control | Status | Evidence |
|---|---|---|
| PITR enabled | ENABLED — 7-day window | `gcloud firestore databases describe`: `pointInTimeRecoveryEnablement: POINT_IN_TIME_RECOVERY_ENABLED`, `versionRetentionPeriod: 604800s` |
| Managed daily backup schedule | ACTIVE since 2026-08-11 — daily, 7-day retention | `gcloud firestore backups schedules list --database='(default)'`: one schedule, `dailyRecurrence: {}`, `retention: 604800s` |
| Managed backups on disk | 2 READY (snapshots 2026-08-12 and 2026-08-13) | `gcloud firestore backups list --location=europe-west3` |
| Weekly GCS export | SCHEDULED — Sundays 03:00 UTC, in **europe-west3** (not europe-west1) | Cloud Scheduler job `firestore-weekly-export`; last run wrote 2026-08-09T03:00Z |
| Backup bucket | CREATED — `gs://butlery-firestore-backups`, **europe-west3** | `gcloud storage buckets describe`: `location: EUROPE-WEST3` — in-region with the database, so exports are NOT cross-region |
| Retention policy (bucket) | 30 days auto-delete — CONFIRMED live | `buckets describe` returns the `Delete`/`age: 30` lifecycle rule |
| Firestore region | **europe-west3 (Frankfurt, EU)** — data; compute pinned to europe-west1 | Resolved in **BUT-819**, 2026-06-14. The EU-region split is **accepted** (both EU → GDPR satisfied). |
| Restore drill | PASSED 2026-08-29 — restored to a scratch database, contents matched, database deleted | `gcloud firestore databases restore --source-backup=.../90760cc7-4053-429a-a9b0-33ba4a58a232 --destination-database=restore-drill-20260829` → operation `SUCCESSFUL` 100%. Row counts in the restored database matched production exactly: users 2, conversations 1, chat_groups 0, `collectionGroup('recipes')` 8. Drill database deleted the same day (`databases list` returns only `(default)`). BUT-880 |

⚠️ The weekly export writes every run to the same `gs://.../weekly/` prefix, so each run
overwrites the previous one. Only the LATEST weekly export exists at any time, and the
30-day lifecycle rule therefore never has an older export to delete. The managed daily
schedule is what actually provides multi-day depth beyond PITR.

⚠️ The 2026-08-29 restore drill proves the MECHANISM, not the timing. It ran against 2
users and 8 recipes, so it says nothing about how long a restore takes at real volume —
the RTO figures in `DISASTER_RECOVERY.md` are still theoretical. Re-run the drill after
launch to replace them with a measured number.

---

## Managed daily backups (the Firestore-native feature)

This is separate from the GCS export pipeline below: Firestore takes and stores the backup
itself, no bucket, no Scheduler job, no IAM wiring.

Already created (2026-08-11) — do **not** run the create command again, it would add a
second schedule and double the storage bill.

```bash
# Create (already done — kept for disaster rebuild):
gcloud firestore backups schedules create \
  --database='(default)' --project=butlery-app-1 \
  --recurrence=daily --retention=7d

# Verify — the schedule (no --location flag on this one):
gcloud firestore backups schedules list --database='(default)' --project=butlery-app-1

# Verify — the backups that schedule has actually produced:
gcloud firestore backups list --location=europe-west3 --project=butlery-app-1
```

**`--location` gotcha:** managed backups live in the DATABASE's region. `--location=eur3`
returns an empty list and looks exactly like "no backups exist"; `--location=europe-west3`
lists them. Always use the long form here.

Restore from a managed backup goes to a NEW database, never over `(default)`:

```bash
gcloud firestore databases restore \
  --source-backup=projects/butlery-app-1/locations/europe-west3/backups/BACKUP_ID \
  --destination-database=recovery-YYYYMMDD --project=butlery-app-1
```

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
# Bucket MUST live in the same region as Firestore — keep exports in-region for GDPR.
# The decision region is europe-west1, but a 2026-05 audit saw gcloud report
# europe-west3 (see status table + BUT-819). VERIFY the live region with the
# describe command above and set --location to match it before creating the bucket.
gcloud storage buckets create gs://butlery-firestore-backups \
  --project=butlery-app-1 \
  --location=europe-west1 \
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
  --location=europe-west1 \
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
  --location=europe-west1

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
  --location=europe-west1 \
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

Measured 2026-08-13, not estimated. Sizes come from Cloud Monitoring
(`firestore.googleapis.com/storage/*_storage_bytes`), prices from
cloud.google.com/firestore/pricing with the location selector on Frankfurt (europe-west3),
which is dearer than the US default tier ($0.039 vs $0.03 per GiB-month for backup data).

- Live database, data + indexes: **21,543,874 B = 0.0201 GiB**
- One managed backup: **21,565,621 B = 0.0201 GiB** (a backup is a full copy)

| Line item | Monthly cost |
|---|---|
| Managed daily backups — 7 retained at a time, 0.141 GiB total × $0.039 | **$0.0055** |
| PITR storage (7-day window, 0.0201 GiB) | < $0.01 |
| Weekly GCS export (2.24 MiB, one copy retained) | < $0.01 |
| Scheduler job (1 exec/week) | $0 (free tier) |
| **Total** | **~$0.02/month (≈0.2 kr)** |

Backup storage is billed prorated by the fraction of the month each backup is retained, so
7-day retention costs 7/30 of a GiB-month per backup — already reflected above by counting
the 7 backups alive at any moment. Backups are **excluded from the Firestore free tier**,
and creating one costs no document reads.

Sensitivity: cost scales linearly with database size. At 100× today's data (2 GiB) the
daily-backup line is still only ~$0.55/month.

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
