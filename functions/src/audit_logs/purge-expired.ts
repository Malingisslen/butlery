/**
 * BUT-665 — Audit log retention purge.
 *
 * Per `docs/security/audit-logs-retention.md`:
 *   - Consent events (operation prefix `consent_`) → 24 months retention
 *     (GDPR Art 7(1) — must be able to demonstrate consent).
 *   - All other events → 6 months retention (Art 5(1)(c) data
 *     minimisation + SOC2-style incident-response window).
 *
 * Schedule: Sunday 05:00 UTC, region `europe-west1`. Idempotent — a
 * same-day re-run finds zero documents past the cutoff and is a no-op.
 *
 * Co-exists (for now) with the legacy `cleanupOldAuditLogs` CF in
 * `cleanup/cleanup-audit-logs.ts` which applies a flat 90-day default
 * sourced from Remote Config. The legacy CF will be retired once this
 * one has been observed in prod for a full retention cycle (tracked
 * separately).
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

/** Days. 24 months ≈ 730 days. Picked to cover any in-flight Art 7(1)
 *  challenge across a typical complaint-resolution horizon. */
export const CONSENT_RETENTION_DAYS = 730;

/** Days. 6 months. Aligns with industry MTTD for cloud incidents. */
export const GENERAL_RETENTION_DAYS = 180;

/** Operation values that count as consent events for retention purposes.
 *  Matched as `startsWith('consent_')` in code; this list is informational
 *  and used by the test for exhaustiveness. Keep in sync with
 *  `lib/repositories/firebase/firebase_consent_repository.dart`. */
export const CONSENT_OPERATION_PREFIX = "consent_";

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

  // Fire two queries: one for the category bucket, one excluding it. We
  // can't use `>=` / `startsWith` on `operation` while ordering by
  // timestamp without a composite index per category, so split:
  //   - "consent": operation in known consent operations
  //   - "general": operation NOT in consent operations
  //
  // Firestore doesn't have NOT-IN against a prefix; for general-category
  // we instead query by timestamp < cutoff, then filter consent events
  // out client-side. Same pattern as `cleanup-old-notifications`. The
  // resulting batch is small enough (≤ maxDocs) that the in-memory
  // filter is acceptable.
  const snapshot = await auditLogs
    .where("timestamp", "<", cutoff)
    .limit(maxDocs)
    .get();

  if (snapshot.empty) return 0;

  const matching = snapshot.docs.filter((doc) => {
    const op = (doc.data().operation as string | undefined) ?? "";
    const isConsent = op.startsWith(CONSENT_OPERATION_PREFIX);
    return category === "consent" ? isConsent : !isConsent;
  });

  if (matching.length === 0) return 0;

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
