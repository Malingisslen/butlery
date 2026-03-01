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

const DEFAULT_TTL_DAYS = 90;
const BATCH_LIMIT = 500;

const PARENT_COLLECTIONS = [
  "shared_recipes",
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

    for (const parentCollection of PARENT_COLLECTIONS) {
      const parentDocs = await db.collection(parentCollection).listDocuments();

      for (const parentDoc of parentDocs) {
        for (const subcollection of METADATA_SUBCOLLECTIONS) {
          const deleted = await cleanupSubcollection(
            db,
            parentDoc.path,
            subcollection,
            cutoffTimestamp
          );
          totalDeleted += deleted;
        }
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
