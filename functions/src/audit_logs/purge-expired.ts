/**
 * BUT-665 — Audit log retention purge.
 *
 * Per `docs/security/audit-logs-retention.md`:
 *   - Consent events (the CONSENT_OPERATIONS enumeration below — the
 *     `consent_` spelling is a naming convention, not the filter) → 24 months
 *     (GDPR Art 7(1) — must be able to demonstrate consent).
 *   - All other events → 6 months retention (Art 5(1)(c) data
 *     minimisation + SOC2-style incident-response window).
 *
 * Schedule: Sunday 05:00 UTC, region `europe-west1`. Idempotent — a
 * same-day re-run finds zero documents past the cutoff and is a no-op.
 *
 * Since BUT-808, `audit_logs` is purged EXCLUSIVELY here. `cleanupOldAuditLogs`
 * (`cleanup/cleanup-audit-logs.ts`) handles only `deletion_audit_logs` now; it
 * keeps its old export name so the deployed scheduler binding does not churn,
 * which is why it still reads like a second purge of this collection and is
 * not one. It formerly applied a flat 90-day Remote Config default here, two
 * hours earlier on the same Sunday schedule, silently defeating the 730-day
 * consent retention.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

/** Days. 24 months ≈ 730 days. Picked to cover any in-flight Art 7(1)
 *  challenge across a typical complaint-resolution horizon. */
export const CONSENT_RETENTION_DAYS = 730;

/** Days. 6 months. Aligns with industry MTTD for cloud incidents. */
export const GENERAL_RETENTION_DAYS = 180;

/** The naming convention consent operations follow.
 *
 *  NOT the filter. Until BUT-1404 (2026-06-28) the purge classified rows with
 *  `startsWith(CONSENT_OPERATION_PREFIX)`, and this docblock still said so for
 *  46 days afterwards — which is how `consent_deleted` came to be mis-bucketed
 *  without anyone reading a contradiction. `CONSENT_OPERATIONS` below IS the
 *  filter, exhaustively; this constant is referenced only by the test. */
export const CONSENT_OPERATION_PREFIX = "consent_";

/**
 * Exhaustive enumeration of every known `consent_*` operation value written
 * to `audit_logs`. Used for the server-side `in` / `not-in` Firestore filter
 * so the limit(maxDocs) window is scoped to the right retention class BEFORE
 * docs are fetched — fixing the starvation bug (BUT-1404) where the unfiltered
 * query window fills with long-lived consent rows and leaves expired general
 * rows unpurged.
 *
 * IMPORTANT: Whenever a new `consent_*` operation is introduced in the write
 * path, add it here AND bump this comment's date so the diff is reviewable.
 * Sources:
 *   - account/verify-signup-age.ts  → "consent_age_verification"
 *   - lib/repositories/firebase/firebase_consent_repository.dart
 *     → "consent_updated" (saveConsent, LIVE) and "consent_revoked"
 *       (deleteConsent, which has had no caller since BUT-788, 2026-05-22 —
 *       listed so the spelling is already classified when one is wired)
 *   - LEGACY, no live writer: "consent_granted" has never been written by any
 *     Dart or TS code; "consent_deleted" was written by deleteConsent between
 *     BUT-498 (2026-04-27) and BUT-788 (2026-05-22), when the client-side
 *     deletion path existed, and rows from that window are still in
 *     audit_logs. Both stay listed — dropping a legacy token silently
 *     reclassifies existing rows into the 180-day bucket. "consent_deleted"
 *     becomes droppable once its youngest row passes 730 days, i.e. after
 *     2028-05-22; before that date, removing it deletes evidence.
 * Last audited: 2026-08-13.
 *
 * Firestore `not-in` supports up to 10 values; if this list exceeds 10,
 * switch to a `retentionTier` field on new writes + backfill (ops-blocked).
 */
export const CONSENT_OPERATIONS: readonly string[] = [
  "consent_age_verification",
  "consent_granted",
  "consent_updated",
  "consent_revoked",
  "consent_deleted",
] as const;

const BATCH_SIZE = 200;
const MAX_DOCS_PER_RUN_PER_CATEGORY = 10000;

interface PurgeCategoryResult {
  category: "consent" | "general";
  deleted: number;
  cutoffIso: string;
  truncated: boolean;
}

/**
 * Pure helper extracted for unit testing — no Firebase imports beyond the
 * injected `db`. Tests pass a fake-admin shape that mirrors the calls used
 * here (`collection().where()...get()`, `batch().delete()/commit()`).
 *
 * Deletes audit_logs in `category` ("consent" | "general") older than
 * `cutoff`. Returns the count deleted.
 */
export async function purgeAuditCategoryWithDb(
  db: admin.firestore.Firestore,
  category: "consent" | "general",
  cutoff: admin.firestore.Timestamp,
  options: { batchSize?: number; maxDocs?: number } = {}
): Promise<number> {
  const batchSize = options.batchSize ?? BATCH_SIZE;
  const maxDocs = options.maxDocs ?? MAX_DOCS_PER_RUN_PER_CATEGORY;

  const auditLogs = db.collection("audit_logs");

  // Server-side filter by retention class so limit(maxDocs) applies only to
  // the docs we actually intend to delete. This closes the BUT-1404 starvation
  // bug: the previous implementation fetched the oldest 10k docs unfiltered,
  // then filtered client-side — over time that window filled with long-lived
  // consent rows (730d retention) leaving expired general docs (180d) unpurged.
  //
  // Requires a composite index on (operation ASC, timestamp ASC) — see
  // firestore.indexes.json.
  //
  // Admin SDK 13+ / Firestore multi-inequality support allows combining `in` /
  // `not-in` on `operation` with a range (`<`) on `timestamp` in the same
  // query.
  const operationFilter =
    category === "consent"
      ? auditLogs.where(
          "operation",
          "in",
          CONSENT_OPERATIONS as string[]
        )
      : auditLogs.where(
          "operation",
          "not-in",
          CONSENT_OPERATIONS as string[]
        );

  const snapshot = await operationFilter
    .where("timestamp", "<", cutoff)
    .limit(maxDocs)
    .get();

  if (snapshot.empty) return 0;

  // All docs in the snapshot are already in the correct retention class —
  // no client-side filtering needed.
  const matching = snapshot.docs;

  let deleted = 0;
  let batch = db.batch();
  let batchCount = 0;
  for (const doc of matching) {
    batch.delete(doc.ref);
    batchCount++;
    deleted++;
    if (batchCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }
  if (batchCount > 0) await batch.commit();

  return deleted;
}

function cutoffFor(daysAgo: number): admin.firestore.Timestamp {
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  return admin.firestore.Timestamp.fromDate(date);
}

export const purgeExpiredAuditLogs = onSchedule(
  {
    schedule: "0 5 * * 0",
    timeZone: "UTC",
    region: "europe-west1",
  },
  async () => {
    const db = admin.firestore();

    const consentCutoff = cutoffFor(CONSENT_RETENTION_DAYS);
    const generalCutoff = cutoffFor(GENERAL_RETENTION_DAYS);

    logger.info(
      `[purgeExpiredAuditLogs] starting — consentCutoff=${consentCutoff
        .toDate()
        .toISOString()} generalCutoff=${generalCutoff.toDate().toISOString()}`
    );

    const results: PurgeCategoryResult[] = [];

    try {
      // Order matters: do general (6mo cutoff) FIRST. Its query window
      // is wider but its filter excludes consent events, so consent docs
      // older than 6mo are left for the consent-category run below.
      const generalDeleted = await purgeAuditCategoryWithDb(
        db,
        "general",
        generalCutoff
      );
      results.push({
        category: "general",
        deleted: generalDeleted,
        cutoffIso: generalCutoff.toDate().toISOString(),
        truncated: generalDeleted >= MAX_DOCS_PER_RUN_PER_CATEGORY,
      });

      const consentDeleted = await purgeAuditCategoryWithDb(
        db,
        "consent",
        consentCutoff
      );
      results.push({
        category: "consent",
        deleted: consentDeleted,
        cutoffIso: consentCutoff.toDate().toISOString(),
        truncated: consentDeleted >= MAX_DOCS_PER_RUN_PER_CATEGORY,
      });

      // Observability — one row in system_events per run.
      await db.collection("system_events").add({
        type: "audit_log_retention_purge",
        results,
        executedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const r of results) {
        logger.info(
          `[purgeExpiredAuditLogs] category=${r.category} deleted=${r.deleted} cutoff=${r.cutoffIso} truncated=${r.truncated}`
        );
      }
    } catch (e) {
      logger.error("[purgeExpiredAuditLogs] failed", e);
      throw e;
    }
  }
);
