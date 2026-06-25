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
 * Like batchUpdateQuery, but pages the READ with a documentId cursor so the
 * full result set is never held in memory at once. Use for unbounded fan-out
 * queries (e.g. cascading an ingredient change to every recipe that uses it),
 * where a popular match could return thousands of docs and a single `.get()`
 * would risk an out-of-memory crash.
 *
 * Orders by `__name__` (documentId), which is always available and needs no
 * composite index even alongside an `array-contains`/equality predicate. The
 * update must not change a field the base query filters on, otherwise the
 * cursor could skip or revisit docs.
 *
 * Each page is at most `pageSize` docs (capped at BATCH_LIMIT so one page = one
 * write batch). Returns the total number of docs updated.
 */
export async function batchUpdateQueryPaginated(
  baseQuery: admin.firestore.Query,
  updates: Record<string, unknown>,
  db: admin.firestore.Firestore,
  pageSize: number = BATCH_LIMIT
): Promise<number> {
  const limit = Math.min(Math.max(1, pageSize), BATCH_LIMIT);
  const ordered = baseQuery.orderBy(admin.firestore.FieldPath.documentId());

  let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;
  let total = 0;

  for (;;) {
    let page = ordered.limit(limit);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }
    const snapshot = await page.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, updates);
    }
    await batch.commit();

    total += snapshot.size;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < limit) break;
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
    /**
     * BUT-886: optional per-doc hook invoked just after the arrayRemove update
     * is staged. Use it to stage additional same-batch writes (e.g. an
     * audit_logs row via stageCascadeAuditEntry) so they commit atomically
     * with the cascade mutation. The hook MUST keep its own writes within
     * the BATCH_LIMIT budget — staging more than one extra op per doc will
     * blow the 500-op cap.
     */
    onItemOp?: (
      batch: admin.firestore.WriteBatch,
      doc: admin.firestore.QueryDocumentSnapshot,
    ) => void;
  } = {}
): Promise<number> {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  const removeOp = admin.firestore.FieldValue.arrayRemove(value);
  let total = 0;
  let batch = db.batch();
  let batchCount = 0;

  // BUT-886: when an onItemOp hook is provided, each doc contributes 2 ops
  // (arrayRemove + hook), so halve the per-chunk cap to stay under the
  // 500-op Firestore batch limit.
  const perChunkCap = opts.onItemOp
    ? Math.floor(BATCH_LIMIT / 2)
    : BATCH_LIMIT;

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
    if (opts.onItemOp) {
      opts.onItemOp(batch, doc);
    }
    batchCount++;
    total++;
    if (batchCount >= perChunkCap) {
      await commitChunk();
    }
  }
  await commitChunk();

  return total;
}

/**
 * BUT-816: chunked best-effort/strict batch commit over an arbitrary item
 * list. Each item is fed to `mutate(batch, item)` which queues `opts.opsPerItem`
 * batch ops (update, delete, set, ...). Items are committed in chunks sized
 * so the per-batch op total stays under `BATCH_LIMIT`.
 *
 * `opts.strict` (default false) controls failure behavior:
 *   - false (best-effort): a failed `batch.commit()` logs a warn with
 *     `opts.label` and the next chunk proceeds. The cascade caller is
 *     responsible for providing an idempotent retry path.
 *   - true: a failed chunk re-throws. Use when partial state is unsafe.
 *
 * `opts.opsPerItem` (default 1) — declare when the mutate callback stages
 * more than one batch op per item. BUT-886 added this: cascade audit callers
 * pass `opsPerItem: 2` because they stage `mutation + stageCascadeAuditEntry`
 * per item. Without it, a 500-item input would queue 1000 ops and Firestore
 * would reject the batch with INVALID_ARGUMENT.
 *
 * Returns the number of items queued (not commits succeeded). Useful for
 * "matched and attempted" metrics in cascade results.
 */
export async function commitInChunks<T>(
  database: admin.firestore.Firestore,
  items: readonly T[],
  mutate: (batch: admin.firestore.WriteBatch, item: T) => void,
  opts: { label: string; strict?: boolean; opsPerItem?: number }
): Promise<number> {
  if (items.length === 0) return 0;

  const opsPerItem = Math.max(1, opts.opsPerItem ?? 1);
  const itemsPerChunk = Math.max(1, Math.floor(BATCH_LIMIT / opsPerItem));

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
    if (batchCount >= itemsPerChunk) {
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
