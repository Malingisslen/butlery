/**
 * Cache Cleanup Cloud Function
 *
 * Deletes expired entries from the `globalRecipeCache` collection.
 *
 * Expiration is per-document, not a single cutoff: it is
 * `cachedAt + ttlDays` (ttlDays defaults to 90), and the writer picks
 * ttlDays by source type (30–180 days, see
 * `lib/services/import/cache/global_recipe_cache.dart`). The rows DO carry a
 * client-stamped `expireAt` (see below), but this job deliberately derives
 * expiry server-side from `cachedAt` instead of trusting it, which is why it
 * walks the collection and evaluates each row rather than filtering.
 *
 * BUT-1786: it used to walk it with a single unbounded `collectionRef.get()`,
 * materialising every cached recipe payload at once in a default-memory
 * instance. That is the defect on its own terms. It also blocks a possible
 * future: IF this job ever joins a shared maintenance chain an OOM kill, which
 * produces no error log, would take every task behind it down too. It is
 * deliberately NOT chained today — see `scheduled/maintenance-dispatchers.ts`,
 * which states why the cleanup jobs stay standalone. The walk is now PAGED by document
 * id, so peak memory is one page.
 *
 * Semantics are unchanged for every value the Dart writer emits, and for a
 * missing, null or zero `ttlDays` (the original's `|| 90` fallback is
 * preserved). There are four DELIBERATE divergences, all on values only a
 * hostile or legacy client could write — `firestore.rules` constrains field
 * presence on this collection, never type, and does not require `cachedAt` at
 * all:
 *
 *   - a `cachedAt` that throws on `.toMillis()`: the original aborted the whole
 *     run; this counts it as `malformed` and treats the row as expired;
 *   - `ttlDays: -5`: truthy under `||`, so the original expired it INSTANTLY;
 *     this falls back to 90 days and keeps it;
 *   - `ttlDays: "abc"`: the original computed a NaN expiry, so the row was
 *     NEVER deleted; this defaults to 90 days. (`"30"` and `true` collapse to
 *     90 the same way.)
 *   - a budget-exhausted run examines fewer rows, by construction.
 *
 * Each is an improvement, but none of them is parity, and this comment said so
 * for one revision before a reviewer checked it against `git show HEAD:`.
 *
 * WHY THIS JOB STILL EXISTS, given the native TTL policy.
 * A first draft of this comment claimed the fix was "stamp an expiresAt in the
 * client and attach a TTL policy" — both of which already shipped:
 * `lib/services/import/cache/cache_entry.dart` stamps `expireAt` on every
 * write, `firestore.indexes.json` declares
 * `{ collectionGroup: globalRecipeCache, fieldPath: expireAt, ttl: true }`, and
 * `__tests__/firestore-ttl-policies.test.ts` pins it as live. So Firestore is
 * already deleting most of this collection on its own, and the honest remaining
 * justification for this job is narrower than "the TTL doesn't exist yet":
 *
 *   1. Rows written BEFORE `expireAt` shipped carry no such field, so the TTL
 *      policy will never touch them. This job's `cachedAt + ttlDays` test does.
 *   2. `expireAt` is stamped from the CLIENT clock; this job derives expiry
 *      server-side from `cachedAt`. A device with a skewed clock gets the wrong
 *      `expireAt` and is only ever corrected here.
 *   3. Firestore's TTL deletes "within 24 hours" of the timestamp, not at it.
 *
 * Whether those three are worth a daily full-collection read is a real open
 * question — but it is a separate one, with its own answer (a backfill would
 * retire 1 and 2), and it does not belong in a scheduling refactor.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { BATCH_LIMIT } from "../shared/batch-update";

/** Days an entry lives when the document carries no explicit `ttlDays`. */
export const DEFAULT_TTL_DAYS = 90;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Guard against a page that never advances. Each iteration consumes one page of
 * BATCH_LIMIT docs, so this bounds the walk at 10M documents — far above any
 * realistic cache — and only a non-advancing cursor can reach it.
 */
const MAX_PAGE_ITERATIONS = 20000;

/**
 * Wall clock this walk gives itself, in ms.
 *
 * MUST stay below the function's platform timeout or it is dead code — the
 * instance is killed first, which produces no error log (the trap
 * `shared/with-timeout.ts` documents about itself). The wrapper declares
 * `timeoutSeconds: CACHE_CLEANUP_TIMEOUT_SECONDS` (60s, which is also the v2
 * default, so declaring it changed nothing at deploy time — it just stops the
 * pairing resting on an inherited value); 45s leaves room to log and return.
 *
 * Paging costs no FEWER sequential round-trips than the old single `get()` —
 * one per page once the collection exceeds BATCH_LIMIT, exactly one below it —
 * and there is no persisted cursor, so a kill mid-walk restarts at page one
 * tomorrow; stopping cleanly with `truncated: true` is how that stays visible
 * instead of silent.
 *
 * Raise this and `CACHE_CLEANUP_TIMEOUT_SECONDS` together, never one alone.
 */
export const WALL_CLOCK_BUDGET_MS = 45_000;

/**
 * `timeoutSeconds` the wrapper declares. Paired with `WALL_CLOCK_BUDGET_MS`
 * above, which must stay strictly below it.
 *
 * Declared rather than inherited: relying on the v2 default kept the pairing
 * true only by luck, and the BUT-1781 closing shape is that the guard and the
 * limit it hides behind are visible in the same file.
 */
export const CACHE_CLEANUP_TIMEOUT_SECONDS = 60;

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /**
   * Wall-clock budget override. Exists so the truncation path — the thing that
   * turns an otherwise-silent timeout into a visible `truncated: true` — can be
   * tested without editing a constant.
   *
   * It is also the correct integration seam if this job ever joins a
   * maintenance chain: `runTaskChain` wraps tasks in `withTimeout`, which RACES
   * rather than cancels, so a chained caller should pass its slice here and let
   * the walk stop itself, not rely on the race.
   */
  budgetMs?: number;
}

export interface CacheCleanupResult {
  scanned: number;
  deleted: number;
  /** Docs whose `cachedAt` could not be read; treated as expired. */
  malformed: number;
  /** True when the walk stopped early — budget or iteration cap. */
  truncated: boolean;
}

/**
 * Walk `globalRecipeCache` one page at a time and delete expired entries.
 *
 * Paging is by `__name__` with a `startAfter` cursor rather than by re-running
 * a filtered query: unlike the notification cleanup, the delete does NOT
 * advance the window here (the "is it expired" test is computed in memory, not
 * expressed as a query), so a cursor is required or the walk would re-read the
 * same page forever.
 */
export async function runCleanupExpiredCache(
  deps: RunDeps = {},
): Promise<CacheCleanupResult> {
  const db = deps.db ?? admin.firestore();
  const nowMs = deps.now != null ? deps.now.getTime() : Date.now();
  const collectionRef = db.collection("globalRecipeCache");

  logger.info("cache_cleanup_start");

  // Real wall clock, never `deps.now` — the budget measures how long THIS
  // invocation has been running, while `nowMs` is the injectable "what counts
  // as expired" clock. Conflating them makes an injected past date exhaust the
  // budget on the first iteration.
  const startedAt = Date.now();
  const budgetMs = deps.budgetMs ?? WALL_CLOCK_BUDGET_MS;
  let scanned = 0;
  let deleted = 0;
  let malformed = 0;
  let iterations = 0;
  let truncated = false;
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    if (Date.now() - startedAt >= budgetMs) {
      truncated = true;
      logger.warn("cache_cleanup_budget_exhausted", {
        budgetMs,
        scanned,
        deleted,
      });
      break;
    }
    if (iterations >= MAX_PAGE_ITERATIONS) {
      truncated = true;
      logger.error("cache_cleanup_max_iterations", {
        maxIterations: MAX_PAGE_ITERATIONS,
        scanned,
        deleted,
      });
      break;
    }
    iterations++;

    let pageQuery = collectionRef
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_LIMIT);
    if (cursor) {
      pageQuery = pageQuery.startAfter(cursor);
    }

    const page = await pageQuery.get();
    if (page.empty) {
      break;
    }

    scanned += page.size;

    // A plain loop, not `.filter()`: `malformed` is a counter, and a side
    // effect inside a predicate is correct only until someone restructures
    // this into `.map().filter()` or re-evaluates it.
    const expired: admin.firestore.QueryDocumentSnapshot[] = [];
    for (const doc of page.docs) {
      const data = doc.data();

      // A malformed `cachedAt` (present but not a Timestamp) would throw out of
      // the whole run. Because the walk is `__name__`-ordered with no persisted
      // cursor, ONE such document would then block every document sorting after
      // it — every day, forever — and inside a shared maintenance chain it would
      // take the tasks behind it down too. `firestore.rules` validates only
      // url/title/createdBy/createdAt on this collection, so a client can write
      // it. Treat unreadable as epoch-0, i.e. expired, and count it.
      let cachedAt = 0;
      try {
        cachedAt = data.cachedAt?.toMillis() ?? 0;
      } catch {
        malformed++;
        cachedAt = 0;
      }

      // `> 0`, not `??`. The old code used `data.ttlDays || 90`, so a stored
      // `0`/`null`/`""` fell back to the 90-day default; `??` would let `0`
      // through and expire the row on the next run. The Dart writer never emits
      // those, but the rules do not forbid them, and "behaviour unchanged" has
      // to survive the values the schema actually permits.
      const ttlDays =
        typeof data.ttlDays === "number" && data.ttlDays > 0
          ? data.ttlDays
          : DEFAULT_TTL_DAYS;

      if (cachedAt + ttlDays * MS_PER_DAY < nowMs) {
        expired.push(doc);
      }
    }

    if (expired.length > 0) {
      // A page is at most BATCH_LIMIT docs, so `expired` is at most one
      // Firestore write batch — no chunking needed, and no need to fake a
      // QuerySnapshot to reuse `batchDeleteDocs`.
      const batch = db.batch();
      for (const doc of expired) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      deleted += expired.length;
    }

    // Advance from the last SCANNED doc, never the last deleted one. NOT
    // because a deleted anchor fails — Firestore builds the cursor from the
    // snapshot's sort-key values locally (`documentSnapshot.ref` for
    // `__name__`; see `Query._extractFieldValues`) and never re-reads the
    // anchor, which is why `testFullyDeletedPageDoesNotStall` passes. The
    // reason is ORDERING: the last deleted doc can sort BEFORE the last
    // scanned one, so anchoring on it re-reads the page's surviving tail and
    // inflates `scanned` — measured 700 → 701 in
    // `testCursorAnchorsOnLastScannedNotLastDeleted`, whose fixture leaves page
    // one's last doc ALIVE, so the two anchors differ and another page follows
    // to observe it. (The 700 → 799 figure is a DIFFERENT mutant —
    // an `indexOf`-based fake cursor, pinned by `testFakeCursorModelIsFaithful`,
    // which stays green under the anchor mutant because its page-one tail is
    // itself deleted.)
    //
    // The "deleted docs cannot anchor a cursor" belief is also written into
    // `cleanup-old-notifications.ts:49-50` — wrong there too, but harmless,
    // since that walk genuinely needs no cursor.
    cursor = page.docs[page.docs.length - 1];

    if (page.size < BATCH_LIMIT) {
      break;
    }
  }

  logger.info("cache_cleanup_complete", { scanned, deleted, malformed, truncated });
  return { scanned, deleted, malformed, truncated };
}

/** Schedule wrapper — thin delegate, daily at 02:00 UTC. */
export const cleanupExpiredCache = onSchedule(
  {
    schedule: "0 2 * * *",
    timeZone: "UTC",
    timeoutSeconds: CACHE_CLEANUP_TIMEOUT_SECONDS,
  },
  async () => {
    await runCleanupExpiredCache();
  },
);
