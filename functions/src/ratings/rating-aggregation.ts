/**
 * BUT-482: Debounced rating aggregation.
 *
 * Background:
 *   `updateRecipeRatingStats(recipeId)` re-reads ALL ratings for a recipe and
 *   writes `recipe_social_stats/{recipeId}`. Triggered synchronously on every
 *   rating create/update/delete, popular recipes hit Firestore's ~1/sec
 *   single-doc write throttle. This debounces those recomputes.
 *
 * As of the pooled-ratings work (decision 5), the debounce mechanism itself
 * lives in `../shared/debounce-queue.ts` and is SHARED with the pooled-rating
 * aggregator — this module is now a thin, behavior-preserving adapter that pins
 * the rating namespace/config. The public API (`scheduleRatingAggregation`,
 * `drainRatingAggregationQueue`, `__test__`) is unchanged, so index.ts and the
 * BUT-482 test are untouched.
 *
 * Why a Firestore queue + scheduler instead of Cloud Tasks: see the original
 * rationale — zero Cloud Tasks usage in this codebase; a single-collection scan
 * for ~10 popular recipes/min is lighter than a Cloud Tasks queue + IAM. Same
 * trade-off as BUT-647. Inflection point ~10k debounced events/min.
 */

import * as admin from "firebase-admin";
import {
  DebounceConfig,
  ScheduleDeps,
  debounceMarkerRef,
  drainDebounceQueue,
  scheduleDebounced,
} from "../shared/debounce-queue";

export type { ScheduleDeps };

const RATING_DEBOUNCE: DebounceConfig = {
  markerCollection: "_internal/rating_debounce/markers",
  debounceMs: 5_000,
  logPrefix: "rating_aggregation",
  // Preserve the pre-extraction log field name so existing log-based metrics
  // that filter on jsonPayload.recipeId keep matching.
  logKeyField: "recipeId",
};

export interface DrainDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
  /**
   * The per-recipe recompute. REQUIRED in production — the shared drainer has
   * no default and throws if this is omitted; index.ts wires
   * `updateRecipeRatingStats`. Also the test seam.
   */
  aggregate?: (recipeId: string) => Promise<void>;
}

/**
 * Schedule (or coalesce into) a debounced aggregation run for `recipeId`.
 * Returns whether a new run was scheduled (`true`) or coalesced (`false`).
 */
export async function scheduleRatingAggregation(
  recipeId: string,
  deps: ScheduleDeps = {}
): Promise<boolean> {
  return scheduleDebounced(RATING_DEBOUNCE, recipeId, deps);
}

/**
 * Drain pending rating-aggregation markers whose window has elapsed. Runs from
 * the every-1-min scheduler; `deps.aggregate` is the per-recipe recompute.
 */
export async function drainRatingAggregationQueue(
  deps: DrainDeps = {}
): Promise<{
  processed: number;
  failed: number;
  durationMs: number;
  /** True when the drain scan hit the 500-marker cap — queue is saturated. */
  capped: boolean;
}> {
  return drainDebounceQueue(RATING_DEBOUNCE, {
    db: deps.db,
    now: deps.now,
    drain: deps.aggregate,
  });
}

/** @internal — exported only for unit tests. */
export const __test__ = {
  DEBOUNCE_MS: RATING_DEBOUNCE.debounceMs,
  MARKER_COLLECTION: RATING_DEBOUNCE.markerCollection,
  markerRef: (db: admin.firestore.Firestore, recipeId: string) =>
    debounceMarkerRef(db, RATING_DEBOUNCE, recipeId),
};
