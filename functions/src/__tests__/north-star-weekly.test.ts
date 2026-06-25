/**
 * BUT-638: North Star weekly aggregation tests.
 *
 * Coverage:
 *   1. Aggregation correctness on synthetic data:
 *        3 users, 12 cooks, 1 retained from prior week
 *        → wau=3, totalCooks=12, cooksPerActiveUser=4, retentionW1=0.333.
 *   2. Empty-week handling: no events → all zeros, doc still written.
 *   3. Retention calculation across week boundary (W1 vs W2 vs W3 buckets).
 *   4. Idempotent re-run: second run for the same week overwrites the first.
 *
 * Run with: npx ts-node src/__tests__/north-star-weekly.test.ts
 */

import { runNorthStarWeekly, isoWeekLabel } from "../scheduled/north-star-weekly";

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

interface FakeEvent {
  userId: string;
  eventType: string;
  /** Days before `now` (positive number = past). */
  daysAgo: number;
}

interface DocStore {
  /** Map keyed by `<col>/<doc>/<col>/<doc>` path. */
  data: Map<string, Record<string, unknown>>;
  /** Counts how many times the metrics doc was written (idempotency check). */
  writeCount: number;
}

function makeFakeDb(events: FakeEvent[], now: Date, store: DocStore) {
  return {
    collection(name: string) {
      if (name === "activity_events") {
        return makeEventCol(events, now);
      }
      if (name === "metrics") {
        return makeMetricsRoot(store);
      }
      throw new Error(`unexpected collection: ${name}`);
    },
  };
}

function makeEventCol(events: FakeEvent[], now: Date) {
  let fromMs = -Infinity;
  let toMs = Infinity;
  const col = {
    where(field: string, op: string, value: { toMillis(): number }) {
      const v = value.toMillis();
      if (op === ">=") fromMs = v;
      if (op === "<") toMs = v;
      return col;
    },
    // Pagination chain is no-op here: the test windows hold far fewer than one
    // page, so production's `fetchWindowAgg` reads everything in a single page
    // and never advances the cursor.
    select() {
      return col;
    },
    orderBy() {
      return col;
    },
    limit() {
      return col;
    },
    startAfter() {
      return col;
    },
    async get() {
      const docs = events
        .filter((e) => {
          const ts = now.getTime() - e.daysAgo * MS_PER_DAY;
          return ts >= fromMs && ts < toMs;
        })
        .map((e) => ({
          data: () => ({
            userId: e.userId,
            eventType: e.eventType,
            createdAt: {
              toMillis: () => now.getTime() - e.daysAgo * MS_PER_DAY,
            },
          }),
        }));
      // Mirror a real QuerySnapshot: production reads `.size`/`.empty` to drive
      // pagination, so the fake must expose them too.
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  };
  return col;
}

function makeMetricsRoot(store: DocStore) {
  return {
    doc(docId: string) {
      const docPath = `metrics/${docId}`;
      return {
        collection(subName: string) {
          return {
            doc(subId: string) {
              const fullPath = `${docPath}/${subName}/${subId}`;
              return {
                async set(data: Record<string, unknown>) {
                  store.data.set(fullPath, data);
                  store.writeCount++;
                },
              };
            },
          };
        },
      };
    },
  };
}

async function aggregationCorrectness(): Promise<void> {
  // 3 users active in W0 (past 7 days): u1, u2, u3.
  // 12 cooks total in W0 — split across users.
  // 1 of W0 users (u1) was also active in W1 (8-14 days ago).
  // Expected: wau=3, totalCooks=12, cooksPerActiveUser=4, retentionW1=1/3.
  const events: FakeEvent[] = [];
  // u1: 4 cooks in W0
  for (let i = 0; i < 4; i++) {
    events.push({ userId: "u1", eventType: "recipe_cooked", daysAgo: 1 });
  }
  // u2: 4 cooks in W0
  for (let i = 0; i < 4; i++) {
    events.push({ userId: "u2", eventType: "recipe_cooked", daysAgo: 2 });
  }
  // u3: 4 cooks in W0
  for (let i = 0; i < 4; i++) {
    events.push({ userId: "u3", eventType: "recipe_cooked", daysAgo: 3 });
  }
  // u1 retained from W1
  events.push({ userId: "u1", eventType: "recipe_cooked", daysAgo: 10 });

  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0 };
  const metrics = await runNorthStarWeekly({
    db: makeFakeDb(events, now, store) as never,
    now,
  });

  const okWau = metrics.wau === 3;
  const okCooks = metrics.totalCooks === 12;
  const okPerUser = metrics.cooksPerActiveUser === 4;
  const okRetW1 = Math.abs(metrics.retentionW1 - 1 / 3) < 0.001;
  const okWritten = store.writeCount === 1;
  const ok = okWau && okCooks && okPerUser && okRetW1 && okWritten;
  record(
    "aggregation: 3 users, 12 cooks, 1 retained → wau=3 cooks=12 cpu=4 retW1=0.333",
    ok,
    `wau=${metrics.wau} cooks=${metrics.totalCooks} cpu=${metrics.cooksPerActiveUser} ` +
      `retW1=${metrics.retentionW1} writes=${store.writeCount}`
  );
}

async function emptyWeekHandling(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0 };
  const metrics = await runNorthStarWeekly({
    db: makeFakeDb([], now, store) as never,
    now,
  });
  const ok =
    metrics.wau === 0 &&
    metrics.totalCooks === 0 &&
    metrics.cooksPerActiveUser === 0 &&
    metrics.retentionW1 === 0 &&
    metrics.retentionW2 === 0 &&
    metrics.retentionW3 === 0 &&
    store.writeCount === 1;
  record(
    "empty week: no events → all zeros, doc still written",
    ok,
    `wau=${metrics.wau} writes=${store.writeCount}`
  );
}

async function retentionAcrossWeekBoundaries(): Promise<void> {
  // W0 has u1, u2.
  // u1 was also active in W1, W2, and W3.
  // u2 was also active in W2 only.
  // → retentionW1 = 1/2 (only u1)
  // → retentionW2 = 2/2 (both)
  // → retentionW3 = 1/2 (only u1)
  const events: FakeEvent[] = [
    { userId: "u1", eventType: "shared", daysAgo: 1 },
    { userId: "u2", eventType: "shared", daysAgo: 1 },
    { userId: "u1", eventType: "shared", daysAgo: 9 }, // W1
    { userId: "u1", eventType: "shared", daysAgo: 16 }, // W2
    { userId: "u2", eventType: "shared", daysAgo: 17 }, // W2
    { userId: "u1", eventType: "shared", daysAgo: 24 }, // W3
  ];
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0 };
  const metrics = await runNorthStarWeekly({
    db: makeFakeDb(events, now, store) as never,
    now,
  });
  const okR1 = Math.abs(metrics.retentionW1 - 0.5) < 0.001;
  const okR2 = Math.abs(metrics.retentionW2 - 1.0) < 0.001;
  const okR3 = Math.abs(metrics.retentionW3 - 0.5) < 0.001;
  const ok = okR1 && okR2 && okR3;
  record(
    "retention buckets across W1/W2/W3 boundaries",
    ok,
    `retW1=${metrics.retentionW1} retW2=${metrics.retentionW2} retW3=${metrics.retentionW3}`
  );
}

async function idempotentRerun(): Promise<void> {
  const events: FakeEvent[] = [
    { userId: "u1", eventType: "recipe_cooked", daysAgo: 1 },
  ];
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0 };
  await runNorthStarWeekly({
    db: makeFakeDb(events, now, store) as never,
    now,
  });
  await runNorthStarWeekly({
    db: makeFakeDb(events, now, store) as never,
    now,
  });
  // Second run should overwrite the same path; data Map size stays at 1
  // but writeCount is 2. That's the idempotency contract: latest wins,
  // re-runs don't proliferate.
  const ok = store.data.size === 1 && store.writeCount === 2;
  record(
    "idempotent re-run: writeCount=2 but only 1 unique doc path",
    ok,
    `pathsWritten=${store.data.size} writeCount=${store.writeCount}`
  );
}

async function isoWeekLabelFormat(): Promise<void> {
  // 2026-01-01 is a Thursday → ISO week 1 of 2026.
  const label = isoWeekLabel(new Date("2026-01-01T12:00:00Z"));
  const ok = label === "2026-W01";
  record(
    "isoWeekLabel: 2026-01-01 → 2026-W01",
    ok,
    `got "${label}"`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-638: North Star weekly aggregation tests\n");
  console.log("==============================================\n");
  await aggregationCorrectness();
  await emptyWeekHandling();
  await retentionAcrossWeekBoundaries();
  await idempotentRerun();
  await isoWeekLabelFormat();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
