# Data Residency & Region Pin (BUT-774)

This doc captures the canonical regions for Butlery's Firebase + Cloud Functions
deployment. Code-level pins are verified against the source tree; the
Firestore database region (a console-only setting) was confirmed on 2026-06-14
to be `europe-west3` — see "Console-side state" and the accept decision below.

## Code-pinned regions (verified 2026-05-06)

All Cloud Functions and the Vertex AI client are pinned to `europe-west1`:

| Pin location | Region | Verified |
| ------------ | ------ | -------- |
| `functions/src/index.ts` `setGlobalOptions({ region })` | `europe-west1` | ✅ source-grep |
| `functions/src/llm/gemini-client.ts` `VERTEX_LOCATION` | `europe-west1` | ✅ source-grep |
| `functions/src/cleanup/on-user-deleted.ts` `.region(...)` | `europe-west1` | ✅ source-grep |
| `functions/src/audit_logs/purge-expired.ts` scheduler | `europe-west1` | ✅ source-grep |
| All BUT-770/BUT-778/BUT-780 callables/triggers | `europe-west1` | ✅ source-grep |

## Console-side state (verified 2026-06-14, BUT-819)

The Firestore database region is set via the Firebase Console (or `gcloud
firestore databases describe`) and is **not** in version control.
A 2026-05 infrastructure audit (finding CRIT-INFRA1) flagged a possible
mismatch with the code pin — which is confirmed:

```sh
# Resolves the region of the (default) Firestore database.
gcloud firestore databases describe --database='(default)' \
  --project=butlery-app-1 \
  --format='value(locationId)'
# → europe-west3
```

**Verified result: the (default) Firestore database is in `europe-west3`
(Frankfurt)** — i.e. it does NOT match the `europe-west1` code pins. This is a
real region split, resolved by the accept decision below. (Verified via the
Firebase Admin API; PITR is enabled and delete-protection was turned on the
same day.)

## Region topology: compute `europe-west1`, data `europe-west3` (accepted)

Decision (2026-06-14, BUT-819): **accept the split — do NOT migrate.** Cloud
Functions and the Vertex AI client stay pinned to `europe-west1`; the Firestore
database stays in `europe-west3`. Rationale:

- **Both are EU regions** → GDPR / data-residency requirements are satisfied
  either way; user data never leaves the EU.
- **The latency cost is negligible** — `europe-west1` (Belgium) and
  `europe-west3` (Frankfurt) are ~500 km apart, adding a few milliseconds per
  cross-region call, not the expensive cross-continent hop the pin exists to
  prevent.
- **A Firestore database cannot change region in place.** "Fixing" the split
  would mean a full export/import to a new database (Option A below) — a risky,
  high-effort migration for a negligible gain.
- Re-pinning compute to `europe-west3` instead (Option B) would touch nine code
  sites plus the cert-pin allow-list, again for negligible benefit.

So neither reconciliation path is worth executing; the split is the accepted
steady state.

## Mismatch handling (reference only — NOT being executed)

The mismatch is real (`europe-west3`), but the decision above is to **accept
the split**, so neither option below is being executed. They are retained for
reference in case a future requirement (e.g. a hard single-region mandate)
forces reconciliation.

If a future decision reverses the accept and requires a single region:

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
| 2026-06-14 | Console verified: Firestore is `europe-west3`, not `europe-west1`. **Accepted the compute(`west1`)/data(`west3`) split — no migration.** | BUT-819. Both EU regions → GDPR fine; cross-region latency negligible; in-place region change impossible. Delete-protection enabled the same day. |
