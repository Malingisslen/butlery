/**
 * Generic Firestore debounce queue (extracted from BUT-482's rating debounce).
 *
 * A namespaced coalescing queue: many rapid "please recompute X" signals within
 * a short window collapse to ONE eventual drain of X. Used by:
 *   - rating aggregation (namespace `_internal/rating_debounce/markers`,
 *     key = recipeId) — see ratings/rating-aggregation.ts
 *   - pooled-rating aggregation (namespace `_internal/pool_debounce/markers`,
 *     key = poolKey) — added by the pooled-ratings aggregator (increments 2–3
 *     of tasks/todo.md); not yet wired at the time this core landed.
 *
 * Decision 5 of tasks/pooled-ratings-plan.md: the pool aggregator REUSES this
 * (a `DebounceConfig` with a different marker collection), it does NOT fork a
 * second copy of the transaction/claim-by-delete logic.
 *
 * Mechanism (unchanged from BUT-482):
 *   1. `scheduleDebounced(config, key)` runs a transaction on
 *      `{markerCollection}/{key}`: if no marker or the pending window has passed,
 *      write a fresh marker `pendingUntil = now + debounceMs`; if a marker is
 *      still pending, coalesce (no write).
 *   2. A scheduled drainer calls `drainDebounceQueue(config, {drain})`, scans for
 *      `pendingUntil <= now`, and per marker: delete-first (claim), then drain.
 *   3. The drain callback is expected to be idempotent (it recomputes from the
 *      source of truth), so a rare double-run across concurrent drains is safe.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

/**
 * Max markers a single scheduled drain claims. When a scan comes back full, the
 * queue is at/over capacity: the overflow waits for the next minute's run (the
 * drain self-corrects across runs). That silent self-correction hides a
 * sustained backlog, so a full scan raises `capped` + a warn log — BUT-1509.
 */
export const DRAIN_LIMIT = 500;

export interface DebounceConfig {
  /** Firestore collection path holding markers, e.g. "_internal/rating_debounce/markers". */
  markerCollection: string;
  /** Coalescing window in milliseconds. */
  debounceMs: number;
  /** Structured-log event prefix, e.g. "rating_aggregation" or "pool_aggregation". */
  logPrefix: string;
  /**
   * Name of the structured-log payload field carrying the key value, e.g.
   * "recipeId" or "poolKey". Defaults to "key". Set per-namespace so existing
   * log-based metrics/alerts that filter on the domain field keep matching.
   */
  logKeyField?: string;
}

export interface ScheduleDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
}

export interface DrainDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
  /** The per-key work. Test seam — defaults to throwing (caller must wire it). */
  drain?: (key: string) => Promise<void>;
}

interface DebounceMarker {
  key: string;
  pendingUntil: admin.firestore.Timestamp;
  scheduledAt: admin.firestore.Timestamp;
}

export function debounceMarkerRef(
  db: admin.firestore.Firestore,
  config: DebounceConfig,
  key: string
): admin.firestore.DocumentReference {
  return db.doc(`${config.markerCollection}/${key}`);
}

/**
 * Schedule (or coalesce into) a debounced drain for `key`.
 * Returns true if a fresh run was scheduled, false if coalesced/short-circuited.
 */
export async function scheduleDebounced(
  config: DebounceConfig,
  key: string,
  deps: ScheduleDeps = {}
): Promise<boolean> {
  if (!key) {
    logger.warn(`${config.logPrefix}.schedule called with empty key`);
    return false;
  }
  const db = deps.db ?? admin.firestore();
  const nowMs = (deps.now ?? (() => new Date()))().getTime();

  const ref = debounceMarkerRef(db, config, key);
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
      key,
      pendingUntil: admin.firestore.Timestamp.fromMillis(nowMs + config.debounceMs),
      scheduledAt: admin.firestore.Timestamp.fromMillis(nowMs),
    };
    tx.set(ref, marker);
    return true;
  });

  const keyField = config.logKeyField ?? "key";
  if (scheduled) {
    logger.info(`${config.logPrefix}.scheduled`, {
      event: `${config.logPrefix}.scheduled`,
      [keyField]: key,
    });
  } else {
    logger.info(`${config.logPrefix}.skipped`, {
      event: `${config.logPrefix}.skipped`,
      [keyField]: key,
      reason: "debounce",
    });
  }
  return scheduled;
}

/**
 * Drain pending markers whose `pendingUntil` has elapsed. Per marker:
 * delete-first (claim; minimises double-runs — the drain is idempotent), then
 * run the drain callback. Returns counts for one summary log.
 */
export async function drainDebounceQueue(
  config: DebounceConfig,
  deps: DrainDeps = {}
): Promise<{
  processed: number;
  failed: number;
  durationMs: number;
  capped: boolean;
}> {
  const start = Date.now();
  const db = deps.db ?? admin.firestore();
  const now = (deps.now ?? (() => new Date()))();
  const drain =
    deps.drain ??
    (async () => {
      throw new Error(`${config.logPrefix}: no drain impl provided`);
    });

  const snap = await db
    .collection(config.markerCollection)
    .where("pendingUntil", "<=", admin.firestore.Timestamp.fromDate(now))
    .limit(DRAIN_LIMIT)
    .get();

  // A full scan means more ready markers may be waiting for the next run. Emit a
  // warn-level structured signal so a saturated queue is observable (a log-based
  // metric/alert can watch `${logPrefix}.drain_saturated`) instead of silently
  // self-correcting one minute at a time (BUT-1509).
  const capped = snap.size >= DRAIN_LIMIT;
  if (capped) {
    logger.warn(`${config.logPrefix}.drain_saturated`, {
      event: `${config.logPrefix}.drain_saturated`,
      limit: DRAIN_LIMIT,
      scanned: snap.size,
    });
  }

  let processed = 0;
  let failed = 0;
  for (const doc of snap.docs) {
    const data = doc.data() as DebounceMarker | undefined;
    // `?? doc.id` keeps drain correct for markers written by the pre-extraction
    // code (field `recipeId`) and for any future field rename — the doc ID is
    // always the key.
    const key = data?.key ?? doc.id;
    try {
      // Claim-by-delete before draining (unchanged BUT-482 design). A fresh
      // signal landing mid-drain writes a new marker the next drain picks up —
      // the desired re-fire behaviour. Tradeoff (pre-existing): if the drain
      // THROWS transiently and no further signal for this key arrives, its
      // recompute waits until the next signal (self-heals then). Acceptable —
      // the recompute is idempotent and active recipes/pools get frequent
      // signals; not changed here to keep this extraction behavior-preserving.
      await doc.ref.delete();
      await drain(key);
      processed++;
    } catch (err) {
      failed++;
      logger.error(`${config.logPrefix}.failed`, {
        event: `${config.logPrefix}.failed`,
        [config.logKeyField ?? "key"]: key,
        err,
      });
    }
  }
  return { processed, failed, durationMs: Date.now() - start, capped };
}
