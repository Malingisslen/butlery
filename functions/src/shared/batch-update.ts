/**
 * Shared batch-update utilities for Cloud Functions.
 * Handles paginated Firestore batch writes within the 500-op limit.
 */

import * as admin from "firebase-admin";

const BATCH_LIMIT = 500;

/**
 * Batch-update all docs matching a query with the same update map.
 */
export async function batchUpdateQuery(
  query: admin.firestore.Query,
  updates: Record<string, unknown>,
  db: admin.firestore.Firestore
): Promise<number> {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, updates);
    batchCount++;
    total++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return total;
}

/**
 * Batch-update docs with per-doc update maps, from either a query or explicit refs.
 */
export async function batchUpdateDocs(
  query: admin.firestore.Query | null,
  db: admin.firestore.Firestore,
  getUpdates: (doc: admin.firestore.DocumentSnapshot) => Record<string, unknown>,
  refs?: admin.firestore.DocumentReference[]
): Promise<number> {
  const docs = refs
    ? refs.map((ref) => ({ ref } as admin.firestore.DocumentSnapshot))
    : (await query!.get()).docs;

  if (docs.length === 0) return 0;

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (const doc of docs) {
    batch.update(doc.ref, getUpdates(doc));
    batchCount++;
    total++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return total;
}
