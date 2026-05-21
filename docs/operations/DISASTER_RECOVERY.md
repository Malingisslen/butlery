# Disaster Recovery Runbook (BUT-452)

This runbook covers recovering Butlery from data loss or major Firebase
outage. Companion docs: `backups.md` (backup configuration), `data-residency.md`
(canonical region: `europe-west1`), `DEPLOY_ROLLBACK.md` (config rollback).

## Recovery scope

| Scenario | Tier | RTO target | Procedure |
| -------- | ---- | ---------- | --------- |
| Accidental document delete (single user) | T1 | < 1h | PITR point-in-time read |
| Collection drop / mass corruption | T0 | < 4h | PITR restore to new database |
| Region outage (Firestore down) | T0 | wait | None — Firestore is multi-zone within region; Google handles |
| Auth user store corruption | T1 | < 2h | Auth export/import (see §3) |
| Storage object loss | T2 | best-effort | Object-versioning recovery (if enabled) |

> **Drill status:** Restore drill NOT YET PERFORMED. CRIT-INFRA1 follow-up
> ticket tracks running a real drill against a non-prod project. Until then
> RTO numbers above are **theoretical, not validated**.

## 1. PITR point-in-time read (T1)

Firestore PITR retains the last 7 days. Use this for recovering a small
number of documents the user accidentally deleted.

```sh
PROJECT=butlery-app-1
# ISO-8601 timestamp within the last 7 days.
RECOVER_TIME="2026-05-20T14:00:00Z"

# Read the doc as it existed at RECOVER_TIME (does NOT restore — read-only).
gcloud firestore documents read \
  --project=$PROJECT \
  --read-time=$RECOVER_TIME \
  "projects/$PROJECT/databases/(default)/documents/users/<UID>"
```

Then manually re-create the document via the admin SDK or Console.

## 2. PITR restore to new database (T0)

Use this when a collection is mass-corrupted or accidentally dropped.

```sh
PROJECT=butlery-app-1
RECOVER_TIME="2026-05-20T14:00:00Z"
TARGET_DB=butlery-recover-$(date +%s)

# 1. Restore a snapshot to a NEW database (does not touch (default)).
gcloud firestore databases restore \
  --project=$PROJECT \
  --source-database=projects/$PROJECT/databases/\(default\) \
  --destination-database=$TARGET_DB \
  --snapshot-time=$RECOVER_TIME

# 2. Verify TARGET_DB has the expected data via the Console.
# 3. Re-point the app: only when verified. Switching the (default) database
#    requires a code change (FirebaseFirestore.instanceFor(database: ...))
#    AND a coordinated client release. Not a same-hour operation.
```

**Reality check:** Restoring to `(default)` is a one-way migration. Always
restore to a side database first, validate, then plan the cut-over.

## 3. Auth export / import

Firebase Auth has no PITR. Daily exports live in Cloud Storage (configure
via `backups.md`).

```sh
PROJECT=butlery-app-1
BUCKET=gs://$PROJECT-auth-backups
# Find the latest export
gsutil ls $BUCKET/ | sort | tail -3

# Import (overwrites users with matching UIDs).
firebase auth:import auth-export-2026-05-20.json \
  --project=$PROJECT \
  --hash-algo=STANDARD_SCRYPT
```

**Caveat:** Auth import does NOT restore custom claims if the export was
created via `firebase auth:export` (which omits them). Custom claims for
admin-marked users live in `users/<uid>/custom_claims` — re-apply via Cloud
Functions admin path.

## 4. Storage object recovery

Object Versioning must be enabled on `<project>.appspot.com` (verify via
Console → Storage → Rules → Lifecycle). If enabled:

```sh
PROJECT=butlery-app-1
OBJECT=recipes/<recipe_id>/image.jpg

# List historical versions (generation IDs).
gsutil ls -a gs://$PROJECT.appspot.com/$OBJECT

# Restore a specific generation.
gsutil cp gs://$PROJECT.appspot.com/$OBJECT#<generation_id> \
          gs://$PROJECT.appspot.com/$OBJECT
```

## 5. Communications

After any T0 recovery: post-mortem within 72h using the template in
`INCIDENTS.md` §Post-mortem. Customer-facing comms drafted in the same doc.

## Validation checklist (after restore)

- [ ] Sample 5 known user UIDs — Firestore reads return expected data.
- [ ] Auth sign-in works for a test user (token refresh succeeds).
- [ ] Cloud Functions still deploy clean against the restored DB (try a
      no-op deploy to confirm region binding).
- [ ] Crashlytics shows no spike in `permission-denied` errors (rules drift
      can mask a region or DB rebind).
- [ ] Update `backups.md` with the drill date + measured RTO.
