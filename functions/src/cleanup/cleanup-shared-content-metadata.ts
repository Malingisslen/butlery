/**
 * Shared Content Metadata TTL Cleanup Cloud Function
 *
 * Scheduled to run weekly on Saturday at 4 AM UTC to delete old metadata
 * subcollection documents (views, engagements, dismissals) from shared content.
 *
 * Subcollection paths cleaned:
 * - shared_content/{id}/views
 * - shared_content/{id}/engagements
 * - shared_content/{id}/dismissals
 *
 * The app writes each row with an `expireAt`; this job is the backstop for
 * rows that carry none.
 *
 * TTL: 90 days (metadata older than this has no analytical value)
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

const DEFAULT_TTL_DAYS = 90;
const BATCH_LIMIT = 500;
export const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000; // 8 minutes (leave 1 min margin)
const TIMEOUT_SECONDS = 540;

const METADATA_SUBCOLLECTIONS = ["views", "engagements", "dismissals"];

/**
 * Weekly cleanup of expired shared content metadata subcollections.
 *
 * Schedule: 0 4 * * 6 (Saturday at 4 AM UTC)
 *
 * The scheduler wrapper just delegates to `cleanupSharedContentMetadataCore`
 * so the logic can be exercised against a real Firestore emulator in
 * integration tests.
 */
export const cleanupSharedContentMetadata = onSchedule(
  { schedule: "0 4 * * 6", timeZone: "UTC", timeoutSeconds: TIMEOUT_SECONDS },
  async () => {
    await cleanupSharedContentMetadataCore(admin.firestore());
  }
);

/** Summary returned by the testable core so callers/tests can assert effects. */
export interface CleanupSharedContentMetadataResult {
  totalDeleted: number;
}

/**
 * Testable core for the shared-content-metadata TTL cleanup. Accepts an
 * injected Firestore so integration tests can point it at the emulator.
 * Returns a small summary.
 *
 * One collection-group query per subcollection on `timestamp < cutoff`, so a
 * run reads the expired rows and nothing else. A row whose parent is not a
 * `shared_content` document is skipped, and the cursor moves past it.
 */
export async function cleanupSharedContentMetadataCore(
  db: admin.firestore.Firestore
): Promise<CleanupSharedContentMetadataResult> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - DEFAULT_TTL_DAYS);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

  logger.info(
    `Starting shared content metadata cleanup (TTL: ${DEFAULT_TTL_DAYS} days, cutoff: ${cutoffDate.toISOString()})`
  );

  let totalDeleted = 0;
  const startTime = Date.now();

  for (const subcollection of METADATA_SUBCOLLECTIONS) {
    let cursor: admin.firestore.QueryDocumentSnapshot | null = null;
    let deleted = 0;
    let skipped = 0;
    for (;;) {
      if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
        logger.warn(
          `Approaching timeout — stopping cleanup for ${subcollection}. Will continue next run.`
        );
        break;
      }
      let query = db
        .collectionGroup(subcollection)
        .where("timestamp", "<", cutoffTimestamp)
        .orderBy("timestamp")
        .limit(BATCH_LIMIT);
      if (cursor) query = query.startAfter(cursor);

      const snapshot = await query.get();
      if (snapshot.empty) break;
      cursor = snapshot.docs[snapshot.docs.length - 1];

      const expired = snapshot.docs.filter(isUnderSharedContent);
      skipped += snapshot.size - expired.length;
      if (expired.length > 0) {
        const batch = db.batch();
        for (const doc of expired) batch.delete(doc.ref);
        await batch.commit();
        deleted += expired.length;
      }
      if (snapshot.size < BATCH_LIMIT) break;
    }
    // `skipped` counts expired rows under another parent, which every run
    // reads again; a non-zero count is residue this job does not reach.
    logger.info("shared_metadata_cleanup", { subcollection, deleted, skipped });
    totalDeleted += deleted;
  }

  logger.info(
    `Shared content metadata cleanup complete: deleted ${totalDeleted} expired entries`
  );

  return { totalDeleted };
}

function isUnderSharedContent(doc: admin.firestore.QueryDocumentSnapshot): boolean {
  const parent = doc.ref.parent.parent;
  return parent != null &&
    parent.parent.id === Collections.sharedContent &&
    parent.parent.parent === null;
}
