/**
 * BUT-482: rating-aggregation debounce tests.
 *
 * Coverage:
 *   1. First call writes a marker (scheduled=true) and bursts within the
 *      5s window coalesce (scheduled=false).
 *   2. After the window passes, the next call writes a fresh marker.
 *   3. Drainer aggregates exactly one run per ready marker and deletes it.
 *   4. Drainer leaves not-yet-ready markers in place.
 *   5. Aggregator failure does not abort the drain loop.
 *
 * Run with: npx ts-node src/__tests__/rating-aggregation.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-rating-debounce" });
}

import {
  scheduleRatingAggregation,
  drainRatingAggregationQueue,
  __test__,
} from "../ratings/rating-aggregation";

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

interface FakeDoc {
  path: string;
  data: Record<string, unknown>;
}

/**
 * Minimal Firestore stub covering the surface used by
 * rating-aggregation.ts:
 *   - db.doc(path).get / set / delete
 *   - db.runTransaction(fn) — fn receives a tx with .get / .set
 *   - db.collection(path).where('pendingUntil', '<=', ts).limit(N).get()
 */
class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  public deletes: string[] = [];
  public sets: { path: string; data: Record<string, unknown> }[] = [];

  // -------- doc ref ----------
  doc(path: string) {
    return this.makeRef(path);
  }

  private makeRef(path: string) {
    const self = this;
    return {
      path,
      async get() {
        const data = self.docs.get(path);
        return {
          exists: data !== undefined,
          data: () => data,
        };
      },
      async set(data: Record<string, unknown>) {
        self.docs.set(path, data);
        self.sets.push({ path, data });
      },
      async delete() {
        self.docs.delete(path);
        self.deletes.push(path);
      },
    };
  }

  // -------- runTransaction ----------
  async runTransaction<T>(
    fn: (tx: {
      get: (ref: { path: string }) => Promise<{
        exists: boolean;
        data: () => Record<string, unknown> | undefined;
      }>;
      set: (ref: { path: string }, data: Record<string, unknown>) => void;
    }) => Promise<T>
  ): Promise<T> {
    const writes: { path: string; data: Record<string, unknown> }[] = [];
    const tx = {
      get: async (ref: { path: string }) => {
        const data = this.docs.get(ref.path);
        return { exists: data !== undefined, data: () => data };
      },
      set: (ref: { path: string }, data: Record<string, unknown>) => {
        writes.push({ path: ref.path, data });
      },
    };
    const result = await fn(tx);
    for (const w of writes) {
      this.docs.set(w.path, w.data);
      this.sets.push(w);
    }
    return result;
  }

  // -------- collection / where / get ----------
  collection(name: string) {
    return this.makeQuery(name, []);
  }

  private makeQuery(
    collectionPath: string,
    wheres: Array<{ field: string; op: string; value: unknown }>
  ) {
    const self = this;
    const limitVal = { n: 0 as number | undefined };
    const obj = {
      where(field: string, op: string, value: unknown) {
        return self.makeQuery(collectionPath, [...wheres, { field, op, value }]);
      },
      limit(n: number) {
        limitVal.n = n;
        return obj;
      },
      async get() {
        const out: FakeDoc[] = [];
        for (const [path, data] of self.docs) {
          if (!path.startsWith(collectionPath + "/")) continue;
          // ensure the doc is a direct child (no further `/`)
          const remainder = path.slice(collectionPath.length + 1);
          if (remainder.includes("/")) continue;

          let match = true;
          for (const w of wheres) {
            const v = data[w.field] as { toMillis?: () => number } | undefined;
            const target = w.value as { toMillis?: () => number };
            const vMs = typeof v?.toMillis === "function" ? v.toMillis() : NaN;
            const tMs =
              typeof target?.toMillis === "function" ? target.toMillis() : NaN;
            if (w.op === "<=" && !(vMs <= tMs)) match = false;
            if (w.op === "<" && !(vMs < tMs)) match = false;
            if (w.op === ">=" && !(vMs >= tMs)) match = false;
          }
          if (match) out.push({ path, data });
        }
        const sliced =
          limitVal.n !== undefined ? out.slice(0, limitVal.n) : out;
        return {
          empty: sliced.length === 0,
          size: sliced.length,
          docs: sliced.map((d) => ({
            id: d.path.split("/").pop()!,
            ref: self.makeRef(d.path),
            data: () => d.data,
          })),
        };
      },
    };
    return obj;
  }
}

const ts = (ms: number): admin.firestore.Timestamp =>
  admin.firestore.Timestamp.fromMillis(ms);

async function debounceCoalescesBurst(): Promise<void> {
  const db = new FakeFirestore();
  const t0 = 1_000_000;
  let now = t0;
  const deps = { db: db as never, now: () => new Date(now) };

  // 5 rapid creates within 5s
  const results: boolean[] = [];
  for (let i = 0; i < 5; i++) {
    results.push(await scheduleRatingAggregation("recipe-A", deps));
    now += 500; // 0.5s between
  }

  const firstScheduled = results[0] === true;
  const restCoalesced = results.slice(1).every((r) => r === false);
  // marker should exist exactly once
  const markerPath = __test__.markerRef(db as never, "recipe-A").path;
  const hasMarker = !!(await db.doc(markerPath).get()).exists;

  record(
    "5 rapid ratings within 5s → 1 schedule, 4 coalesced",
    firstScheduled && restCoalesced && hasMarker,
    `results=${JSON.stringify(results)} hasMarker=${hasMarker}`
  );
}

async function newWindowAfterExpiry(): Promise<void> {
  const db = new FakeFirestore();
  let now = 2_000_000;
  const deps = { db: db as never, now: () => new Date(now) };

  const r1 = await scheduleRatingAggregation("recipe-B", deps);
  // skip past pendingUntil (now + 5_000)
  now += 6_000;
  const r2 = await scheduleRatingAggregation("recipe-B", deps);

  record(
    "after 6s, second schedule writes new marker",
    r1 === true && r2 === true,
    `r1=${r1} r2=${r2}`
  );
}

async function drainerProcessesReadyMarkers(): Promise<void> {
  const db = new FakeFirestore();
  const t0 = 3_000_000;

  // Seed two markers — one ready, one not yet
  await db.doc("_internal/rating_debounce/markers/recipe-X").set({
    recipeId: "recipe-X",
    pendingUntil: ts(t0 - 1000), // already due
    scheduledAt: ts(t0 - 6000),
  });
  await db.doc("_internal/rating_debounce/markers/recipe-Y").set({
    recipeId: "recipe-Y",
    pendingUntil: ts(t0 + 10_000), // not yet
    scheduledAt: ts(t0),
  });

  const aggregated: string[] = [];
  const result = await drainRatingAggregationQueue({
    db: db as never,
    now: () => new Date(t0),
    aggregate: async (recipeId) => {
      aggregated.push(recipeId);
    },
  });

  const xDeleted = !(await db.doc("_internal/rating_debounce/markers/recipe-X").get()).exists;
  const yKept = (await db.doc("_internal/rating_debounce/markers/recipe-Y").get()).exists;

  record(
    "drainer aggregates ready, leaves not-yet markers",
    aggregated.length === 1 &&
      aggregated[0] === "recipe-X" &&
      xDeleted &&
      yKept &&
      result.processed === 1 &&
      result.failed === 0,
    `aggregated=${JSON.stringify(aggregated)} xDel=${xDeleted} yKept=${yKept} processed=${result.processed} failed=${result.failed}`
  );
}

async function drainerSurvivesAggregatorFailure(): Promise<void> {
  const db = new FakeFirestore();
  const t0 = 4_000_000;

  await db.doc("_internal/rating_debounce/markers/recipe-bad").set({
    recipeId: "recipe-bad",
    pendingUntil: ts(t0 - 1000),
    scheduledAt: ts(t0 - 6000),
  });
  await db.doc("_internal/rating_debounce/markers/recipe-ok").set({
    recipeId: "recipe-ok",
    pendingUntil: ts(t0 - 1000),
    scheduledAt: ts(t0 - 6000),
  });

  const aggregated: string[] = [];
  const result = await drainRatingAggregationQueue({
    db: db as never,
    now: () => new Date(t0),
    aggregate: async (recipeId) => {
      if (recipeId === "recipe-bad") throw new Error("boom");
      aggregated.push(recipeId);
    },
  });

  record(
    "drainer continues after one aggregator throws",
    aggregated.length === 1 &&
      aggregated[0] === "recipe-ok" &&
      result.processed === 1 &&
      result.failed === 1,
    `processed=${result.processed} failed=${result.failed} aggregated=${JSON.stringify(aggregated)}`
  );
}

async function emptyRecipeIdShortCircuits(): Promise<void> {
  const db = new FakeFirestore();
  const r = await scheduleRatingAggregation("", {
    db: db as never,
    now: () => new Date(0),
  });
  record(
    "empty recipeId → no schedule, no marker write",
    r === false && db.sets.length === 0,
    `result=${r} sets=${db.sets.length}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-482: rating-aggregation debounce tests\n");
  console.log("==============================================\n");
  await debounceCoalescesBurst();
  await newWindowAfterExpiry();
  await drainerProcessesReadyMarkers();
  await drainerSurvivesAggregatorFailure();
  await emptyRecipeIdShortCircuits();

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
