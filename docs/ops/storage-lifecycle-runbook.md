# Cloud Storage Versioning & Lifecycle (BUT-419)

**Status: PENDING — script ready, gcloud activation user-blocked.**

Operational runbook for object versioning + 30-day noncurrent-version retention
on the Butlery Firebase Storage bucket.

---

## Why this matters

Deleted recipe images, avatars, and OCR uploads have no recovery story without
object versioning — once a client `delete()` lands or a user overwrites a blob,
the previous bytes are gone. Object versioning preserves overwritten and
deleted objects as **noncurrent versions** for the lifecycle window; a single
`Restore` from the console (or a copy from the noncurrent generation) puts
them back.

Recovery target:

- **Recovery Point Objective (RPO):** 30 days for any image / OCR upload that
  was deleted or overwritten in Cloud Storage.
- **Recovery Time Objective (RTO):** seconds (single-object restore from the
  console) to minutes (bulk restore via `gcloud storage cp` with `#GENERATION`
  suffix).

Sister runbooks for the same DR tier:

- `docs/ops/backups.md` — Firestore PITR + weekly GCS exports (BUT-418).
- `docs/ops/gcp-alerting-runbook.md` — GCP alerting policies (BUT-450, same
  fail-loud script pattern).

---

## Prerequisites

- `gcloud` CLI installed and authenticated:
  ```bash
  gcloud auth login
  gcloud config set project butlery-app-1
  ```
- The bucket name. Open Firebase Console → Storage; the **Files** tab shows
  the canonical bucket reference. Newer Firebase projects (created after
  late 2024) use the `<project>.firebasestorage.app` domain — for Butlery
  this is `butlery-app-1.firebasestorage.app`. Older projects still use
  `<project>.appspot.com`. Confirm against `lib/firebase_options.dart`
  (`storageBucket` field) — the live bucket name is whatever the SDK uses.
  Do NOT use the project ID by itself.
- IAM: the executing principal needs `roles/storage.admin` on the bucket (or
  on the project). The Firebase Owner role covers this.

---

## Run instructions

```bash
# From repo root, on a maintainer workstation with gcloud authenticated.
export STORAGE_BUCKET=butlery-app-1.firebasestorage.app
./infrastructure/storage/setup-storage-versioning.sh
```

The script:

1. Enables object versioning on the bucket
   (`gcloud storage buckets update gs://${STORAGE_BUCKET} --versioning`).
2. Writes a temporary lifecycle JSON (30-day noncurrent-version delete) and
   applies it with `--lifecycle-file=...`.
3. Re-reads the bucket via `gcloud storage buckets describe` and exits non-zero
   if either policy isn't visible — fails loud if any step silently no-oped.

The `STORAGE_BUCKET` env var uses bash `:?` expansion, so omitting it aborts
the script before any gcloud call lands. Same fail-loud pattern as
`infrastructure/alerting/setup-gcp-alerts.sh` (BUT-450).

---

## Lifecycle policy applied

```json
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
```

- `isLive: false` — the rule applies **only** to noncurrent versions. Current
  (live) objects are never auto-deleted by this rule.
- `age: 30` — days since the version became noncurrent (i.e. since it was
  overwritten or "deleted"). Matches the Firestore export retention window
  (`docs/ops/backups.md`) so the DR window is uniform across data tiers.

---

## Verification

After the script reports OK:

1. **Firebase Console** → Storage → your bucket → **Rules** / **Files** tabs.
   The Versioning indicator on the bucket details panel should read
   *Enabled*. Lifecycle policy is visible under
   `https://console.cloud.google.com/storage/browser/<bucket>;tab=lifecycle`.
2. **CLI re-check** (optional, paranoid):
   ```bash
   gcloud storage buckets describe "gs://${STORAGE_BUCKET}" \
     --format='value(versioning.enabled, lifecycle.rule[0].action.type)'
   # Expected output: True   Delete
   ```
3. **Manual smoke** (fresh project only — skip if production has user data):
   - Upload a small object, overwrite it, delete the live version.
   - Run `gcloud storage ls -a gs://${STORAGE_BUCKET}/<path>` — the noncurrent
     generation must be visible.

---

## Rollback

If versioning needs to be disabled (storage cost spike, never expected to be
needed unless a regulator forces immediate-erasure mode that conflicts with
the 30-day window):

```bash
gcloud storage buckets update "gs://${STORAGE_BUCKET}" --no-versioning
```

Important nuance: **existing noncurrent versions still age out per the
lifecycle rule** even after versioning is turned off. New deletes will no
longer create noncurrent versions, but the historical 0..30-day backlog
remains until the lifecycle rule reaps it. To purge immediately, list
noncurrent generations and `gcloud storage rm` them by `#GENERATION` ID:

```bash
gcloud storage ls -a "gs://${STORAGE_BUCKET}/**" \
  | grep '#' \
  | xargs -I {} gcloud storage rm "{}"
```

(Be careful — that will permanently delete every noncurrent version. There is
no undo.)

---

## Cost estimate

| Line item | Estimate |
|---|---|
| Versioning storage (~30d of churn, low — image overwrites are rare) | < $1/mo |
| Lifecycle delete operations | $0 (free tier covers it) |
| **Total** | **negligible** |

If a future feature starts churning images at scale (e.g. an editor that
re-uploads thumbnails on every save), revisit the 30-day window and consider
tightening to 7d.

---

## GDPR considerations

Right-to-erasure cascade lives in
`functions/src/cleanup/on-user-deleted.ts`. When a user deletes their account,
the cascade `gsutil rm`-equivalent already targets the live versions of their
storage paths. **With versioning enabled, those deletes create noncurrent
versions that linger up to 30 days.** Two options:

1. **Accepted (current default):** the 30-day window is the same retention we
   hold for Firestore exports, and the user-deletion record itself is
   deleted from Firestore — the storage objects without an owning user are
   unrecoverable from the app surface. Treat the 30-day storage tail as the
   same DR tier as Firestore PITR.
2. **Strict erasure:** extend `on-user-deleted` to do a generation-aware
   `gcloud storage rm` of every noncurrent version under that user's prefix.
   File a follow-up ticket if a DPA or regulator requires it; current
   posture is option 1.

---

## Activation status

**Activated 2026-04-26 on `gs://butlery-app-1.firebasestorage.app`.**
Versioning enabled + 30-day noncurrent-version delete lifecycle in effect.
Verified via `gcloud storage buckets describe` — `versioning_enabled=True`,
`lifecycle_config.rule[0]={action:Delete, age:30, isLive:false}`.

The bucket also has a 7-day soft-delete policy (Firebase Storage default
since 2024) layered underneath — recovery window is now effectively 30 days
for overwrites and deletes. Script is idempotent: re-running it is safe and
re-applies the same policies.

## Related Linear tickets

- BUT-419 — this runbook's parent ticket. **Closed 2026-04-26.**
- BUT-418 — sibling DR pattern for Firestore (PITR + GCS exports).
- BUT-450 — sibling fail-loud script pattern for GCP alerting.
