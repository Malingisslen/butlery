# Firestore Backups & Disaster Recovery

**Status: ACTIVE — PITR enabled, managed daily backups (7-day retention), managed weekly
backups (14-week retention).**

Operational runbook for Firestore data protection in `butlery-app-1`.

---

## Why this matters

Without PITR (Point-in-Time Recovery) or scheduled exports, any accidental delete, bad
Cloud Function, or malicious write is permanent. Recovery Point Objective (RPO) is
effectively **infinite** — we cannot restore yesterday's state.

After the runbook is executed:
- **RPO:** 7 days (PITR window) for accidental data loss up to 7 days old
- **RPO:** 1 day (managed daily backups) up to 7 days back, then 7 days (managed weekly
  backups) out to 14 weeks
- **RTO:** < 1 hour for PITR or managed-backup restore to a sibling database

---

## Current status (verified against live GCP 2026-09-12)

Every row below was read off the live project on the date in its Status cell; the command
that proves it is in the Evidence column. Do not edit a row without re-running its command.

| Control | Status | Evidence |
|---|---|---|
| PITR enabled | ENABLED — 7-day window | `gcloud firestore databases describe`: `pointInTimeRecoveryEnablement: POINT_IN_TIME_RECOVERY_ENABLED`, `versionRetentionPeriod: 604800s` |
| Managed daily backup schedule | ACTIVE since 2026-08-11 — daily, 7-day retention | `gcloud firestore backups schedules list --database='(default)'`: one schedule, `dailyRecurrence: {}`, `retention: 604800s` |
| Managed weekly backup schedule | ACTIVE since 2026-09-12 — Sundays, 14-week retention | `gcloud firestore backups schedules list --database='(default)'`: `weeklyRecurrence: {day: SUNDAY}`, `retention: 8467200s` |
| Managed backups on disk | 7 READY (daily snapshots 2026-09-06 through 2026-09-12) on 2026-09-12 | `gcloud firestore backups list --location=europe-west3` |
| Weekly GCS export | **RETIRED 2026-09-12** — Scheduler job `firestore-weekly-export` deleted, replaced by the managed weekly schedule above | `gcloud scheduler jobs list --location=europe-west3` returns 0 items |
| Backup bucket | EXISTS and is EMPTY — `gs://butlery-firestore-backups`, **europe-west3** | `gcloud storage buckets describe`: `location: EUROPE-WEST3`. No longer a scheduled-export target; kept only for the manual incident snapshot below |
| Retention policy (bucket) | 30 days auto-delete — CONFIRMED live 2026-09-12 | `buckets describe` returns the `Delete`/`age: 30` lifecycle rule |
| Firestore region | **europe-west3 (Frankfurt, EU)** — data; compute pinned to europe-west1 | Resolved in **BUT-819**, 2026-06-14. The EU-region split is **accepted** (both EU → GDPR satisfied). |
| Restore drill | PASSED 2026-08-29 — restored to a scratch database, contents matched, database deleted | `gcloud firestore databases restore --source-backup=.../90760cc7-4053-429a-a9b0-33ba4a58a232 --destination-database=restore-drill-20260829` → operation `SUCCESSFUL` 100%. Row counts in the restored database matched production exactly: users 2, conversations 1, chat_groups 0, `collectionGroup('recipes')` 8. Drill database deleted the same day (`databases list` returns only `(default)`). BUT-880 |

⚠️ A live `reset-user-data` run pauses every enabled Cloud Scheduler job for its duration
and resumes it afterwards. The backup schedules on this page are **not** Scheduler jobs, so
that pause does not reach them. See `docs/ops/reset-user-data-runbook.md`.

⚠️ Why the GCS export was retired (BUT — 2026-09-12): the Scheduler job posted a fixed
`outputUriPrefix` of `gs://butlery-firestore-backups/weekly`, and the Firestore export API
REFUSES a prefix it has already written — `Path already exists:
/butlery-firestore-backups/weekly/weekly.overall_export_metadata`, `INVALID_ARGUMENT`. Every
run failed from at least 2026-08-16 (the oldest surviving Scheduler log) until the 30-day
lifecycle rule deleted the one surviving export, after which a run would have succeeded and
the weekly failures would have resumed. Cloud Scheduler cannot compute a date, so a unique
per-run prefix would have required new code. The managed weekly schedule gives the same
depth — more, 14 weeks against 30 days — with no code, no bucket and no Scheduler job.
**What it costs:** a managed backup restores only into a Firestore database in this project;
it is not a set of files that can be carried off-platform the way a GCS export is.

⚠️ The 2026-08-29 restore drill proves the MECHANISM, not the timing. It ran against 2
users and 8 recipes, so it says nothing about how long a restore takes at real volume —
the RTO figures in `DISASTER_RECOVERY.md` are still theoretical. Re-run the drill after
launch to replace them with a measured number.

---

## Managed backups (the Firestore-native feature)

Firestore takes and stores these itself: no bucket, no Scheduler job, no IAM wiring. Two
schedules run, and together they are the whole depth story beyond PITR — daily for the
first week, weekly out to 14 weeks.

Both already created — do **not** run a create command again, each one would add another
schedule and another storage bill.

```bash
# Create (already done — kept for disaster rebuild):
gcloud firestore backups schedules create \
  --database='(default)' --project=butlery-app-1 \
  --recurrence=daily --retention=7d

gcloud firestore backups schedules create \
  --database='(default)' --project=butlery-app-1 \
  --recurrence=weekly --day-of-week=SUN --retention=14w

# Verify — the schedules (no --location flag on this one):
gcloud firestore backups schedules list --database='(default)' --project=butlery-app-1

# Verify — the backups those schedules have actually produced:
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

### 3. Create the backup schedules

```bash
gcloud firestore backups schedules create \
  --database='(default)' --project=butlery-app-1 \
  --recurrence=daily --retention=7d

gcloud firestore backups schedules create \
  --database='(default)' --project=butlery-app-1 \
  --recurrence=weekly --day-of-week=SUN --retention=14w
```

Backups land in the DATABASE's region (europe-west3), so there is nothing to place and no
cross-region question to answer.

### 4. Create the incident-snapshot bucket

Not part of any schedule — this is only the destination for the manual export under
"Incident notification" below.

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

### 5. Apply 30-day lifecycle retention

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

### 6. Grant the Firestore service account write access

```bash
# Firestore uses a Google-managed service account for exports.
# Project number is visible in the GCP console; replace PROJECT_NUMBER below.
PROJECT_NUMBER=$(gcloud projects describe butlery-app-1 --format='value(projectNumber)')

gcloud storage buckets add-iam-policy-binding gs://butlery-firestore-backups \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-firestore.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### 7. Verify

```bash
gcloud firestore backups schedules list --database='(default)' --project=butlery-app-1
gcloud firestore backups list --location=europe-west3 --project=butlery-app-1
```

**Do not rebuild a scheduled GCS export here.** One existed from 2026-04-24 to 2026-09-12
and was retired; the status table says why. A scheduled export needs a unique
`outputUriPrefix` per run, and Cloud Scheduler cannot compute one — anyone rebuilding it
needs code that does, not another static `--message-body`.

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

### Scenario 2: Older than 7 days (use a managed backup)

```bash
# Identify the backup to restore from — daily snapshots cover the last 7 days,
# Sunday snapshots the last 14 weeks:
gcloud firestore backups list --location=europe-west3 --project=butlery-app-1

# Restore to a NEW database (never into production):
gcloud firestore databases restore \
  --source-backup=projects/butlery-app-1/locations/europe-west3/backups/BACKUP_ID \
  --destination-database=recovery-YYYYMMDD --project=butlery-app-1
```

Then migrate the affected data back into `(default)` via a controlled script.

### Scenario 3: Catastrophic loss

Full restore into a new default database is the last resort. Coordinate with the
user before doing this — it requires app downtime and communicating with users about
data losses between the snapshot and the incident.

---

## Retention policy

- **PITR:** 7 days (Firestore default, not configurable)
- **Managed daily backups:** 7 days
- **Managed weekly backups:** 14 weeks (Sundays)
- **Incident-specific exports:** the bucket's 30-day lifecycle rule deletes them; copy to a
  separate non-lifecycle bucket before that window expires if the incident is still under
  investigation

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
| Managed weekly backups — 14 retained at a time, 0.281 GiB total × $0.039 | **$0.011** |
| PITR storage (7-day window, 0.0201 GiB) | < $0.01 |
| **Total** | **~$0.02/month (≈0.2 kr)** |

The weekly line is arithmetic off the same measured backup size, not a separate
measurement — 14 backups alive at a time, once the schedule has been running 14 weeks.

Backup storage is billed prorated by the fraction of the month each backup is retained, so
7-day retention costs 7/30 of a GiB-month per backup — already reflected above by counting
the backups alive at any moment. Backups are **excluded from the Firestore free tier**,
and creating one costs no document reads.

Sensitivity: cost scales linearly with database size. At 100× today's data (2 GiB) the two
backup lines are ~$0.55 and ~$1.10/month.

---

## Storage versioning

Firestore PITR + managed backups cover the structured-data DR tier. Cloud
Storage (recipe images, avatars, OCR uploads) has its own independent
recovery story — object versioning + a 30-day noncurrent-version lifecycle —
documented in `docs/ops/storage-lifecycle-runbook.md` (BUT-419). The two tiers no longer
share a retention window: Firestore reaches 14 weeks back, Storage 30 days.

---

## Related Linear tickets

- BUT-418 — this runbook's parent ticket (Urgent, launch-readiness)
- BUT-419 — sibling Cloud Storage versioning + lifecycle (`storage-lifecycle-runbook.md`)
- BUT-607 — EU data residency verification (shares the region decision in step 3)
