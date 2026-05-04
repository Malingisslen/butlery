/**
 * BUT-482: Debounced rating aggregation.
 *
 * Background:
 *   `updateRecipeRatingStats(recipeId)` re-reads ALL ratings for a recipe
 *   and writes `recipe_social_stats/{recipeId}`. Triggered synchronously on
 *   every rating create/update/delete, popular recipes hit Firestore's
 *   ~1/sec single-doc write throttle.
 *
 * Mechanism:
 *   1. Trigger handlers (`onRatingCreated/Updated/Deleted`) call
 *      `scheduleRatingAggregation(recipeId)` instead of running aggregation
 *      directly.
 *   2. `scheduleRatingAggregation` runs a transaction on
 *      `_internal/rating_debounce/{recipeId}`:
 *        - if marker absent OR `pendingUntil` already passed: write a fresh
 *          marker `pendingUntil = now + DEBOUNCE_MS` and exit. The marker is
 *          the work-to-do signal.
 *        - if marker pending: log skipped + exit (no write).
 *   3. A 1-minute scheduled drainer (`drainRatingAggregationQueue`) scans
 *      `_internal/rating_debounce` for `pendingUntil <= now`, runs
 *      `updateRecipeRatingStats(recipeId)` per match, deletes the marker.
 *   4. Aggregation reads ALL ratings on each run, so collapsing a 5s window
 *      to one run is correct by construction (no lost ratings).
 *
 * Why a Firestore queue + scheduler instead of Cloud Tasks:
 *   This codebase has zero Cloud Tasks usage. Adding `@google-cloud/tasks`,
 *   the Cloud Tasks Enqueuer IAM role, and a queue resource for a
 *   debounce-by-5s case is heavier than a single-collection scan that runs
 *   for ~10 popular recipes per minute at our scale. Same trade-off as
 *   BUT-647 (deliver-scheduled-notifications). Inflection point ~10k
 *   debounced events/min.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

const DEBOUNCE_MS = 5_000;
const MARKER_COLLECTION = "_internal/rating_debounce/markers";

export interface ScheduleDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
}

export interface DrainDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
  /** Test seam — defaults to the production aggregator. */
  aggregate?: (recipeId: string) => Promise<void>;
}

interface DebounceMarker {
  recipeId: string;
  pendingUntil: admin.firestore.Timestamp;
  scheduledAt: admin.firestore.Timestamp;
}

function markerRef(
  db: admin.firestore.Firestore,
  recipeId: string
): admin.firestore.DocumentReference {
  return db.doc(`${MARKER_COLLECTION}/${recipeId}`);
}

/**
 * Schedule (or coalesce into) a debounced aggregation run for `recipeId`.
 *
 * Returns whether a new run was scheduled (`true`) or skipped because one
 * was already pending (`false`). Either way the eventual aggregation will
 * see the latest ratings — the function reads the full ratings collection.
 */
export async function scheduleRatingAggregation(
  recipeId: string,
  deps: ScheduleDeps = {}
): Promise<boolean> {
  if (!recipeId) {
    logger.warn("scheduleRatingAggregation called with empty recipeId");
    return false;
  }
  const db = deps.db ?? admin.firestore();
  const nowMs = (deps.now ?? (() => new Date()))().getTime();

  const ref = markerRef(db, recipeId);
  const scheduled = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const data = snap.data() as DebounceMarker | undefined;
      const pendingMs = data?.pendingUntil?.toMillis() ?? 0;
      // Existing marker still in flight — coalesce.
      if (pendingMs > nowMs) {
        return false;
      }
    }
    const marker: DebounceMarker = {
      recipeId,
      pendingUntil: admin.firestore.Timestamp.fromMillis(nowMs + DEBOUNCE_MS),
      scheduledAt: admin.firestore.Timestamp.fromMillis(nowMs),
    };
    tx.set(ref, marker);
    return true;
  });

  if (scheduled) {
    logger.info("rating_aggregation.scheduled", {
      event: "rating_aggregation.scheduled",
      recipeId,
    });
  } else {
    logger.info("rating_aggregation.skipped", {
      event: "rating_aggregation.skipped",
      recipeId,
      reason: "debounce",
    });
  }
  return scheduled;
}

/**
 * Drain pending aggregation markers whose `pendingUntil` has elapsed.
 *
 * Run from the every-1-min scheduler. Per marker:
 *   1. read marker (already filtered by where-query)
 *   2. delete marker FIRST (claim it — minimises double-runs across
 *      concurrent drains; aggregation itself is idempotent so a rare
 *      double-run is safe)
 *   3. run aggregator
 *
 * Returns counts so the caller can emit a single summary log.
 */
export async function drainRatingAggregationQueue(
  deps: DrainDeps = {}
): Promise<{ processed: number; failed: number; durationMs: number }> {
  const start = Date.now();
  const db = deps.db ?? admin.firestore();
  const now = (deps.now ?? (() => new Date()))();
  const aggregate = deps.aggregate ?? (async () => {
    // Lazy import to avoid a circular dep with index.ts.
    // The default aggregator lives there and is wired by the caller in
    // production; falling back here is defence in depth.
    throw new Error("drainRatingAggregationQueue: no aggregate impl provided");
  });

  const snap = await db
    .collection(MARKER_COLLECTION)
    .where("pendingUntil", "<=", admin.firestore.Timestamp.fromDate(now))
    .limit(500)
    .get();

  let processed = 0;
  let failed = 0;
  for (const doc of snap.docs) {
    const data = doc.data() as DebounceMarker | undefined;
    const recipeId = data?.recipeId ?? doc.id;
    try {
      // Claim-by-delete: remove marker before aggregating. A new rating
      // landing during aggregation will create a fresh marker which the
      // next drain picks up — that's the desired re-fire behaviour.
      await doc.ref.delete();
      await aggregate(recipeId);
      processed++;
    } catch (err) {
      failed++;
      logger.error("rating_aggregation.failed", {
        event: "rating_aggregation.failed",
        recipeId,
        err,
      });
    }
  }
  return { processed, failed, durationMs: Date.now() - start };
}

/** @internal — exported only for unit tests. */
export const __test__ = {
  DEBOUNCE_MS,
  MARKER_COLLECTION,
  markerRef,
};
