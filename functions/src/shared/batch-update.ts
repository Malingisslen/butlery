/**
 * Shared batch-update utilities for Cloud Functions.
 * Handles paginated Firestore batch writes within the 500-op limit.
 */

import * as admin from "firebase-admin";
import { logger as v1Logger } from "firebase-functions/v1";

export const BATCH_LIMIT = 500;

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
 * Batch-update docs matching a query with per-doc update maps.
 */
export async function batchUpdateDocs(
  query: admin.firestore.Query,
  db: admin.firestore.Firestore,
  getUpdates: (doc: admin.firestore.DocumentSnapshot) => Record<string, unknown>
): Promise<number> {
  const docs = (await query.get()).docs;
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

/**
 * Cascade-remove `value` from an array `field` on every doc matching `query`.
 * Chunked at BATCH_LIMIT. Idempotent: `arrayRemove` is a no-op when the value
 * is absent, AND `array-contains` queries return empty once the value has
 * been scrubbed — so re-runs against already-cleaned data are free of side
 * effects regardless of which guarantee fails first.
 *
 * `opts.bestEffort` (default false) controls failure behavior:
 *   - false (strict): a failed `batch.commit()` aborts the cascade and
 *     re-throws. Use when cascade is the only chance to converge.
 *   - true: a failed chunk calls `opts.onChunkFailure` (or logs a v1 warn
 *     by default) and the next chunk proceeds. Idempotency makes a future
 *     retry safe. Use when partial cleanup beats total failure (GDPR
 *     deletion cascades, where the next user-delete event will retry).
 *
 * Returns the number of docs MATCHED (queued for update) — not the number
 * of commits that succeeded. A re-run on already-scrubbed data returns 0.
 */
export async function cascadeArrayRemove(
  query: admin.firestore.Query,
  field: string,
  value: unknown,
  db: admin.firestore.Firestore,
  opts: {
    bestEffort?: boolean;
    onChunkFailure?: (err: unknown) => void;
  } = {}
): Promise<number> {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  const removeOp = admin.firestore.FieldValue.arrayRemove(value);
  let total = 0;
  let batch = db.batch();
  let batchCount = 0;

  const commitChunk = async (): Promise<void> => {
    if (batchCount === 0) return;
    if (opts.bestEffort) {
      try {
        await batch.commit();
      } catch (err) {
        if (opts.onChunkFailure) {
          opts.onChunkFailure(err);
        } else {
          v1Logger.warn(
            `cascadeArrayRemove: chunk commit failed (field=${field})`,
            { err }
          );
        }
      }
    } else {
      await batch.commit();
    }
    batch = db.batch();
    batchCount = 0;
  };

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { [field]: removeOp });
    batchCount++;
    total++;
    if (batchCount >= BATCH_LIMIT) {
      await commitChunk();
    }
  }
  await commitChunk();

  return total;
}

/**
 * BUT-816: chunked best-effort/strict batch commit over an arbitrary item
 * list. Each item is fed to `mutate(batch, item)` which queues exactly one
 * batch op (update, delete, set, ...). Items are committed in `BATCH_LIMIT`
 * chunks.
 *
 * `opts.strict` (default false) controls failure behavior:
 *   - false (best-effort): a failed `batch.commit()` logs a warn with
 *     `opts.label` and the next chunk proceeds. The cascade caller is
 *     responsible for providing an idempotent retry path.
 *   - true: a failed chunk re-throws. Use when partial state is unsafe.
 *
 * Returns the number of items queued (not commits succeeded). Useful for
 * "matched and attempted" metrics in cascade results.
 */
export async function commitInChunks<T>(
  database: admin.firestore.Firestore,
  items: readonly T[],
  mutate: (batch: admin.firestore.WriteBatch, item: T) => void,
  opts: { label: string; strict?: boolean }
): Promise<number> {
  if (items.length === 0) return 0;

  let batch = database.batch();
  let batchCount = 0;
  let queued = 0;

  const commitChunk = async (): Promise<void> => {
    if (batchCount === 0) return;
    if (opts.strict) {
      await batch.commit();
    } else {
      try {
        await batch.commit();
      } catch (err) {
        v1Logger.warn(`${opts.label}: chunk commit failed`, { err });
      }
    }
    batch = database.batch();
    batchCount = 0;
  };

  for (const item of items) {
    mutate(batch, item);
    batchCount++;
    queued++;
    if (batchCount >= BATCH_LIMIT) {
      await commitChunk();
    }
  }
  await commitChunk();

  return queued;
}

/**
 * Batch-update explicit document refs with per-ref update maps.
 * Type-safe alternative to batchUpdateDocs when working with refs directly.
 */
export async function batchUpdateRefs(
  refs: admin.firestore.DocumentReference[],
  getUpdates: (ref: admin.firestore.DocumentReference) => Record<string, unknown>,
  db: admin.firestore.Firestore
): Promise<number> {
  if (refs.length === 0) return 0;

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (const ref of refs) {
    batch.update(ref, getUpdates(ref));
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
