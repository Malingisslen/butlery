/**
 * Nightly anomaly detector for the admin dashboard's non-time-series tabs.
 *
 * The `daily-snapshots.ts` jobs each write ONE scalar-bearing doc per UTC day
 * at `analytics/<group>/daily/{date}`. This job reads the recent daily series
 * for each monitored group and flags a metric as anomalous when today's value
 * is a statistical outlier versus the trailing baseline.
 *
 * It runs as the ninth task in the `dailyAnalytics` chain (06:00 UTC — see
 * `scheduled/maintenance-dispatchers.ts`); it no longer owns a Cloud Scheduler
 * job. Its position is load-bearing: the five snapshot tasks are its producers
 * and run ahead of it in the same chain. A missing producer doc is SKIPPED,
 * never assumed zero.
 *
 * Structurally mirrors `daily-snapshots.ts`:
 *   - A `runDetectAnomalies(deps)` test-seam function, called both by the
 *     dispatcher and directly by tests. No `onSchedule` wrapper lives here.
 *   - `logger.info` start/complete with structured fields.
 *   - Deterministic doc id = the run-day UTC date string → a same-day re-run
 *     OVERWRITES (idempotent via `set()`, never `create()`). The chain runs
 *     with `retryCount: 0`, so there is no automatic re-run.
 *
 * Output: `analytics/anomalies/daily/{date}` (4 segments = a doc), matching the
 * snapshot-path convention and the Flutter AnomalyRepository that reads it.
 *
 * **Read budget (per run)**: 5 series × ≤29 daily docs ≈ ≤145 reads/day —
 * effectively free. Each series is a single ordered, limited subcollection
 * scan.
 *
 * **Detection rule** (per series, ALL must hold to flag):
 *   1. baseline sample count ≥ MIN_SAMPLES (14)
 *   2. baseline stddev > 0
 *   3. |z| > Z_THRESHOLD (3)
 *   4. |today − mean| ≥ the per-series ABSOLUTE_FLOOR (default 5) — so a 3σ
 *      deviation on tiny counts (e.g. 0→2) does not fire.
 * If today's doc is missing for a series, it is skipped (logged at info).
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

/** Minimum baseline sample count before a series can be flagged. */
const MIN_SAMPLES = 14;

/** How many trailing daily docs to read (1 run-day + ≤28 baseline). */
const SERIES_WINDOW = 29;

/** |z| above which a deviation is a candidate anomaly. */
const Z_THRESHOLD = 3;

/** Default absolute floor on |today − mean| so 3σ on tiny numbers won't fire. */
const DEFAULT_ABSOLUTE_FLOOR = 5;

/**
 * One monitored scalar series. `group` is the snapshot subtree under
 * `analytics/<group>/daily`; `field` is the numeric field inside each daily
 * doc; `metric` is the exact `<group>_<field>` token the Flutter banner maps
 * to a human label. `absoluteFloor` overrides DEFAULT_ABSOLUTE_FLOOR.
 */
export interface MonitoredSeries {
  group: string;
  field: string;
  metric: string;
  absoluteFloor: number;
}

/**
 * The five series this job watches. `metric` MUST equal `<group>_<field>` —
 * the Flutter AnomalyRepository keys its label map off these exact strings.
 */
export const MONITORED_SERIES: readonly MonitoredSeries[] = [
  {
    group: "import_health",
    field: "totalFailure",
    metric: "import_health_totalFailure",
    absoluteFloor: DEFAULT_ABSOLUTE_FLOOR,
  },
  {
    group: "recipes",
    field: "total",
    metric: "recipes_total",
    absoluteFloor: DEFAULT_ABSOLUTE_FLOOR,
  },
  {
    group: "parsing_corrections",
    field: "total",
    metric: "parsing_corrections_total",
    absoluteFloor: DEFAULT_ABSOLUTE_FLOOR,
  },
  {
    group: "ops",
    field: "totalEvents",
    metric: "ops_totalEvents",
    absoluteFloor: DEFAULT_ABSOLUTE_FLOOR,
  },
  {
    group: "feedback",
    field: "total",
    metric: "feedback_total",
    absoluteFloor: DEFAULT_ABSOLUTE_FLOOR,
  },
];

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

const getDb = () => admin.firestore();

/** Format a UTC `yyyy-mm-dd` from a millisecond timestamp. */
export function formatUtcDate(ms: number): string {
  const d = new Date(ms);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

export interface AnomalyEntry {
  metric: string;
  today: number;
  mean: number;
  /** z-score, rounded to 1 decimal. */
  z: number;
  direction: "up" | "down";
}

export interface AnomalyReport {
  date: string;
  anomalies: AnomalyEntry[];
  computedAt: admin.firestore.Timestamp;
}

/**
 * A single daily-series row pulled from `analytics/<group>/daily`: the doc id
 * (the `yyyy-mm-dd`) plus the monitored numeric value.
 */
interface SeriesPoint {
  date: string;
  value: number;
}

/** Population/sample stats over a numeric array. */
interface BaselineStats {
  count: number;
  mean: number;
  /** Sample standard deviation (n−1 denominator). */
  stddev: number;
}

/** Sample mean + sample stddev (n−1). Returns stddev 0 when count < 2. */
export function computeBaselineStats(values: number[]): BaselineStats {
  const count = values.length;
  if (count === 0) return { count: 0, mean: 0, stddev: 0 };
  const mean = values.reduce((a, b) => a + b, 0) / count;
  if (count < 2) return { count, mean, stddev: 0 };
  const variance =
    values.reduce((acc, v) => acc + (v - mean) * (v - mean), 0) / (count - 1);
  return { count, mean, stddev: Math.sqrt(variance) };
}

/**
 * Decide whether a (today, baseline) pair is anomalous and, if so, build the
 * entry. Pure — testable in isolation. Applies all four gates.
 */
export function evaluateSeries(
  series: MonitoredSeries,
  today: number,
  baseline: number[],
): AnomalyEntry | null {
  const { count, mean, stddev } = computeBaselineStats(baseline);
  if (count < MIN_SAMPLES) return null;
  if (stddev <= 0) return null;

  const delta = today - mean;
  if (Math.abs(delta) < series.absoluteFloor) return null;

  const z = delta / stddev;
  if (Math.abs(z) <= Z_THRESHOLD) return null;

  return {
    metric: series.metric,
    today,
    mean,
    z: Math.round(z * 10) / 10,
    direction: delta >= 0 ? "up" : "down",
  };
}

/** Coerce a stored field to a finite number, or null if absent/invalid. */
function readNumericField(
  data: Record<string, unknown> | undefined,
  field: string,
): number | null {
  const raw = data?.[field];
  return typeof raw === "number" && Number.isFinite(raw) ? raw : null;
}

/**
 * Read the trailing daily series for one group: the last SERIES_WINDOW docs
 * by date desc. Returns oldest→newest is irrelevant here; callers split on the
 * run-day date string, so we return the raw points keyed by date.
 */
async function readSeries(
  db: admin.firestore.Firestore,
  group: string,
  field: string,
): Promise<SeriesPoint[]> {
  const snap = await db
    .collection("analytics")
    .doc(group)
    .collection("daily")
    .orderBy(admin.firestore.FieldPath.documentId(), "desc")
    .limit(SERIES_WINDOW)
    .get();

  const points: SeriesPoint[] = [];
  for (const doc of snap.docs) {
    const value = readNumericField(doc.data(), field);
    if (value == null) continue;
    points.push({ date: doc.id, value });
  }
  return points;
}

export async function runDetectAnomalies(
  deps: RunDeps = {},
): Promise<AnomalyReport> {
  const db = deps.db ?? getDb();
  const nowMs = deps.now != null ? deps.now.getTime() : Date.now();
  const dateStr = formatUtcDate(nowMs);
  const computedAt = admin.firestore.Timestamp.fromMillis(nowMs);

  logger.info("detect_anomalies_start", { date: dateStr });

  const anomalies: AnomalyEntry[] = [];

  for (const series of MONITORED_SERIES) {
    const points = await readSeries(db, series.group, series.field);

    const todayPoint = points.find((p) => p.date === dateStr);
    if (todayPoint == null) {
      // No run-day snapshot for this series — the snapshot job may not have
      // run yet or the series has no data. Skip rather than guess.
      logger.info("detect_anomalies_today_missing", {
        date: dateStr,
        group: series.group,
        metric: series.metric,
      });
      continue;
    }

    // Baseline = the ≤28 prior days (exclude the run-day doc).
    const baseline = points
      .filter((p) => p.date !== dateStr)
      .map((p) => p.value);

    const entry = evaluateSeries(series, todayPoint.value, baseline);
    if (entry != null) {
      anomalies.push(entry);
      logger.info("detect_anomalies_flagged", {
        date: dateStr,
        metric: entry.metric,
        today: entry.today,
        mean: entry.mean,
        z: entry.z,
        direction: entry.direction,
        baselineSamples: baseline.length,
      });
    }
  }

  const result: AnomalyReport = { date: dateStr, anomalies, computedAt };

  // `analytics/anomalies/daily/{date}` (4 segments = a doc). set() = idempotent.
  await db
    .collection("analytics")
    .doc("anomalies")
    .collection("daily")
    .doc(dateStr)
    .set(result);

  logger.info("detect_anomalies_complete", {
    date: dateStr,
    flagged: anomalies.length,
  });
  return result;
}
