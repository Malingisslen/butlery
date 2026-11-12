/**
 * Pooled-ratings abuse alarm (BUT-1517, plan condition C9). A shared
 * "Butlery-betyget" is a public reputation signal, so a brigaded pool or a
 * newly-built fake pool must surface on the admin anomaly banner the morning
 * after. Runs inside `runDetectAnomalies` and adds its entries to the same
 * report doc, so no new reader or scheduler is needed.
 *
 * Inputs per run:
 *   - every pool event written in the last 48 h (collection-group range query
 *     on `createdAt`, which the mirror rewrites on every vote and re-vote, so a
 *     wave of changed votes counts as activity too);
 *   - the stored daily vote counts of earlier runs (baseline);
 *   - `canonical_recipe_stats/{poolKey}` for each pool active in the window.
 *
 * Three deterministic rules, no LLM:
 *   - `pool_velocity`: a pool takes at least VELOCITY_FLOOR votes in 24 h and
 *     that is a spike against its own history (|z| > 3 with ≥ MIN_SAMPLES
 *     baseline days; otherwise, or when the history is flat, at least
 *     FLAT_MULTIPLIER times its baseline mean).
 *   - `pool_rating_skew`: at least SKEW_MIN_VOTES votes in 24 h whose mean sits
 *     SKEW_STARS or more from the pool's average WITHOUT those votes.
 *   - `pool_new_over_floor`: a pool shows a number (count ≥ DISPLAY_FLOOR) that
 *     it did not show 48 h ago, and most of its votes are from those 48 h. This
 *     covers the gap below VELOCITY_FLOOR, where a handful of matured accounts
 *     could otherwise publish an invented average unnoticed.
 *
 * Known limit: an attack slower than a few votes a day trips none of these and
 * also raises its own baseline. The go-live runbook says so.
 *
 * Budget per run: one read per pool event written in the last 48 h (so each
 * vote is billed on two nights, capped at MAX_WINDOW_EVENTS), ≤ 29 day docs
 * (only when some pool was active), one stats read per active pool, and one
 * write.
 *
 * Privacy: nothing here stores or logs a uid, a uid hash or recipe content. The
 * daily doc holds pool keys and counts only, and expires after RETENTION_DAYS.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "../ratings/canonical-rating-aggregation";
import { CANONICAL_STATS_COLLECTION } from "../ratings/update-pooled-rating-stats";

export const VELOCITY_FLOOR = 10;
export const FLAT_MULTIPLIER = 3;
export const SKEW_MIN_VOTES = 5;
export const SKEW_STARS = 1.5;
/** Mirrors the client's pill threshold (n ≥ 5). */
export const DISPLAY_FLOOR = 5;
const MIN_SAMPLES = 14;
const Z_THRESHOLD = 3;
const BASELINE_DAYS = 28;
/** Pools below this daily count are left out of the stored map to keep the doc small. */
const MIN_STORED_DAILY_COUNT = 2;
export const RETENTION_DAYS = 35;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * `analytics/pool_velocity/pool_velocity_days/{date}`. The collection id is
 * unique so its TTL policy (a collection-group setting) reaches nothing else.
 */
export const POOL_VELOCITY_DAYS = "pool_velocity_days";

export type PoolMetric =
  | "pool_velocity"
  | "pool_rating_skew"
  | "pool_new_over_floor"
  | "pool_window_overflow";

/**
 * Cap on the 48 h window read. Above it the run evaluates what it read (counts
 * are then lower bounds) and reports `pool_window_overflow`, so a flood cannot
 * blind the alarm silently.
 */
export const MAX_WINDOW_EVENTS = 20_000;
/** `getAll` batch size for the per-pool stats reads. */
const STATS_BATCH = 100;

export interface PoolAnomaly {
  metric: PoolMetric;
  /** Absent only on `pool_window_overflow`, which is about the run, not a pool. */
  poolKey?: string;
  today: number;
  mean: number;
  z: number;
  direction: "up" | "down";
}

export interface PoolActivity {
  votes24h: number;
  sum24h: number;
  votes48h: number;
}

export interface PoolStatsSnapshot {
  count: number;
  average: number | null;
}

function round1(x: number): number {
  return Math.round(x * 10) / 10;
}

function meanAndStddev(values: number[]): { mean: number; stddev: number } {
  if (values.length === 0) return { mean: 0, stddev: 0 };
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  if (values.length < 2) return { mean, stddev: 0 };
  const variance =
    values.reduce((acc, v) => acc + (v - mean) * (v - mean), 0) / (values.length - 1);
  return { mean, stddev: Math.sqrt(variance) };
}

/** Pure: every rule for one pool. `baseline` holds one count per earlier stored day. */
export function evaluatePool(
  poolKey: string,
  activity: PoolActivity,
  poolStats: PoolStatsSnapshot | null,
  baseline: number[],
): PoolAnomaly[] {
  const out: PoolAnomaly[] = [];
  const today = activity.votes24h;

  if (today >= VELOCITY_FLOOR) {
    const { mean, stddev } = meanAndStddev(baseline);
    const useZ = baseline.length >= MIN_SAMPLES && stddev > 0;
    const spike = useZ
      ? (today - mean) / stddev > Z_THRESHOLD && today - mean >= VELOCITY_FLOOR
      : today >= FLAT_MULTIPLIER * mean;
    if (spike) {
      out.push({
        metric: "pool_velocity",
        poolKey,
        today,
        mean: round1(mean),
        z: useZ ? round1((today - mean) / stddev) : 0,
        direction: "up",
      });
    }
  }

  if (
    today >= SKEW_MIN_VOTES &&
    poolStats != null &&
    poolStats.average != null &&
    poolStats.count > today
  ) {
    // The stored average already includes today's votes; back them out. A
    // changed vote is treated as new here, which slightly understates the shift.
    const before =
      (poolStats.count * poolStats.average - activity.sum24h) / (poolStats.count - today);
    const todayMean = activity.sum24h / today;
    const delta = todayMean - before;
    if (Math.abs(delta) >= SKEW_STARS) {
      out.push({
        metric: "pool_rating_skew",
        poolKey,
        today: round1(todayMean),
        mean: round1(before),
        z: 0,
        direction: delta >= 0 ? "up" : "down",
      });
    }
  }

  if (
    poolStats != null &&
    poolStats.count >= DISPLAY_FLOOR &&
    poolStats.count - activity.votes48h < DISPLAY_FLOOR &&
    activity.votes48h * 2 > poolStats.count
  ) {
    out.push({
      metric: "pool_new_over_floor",
      poolKey,
      today: poolStats.count,
      mean: activity.votes48h,
      z: 0,
      direction: "up",
    });
  }

  return out;
}

export interface PoolVelocityDeps {
  db: admin.firestore.Firestore;
  nowMs: number;
  dateStr: string;
}

// The parent is spelled as a literal so the reset's analytics writer scan can resolve it.
function daysCollection(db: admin.firestore.Firestore) {
  return db.collection("analytics").doc("pool_velocity").collection(POOL_VELOCITY_DAYS);
}

async function readActivity(
  db: admin.firestore.Firestore,
  nowMs: number,
): Promise<{ byPool: Map<string, PoolActivity>; overflow: boolean }> {
  const since48 = admin.firestore.Timestamp.fromMillis(nowMs - 2 * DAY_MS);
  const since24Ms = nowMs - DAY_MS;
  const snap = await db
    .collectionGroup(CANONICAL_EVENTS_SUBCOLLECTION)
    .where("createdAt", ">=", since48)
    .select("poolKey", "ratingValue", "createdAt")
    .limit(MAX_WINDOW_EVENTS + 1)
    .get();
  const overflow = snap.docs.length > MAX_WINDOW_EVENTS;
  const byPool = new Map<string, PoolActivity>();
  for (const doc of snap.docs.slice(0, MAX_WINDOW_EVENTS)) {
    const data = doc.data();
    const poolKey = data.poolKey;
    const value = data.ratingValue;
    const createdMs = (data.createdAt as admin.firestore.Timestamp | undefined)?.toMillis?.();
    if (typeof poolKey !== "string" || typeof value !== "number" || createdMs == null) continue;
    const a = byPool.get(poolKey) ?? { votes24h: 0, sum24h: 0, votes48h: 0 };
    a.votes48h++;
    if (createdMs >= since24Ms) {
      a.votes24h++;
      a.sum24h += value;
    }
    byPool.set(poolKey, a);
  }
  return { byPool, overflow };
}

/**
 * Baseline per pool from the earlier stored days. A pool absent from a day doc
 * that EXISTS had fewer than MIN_STORED_DAILY_COUNT votes and counts as 0; a day
 * with no doc (the job did not run) is skipped, never guessed.
 */
async function readBaselines(
  db: admin.firestore.Firestore,
  dateStr: string,
  poolKeys: string[],
): Promise<Map<string, number[]>> {
  const out = new Map<string, number[]>();
  if (poolKeys.length === 0) return out;
  const snap = await daysCollection(db)
    .orderBy(admin.firestore.FieldPath.documentId(), "desc")
    .limit(BASELINE_DAYS + 1)
    .get();
  const days = snap.docs
    .filter((d) => d.id !== dateStr)
    .slice(0, BASELINE_DAYS)
    .map((d) => (d.data().counts ?? {}) as Record<string, unknown>);
  for (const key of poolKeys) {
    out.set(
      key,
      days.map((counts) => (typeof counts[key] === "number" ? (counts[key] as number) : 0)),
    );
  }
  return out;
}

async function readStats(
  db: admin.firestore.Firestore,
  poolKeys: string[],
): Promise<Map<string, PoolStatsSnapshot>> {
  const out = new Map<string, PoolStatsSnapshot>();
  for (let i = 0; i < poolKeys.length; i += STATS_BATCH) {
    const refs = poolKeys
      .slice(i, i + STATS_BATCH)
      .map((key) => db.collection(CANONICAL_STATS_COLLECTION).doc(key));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      if (!snap.exists) continue;
      const data = snap.data() ?? {};
      out.set(snap.id, {
        count: typeof data.count === "number" ? data.count : 0,
        average: typeof data.average === "number" ? data.average : null,
      });
    }
  }
  return out;
}

/** Reads the window, stores today's counts, and returns the flagged pools. */
export async function runDetectPoolVelocity(deps: PoolVelocityDeps): Promise<PoolAnomaly[]> {
  const { db, nowMs, dateStr } = deps;
  const { byPool: activity, overflow } = await readActivity(db, nowMs);
  const poolKeys = [...activity.keys()];
  const baselines = await readBaselines(db, dateStr, poolKeys);

  const counts: Record<string, number> = {};
  for (const [key, a] of activity) {
    if (a.votes24h >= MIN_STORED_DAILY_COUNT) counts[key] = a.votes24h;
  }
  // Written every night, also with no activity, so "no doc" keeps meaning "the job did not run".
  await daysCollection(db).doc(dateStr).set({
    date: dateStr,
    counts,
    expireAt: admin.firestore.Timestamp.fromMillis(nowMs + RETENTION_DAYS * DAY_MS),
  });

  const stats = await readStats(db, poolKeys);
  const anomalies: PoolAnomaly[] = [];
  for (const key of poolKeys) {
    anomalies.push(
      ...evaluatePool(key, activity.get(key)!, stats.get(key) ?? null, baselines.get(key) ?? []),
    );
  }
  if (overflow) {
    anomalies.push({
      metric: "pool_window_overflow",
      today: MAX_WINDOW_EVENTS,
      mean: 0,
      z: 0,
      direction: "up",
    });
  }

  logger.info("detect_pool_velocity_complete", {
    date: dateStr,
    activePools: poolKeys.length,
    flagged: anomalies.length,
  });
  return anomalies;
}
