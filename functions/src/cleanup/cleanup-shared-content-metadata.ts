/**
 * Shared Content Metadata TTL Cleanup Cloud Function
 *
 * Scheduled to run weekly on Saturday at 4 AM UTC to delete old metadata
 * subcollection documents (views, engagements, dismissals) from shared content.
 *
 * Subcollection paths cleaned:
 * - shared_recipes/{id}/views
 * - shared_recipes/{id}/engagements
 * - shared_recipes/{id}/dismissals
 * - shared_menus/{id}/views
 * - shared_menus/{id}/engagements
 * - shared_menus/{id}/dismissals
 * - shared_shopping_lists/{id}/views
 * - shared_shopping_lists/{id}/engagements
 * - shared_shopping_lists/{id}/dismissals
 *
 * TTL: 90 days (metadata older than this has no analytical value)
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

const DEFAULT_TTL_DAYS = 90;
const BATCH_LIMIT = 500;
const PARENT_CHUNK_SIZE = 100;
const MAX_EXECUTION_TIME_MS = 8 * 60 * 1000; // 8 minutes (leave 1 min margin)

const PARENT_COLLECTIONS = [
  Collections.sharedRecipes,
  "shared_menus",
  "shared_shopping_lists",
];

const METADATA_SUBCOLLECTIONS = ["views", "engagements", "dismissals"];

/**
 * Weekly cleanup of expired shared content metadata subcollections.
 *
 * Schedule: 0 4 * * 6 (Saturday at 4 AM UTC)
 *
 * The scheduler wrapper just delegates to `cleanupSharedContentMetadataCore`
 * so the logic can be exercised against a real Firestore emulator in
 * integration tests. Pure extraction of the former inline body — no logic
 * change.
 */
export const cleanupSharedContentMetadata = onSchedule(
  { schedule: "0 4 * * 6", timeZone: "UTC" },
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
 * Pure extraction of the prior `onSchedule` body — identical parent
 * pagination, per-subcollection cutoff query, and batch-delete semantics.
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

    for (const parentCollection of PARENT_COLLECTIONS) {
      let lastDoc: admin.firestore.DocumentSnapshot | null = null;
      let hasMore = true;

      while (hasMore) {
        if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
          logger.warn(
            `Approaching timeout — stopping cleanup for ${parentCollection}. Will continue next run.`
          );
          hasMore = false;
          break;
        }

        let query = db.collection(parentCollection)
          .orderBy("__name__")
          .limit(PARENT_CHUNK_SIZE);

        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) { hasMore = false; break; }

        for (const parentDoc of snapshot.docs) {
          for (const subcollection of METADATA_SUBCOLLECTIONS) {
            const deleted = await cleanupSubcollection(
              db,
              parentDoc.ref.path,
              subcollection,
              cutoffTimestamp
            );
            totalDeleted += deleted;
          }
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < PARENT_CHUNK_SIZE) { hasMore = false; }
      }
    }

    logger.info(
      `Shared content metadata cleanup complete: deleted ${totalDeleted} expired entries`
    );

    return { totalDeleted };
}

async function cleanupSubcollection(
  db: admin.firestore.Firestore,
  parentPath: string,
  subcollection: string,
  cutoffTimestamp: admin.firestore.Timestamp
): Promise<number> {
  const collectionRef = db.collection(`${parentPath}/${subcollection}`);

  // Drain every expired doc, not just the first page. Because each page is
  // deleted before the next query, the same `timestamp < cutoff` filter
  // returns fresh expired rows each pass (deleted docs no longer match), so a
  // subcollection with more than one page of residue is fully cleaned instead
  // of being silently truncated at the old 10k cap. No startAfter is needed.
  let deletedCount = 0;

  for (;;) {
    const snapshot = await collectionRef
      .where("timestamp", "<", cutoffTimestamp)
      .limit(BATCH_LIMIT)
      .get();

    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedCount += snapshot.size;

    if (snapshot.size < BATCH_LIMIT) {
      break;
    }
  }

  if (deletedCount > 0) {
    logger.info(
      `Cleaned ${deletedCount} expired ${subcollection} from ${parentPath}`
    );
  }

  return deletedCount;
}
