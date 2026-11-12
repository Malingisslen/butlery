/**
 * Pooled-ratings abuse alarm tests (BUT-1517, plan condition C9) — pure unit
 * level, no emulator.
 *
 * Part 1 drives the pure rules (`evaluatePool`) with fixtures that sit ON each
 * boundary: VELOCITY_FLOOR (9/10), the "at least 10 above the mean" clause, the
 * strict |z| > 3, MIN_SAMPLES (13/14), the flat 3x rule, SKEW_MIN_VOTES (4/5),
 * SKEW_STARS (1.5) and the new-over-floor arithmetic.
 *
 * Part 2 drives `runDetectPoolVelocity` through a fake Firestore that models
 * exactly the verbs the SUT calls:
 *   db.collectionGroup(id).where("createdAt", ">=", ts).get()
 *   db.collection("analytics").doc("pool_velocity").collection("pool_velocity_days")
 *     .orderBy(FieldPath.documentId(), "desc").limit(n).get() / .doc(date).set(data)
 *   db.collection("canonical_recipe_stats").doc(key).get()
 *
 * Run with: npx ts-node src/__tests__/detect-pool-velocity.test.ts
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "butlery-test-detect-pool-velocity" });
}

import {
  evaluatePool,
  runDetectPoolVelocity,
  PoolActivity,
  PoolAnomaly,
  PoolMetric,
  POOL_VELOCITY_DAYS,
  MAX_WINDOW_EVENTS,
} from "../analytics/detect-pool-velocity";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "../ratings/canonical-rating-aggregation";
import * as fs from "fs";
import * as path from "path";
import { CANONICAL_STATS_COLLECTION } from "../ratings/update-pooled-rating-stats";

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

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

const POOL = "v1:aaaabbbbccccdddd";

function activity(votes24h: number, sum24h = votes24h * 3, votes48h = votes24h): PoolActivity {
  return { votes24h, sum24h, votes48h };
}

function only(list: PoolAnomaly[], metric: PoolMetric): PoolAnomaly[] {
  return list.filter((a) => a.metric === metric);
}

/** `n` values alternating lo/hi, starting with lo (so the mean is exact for even n). */
function alternating(n: number, lo: number, hi: number): number[] {
  return Array.from({ length: n }, (_, i) => (i % 2 === 0 ? lo : hi));
}

function velocityRules(): void {
  // ── VELOCITY_FLOOR boundary on a brand-new pool (empty baseline) ──────
  const e12 = only(evaluatePool(POOL, activity(12), null, []), "pool_velocity");
  record(
    "velocity: new pool, empty baseline, 12 votes -> flagged up with poolKey",
    e12.length === 1 &&
      e12[0].poolKey === POOL &&
      e12[0].today === 12 &&
      e12[0].direction === "up" &&
      e12[0].mean === 0,
    JSON.stringify(e12),
  );
  const e10 = only(evaluatePool(POOL, activity(10), null, []), "pool_velocity");
  const e9 = only(evaluatePool(POOL, activity(9), null, []), "pool_velocity");
  record(
    "velocity: exactly 10 votes (VELOCITY_FLOOR) flagged, 9 not",
    e10.length === 1 && e9.length === 0,
    `e10=${e10.length} e9=${e9.length}`,
  );

  // ── steady pool, z path ───────────────────────────────────────────────
  // Seven 2s and seven 4s: mean exactly 3, sample stddev ~1.04.
  const steady = alternating(14, 2, 4);
  const spike15 = only(evaluatePool(POOL, activity(15), null, steady), "pool_velocity");
  record(
    "velocity: steady ~3/day pool, 15 today -> flagged with z > 0 and mean 3",
    spike15.length === 1 && spike15[0].z > 0 && spike15[0].mean === 3,
    JSON.stringify(spike15),
  );
  const d10 = only(evaluatePool(POOL, activity(13), null, steady), "pool_velocity");
  const d9 = only(evaluatePool(POOL, activity(12), null, steady), "pool_velocity");
  record(
    "velocity: today - mean exactly 10 flagged, 9 not (z is huge in both)",
    d10.length === 1 && d9.length === 0,
    `13->${d10.length} 12->${d9.length}`,
  );

  // z must be strictly > 3, and the z path must be the one deciding: this
  // baseline (seven 0s, seven 20s, mean 10, stddev ~10.4) would pass the flat
  // 3x rule at 40 but its z is ~2.9.
  const noisy = alternating(14, 0, 20);
  const z29 = only(evaluatePool(POOL, activity(40), null, noisy), "pool_velocity");
  const z34 = only(evaluatePool(POOL, activity(45), null, noisy), "pool_velocity");
  record(
    "velocity: noisy 14-day baseline uses z (40 -> z~2.9 not flagged, 45 -> z~3.4 flagged)",
    z29.length === 0 && z34.length === 1 && z34[0].z > 3,
    `40->${z29.length} 45->${JSON.stringify(z34)}`,
  );

  // MIN_SAMPLES boundary: one day short falls back to the flat rule.
  const thirteen = [...alternating(12, 5, 7), 7]; // mean 79/13 ~ 6.08
  const fourteen = alternating(14, 5, 7); // mean 6
  const m13 = only(evaluatePool(POOL, activity(17), null, thirteen), "pool_velocity");
  const m14 = only(evaluatePool(POOL, activity(17), null, fourteen), "pool_velocity");
  record(
    "velocity: 13 baseline days use flat rule (17 < 3x6.08, not flagged); 14 use z (flagged)",
    m13.length === 0 && m14.length === 1 && m14[0].z > 3,
    `13->${m13.length} 14->${JSON.stringify(m14)}`,
  );

  // ── flat series: stddev 0 -> 3x mean ──────────────────────────────────
  const flat = Array.from({ length: 14 }, () => 10);
  const f10 = only(evaluatePool(POOL, activity(10), null, flat), "pool_velocity");
  const f29 = only(evaluatePool(POOL, activity(29), null, flat), "pool_velocity");
  const f30 = only(evaluatePool(POOL, activity(30), null, flat), "pool_velocity");
  record(
    "velocity: flat ~10/day, 10 today not flagged; 3x boundary: 29 not, 30 flagged with z 0",
    f10.length === 0 &&
      f29.length === 0 &&
      f30.length === 1 &&
      f30[0].z === 0,
    `10->${f10.length} 29->${f29.length} 30->${JSON.stringify(f30)}`,
  );
}

function skewRules(): void {
  // Pool of 20, 15 votes before at 4.5 avg, then 5 one-star votes today.
  const count = 20;
  const avg5 = (15 * 4.5 + 5 * 1) / count;
  const s5 = only(evaluatePool(POOL, activity(5, 5), { count, average: avg5 }, []), "pool_rating_skew");
  record(
    "skew: 5 one-star votes against a 4.5 pool -> flagged down, mean 4.5, today 1",
    s5.length === 1 && s5[0].direction === "down" && s5[0].mean === 4.5 && s5[0].today === 1,
    JSON.stringify(s5),
  );

  const avg4 = (16 * 4.5 + 4 * 1) / count;
  const s4 = only(evaluatePool(POOL, activity(4, 4), { count, average: avg4 }, []), "pool_rating_skew");
  record(
    "skew: same shape with 4 votes (SKEW_MIN_VOTES - 1) -> not flagged",
    s4.length === 0,
    JSON.stringify(s4),
  );

  // Delta boundary: 5 votes of 3 stars against 4.5 -> delta exactly -1.5.
  const avgEdge = (15 * 4.5 + 5 * 3) / count;
  const edge = only(evaluatePool(POOL, activity(5, 15), { count, average: avgEdge }, []), "pool_rating_skew");
  const avgJust = (15 * 4.5 + 16) / count;
  const just = only(evaluatePool(POOL, activity(5, 16), { count, average: avgJust }, []), "pool_rating_skew");
  record(
    "skew: delta exactly SKEW_STARS (1.5) flagged, delta 1.3 not",
    edge.length === 1 && just.length === 0,
    `edge=${edge.length} just=${just.length}`,
  );

  // Upward skew.
  const avgUp = (15 * 3.0 + 5 * 5) / count;
  const up = only(evaluatePool(POOL, activity(5, 25), { count, average: avgUp }, []), "pool_rating_skew");
  record(
    "skew: five-star wave against a 3.0 pool -> direction up, mean 3",
    up.length === 1 && up[0].direction === "up" && up[0].mean === 3,
    JSON.stringify(up),
  );

  // count == votes24h: nothing earlier to compare against.
  const fresh = evaluatePool(POOL, activity(5, 5, 5), { count: 5, average: 1 }, []);
  record(
    "skew: new pool where count == votes24h -> no skew entry (divide-by-zero guard)",
    only(fresh, "pool_rating_skew").length === 0 && only(fresh, "pool_new_over_floor").length === 1,
    JSON.stringify(fresh),
  );
  // count == votes24h + 1: the guard's other side, one earlier vote exists.
  const one = only(
    evaluatePool(POOL, activity(5, 5, 5), { count: 6, average: (5 + 5) / 6 }, []),
    "pool_rating_skew",
  );
  record(
    "skew: count == votes24h + 1 is evaluated (before-mean 5, delta -4)",
    one.length === 1 && one[0].mean === 5 && one[0].direction === "down",
    JSON.stringify(one),
  );
  const noAvg = only(evaluatePool(POOL, activity(5, 5), { count: 20, average: null }, []), "pool_rating_skew");
  const noStats = only(evaluatePool(POOL, activity(5, 5), null, []), "pool_rating_skew");
  record(
    "skew: null average or missing stats doc -> no skew entry",
    noAvg.length === 0 && noStats.length === 0,
  );
}

function newOverFloorRules(): void {
  const noise: Pick<PoolActivity, "votes24h" | "sum24h"> = { votes24h: 0, sum24h: 0 };
  const run = (count: number, votes48h: number) =>
    only(evaluatePool(POOL, { ...noise, votes48h }, { count, average: 3 }, []), "pool_new_over_floor");

  const a = run(5, 5);
  record(
    "new-over-floor: count 5, votes48h 5 -> flagged (today=count, mean=votes48h, up)",
    a.length === 1 &&
      a[0].today === 5 &&
      a[0].mean === 5 &&
      a[0].direction === "up" &&
      a[0].poolKey === POOL,
    JSON.stringify(a),
  );
  record("new-over-floor: count 5, votes48h 2 (3 older, 4 !> 5) -> not flagged", run(5, 2).length === 0);
  record("new-over-floor: count 9, votes48h 5 (4 older, 10 > 9) -> flagged", run(9, 5).length === 1);
  record("new-over-floor: count 9, votes48h 4 (5 older, not < 5) -> not flagged", run(9, 4).length === 0);
  record("new-over-floor: count 11, votes48h 6 (exactly 5 older, 12 > 11) -> not flagged", run(11, 6).length === 0);
  record("new-over-floor: count 10, votes48h 6 (4 older, 12 > 10) -> flagged", run(10, 6).length === 1);
  record("new-over-floor: count 8, votes48h 4 (8 !> 8) -> not flagged", run(8, 4).length === 0);
  record("new-over-floor: count 7, votes48h 4 (8 > 7, 3 older) -> flagged", run(7, 4).length === 1);
  record("new-over-floor: count 4 (below DISPLAY_FLOOR), votes48h 4 -> not flagged", run(4, 4).length === 0);
  const noStats = only(evaluatePool(POOL, activity(5, 5, 5), null, []), "pool_new_over_floor");
  record("new-over-floor: missing stats doc -> not flagged", noStats.length === 0);
}

// ── Fake Firestore for runDetectPoolVelocity ──────────────────────────────

interface FakeEvent {
  uid: string;
  poolKey: unknown;
  ratingValue: unknown;
  createdAtMs: number;
}

interface FakeDb {
  events: FakeEvent[];
  days: Map<string, Record<string, unknown>>;
  stats: Map<string, Record<string, unknown>>;
  groupQueries: Array<{ id: string; filters: Array<[string, string, unknown]> }>;
  daysGets: number;
  daysLimit: number | null;
  daysWrites: Array<{ date: string; data: Record<string, unknown> }>;
  statsReads: string[];
  statsDocGets: number;
  getAllCalls: string[][];
  selects: string[][];
  windowLimits: number[];
}

function newFake(): FakeDb {
  return {
    events: [],
    days: new Map(),
    stats: new Map(),
    groupQueries: [],
    daysGets: 0,
    daysLimit: null,
    daysWrites: [],
    statsReads: [],
    statsDocGets: 0,
    getAllCalls: [],
    selects: [],
    windowLimits: [],
  };
}

function asDb(f: FakeDb): admin.firestore.Firestore {
  const daysCollection = {
    orderBy(_field: unknown, _dir: string) {
      return {
        limit(n: number) {
          f.daysLimit = n;
          return {
            async get() {
              f.daysGets++;
              const docs = [...f.days.entries()]
                .sort((a, b) => (a[0] < b[0] ? 1 : a[0] > b[0] ? -1 : 0))
                .slice(0, n)
                .map(([id, data]) => ({ id, data: () => data }));
              return { docs, size: docs.length, empty: docs.length === 0 };
            },
          };
        },
      };
    },
    doc(date: string) {
      return {
        async set(data: Record<string, unknown>) {
          f.daysWrites.push({ date, data });
          f.days.set(date, data);
        },
      };
    },
  };
  return {
    async getAll(...refs: Array<{ id: string }>) {
      f.getAllCalls.push(refs.map((r) => r.id));
      return refs.map((r) => {
        f.statsReads.push(r.id);
        const data = f.stats.get(r.id);
        return { id: r.id, exists: data !== undefined, data: () => data };
      });
    },
    collectionGroup(id: string) {
      const q = { id, filters: [] as Array<[string, string, unknown]> };
      let limitN: number | null = null;
      f.groupQueries.push(q);
      return {
        where(field: string, op: string, value: unknown) {
          q.filters.push([field, op, value]);
          return this;
        },
        select(...fields: string[]) {
          f.selects.push(fields);
          return this;
        },
        limit(n: number) {
          f.windowLimits.push(n);
          limitN = n;
          return this;
        },
        async get() {
          if (id !== CANONICAL_EVENTS_SUBCOLLECTION) throw new Error(`unexpected group ${id}`);
          let hits = f.events.filter((e) =>
            q.filters.every(([field, op, value]) => {
              if (field !== "createdAt" || op !== ">=") throw new Error("unsupported filter");
              return e.createdAtMs >= (value as admin.firestore.Timestamp).toMillis();
            }),
          );
          if (limitN != null) hits = hits.slice(0, limitN);
          const docs = hits.map((e) => ({
            data: () => ({
              poolKey: e.poolKey,
              ratingValue: e.ratingValue,
              createdAt: admin.firestore.Timestamp.fromMillis(e.createdAtMs),
            }),
            ref: { path: `users/${e.uid}/${CANONICAL_EVENTS_SUBCOLLECTION}/${String(e.poolKey)}` },
          }));
          return { docs, size: docs.length, empty: docs.length === 0 };
        },
      };
    },
    collection(name: string) {
      if (name === CANONICAL_STATS_COLLECTION) {
        return {
          doc(key: string) {
            return {
              id: key,
              async get() {
                f.statsDocGets++;
                throw new Error("per-doc stats get: use getAll");
              },
            };
          },
        };
      }
      if (name === "analytics") {
        return {
          doc(group: string) {
            if (group !== "pool_velocity") throw new Error(`unexpected doc ${group}`);
            return {
              collection(sub: string) {
                if (sub !== POOL_VELOCITY_DAYS) throw new Error(`unexpected sub ${sub}`);
                return daysCollection;
              },
            };
          },
        };
      }
      throw new Error(`unexpected collection ${name}`);
    },
  } as unknown as admin.firestore.Firestore;
}

function utcDate(ms: number): string {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
}

const NOW = Date.UTC(2026, 5, 20, 6, 0, 0);
const DATE = utcDate(NOW);

const POOL_B = "v1:bbbb000011112222"; // only events older than 48 h
const POOL_C = "v1:cccc000011112222"; // 30 h old: 48 h window only
const POOL_D = "v1:dddd000011112222"; // exactly 48 h old: on the boundary, included
const POOL_E = "v1:eeee000011112222"; // 2 votes exactly 24 h old: counted, stored
const POOL_F = "v1:ffff000011112222"; // 1 vote in 24 h: active but below the stored minimum
const POOL_G = "v1:9999000011112222"; // 2 votes 1 ms past 24 h: 48 h window only
const POOL_H = "v1:8888000011112222"; // malformed events only

async function burstAndWindow(): Promise<void> {
  const f = newFake();
  const uids: string[] = [];
  for (let i = 0; i < 12; i++) {
    const uid = `uidBurst${String(i).padStart(2, "0")}`;
    uids.push(uid);
    f.events.push({ uid, poolKey: POOL, ratingValue: 3, createdAtMs: NOW - i * HOUR_MS });
  }
  const add = (uid: string, poolKey: unknown, ms: number, rating: unknown = 4) => {
    uids.push(uid);
    f.events.push({ uid, poolKey, ratingValue: rating, createdAtMs: ms });
  };
  add("uidOld01", POOL_B, NOW - 48 * HOUR_MS - 1);
  add("uidOld02", POOL_B, NOW - 5 * DAY_MS);
  add("uidMid01", POOL_C, NOW - 30 * HOUR_MS);
  add("uidEdge48", POOL_D, NOW - 48 * HOUR_MS);
  add("uidEdge24a", POOL_E, NOW - 24 * HOUR_MS);
  add("uidEdge24b", POOL_E, NOW - 24 * HOUR_MS);
  add("uidSingle", POOL_F, NOW - HOUR_MS);
  add("uidJust1", POOL_G, NOW - 24 * HOUR_MS - 1);
  add("uidJust2", POOL_G, NOW - 24 * HOUR_MS - 1);
  add("uidBadRating", POOL_H, NOW - HOUR_MS, "5");
  add("uidBadKey", 42, NOW - HOUR_MS);

  const result = await runDetectPoolVelocity({ db: asDb(f), nowMs: NOW, dateStr: DATE });

  const velocity = only(result, "pool_velocity");
  record(
    "run: burst of 12 votes in 24 h yields exactly one pool_velocity entry for that pool",
    velocity.length === 1 && velocity[0].poolKey === POOL && velocity[0].today === 12,
    JSON.stringify(result),
  );
  record(
    "run: the window query is createdAt >= now - 48 h on the events collection group",
    f.groupQueries.length === 1 &&
      f.groupQueries[0].id === CANONICAL_EVENTS_SUBCOLLECTION &&
      f.groupQueries[0].filters.length === 1 &&
      f.groupQueries[0].filters[0][0] === "createdAt" &&
      f.groupQueries[0].filters[0][1] === ">=" &&
      (f.groupQueries[0].filters[0][2] as admin.firestore.Timestamp).toMillis() === NOW - 2 * DAY_MS,
    JSON.stringify(f.groupQueries),
  );
  record(
    "run: events older than 48 h are ignored (pool B never read), 48 h edge is kept",
    !f.statsReads.includes(POOL_B) && f.statsReads.includes(POOL_D),
    `statsReads=${f.statsReads.join(",")}`,
  );
  record(
    "run: malformed events (string rating, non-string poolKey) are skipped",
    !f.statsReads.includes(POOL_H) && f.statsReads.length === 6,
    `statsReads=${f.statsReads.join(",")}`,
  );

  const day = f.daysWrites;
  const counts = (day[0]?.data.counts ?? {}) as Record<string, number>;
  record(
    "run: exactly one day doc written, at the run date, with date field",
    day.length === 1 && day[0].date === DATE && day[0].data.date === DATE,
    JSON.stringify(day.map((d) => d.date)),
  );
  record(
    "run: stored counts hold only pools with >= 2 votes in 24 h (A=12, E=2 on the 24 h edge)",
    Object.keys(counts).length === 2 && counts[POOL] === 12 && counts[POOL_E] === 2,
    JSON.stringify(counts),
  );
  const expire = day[0]?.data.expireAt as admin.firestore.Timestamp | undefined;
  record(
    "run: expireAt is a Timestamp now + 35 days",
    expire != null &&
      typeof expire.toMillis === "function" &&
      expire.toMillis() === NOW + 35 * DAY_MS,
    String(expire),
  );
  const serialised = JSON.stringify(day[0]?.data ?? {});
  const leaked = uids.filter((u) => serialised.includes(u));
  record(
    "run: stored day doc contains no uid anywhere",
    uids.length > 0 && day.length === 1 && leaked.length === 0,
    `leaked=${leaked.join(",")}`,
  );
  const fieldNames = Object.keys(day[0]?.data ?? {}).sort().join(",");
  record(
    "run: day doc holds only date, counts, expireAt",
    fieldNames === "counts,date,expireAt",
    fieldNames,
  );
}

async function baselineHandling(): Promise<void> {
  const f = newFake();
  // 14 EXISTING earlier day docs on every second date (the days between have
  // no doc: the job did not run). P is in seven of them at 4 and absent from
  // the other seven (the doc exists, so absent means < 2 votes, i.e. 0).
  for (let i = 0; i < 14; i++) {
    const date = utcDate(NOW - (2 * i + 2) * DAY_MS);
    f.days.set(date, { date, counts: i % 2 === 0 ? { [POOL]: 4 } : {} });
  }
  // A re-run: today's own doc already exists and must not feed the baseline.
  f.days.set(DATE, { date: DATE, counts: { [POOL]: 999 } });
  for (let i = 0; i < 12; i++) {
    f.events.push({ uid: `uidB${i}`, poolKey: POOL, ratingValue: 3, createdAtMs: NOW - i * HOUR_MS });
  }

  const result = await runDetectPoolVelocity({ db: asDb(f), nowMs: NOW, dateStr: DATE });
  const hit = only(result, "pool_velocity");
  // mean over the 14 existing docs is 2 (absent = 0). A skipped-as-absent
  // reading would give mean 4 and 12 - 4 < 10: not flagged. Counting the
  // missing calendar days as 0 would lower the mean further and change it.
  record(
    "baseline: absent from an existing day doc counts 0; days with no doc are skipped (mean 2.0, z > 3)",
    hit.length === 1 && hit[0].mean === 2 && hit[0].z > 3,
    JSON.stringify(result),
  );
  record(
    "baseline: reads limit(29) day docs once, newest first, and replaces today's doc",
    f.daysLimit === 29 &&
      f.daysGets === 1 &&
      (f.days.get(DATE)?.counts as Record<string, number>)[POOL] === 12,
    `limit=${f.daysLimit} gets=${f.daysGets}`,
  );
}

async function zeroEvents(): Promise<void> {
  const f = newFake();
  f.days.set("2026-06-19", { date: "2026-06-19", counts: { [POOL]: 3 } });
  const result = await runDetectPoolVelocity({ db: asDb(f), nowMs: NOW, dateStr: DATE });
  const written = f.daysWrites[0];
  const counts = (written?.data.counts ?? null) as Record<string, number> | null;
  record(
    "zero events: no anomalies, day doc still written with empty counts and expireAt",
    result.length === 0 &&
      f.daysWrites.length === 1 &&
      written.date === DATE &&
      counts != null &&
      Object.keys(counts).length === 0 &&
      written.data.expireAt != null,
    JSON.stringify(written),
  );
  record(
    "zero events: no baseline read and no stats read",
    f.daysGets === 0 && f.statsReads.length === 0,
    `daysGets=${f.daysGets} statsReads=${f.statsReads.length}`,
  );
}

async function statsFeedRules(): Promise<void> {
  const f = newFake();
  // 5 one-star votes today into a pool of 20 whose stored average is 3.625
  // (before-mean 4.5): the stats doc must reach the skew rule.
  for (let i = 0; i < 5; i++) {
    f.events.push({ uid: `uidS${i}`, poolKey: POOL, ratingValue: 1, createdAtMs: NOW - i * HOUR_MS });
  }
  f.stats.set(POOL, { count: 20, average: (15 * 4.5 + 5) / 20, updatedAt: "x" });
  const result = await runDetectPoolVelocity({ db: asDb(f), nowMs: NOW, dateStr: DATE });
  const skew = only(result, "pool_rating_skew");
  record(
    "run: stats doc feeds the skew rule (down, mean 4.5) and is read once per active pool",
    skew.length === 1 &&
      skew[0].direction === "down" &&
      skew[0].mean === 4.5 &&
      f.statsReads.length === 1 &&
      f.statsReads[0] === POOL,
    JSON.stringify(result),
  );
}

async function statsBatching(): Promise<void> {
  const f = newFake();
  const keys: string[] = [];
  for (let i = 0; i < 150; i++) {
    const key = `v1:${String(i).padStart(16, "0")}`;
    keys.push(key);
    f.events.push({ uid: `uidP${i}`, poolKey: key, ratingValue: 3, createdAtMs: NOW - HOUR_MS });
  }
  for (let j = 0; j < 2; j++) {
    f.events.push({ uid: `uidX${j}`, poolKey: keys[149], ratingValue: 3, createdAtMs: NOW - HOUR_MS });
  }
  // count 5 with 3 votes in the window: 2 older < 5 and 6 > 5.
  f.stats.set(keys[149], { count: 5, average: 3 });
  const result = await runDetectPoolVelocity({ db: asDb(f), nowMs: NOW, dateStr: DATE });
  const flat = f.getAllCalls.flat();
  record(
    "stats: 150 active pools -> 2 getAll calls (100 + 50), every pool once, no per-doc get",
    f.getAllCalls.length === 2 &&
      f.getAllCalls[0].length === 100 &&
      f.getAllCalls[1].length === 50 &&
      new Set(flat).size === 150 &&
      f.statsDocGets === 0,
    `calls=${f.getAllCalls.map((c) => c.length)} perDoc=${f.statsDocGets}`,
  );
  record(
    "stats: a stats doc in the second batch reaches the rules (new-over-floor for the 150th pool)",
    only(result, "pool_new_over_floor").length === 1 && only(result, "pool_new_over_floor")[0].poolKey === keys[149],
    JSON.stringify(result),
  );
  const g = newFake();
  g.events.push({ uid: "u", poolKey: POOL, ratingValue: 3, createdAtMs: NOW - HOUR_MS });
  await runDetectPoolVelocity({ db: asDb(g), nowMs: NOW, dateStr: DATE });
  const h = newFake();
  for (let i = 0; i < 100; i++) {
    h.events.push({ uid: `u${i}`, poolKey: `v1:${String(i).padStart(16, "0")}`, ratingValue: 3, createdAtMs: NOW - HOUR_MS });
  }
  await runDetectPoolVelocity({ db: asDb(h), nowMs: NOW, dateStr: DATE });
  record(
    "stats: 1 pool -> one getAll; exactly 100 pools -> one getAll (batch edge)",
    g.getAllCalls.length === 1 && h.getAllCalls.length === 1 && h.getAllCalls[0].length === 100,
    `${g.getAllCalls.length} ${h.getAllCalls.length}`,
  );
}

async function windowOverflow(): Promise<void> {
  const seed = (n: number): FakeDb => {
    const f = newFake();
    for (let i = 0; i < n; i++) {
      f.events.push({ uid: `u${i}`, poolKey: POOL, ratingValue: 3, createdAtMs: NOW - HOUR_MS });
    }
    return f;
  };
  const over = seed(MAX_WINDOW_EVENTS + 1);
  const resOver = await runDetectPoolVelocity({ db: asDb(over), nowMs: NOW, dateStr: DATE });
  const ov = only(resOver, "pool_window_overflow");
  const stored = (over.daysWrites[0]?.data.counts ?? {}) as Record<string, number>;
  record(
    "window: MAX_WINDOW_EVENTS + 1 events -> one pool_window_overflow entry without poolKey",
    ov.length === 1 && ov[0].poolKey === undefined && ov[0].today === MAX_WINDOW_EVENTS && ov[0].direction === "up",
    JSON.stringify(ov),
  );
  record(
    "window: exactly MAX_WINDOW_EVENTS of them are evaluated (stored count), not the extra probe row",
    stored[POOL] === MAX_WINDOW_EVENTS,
    `stored=${stored[POOL]}`,
  );
  const at = seed(MAX_WINDOW_EVENTS);
  const resAt = await runDetectPoolVelocity({ db: asDb(at), nowMs: NOW, dateStr: DATE });
  record(
    "window: exactly MAX_WINDOW_EVENTS events -> no overflow entry, all evaluated",
    only(resAt, "pool_window_overflow").length === 0 &&
      ((at.daysWrites[0]?.data.counts ?? {}) as Record<string, number>)[POOL] === MAX_WINDOW_EVENTS,
  );
  record(
    "window: the query selects only poolKey, ratingValue, createdAt and limits to MAX_WINDOW_EVENTS + 1",
    JSON.stringify(over.selects) === JSON.stringify([["poolKey", "ratingValue", "createdAt"]]) &&
      JSON.stringify(over.windowLimits) === JSON.stringify([MAX_WINDOW_EVENTS + 1]),
    `${JSON.stringify(over.selects)} ${JSON.stringify(over.windowLimits)}`,
  );
}

function indexPins(): void {
  const raw = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "..", "..", "firestore.indexes.json"), "utf8"),
  ) as {
    indexes: Array<{ collectionGroup: string; queryScope: string; fields: Array<{ fieldPath: string; order?: string }> }>;
    fieldOverrides: Array<{
      collectionGroup: string;
      fieldPath: string;
      indexes: Array<{ order?: string; queryScope: string }>;
    }>;
  };
  const override = raw.fieldOverrides.find(
    (o) => o.collectionGroup === CANONICAL_EVENTS_SUBCOLLECTION && o.fieldPath === "createdAt",
  );
  record(
    "index config: canonical_rating_events.createdAt override has ASCENDING COLLECTION_GROUP (window range query)",
    !!override && override.indexes.some((i) => i.order === "ASCENDING" && i.queryScope === "COLLECTION_GROUP"),
    JSON.stringify(override),
  );
  const composite = raw.indexes.filter(
    (ix) =>
      ix.collectionGroup === CANONICAL_EVENTS_SUBCOLLECTION &&
      ix.queryScope === "COLLECTION_GROUP" &&
      ix.fields.some((f) => f.fieldPath === "createdAt"),
  );
  record(
    "index config: the COLLECTION_GROUP createdAt composite is exactly [poolKey ASC, createdAt DESC]",
    composite.length === 1 &&
      JSON.stringify(composite[0].fields) ===
        JSON.stringify([
          { fieldPath: "poolKey", order: "ASCENDING" },
          { fieldPath: "createdAt", order: "DESCENDING" },
        ]),
    JSON.stringify(composite),
  );
  const days = raw.indexes.filter(
    (ix) =>
      ix.collectionGroup === POOL_VELOCITY_DAYS &&
      ix.queryScope === "COLLECTION" &&
      ix.fields.length === 1 &&
      ix.fields[0].fieldPath === "__name__" &&
      ix.fields[0].order === "DESCENDING",
  );
  record("index config: pool_velocity_days COLLECTION composite on __name__ DESCENDING exists", days.length === 1, JSON.stringify(days));
}

async function main(): Promise<void> {
  console.log("detect-pool-velocity tests\n");
  velocityRules();
  skewRules();
  newOverFloorRules();
  await burstAndWindow();
  await baselineHandling();
  await zeroEvents();
  await statsFeedRules();
  await statsBatching();
  await windowOverflow();
  indexPins();

  console.log(`\n${totalRun - totalFailed}/${totalRun} passed`);
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
