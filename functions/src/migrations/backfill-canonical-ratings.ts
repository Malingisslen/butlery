/**
 * Pooled ratings ("Butlery-betyget") — one-shot BACKFILL of pre-existing
 * `recipe_ratings` into the pool event store. See tasks/pooled-ratings-plan.md
 * decision 14 and tasks/todo.md Increment 8.
 *
 * The Stage-A mirror (`../ratings/canonical-rating-aggregation.ts`) only fires on
 * NEW rating writes. This admin-only callable replays every EXISTING 'alla'
 * rating through the SAME server-side key derivation + eligibility gates, filing
 * the identical frozen event `users/{uid}/canonical_rating_events/{poolKey}`. It
 * NEVER trusts a client-written key — it recomputes from the rater's own recipe
 * content (`computePoolKey`), exactly like the live mirror.
 *
 * ══════════════════════════════════════════════════════════════════════════
 * ⛔ HARD GATE — DO NOT RUN A REAL BACKFILL UNTIL ALL OF THESE HOLD:
 *   1. The `enable_pooled_ratings` flag is ON in prod (this CF REFUSES a real
 *      run while it is off — dry-run is always allowed so you can preview).
 *   2. The privacy-policy EN/SV pooling disclosure (§5.3) is LIVE in the shipped
 *      app (decision 12(e); backfill is a purpose-change over already-collected
 *      ratings — the LIA covers it, but the disclosure must precede the run).
 *      NOTE: there is no code-side policy-version constant, so this precondition
 *      is OPERATIONAL — the operator confirms it before invoking; it is NOT
 *      machine-enforced here.
 *   3. The poolKey hit-rate harness (`tools/measure_poolkey_hitrate.dart`) has
 *      been re-run on ≥20–30 REAL corpus scans with 0 false merges (C6/C7/C8).
 *   4. The collectionGroup composite index `(poolKey, ratingValue)` on
 *      `canonical_rating_events` is ENABLED (Stage-B aggregate query needs it;
 *      decision 14) — each backfilled event fires the Stage-B trigger.
 * The LIA (docs/legal/pooled-ratings-lia.md) must be SIGNED OFF before (1).
 * ══════════════════════════════════════════════════════════════════════════
 *
 * **LIFECYCLE — REMOVE THIS FILE WHEN:**
 *   1. A real invocation returns `hasMore: false` (all eligible ratings mirrored),
 *      AND
 *   2. A 30-day soak window passes with no pool-correctness incident tied to the
 *      backfill.
 * Then delete this file, its `backfillCanonicalRatings` export in
 * `functions/src/index.ts`, and its `test:backfill-canonical-ratings` script in
 * `functions/package.json`. Going forward the live mirror keeps every NEW rating
 * pooled; one-shot migration code is liability after the soak.
 *
 * ── RUNBOOK ──────────────────────────────────────────────────────────────
 * • Preview:  call with { dryRun: true } — scans + logs counts, writes nothing,
 *   ignores the flag gate. Run this first and eyeball the `wouldWrite` count vs
 *   your rating total and the `skippedNoKey` (fail-closed dishes) share.
 * • Real run: call with { dryRun: false } — requires the flag ON. Paginated:
 *   each response returns `hasMore` + `nextCursor`; while `hasMore` is true,
 *   re-invoke passing `{ startAfter: <nextCursor> }` until it returns false.
 *   (Idempotent — re-running a range is safe; see below.) A dry-run also returns
 *   a cursor, so you can page a large preview the same way.
 * • Look up a pool: read `canonical_recipe_stats/{poolKey}` for count+average; list
 *   its member ratings with a collectionGroup query on `canonical_rating_events`
 *   where `poolKey == <key>` (each doc path reveals the rater uid + recipeId).
 * • Split a bad merge: delete the offending `users/{uid}/canonical_rating_events/
 *   {poolKey}` docs (Stage-B re-aggregates on the delete); the underlying
 *   `recipe_ratings` are untouched, so a corrected key on a later edit re-pools.
 * • Idempotent: re-running upserts the SAME event per (uid, poolKey), so a repeat
 *   or overlapping run re-writes identical data — safe. Per (uid, poolKey) the
 *   LAST-PROCESSED rating wins (doc-id order), matching the live mirror's
 *   last-write semantics + accepted-deviations edge #1 (self-heals on next rating).
 * ─────────────────────────────────────────────────────────────────────────
 *
 * **Region:** europe-west1.  **Auth:** admin custom claim (`requireAdmin`).
 */

import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

import { requireAdmin } from "../shared/require-admin";
import { computePoolKey } from "../ratings/canonical-pool-key";
import { isPooledRatingsEnabled } from "../ratings/pooled-ratings-flag";
import {
  isAccountMatured,
  recipeContentToKey,
  CANONICAL_EVENTS_SUBCOLLECTION,
} from "../ratings/canonical-rating-aggregation";

const REGION = "europe-west1";
// Firestore writeBatch hard cap is 500; 450 leaves headroom (BUT-741 precedent).
const BATCH_SIZE = 450;
// 23 × 450 = 10,350 ratings/invocation ceiling; `maxRatings` (default 10,000)
// short-circuits first. Re-invoke while hasMore to continue past this.
const MAX_BATCHES_PER_INVOCATION = 23;

const getDb = () => admin.firestore();

interface BackfillRequest {
  /** Scan + log without writing; ignores the flag gate. Default false. */
  dryRun?: boolean;
  /** Hard ceiling on ratings scanned this invocation. Default 10,000. */
  maxRatings?: number;
  /**
   * Resume cursor — the `nextCursor` returned by the previous invocation. Pass
   * it back to continue where the last one stopped (the pagination is EXCLUSIVE,
   * so no rating is re-scanned). Omit/undefined starts from the beginning.
   */
  startAfter?: string;
}

interface BackfillResponse {
  success: boolean;
  /** Events written (or, in dryRun, that WOULD be written). One per unique pool. */
  mirrored: number;
  /** Already-identical events skipped (idempotent no-op). */
  skippedIdentical: number;
  /** Ratings with an immature/deleted rater account (decision 7 gate). */
  skippedImmature: number;
  /** Ratings whose rater has no own recipe copy (cannot derive key). */
  skippedNoRecipe: number;
  /** Ratings whose dish yields no key (fail-closed: generic/no anchor). */
  skippedNoKey: number;
  /** Malformed rating docs (missing uid/recipeId or out-of-range value). */
  skippedInvalid: number;
  batchesProcessed: number;
  hasMore: boolean;
  /**
   * When `hasMore`, the doc-id to pass as `startAfter` on the next invocation to
   * resume (points at the LAST PROCESSED rating, never past unprocessed ones).
   * null when the whole corpus is done.
   */
  nextCursor: string | null;
  dryRun: boolean;
}

/**
 * Replay `recipe_ratings` into the pool event store. Exposed for unit testing
 * alongside the callable wrapper. All IO through the injected `db`/`auth`.
 */
export async function runCanonicalRatingsBackfill(
  db: admin.firestore.Firestore,
  options: {
    dryRun: boolean;
    maxRatings: number;
    startAfter?: string;
    auth?: admin.auth.Auth;
    now?: () => number;
    computeKey?: (title: string, ingredients: string[]) => string | null;
  }
): Promise<BackfillResponse> {
  const { dryRun } = options;
  // Clamp to >=1: maxRatings:0 would cut off on doc #1 (nothing processed) and
  // then advance the cursor past the whole unprocessed batch — a silent skip.
  const maxRatings = Math.max(1, options.maxRatings);
  const now = options.now ?? (() => Date.now());
  const computeKey = options.computeKey ?? computePoolKey;
  // Reuse the live mirror's maturity gate through its deps shape.
  const gateDeps = { db, auth: options.auth ?? admin.auth() };

  let mirrored = 0;
  let skippedIdentical = 0;
  let skippedImmature = 0;
  let skippedNoRecipe = 0;
  let skippedNoKey = 0;
  let skippedInvalid = 0;
  let batchesProcessed = 0;
  let totalScanned = 0;
  // Resume cursor: start where the previous invocation left off (exclusive), so
  // no rating is ever re-scanned and re-invocation makes real forward progress.
  let lastDocId: string | null = options.startAfter ?? null;
  // The last rating actually PROCESSED (not merely fetched) — the resume point.
  // Never advances past a doc skipped by the maxRatings cutoff.
  let lastProcessedId: string | null = options.startAfter ?? null;
  let hasMore = false;
  let reachedEnd = false;

  while (batchesProcessed < MAX_BATCHES_PER_INVOCATION) {
    // Cursor that BEGAN this batch. Nothing in the current batch is committed
    // until the loop below finishes, so this is the only safe resume point if
    // the batch aborts mid-way (transient maturity error) — resuming from a
    // half-processed doc would skip its uncommitted siblings.
    const batchStartCursor = lastDocId;
    let query = db
      .collection("recipe_ratings")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (lastDocId) query = query.startAfter(lastDocId);

    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    // One resolved event per rating, then collapsed per (uid, poolKey) keeping
    // the LAST by doc-id (deterministic last-write, matching the live mirror and
    // accepted-deviations edge #1). Collapsing BEFORE writing removes the
    // same-batch double-`set` that made a collision pool oscillate across runs.
    interface Resolved {
      ref: admin.firestore.DocumentReference;
      poolKey: string;
      ratingValue: number;
      recipeId: string;
      createdAt: admin.firestore.Timestamp | admin.firestore.FieldValue;
    }
    const winners = new Map<string, Resolved>();
    let cutoffHit = false;

    for (const doc of snapshot.docs) {
      totalScanned += 1;
      if (totalScanned > maxRatings) {
        cutoffHit = true;
        break; // stop BEFORE processing — lastProcessedId stays at the prior doc
      }

      const data = doc.data();
      const uid = data.userId as string | undefined;
      const recipeId = data.recipeId as string | undefined;
      const rating = data.rating as number | undefined;

      // Same validity gate as the live mirror: finite, in [1,5]; half-stars OK.
      if (
        !uid ||
        !recipeId ||
        typeof rating !== "number" ||
        !Number.isFinite(rating) ||
        rating < 1 ||
        rating > 5
      ) {
        skippedInvalid += 1;
        lastProcessedId = doc.id;
        continue;
      }

      // Maturity gate (decision 7) — reused from the mirror. A transient auth
      // error THROWS (propagates → the operator re-invokes from the cursor),
      // never silently drops a mature rater. Terminal (account gone) → skip.
      let matured: boolean;
      try {
        matured = await isAccountMatured(uid, now(), gateDeps);
      } catch (err) {
        throw new HttpsError(
          "unavailable",
          `maturity lookup failed for ${uid}; this batch was NOT committed — ` +
            `re-invoke with startAfter=${
              batchStartCursor ?? "(start)"
            } to resume safely: ${
              err instanceof Error ? err.message : String(err)
            }`
        );
      }
      if (!matured) {
        skippedImmature += 1;
        lastProcessedId = doc.id;
        continue;
      }

      // Server-recompute the key from the rater's OWN recipe copy (never the
      // client) — the pool-poisoning defence, identical to the mirror.
      const keyed = await recipeContentToKey(db, uid, recipeId, computeKey);
      if (!keyed.found) {
        skippedNoRecipe += 1;
        lastProcessedId = doc.id;
        continue;
      }
      if (keyed.poolKey === null) {
        skippedNoKey += 1;
        lastProcessedId = doc.id;
        continue;
      }
      const poolKey = keyed.poolKey;

      // Preserve the ORIGINAL rating time when it is a real Timestamp (more
      // truthful for a historical event; no reader depends on it today), else
      // serverTimestamp — guarded so a malformed createdAt never rides through.
      const createdAt =
        data.createdAt instanceof admin.firestore.Timestamp
          ? data.createdAt
          : admin.firestore.FieldValue.serverTimestamp();

      // Later doc-id overwrites earlier ⇒ last-write winner for this pool.
      winners.set(`${uid} ${poolKey}`, {
        ref: db
          .collection("users")
          .doc(uid)
          .collection(CANONICAL_EVENTS_SUBCOLLECTION)
          .doc(poolKey),
        poolKey,
        ratingValue: rating,
        recipeId,
        createdAt,
      });
      lastProcessedId = doc.id;
    }

    // Idempotency + write, one unique pool at a time. Skipping on an exact match
    // (recipeId + value) makes a re-run of the SAME deterministic winner a no-op,
    // so a collision pool converges instead of oscillating.
    const batchWrites = dryRun ? null : db.batch();
    let writesInBatch = 0;
    for (const w of winners.values()) {
      const existing = await w.ref.get();
      if (existing.exists) {
        const ex = existing.data() ?? {};
        if (ex.recipeId === w.recipeId && ex.ratingValue === w.ratingValue) {
          skippedIdentical += 1;
          continue;
        }
      }
      if (!dryRun && batchWrites) {
        batchWrites.set(w.ref, {
          poolKey: w.poolKey,
          ratingValue: w.ratingValue,
          recipeId: w.recipeId,
          createdAt: w.createdAt,
        });
        writesInBatch += 1;
      }
      mirrored += 1;
    }

    if (!dryRun && batchWrites && writesInBatch > 0) {
      await batchWrites.commit();
    }

    batchesProcessed += 1;
    logger.info(
      JSON.stringify({
        tag: "backfill-canonical-ratings",
        dryRun,
        mirrored,
        skippedIdentical,
        skippedImmature,
        skippedNoRecipe,
        skippedNoKey,
        skippedInvalid,
        batchNumber: batchesProcessed,
      })
    );

    lastDocId = snapshot.docs[snapshot.docs.length - 1].id;
    if (cutoffHit) {
      hasMore = true; // more docs exist past the maxRatings ceiling
      break;
    }
    if (snapshot.size < BATCH_SIZE) {
      reachedEnd = true; // last (short) page consumed — corpus exhausted
      break;
    }
  }

  // Genuinely more to do only if we stopped WITHOUT reaching the end.
  if (!reachedEnd && (hasMore || batchesProcessed >= MAX_BATCHES_PER_INVOCATION)) {
    hasMore = true;
  }

  return {
    success: true,
    mirrored,
    skippedIdentical,
    skippedImmature,
    skippedNoRecipe,
    skippedNoKey,
    skippedInvalid,
    batchesProcessed,
    hasMore,
    // Resume from the last PROCESSED doc (cutoff) or the last FETCHED doc (batch
    // ceiling); null when there is nothing left.
    nextCursor: hasMore ? (lastProcessedId ?? lastDocId) : null,
    dryRun,
  };
}

/**
 * Admin-only callable. A REAL run (dryRun:false) REFUSES to proceed unless the
 * `enable_pooled_ratings` kill switch is ON (AC10) — so the backfill cannot run
 * before the feature is deliberately enabled. A dry-run is always permitted so
 * the merge can be previewed while the flag is still off.
 */
export const backfillCanonicalRatings = onCall(
  { region: REGION },
  async (
    request: CallableRequest<BackfillRequest>
  ): Promise<BackfillResponse> => {
    requireAdmin(request);

    const { dryRun = false, maxRatings = 10000, startAfter } = request.data ?? {};

    if (!dryRun) {
      // Hard gate (1): a real run requires the feature flag ON. isPooledRatingsEnabled
      // THROWS on an unreachable RC (indeterminate ≠ on), so we never run on a blip.
      const enabled = await isPooledRatingsEnabled();
      if (!enabled) {
        throw new HttpsError(
          "failed-precondition",
          "backfill refused: enable_pooled_ratings is OFF. Turn the feature on " +
            "(and confirm the privacy-policy pooling disclosure is live + the " +
            "real-corpus hit-rate gate has passed) before a real backfill, or " +
            "call with { dryRun: true } to preview."
        );
      }
    }

    logger.info(
      `[backfill-canonical-ratings] starting: dryRun=${dryRun}, maxRatings=${maxRatings}, admin=${request.auth?.uid}`
    );

    try {
      const result = await runCanonicalRatingsBackfill(getDb(), {
        dryRun,
        maxRatings,
        startAfter,
      });
      logger.info(
        `[backfill-canonical-ratings] done: ${JSON.stringify(result)}`
      );
      return result;
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      logger.error(
        `[backfill-canonical-ratings] fatal: ${
          e instanceof Error ? e.message : String(e)
        }`
      );
      throw new HttpsError(
        "internal",
        `Backfill failed: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }
);
