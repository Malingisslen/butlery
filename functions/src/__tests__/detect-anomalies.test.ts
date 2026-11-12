/**
 * detectAnomalies tests — pure unit level, no emulator.
 *
 * The SUT reads, per monitored group, the last ≤29 daily docs at
 * `analytics/<group>/daily` (id-desc) and writes one report doc at
 * `analytics/anomalies/daily/{date}`. We inject the series via a minimal fake
 * Firestore that supports exactly the call shapes the SUT uses:
 *
 *   db.collection("analytics").doc(group).collection("daily")
 *     .orderBy(FieldPath.documentId(), "desc").limit(N).get()
 *   db.collection("analytics").doc("anomalies").collection("daily")
 *     .doc(date).set(data)
 *
 * Coverage:
 *   (a) clear spike → flagged, direction "up"
 *   (b) <14 baseline samples → not flagged
 *   (c) within-floor small numbers (z>3 but |delta|<floor) → not flagged
 *   (d) flat series (stddev 0) → not flagged
 *   (e) a drop → flagged, direction "down"
 *
 * Run with: npx ts-node src/__tests__/detect-anomalies.test.ts
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "butlery-test-detect-anomalies" });
}

import {
  runDetectAnomalies,
  evaluateSeries,
  computeBaselineStats,
  MONITORED_SERIES,
  MonitoredSeries,
  AnomalyReport,
} from "../analytics/detect-anomalies";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

function utcDate(ms: number): string {
  const d = new Date(ms);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** A fake daily-doc store keyed by `analytics/<group>/daily/<date>`. */
interface FakeStore {
  /** group → (date → record). */
  series: Map<string, Map<string, Record<string, unknown>>>;
  /** path → last-written report (output). */
  writes: Map<string, Record<string, unknown>>;
  writeCount: number;
}

/**
 * Build a daily series for a group ending at `endMs`, one doc per day going
 * backwards. `values[0]` is the most-recent (run-day) value, `values[1]` is
 * yesterday, etc. Each value writes `{ [field]: value }`.
 */
function seedSeries(
  store: FakeStore,
  series: MonitoredSeries,
  endMs: number,
  values: number[],
): void {
  let group = store.series.get(series.group);
  if (!group) {
    group = new Map();
    store.series.set(series.group, group);
  }
  values.forEach((value, i) => {
    const date = utcDate(endMs - i * MS_PER_DAY);
    group!.set(date, { [series.field]: value });
  });
}

function makeFakeDb(store: FakeStore) {
  function dailyCollection(group: string) {
    return {
      orderBy(_field: unknown, _dir: string) {
        return this;
      },
      limit(n: number) {
        return {
          async get() {
            const byDate = store.series.get(group) ?? new Map();
            // id-desc order, capped at n.
            const docs = Array.from(byDate.entries())
              .sort((a, b) => (a[0] < b[0] ? 1 : a[0] > b[0] ? -1 : 0))
              .slice(0, n)
              .map(([id, data]) => ({ id, data: () => data }));
            return { size: docs.length, docs, empty: docs.length === 0 };
          },
        };
      },
      // The output path uses .doc(date).set(...) on the "anomalies/daily" coll.
      doc(date: string) {
        return {
          async set(data: Record<string, unknown>) {
            const path = `analytics/${group}/daily/${date}`;
            store.writes.set(path, data);
            store.writeCount++;
          },
        };
      },
    };
  }

  return {
    collection(name: string) {
      if (name !== "analytics") {
        throw new Error(`unexpected collection ${name}`);
      }
      return {
        doc(group: string) {
          return {
            collection(sub: string) {
              if (sub !== "daily") {
                throw new Error(`unexpected subcollection ${sub}`);
              }
              return dailyCollection(group);
            },
          };
        },
      };
    },
  } as unknown as admin.firestore.Firestore;
}

function newStore(): FakeStore {
  return { series: new Map(), writes: new Map(), writeCount: 0 };
}

function bySeries(metric: string): MonitoredSeries {
  const s = MONITORED_SERIES.find((x) => x.metric === metric);
  if (!s) throw new Error(`no series ${metric}`);
  return s;
}

function readReport(store: FakeStore, date: string): AnomalyReport {
  const path = `analytics/anomalies/daily/${date}`;
  return store.writes.get(path) as unknown as AnomalyReport;
}

const noPool = async () => [];

async function main() {
  // Fail closed: case (m) pins a deadline against a promise that never
  // resolves, and if the deadline is gone Node exits 0 with the summary unprinted.
  process.exitCode = 1;
  console.log("detect-anomalies tests\n");

  const now = new Date(Date.UTC(2026, 5, 20, 6, 0, 0));
  const nowMs = now.getTime();
  const runDate = utcDate(nowMs);

  // ── (a) clear spike → flagged, direction "up" ──────────────────────────
  {
    const store = newStore();
    // 28 baseline days at ~2 import failures (small jitter), today = 40.
    const baseline = Array.from({ length: 28 }, (_, i) => (i % 2 === 0 ? 2 : 3));
    seedSeries(store, bySeries("import_health_totalFailure"), nowMs, [
      40,
      ...baseline,
    ]);

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const hit = report.anomalies.find(
      (a) => a.metric === "import_health_totalFailure",
    );
    record(
      "(a) clear spike is flagged with direction up",
      !!hit && hit.direction === "up" && hit.today === 40,
      JSON.stringify(report.anomalies),
    );
    record(
      "(a) report doc written at analytics/anomalies/daily/{runDate}",
      readReport(store, runDate) != null && report.date === runDate,
    );
  }

  // ── (b) <14 baseline samples → not flagged ─────────────────────────────
  {
    const store = newStore();
    // Only 10 baseline days + today spike. Below MIN_SAMPLES (14).
    const baseline = Array.from({ length: 10 }, () => 2);
    seedSeries(store, bySeries("recipes_total"), nowMs, [100, ...baseline]);

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const hit = report.anomalies.find((a) => a.metric === "recipes_total");
    record(
      "(b) under MIN_SAMPLES baseline is not flagged",
      !hit,
      JSON.stringify(report.anomalies),
    );
  }

  // ── (c) within-floor small numbers → not flagged even if z>3 ────────────
  {
    const store = newStore();
    // Baseline all 0, today = 2. stddev 0 would short-circuit, so add a tiny
    // jitter to give a positive stddev, keeping |delta| below the floor (5).
    // 27 zeros + 1 one → mean ≈ 0.036, stddev > 0. today = 2 → z is huge but
    // |today - mean| ≈ 1.96 < 5.
    const baseline = [1, ...Array.from({ length: 27 }, () => 0)];
    seedSeries(store, bySeries("feedback_total"), nowMs, [2, ...baseline]);

    const stats = computeBaselineStats(baseline);
    const z =
      stats.stddev > 0 ? (2 - stats.mean) / stats.stddev : 0;
    const sanity = stats.stddev > 0 && Math.abs(z) > 3;

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const hit = report.anomalies.find((a) => a.metric === "feedback_total");
    record(
      "(c) within-floor small numbers not flagged despite z>3",
      !hit && sanity,
      `z=${z.toFixed(2)} stddev=${stats.stddev.toFixed(3)} hit=${JSON.stringify(hit)}`,
    );
  }

  // ── (d) flat series (stddev 0) → not flagged ───────────────────────────
  {
    const store = newStore();
    // 28 baseline days all 100, today = 1000. stddev = 0 → no flag.
    const baseline = Array.from({ length: 28 }, () => 100);
    seedSeries(store, bySeries("ops_totalEvents"), nowMs, [1000, ...baseline]);

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const hit = report.anomalies.find((a) => a.metric === "ops_totalEvents");
    record(
      "(d) flat baseline (stddev 0) not flagged",
      !hit,
      JSON.stringify(report.anomalies),
    );
  }

  // ── (e) a drop → flagged, direction "down" ─────────────────────────────
  {
    const store = newStore();
    // 28 baseline days at ~50 (jitter), today = 5 → big downward deviation.
    const baseline = Array.from({ length: 28 }, (_, i) =>
      i % 2 === 0 ? 50 : 52,
    );
    seedSeries(store, bySeries("recipes_total"), nowMs, [5, ...baseline]);

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const hit = report.anomalies.find((a) => a.metric === "recipes_total");
    record(
      "(e) a drop is flagged with direction down",
      !!hit && hit.direction === "down" && hit.today === 5,
      JSON.stringify(report.anomalies),
    );
  }

  // ── today missing → series skipped, empty report still written ─────────
  {
    const store = newStore();
    // Baseline exists but NO run-day doc for the series.
    const baseline = Array.from({ length: 28 }, () => 10);
    seedSeries(
      store,
      bySeries("recipes_total"),
      nowMs - MS_PER_DAY, // most-recent doc is yesterday, not today
      baseline,
    );

    const report = await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    record(
      "(f) missing run-day doc → series skipped, report still written",
      report.anomalies.length === 0 && readReport(store, runDate) != null,
      JSON.stringify(report.anomalies),
    );
  }

  // ── evaluateSeries pure-function checks ────────────────────────────────
  {
    const s = bySeries("recipes_total");
    const spikeBaseline = Array.from({ length: 20 }, (_, i) =>
      i % 2 === 0 ? 10 : 11,
    );
    const up = evaluateSeries(s, 60, spikeBaseline);
    record(
      "(g) evaluateSeries flags an up spike with rounded z",
      !!up && up.direction === "up" && Number.isFinite(up.z),
      JSON.stringify(up),
    );
    const within = evaluateSeries(s, 12, spikeBaseline);
    record(
      "(h) evaluateSeries returns null inside the absolute floor",
      within === null,
      JSON.stringify(within),
    );
  }

  // ── idempotency: re-run overwrites same path, count++ ──────────────────
  {
    const store = newStore();
    const baseline = Array.from({ length: 28 }, () => 2);
    seedSeries(store, bySeries("import_health_totalFailure"), nowMs, [
      40,
      ...baseline,
    ]);
    await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    await runDetectAnomalies({ db: makeFakeDb(store), now, poolVelocity: noPool });
    const reportPaths = Array.from(store.writes.keys()).filter((p) =>
      p.startsWith("analytics/anomalies/daily/"),
    );
    record(
      "(i) re-run is idempotent — 2 writes, 1 distinct output path",
      store.writeCount === 2 && new Set(reportPaths).size === 1,
      `writeCount=${store.writeCount} paths=${reportPaths.join(",")}`,
    );
  }

  // ── pooled-ratings alarm (BUT-1517) is appended and isolated ───────────
  {
    const store = newStore();
    const baseline = Array.from({ length: 28 }, (_, i) => (i % 2 === 0 ? 2 : 3));
    seedSeries(store, bySeries("import_health_totalFailure"), nowMs, [40, ...baseline]);
    const POOL_KEY = "v1:aaaabbbbccccdddd";
    const OTHER_KEY = "v1:9999888877776666";
    let seenArgs: { nowMs: number; dateStr: string } | null = null;
    const report = await runDetectAnomalies({
      db: makeFakeDb(store),
      now,
      poolVelocity: async (args) => {
        seenArgs = { nowMs: args.nowMs, dateStr: args.dateStr };
        return [
          { metric: "pool_velocity", poolKey: POOL_KEY, today: 12, mean: 0, z: 0, direction: "up" },
          { metric: "pool_rating_skew", poolKey: OTHER_KEY, today: 1, mean: 4.5, z: 0, direction: "down" },
        ];
      },
    });
    const stored = readReport(store, runDate);
    const poolEntries = report.anomalies.filter((a) => a.poolKey != null);
    record(
      "(j) injected poolVelocity entries are appended after the series entries, keeping poolKey",
      report.anomalies.length === 3 &&
        report.anomalies[0].metric === "import_health_totalFailure" &&
        report.anomalies[0].poolKey === undefined &&
        poolEntries.length === 2 &&
        poolEntries[0].metric === "pool_velocity" &&
        poolEntries[0].poolKey === POOL_KEY &&
        poolEntries[1].metric === "pool_rating_skew" &&
        poolEntries[1].poolKey === OTHER_KEY,
      JSON.stringify(report.anomalies),
    );
    record(
      "(j) the stored report carries the pool entries and poolVelocity got the run's nowMs and date",
      stored.anomalies.length === 3 &&
        stored.anomalies.filter((a) => a.poolKey === POOL_KEY).length === 1 &&
        seenArgs != null &&
        (seenArgs as { nowMs: number }).nowMs === nowMs &&
        (seenArgs as { dateStr: string }).dateStr === runDate,
      JSON.stringify(seenArgs),
    );
  }

  {
    const store = newStore();
    const baseline = Array.from({ length: 28 }, (_, i) => (i % 2 === 0 ? 2 : 3));
    seedSeries(store, bySeries("import_health_totalFailure"), nowMs, [40, ...baseline]);
    let called = 0;
    const report = await runDetectAnomalies({
      db: makeFakeDb(store),
      now,
      poolVelocity: async () => {
        called++;
        throw new Error("boom");
      },
    });
    record(
      "(k) a throwing poolVelocity does not stop the report: series anomaly kept, no pool entry, doc written",
      called === 1 &&
        report.anomalies.length === 1 &&
        report.anomalies[0].metric === "import_health_totalFailure" &&
        readReport(store, runDate) != null &&
        readReport(store, runDate).anomalies.length === 1 &&
        store.writeCount === 1,
      JSON.stringify(report.anomalies),
    );
  }

  {
    const store = newStore();
    const baseline = Array.from({ length: 28 }, (_, i) => (i % 2 === 0 ? 2 : 3));
    seedSeries(store, bySeries("import_health_totalFailure"), nowMs, [40, ...baseline]);
    const started = Date.now();
    const report = await runDetectAnomalies({
      db: makeFakeDb(store),
      now,
      poolAlarmBudgetMs: 50,
      poolVelocity: () => new Promise(() => undefined),
    });
    const elapsed = Date.now() - started;
    record(
      "(m) a poolVelocity that never resolves hits the deadline: report written with the series anomaly, fast",
      elapsed < 2000 &&
        report.anomalies.length === 1 &&
        report.anomalies[0].metric === "import_health_totalFailure" &&
        readReport(store, runDate) != null &&
        store.writeCount === 1,
      `elapsed=${elapsed}ms ${JSON.stringify(report.anomalies)}`,
    );
  }

  {
    const store = newStore();
    const report = await runDetectAnomalies({
      db: makeFakeDb(store),
      now,
      poolVelocity: async () => [],
    });
    record(
      "(l) poolVelocity returning nothing leaves an empty report that is still written",
      report.anomalies.length === 0 && readReport(store, runDate) != null,
    );
  }

  console.log(`\n${totalRun - totalFailed}/${totalRun} passed`);
  if (totalFailed > 0) process.exit(1);
  process.exitCode = 0;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
