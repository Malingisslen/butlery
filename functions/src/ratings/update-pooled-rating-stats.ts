/**
 * Stage B of the pooled-ratings pipeline ("Butlery-betyget") — the pool
 * aggregator. See tasks/pooled-ratings-plan.md decision 5 ("the crux") and
 * tasks/todo.md Increment 3.
 *
 * Stage A (canonical-rating-aggregation.ts) files ONE frozen pool event per
 * eligible rater at users/{uid}/canonical_rating_events/{poolKey}. This stage
 * folds every event that shares a poolKey — across ALL users — into one public
 * stats doc:
 *   canonical_recipe_stats/{poolKey} = { count, average, updatedAt }
 *
 * DECISION 5 (hard rule): a pool's rater count is UNBOUNDED by design, so this
 * must NEVER read every event into memory and recompute (the way the per-recipe
 * `updateRecipeRatingStats` does — that is bounded to one recipe's own raters).
 * Instead it issues a single Firestore AGGREGATE query
 *   collectionGroup("canonical_rating_events").where("poolKey","==",key)
 *     .aggregate({ count, average(ratingValue) })
 * which computes both numbers in the index layer and returns two scalars — O(1)
 * memory, one billed read per ≤1000 matched index entries. There is deliberately
 * no `.get()` fold anywhere in this file.
 *
 * The read spans a COLLECTION GROUP (the same subcollection under every user)
 * and AVERAGES a field other than the one it filters on. Firestore aggregations
 * are computed from index entries and never read the documents, so the averaged
 * `ratingValue` must live in the scanned index next to the `poolKey` filter —
 * i.e. this needs a COMPOSITE collection-group index (poolKey, ratingValue), NOT
 * a single-field index on poolKey (which serves count() but makes average()
 * throw FAILED_PRECONDITION). See firestore.indexes.json; enabling it is an
 * explicit deploy step (decision 14).
 *
 * Idempotent: it recomputes from the source of truth (the events) every run, so
 * the debounce drainer's rare double-run and Cloud Functions retries are safe.
 * When a pool empties (last event retracted / erased by GDPR deletion) the
 * aggregate returns count 0 / average null and we write that — the reader gates
 * on n ≥ 5, so a zeroed doc simply shows no pill (never a stale number).
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "./canonical-rating-aggregation";

/** The public per-pool stats collection (decision 5 / 10). */
export const CANONICAL_STATS_COLLECTION = "canonical_recipe_stats";

export interface PooledRatingStats {
  count: number;
  /** Mean of `ratingValue` across the pool, or null when the pool is empty. */
  average: number | null;
  updatedAt: admin.firestore.Timestamp;
}

/**
 * Recompute `canonical_recipe_stats/{poolKey}` from all events sharing the key.
 *
 * @param poolKey the frozen pool identity (event doc-ID under every rater).
 * @param dbArg   test seam; defaults to the Admin SDK Firestore.
 *
 * MUST stay an aggregate query — see the module header (decision 5). May throw
 * on transient IO; the caller (debounce drainer) logs+counts the failure and the
 * next signal re-runs it.
 */
export async function updatePooledRatingStats(
  poolKey: string,
  dbArg?: admin.firestore.Firestore
): Promise<void> {
  if (!poolKey) {
    logger.warn("pool_aggregation.update called with empty poolKey");
    return;
  }
  const db = dbArg ?? admin.firestore();

  // Decision 5: aggregate in the index layer — NEVER fetch the events. One
  // query returns both scalars; average is null when the pool is empty.
  const snap = await db
    .collectionGroup(CANONICAL_EVENTS_SUBCOLLECTION)
    .where("poolKey", "==", poolKey)
    .aggregate({
      count: admin.firestore.AggregateField.count(),
      average: admin.firestore.AggregateField.average("ratingValue"),
    })
    .get();

  const count = snap.data().count;
  const average = snap.data().average; // number, or null when count === 0

  const stats: PooledRatingStats = {
    count,
    average,
    updatedAt: admin.firestore.Timestamp.now(),
  };

  await db.collection(CANONICAL_STATS_COLLECTION).doc(poolKey).set(stats, {
    merge: true,
  });

  logger.info("pool_aggregation.updated", {
    event: "pool_aggregation.updated",
    poolKey,
    count,
    average,
  });
}
