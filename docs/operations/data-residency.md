# Data Residency & Region Pin (BUT-774)

This doc captures the canonical region for Butlery's Firebase + Cloud Functions
deployment. Code-level pins are verified against the source tree; the
Firestore database region is a console-only setting that ops must confirm.

## Code-pinned regions (verified 2026-05-06)

All Cloud Functions and the Vertex AI client are pinned to `europe-west1`:

| Pin location | Region | Verified |
| ------------ | ------ | -------- |
| `functions/src/index.ts` `setGlobalOptions({ region })` | `europe-west1` | ✅ source-grep |
| `functions/src/llm/gemini-client.ts` `VERTEX_LOCATION` | `europe-west1` | ✅ source-grep |
| `functions/src/cleanup/on-user-deleted.ts` `.region(...)` | `europe-west1` | ✅ source-grep |
| `functions/src/audit_logs/purge-expired.ts` scheduler | `europe-west1` | ✅ source-grep |
| All BUT-770/BUT-778/BUT-780 callables/triggers | `europe-west1` | ✅ source-grep |

## Console-side state (TODO for ops)

The Firestore database region is set via the Firebase Console (or `gcloud
firestore databases describe`) and is **not** in version control. The
master-audit ticket (`MASTER-wave2.md` CRIT-INFRA1) flagged a possible
mismatch with the code pin. To verify and reconcile:

```sh
# Resolves the region of the (default) Firestore database.
gcloud firestore databases describe --database='(default)' \
  --project=butlery-app \
  --format='value(locationId)'
```

If the output is `europe-west1` — no action; everything aligns.

If the output is `europe-west3` (or anything else) — see "Mismatch handling"
below.

## Canonical region: `europe-west1`

Decision: keep `europe-west1` as the canonical region. Rationale:

- All code is already pinned there.
- `europe-west1` (Belgium) is one of the original Firestore regions and has
  full feature support (PITR, scheduled backups, Vertex AI).
- The codebase has nine independent pins to `europe-west1`; migrating to
  another region would require touching every one of them plus a Firestore
  data migration.

## Mismatch handling

If `gcloud firestore databases describe` returns a region different from
`europe-west1`:

**Option A — migrate Firestore to europe-west1** (preferred when the data
volume is small):

1. Export the database to GCS:
   `gcloud firestore export gs://butlery-app-firestore-export --async`
2. Create a new database in `europe-west1`:
   `gcloud firestore databases create --location=europe-west1`
3. Import the export into the new database.
4. Update DNS/SDK config + redeploy.

**Option B — keep the existing region, repin code** (preferred when data
volume makes export/import expensive):

1. Decide on the existing region as the new canonical (e.g. `europe-west3`).
2. Update every entry in the table above + `lib/`, then redeploy.
3. Re-run cert-pin runbook (`docs/operations/cert-pin-rotation.md`) — Vertex
   AI endpoint hostname changes per region, so the pin allow-list may need
   updating.

Either path is a separate ticket (significantly more work than a doc edit).
This ADR exists to declare the canonical region; the migration sprint is
follow-up.

## Related ops tasks (not in this ADR's scope)

- **PITR backup drill.** Take a snapshot, wait, restore to a non-prod
  project, capture RTO/RPO. Tracked separately because it requires
  production/staging access. Originally folded into this ticket; split out
  to keep this artifact focused on the residency decision.
- **`docs/operations/backups.md`.** Will land alongside the drill — the
  drill output (timings, command-by-command transcript) is its content,
  which we don't have until ops runs the drill.
- **CI cron-check.** A scheduled CF that compares the configured backup
  region to the Firestore region and fails loud on drift. Defer to a
  follow-up ticket once the canonical region is console-verified.

## Bump history

| Date       | Decision | Notes |
| ---------- | -------- | ----- |
| 2026-05-06 | Canonical region: `europe-west1` (code-verified). Console verification deferred to ops. | BUT-774. Three doc paths cited in the original ticket (`audit-logs-retention.md`, `data-residency.md`, `backups.md`) didn't exist; this doc replaces the residency one and the other two were never created — backups doc waits for the drill. |
