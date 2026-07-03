/**
 * Pooled-ratings Stage B debounce adapter (decision 5 — the crux).
 *
 * Every write to a `users/{uid}/canonical_rating_events/{poolKey}` doc signals
 * "recompute this pool". A hot pool can take many event writes in a burst, so we
 * coalesce them exactly like the per-recipe rating aggregation does — REUSING the
 * shared `../shared/debounce-queue.ts` (decision 5: "generalize it, don't fork").
 * This module is the thin adapter that pins the POOL namespace/config; the actual
 * per-pool recompute lives in `update-pooled-rating-stats.ts`.
 *
 * Mirrors the shape of `rating-aggregation.ts` (same shared queue, different
 * marker collection + log field) so the two aggregators stay structurally
 * identical and the one debounce implementation is the only copy.
 */

import * as admin from "firebase-admin";
import {
  DebounceConfig,
  ScheduleDeps,
  drainDebounceQueue,
  scheduleDebounced,
} from "../shared/debounce-queue";

export type { ScheduleDeps };

/**
 * Firestore path Stage B is bound to: every rater's frozen pool events. The
 * doc-ID wildcard {poolKey} IS the pool identity, so the trigger recovers it
 * from `event.params.poolKey` even on delete (when the after-snapshot is gone).
 * Kept in sync with `CANONICAL_EVENTS_SUBCOLLECTION` — asserted in the tests.
 */
export const POOL_EVENT_TRIGGER_PATH =
  "users/{uid}/canonical_rating_events/{poolKey}";

/** Separate marker namespace from the rating debounce — the two queues never
 *  share markers. Same 5s window as rating aggregation (decision 5: reuse). */
const POOL_DEBOUNCE: DebounceConfig = {
  markerCollection: "_internal/pool_debounce/markers",
  debounceMs: 5_000,
  logPrefix: "pool_aggregation",
  logKeyField: "poolKey",
};

export interface DrainDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
  /**
   * The per-pool recompute. REQUIRED in production — the shared drainer has no
   * default and throws if omitted; index.ts wires `updatePooledRatingStats`.
   * Also the test seam.
   */
  aggregate?: (poolKey: string) => Promise<void>;
}

/**
 * Schedule (or coalesce into) a debounced pool recompute for `poolKey`.
 * Returns whether a new run was scheduled (`true`) or coalesced (`false`).
 */
export async function schedulePoolAggregation(
  poolKey: string,
  deps: ScheduleDeps = {}
): Promise<boolean> {
  return scheduleDebounced(POOL_DEBOUNCE, poolKey, deps);
}

/**
 * Drain pending pool-aggregation markers whose window has elapsed. Runs from the
 * every-1-min scheduler; `deps.aggregate` is the per-pool recompute
 * (`updatePooledRatingStats`). If `aggregate` is omitted the shared drainer's
 * default throws per key — so an unwired production scheduler fails loudly (and
 * is counted in `failed`) rather than silently passing.
 */
export async function drainPoolAggregationQueue(
  deps: DrainDeps = {}
): Promise<{ processed: number; failed: number; durationMs: number }> {
  return drainDebounceQueue(POOL_DEBOUNCE, {
    db: deps.db,
    now: deps.now,
    drain: deps.aggregate,
  });
}

/** @internal — exported only for unit tests. */
export const __test__ = {
  DEBOUNCE_MS: POOL_DEBOUNCE.debounceMs,
  MARKER_COLLECTION: POOL_DEBOUNCE.markerCollection,
};
