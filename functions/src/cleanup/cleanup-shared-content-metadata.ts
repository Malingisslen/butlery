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

import * as functions from "firebase-functions";
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
 * Region: europe-west1
 */
export const cleanupSharedContentMetadata = functions
  .region("europe-west1")
  .pubsub.schedule("0 4 * * 6")
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - DEFAULT_TTL_DAYS);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

    functions.logger.info(
      `Starting shared content metadata cleanup (TTL: ${DEFAULT_TTL_DAYS} days, cutoff: ${cutoffDate.toISOString()})`
    );

    let totalDeleted = 0;
    const startTime = Date.now();

    for (const parentCollection of PARENT_COLLECTIONS) {
      let lastDoc: admin.firestore.DocumentSnapshot | null = null;
      let hasMore = true;

      while (hasMore) {
        if (Date.now() - startTime > MAX_EXECUTION_TIME_MS) {
          functions.logger.warn(
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

    functions.logger.info(
      `Shared content metadata cleanup complete: deleted ${totalDeleted} expired entries`
    );

    return null;
  });

async function cleanupSubcollection(
  db: admin.firestore.Firestore,
  parentPath: string,
  subcollection: string,
  cutoffTimestamp: admin.firestore.Timestamp
): Promise<number> {
  const collectionRef = db.collection(`${parentPath}/${subcollection}`);

  const snapshot = await collectionRef
    .where("timestamp", "<", cutoffTimestamp)
    .limit(10000)
    .get();

  if (snapshot.empty) {
    return 0;
  }

  let deletedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;
    deletedCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  if (deletedCount > 0) {
    functions.logger.info(
      `Cleaned ${deletedCount} expired ${subcollection} from ${parentPath}`
    );
  }

  return deletedCount;
}
