import * as admin from "firebase-admin";
import { BATCH_LIMIT } from "./batch-update";

/**
 * Batch-delete all documents in a snapshot, committing every BATCH_LIMIT ops.
 * Returns the number of documents deleted.
 */
export async function batchDeleteDocs(
  db: admin.firestore.Firestore,
  snapshot: admin.firestore.QuerySnapshot
): Promise<number> {
  let deleted = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;
    deleted++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return deleted;
}
