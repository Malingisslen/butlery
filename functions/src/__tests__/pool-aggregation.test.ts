/**
 * Pooled ratings Stage B — pool aggregator unit tests (Increment 3).
 *
 * Proves the decision-5 acceptance criteria (tasks/pooled-ratings-plan.md):
 *   AC5  the drain issues a Firestore AGGREGATE query and NEVER folds the pool's
 *        events in memory (a rater count is unbounded — read-all is forbidden).
 *        The fake trips a counter if anyone `.get()`s the raw event query; the
 *        aggregator must leave that counter at 0 and use `.aggregate().get()`.
 *   stats correctness for a small multi-user pool, incl. pool isolation (a
 *        different poolKey's events must not leak into the count/average) and the
 *        empty-pool case (count 0 / average null).
 *   drain wiring — `drainPoolAggregationQueue({aggregate})` runs the aggregator
 *        per pending marker; with NO aggregate the shared drainer throws per key
 *        (counted as failed) so an unwired production scheduler fails loudly.
 *   production-path wiring guard — index.ts actually registers the event trigger
 *        on the events subcollection AND the scheduler passes the real
 *        `updatePooledRatingStats` (not only reachable via injected test deps).
 *
 * Run with: npx ts-node src/__tests__/pool-aggregation.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-pooled-ratings-stage-b" });
}
import * as fs from "fs";
import * as path from "path";

import { updatePooledRatingStats, CANONICAL_STATS_COLLECTION } from "../ratings/update-pooled-rating-stats";
import { drainPoolAggregationQueue, POOL_EVENT_TRIGGER_PATH, __test__ } from "../ratings/pool-aggregation";
import { CANONICAL_EVENTS_SUBCOLLECTION } from "../ratings/canonical-rating-aggregation";

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

// ── Support '==' (event/marker filters) and '<=' (marker pendingUntil). ──
function matchOp(actual: unknown, op: string, value: unknown): boolean {
  if (op === "==") return actual === value;
  if (op === "<=") {
    const a = (actual as { toMillis?: () => number })?.toMillis?.() ?? (actual as number);
    const b = (value as { toMillis?: () => number })?.toMillis?.() ?? (value as number);
    return a <= b;
  }
  throw new Error(`FakeFirestore: unsupported op ${op}`);
}

/**
 * Minimal path-addressed Firestore fake. Supports:
 *   - collection(path).doc(id).{get,set(merge),delete} and .collection(sub)
 *   - collection(path).where().limit().get()      (debounce marker scan)
 *   - collectionGroup(id).where().aggregate(spec).get()   (Stage B aggregate)
 *   - collectionGroup(id).where().get()           (the FORBIDDEN fold — tripwire)
 * aggregateCalls / foldGetCalls let AC5 assert which path the aggregator took.
 */
class FakeFirestore {
  store = new Map<string, Record<string, unknown>>();
  aggregateCalls = 0;
  foldGetCalls = 0;

  collection(p: string) {
    return new FakeCollection(this, p);
  }
  collectionGroup(id: string) {
    return new FakeCollectionGroupQuery(this, id);
  }
  /** Count docs that live DIRECTLY in a collection path (no deeper nesting). */
  countAt(collectionPath: string): number {
    let n = 0;
    for (const key of this.store.keys()) {
      if (!key.startsWith(collectionPath + "/")) continue;
      if (key.slice(collectionPath.length + 1).includes("/")) continue;
      n++;
    }
    return n;
  }
}

class FakeCollection {
  constructor(private db: FakeFirestore, public path: string) {}
  doc(id: string) {
    return new FakeDoc(this.db, `${this.path}/${id}`);
  }
  where(field: string, op: string, value: unknown) {
    return new FakeCollectionQuery(this.db, this.path, [{ field, op, value }]);
  }
}

class FakeCollectionQuery {
  private _limit = Infinity;
  constructor(
    private db: FakeFirestore,
    private path: string,
    private filters: Array<{ field: string; op: string; value: unknown }>
  ) {}
  where(field: string, op: string, value: unknown) {
    return new FakeCollectionQuery(this.db, this.path, [...this.filters, { field, op, value }]);
  }
  limit(n: number) {
    this._limit = n;
    return this;
  }
  async get() {
    // Return QueryDocumentSnapshot-shaped docs: .data()/.id/.ref (the shared
    // debounce drainer reads doc.data() and doc.ref.delete()).
    const docs: Array<{ id: string; data: () => Record<string, unknown>; ref: FakeDoc }> = [];
    for (const [p, data] of this.db.store) {
      if (!p.startsWith(this.path + "/")) continue;
      if (p.slice(this.path.length + 1).includes("/")) continue;
      if (!this.filters.every((f) => matchOp(data[f.field], f.op, f.value))) continue;
      const ref = new FakeDoc(this.db, p);
      docs.push({ id: ref.id, data: () => data, ref });
      if (docs.length >= this._limit) break;
    }
    return { empty: docs.length === 0, size: docs.length, docs };
  }
}

class FakeDoc {
  constructor(private db: FakeFirestore, public path: string) {}
  get ref(): FakeDoc {
    return this;
  }
  get id(): string {
    return this.path.split("/").pop()!;
  }
  async get() {
    const data = this.db.store.get(this.path);
    return { exists: data !== undefined, id: this.id, data: () => data };
  }
  async set(data: Record<string, unknown>, opts?: { merge?: boolean }) {
    const prev = opts?.merge ? this.db.store.get(this.path) ?? {} : {};
    this.db.store.set(this.path, { ...prev, ...data });
  }
  async delete() {
    this.db.store.delete(this.path);
  }
  collection(sub: string) {
    return new FakeCollection(this.db, `${this.path}/${sub}`);
  }
}

/** Docs whose LAST collection segment is `collectionId` (a collection-group). */
function collectionGroupMatches(
  db: FakeFirestore,
  collectionId: string,
  filters: Array<{ field: string; op: string; value: unknown }>
): Array<Record<string, unknown>> {
  const out: Array<Record<string, unknown>> = [];
  for (const [p, data] of db.store) {
    const segs = p.split("/");
    if (segs.length % 2 !== 0) continue; // not a document path
    if (segs[segs.length - 2] !== collectionId) continue;
    if (!filters.every((f) => matchOp(data[f.field], f.op, f.value))) continue;
    out.push(data);
  }
  return out;
}

class FakeCollectionGroupQuery {
  private filters: Array<{ field: string; op: string; value: unknown }> = [];
  constructor(private db: FakeFirestore, private collectionId: string) {}
  where(field: string, op: string, value: unknown) {
    this.filters.push({ field, op, value });
    return this;
  }
  aggregate(spec: Record<string, { aggregateType: string; _field?: string }>) {
    return new FakeAggregateQuery(this.db, this.collectionId, this.filters, spec);
  }
  // The FORBIDDEN read-all path (decision 5). Trip the wire so any in-memory
  // fold is caught — the aggregator must never call this.
  async get() {
    this.db.foldGetCalls++;
    const matches = collectionGroupMatches(this.db, this.collectionId, this.filters);
    return {
      empty: matches.length === 0,
      size: matches.length,
      docs: matches.map((data) => ({ data: () => data })),
    };
  }
}

class FakeAggregateQuery {
  constructor(
    private db: FakeFirestore,
    private collectionId: string,
    private filters: Array<{ field: string; op: string; value: unknown }>,
    private spec: Record<string, { aggregateType: string; _field?: string }>
  ) {}
  async get() {
    this.db.aggregateCalls++;
    const matches = collectionGroupMatches(this.db, this.collectionId, this.filters);
    const result: Record<string, number | null> = {};
    for (const key of Object.keys(this.spec)) {
      const af = this.spec[key];
      if (af.aggregateType === "count") {
        result[key] = matches.length;
      } else if (af.aggregateType === "sum") {
        result[key] = matches.reduce((s, d) => s + Number(d[af._field!] ?? 0), 0);
      } else if (af.aggregateType === "avg") {
        // Firestore's average returns null over an empty set.
        result[key] = matches.length
          ? matches.reduce((s, d) => s + Number(d[af._field!] ?? 0), 0) / matches.length
          : null;
      } else {
        throw new Error(`FakeAggregateQuery: unknown aggregateType ${af.aggregateType}`);
      }
    }
    return { data: () => result };
  }
}

/** Seed one frozen pool event at users/{uid}/canonical_rating_events/{poolKey}. */
function seedEvent(
  db: FakeFirestore,
  uid: string,
  poolKey: string,
  ratingValue: number,
  recipeId = "r1"
): void {
  db.store.set(`users/${uid}/${CANONICAL_EVENTS_SUBCOLLECTION}/${poolKey}`, {
    poolKey,
    ratingValue,
    recipeId,
  });
}

const POOL = "v1:aaaabbbbccccdddd";
const OTHER = "v1:9999888877776666";

async function statsCorrectnessSmallPool(): Promise<void> {
  const db = new FakeFirestore();
  // Five raters in the pool: 5,4,3,5,3 → count 5, avg 4.0.
  seedEvent(db, "u1", POOL, 5);
  seedEvent(db, "u2", POOL, 4);
  seedEvent(db, "u3", POOL, 3);
  seedEvent(db, "u4", POOL, 5);
  seedEvent(db, "u5", POOL, 3);
  // A different pool's event must NOT leak into POOL's aggregate.
  seedEvent(db, "u1", OTHER, 1);

  await updatePooledRatingStats(POOL, db as never);

  const stats = db.store.get(`${CANONICAL_STATS_COLLECTION}/${POOL}`);
  record(
    "stats correctness: 5-rater pool → count 5, average 4.0, other pool excluded",
    stats?.count === 5 &&
      stats?.average === 4.0 &&
      typeof stats?.updatedAt !== "undefined",
    JSON.stringify(stats)
  );
  record(
    "AC5: aggregate query used, events never folded in memory (correctness run)",
    db.aggregateCalls === 1 && db.foldGetCalls === 0,
    `aggregateCalls=${db.aggregateCalls} foldGetCalls=${db.foldGetCalls}`
  );
}

async function aggregateNotFold(): Promise<void> {
  // AC5 focus: even for a large-ish pool the aggregator issues exactly one
  // aggregate query and zero raw fetches.
  const db = new FakeFirestore();
  for (let i = 0; i < 50; i++) {
    seedEvent(db, `u${i}`, POOL, (i % 5) + 1);
  }
  await updatePooledRatingStats(POOL, db as never);
  record(
    "AC5: 50-event pool → 1 aggregate query, 0 in-memory folds",
    db.aggregateCalls === 1 && db.foldGetCalls === 0,
    `aggregateCalls=${db.aggregateCalls} foldGetCalls=${db.foldGetCalls}`
  );
}

async function emptyPoolWritesZero(): Promise<void> {
  const db = new FakeFirestore();
  await updatePooledRatingStats(POOL, db as never);
  const stats = db.store.get(`${CANONICAL_STATS_COLLECTION}/${POOL}`);
  record(
    "empty pool → count 0 / average null written (n≥5 reader shows no pill)",
    stats?.count === 0 && stats?.average === null && db.foldGetCalls === 0,
    JSON.stringify(stats)
  );
}

async function drainRunsAggregatorPerMarker(): Promise<void> {
  // Two pending markers → aggregator called for each, markers claimed (deleted).
  const db = new FakeFirestore();
  const past = admin.firestore.Timestamp.fromMillis(1_000);
  db.store.set(`${__test__.MARKER_COLLECTION}/${POOL}`, {
    key: POOL,
    pendingUntil: past,
    scheduledAt: past,
  });
  db.store.set(`${__test__.MARKER_COLLECTION}/${OTHER}`, {
    key: OTHER,
    pendingUntil: past,
    scheduledAt: past,
  });

  const drained: string[] = [];
  const res = await drainPoolAggregationQueue({
    db: db as never,
    now: () => new Date(2_000),
    aggregate: async (poolKey: string) => {
      drained.push(poolKey);
    },
  });

  record(
    "drain: aggregator invoked per pending marker; markers claimed",
    res.processed === 2 &&
      res.failed === 0 &&
      drained.sort().join(",") === [POOL, OTHER].sort().join(",") &&
      db.countAt(__test__.MARKER_COLLECTION) === 0,
    `res=${JSON.stringify(res)} drained=${JSON.stringify(drained)}`
  );
}

async function drainUnwiredFailsLoudly(): Promise<void> {
  // No `aggregate` dep → shared drainer's default throws per key → counted as
  // failed (never a silent pass). Guards a production wiring mistake.
  const db = new FakeFirestore();
  const past = admin.firestore.Timestamp.fromMillis(1_000);
  db.store.set(`${__test__.MARKER_COLLECTION}/${POOL}`, {
    key: POOL,
    pendingUntil: past,
    scheduledAt: past,
  });
  const res = await drainPoolAggregationQueue({
    db: db as never,
    now: () => new Date(2_000),
    // aggregate omitted on purpose
  });
  record(
    "drain: unwired aggregator → failed (throws), not a silent pass",
    res.processed === 0 && res.failed === 1,
    JSON.stringify(res)
  );
}

async function productionWiringGuard(): Promise<void> {
  // Real production-path guard (no injected deps): index.ts must register the
  // Stage-B trigger on the events subcollection AND wire the real aggregator
  // into the scheduler. This is the analog of Stage A's index.ts wiring assert —
  // it catches a trigger bound to the wrong path or a scheduler that forgot to
  // pass updatePooledRatingStats (which would throw in prod but pass in a test
  // that injected its own aggregate).
  const indexSrc = fs.readFileSync(path.join(__dirname, "..", "index.ts"), "utf8");

  const triggerBound =
    /onPooledRatingEventWritten\s*=\s*onDocumentWritten\(/.test(indexSrc) &&
    /document:\s*POOL_EVENT_TRIGGER_PATH/.test(indexSrc) &&
    /schedulePoolAggregation\(/.test(indexSrc);

  const schedulerWired =
    /drainPooledRatingAggregations\s*=\s*onSchedule\(/.test(indexSrc) &&
    /drainPoolAggregationQueue\(\s*\{[\s\S]*?aggregate:\s*updatePooledRatingStats/.test(indexSrc);

  const pathShape =
    POOL_EVENT_TRIGGER_PATH === "users/{uid}/canonical_rating_events/{poolKey}" &&
    POOL_EVENT_TRIGGER_PATH.includes(CANONICAL_EVENTS_SUBCOLLECTION);

  record(
    "production wiring: index.ts binds trigger to events subcollection + schedules",
    triggerBound && pathShape,
    `triggerBound=${triggerBound} pathShape=${pathShape}`
  );
  record(
    "production wiring: scheduler passes the real updatePooledRatingStats aggregator",
    schedulerWired,
    `schedulerWired=${schedulerWired}`
  );
}

async function requiredCompositeIndexDeclared(): Promise<void> {
  // The unit fakes model DATA, not Firestore's index layer — so a correct-looking
  // aggregate can still throw FAILED_PRECONDITION in prod for lack of an index.
  // average("ratingValue") filtered by poolKey needs a COMPOSITE collection-group
  // index (poolKey, ratingValue): aggregations read index entries, never docs, so
  // the averaged field must be in the scanned index. A single-field poolKey index
  // serves count() but makes average() throw. Assert the composite is declared.
  const indexes = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "..", "..", "firestore.indexes.json"), "utf8")
  ) as {
    indexes: Array<{
      collectionGroup: string;
      queryScope: string;
      fields: Array<{ fieldPath: string; order?: string }>;
    }>;
  };
  const match = indexes.indexes.find(
    (ix) =>
      ix.collectionGroup === CANONICAL_EVENTS_SUBCOLLECTION &&
      ix.queryScope === "COLLECTION_GROUP" &&
      ix.fields.some((f) => f.fieldPath === "poolKey") &&
      ix.fields.some((f) => f.fieldPath === "ratingValue")
  );
  // Equality-filter field must precede the aggregated field in a composite.
  const orderOk =
    !!match &&
    match.fields.findIndex((f) => f.fieldPath === "poolKey") <
      match.fields.findIndex((f) => f.fieldPath === "ratingValue");
  record(
    "index config: composite (poolKey, ratingValue) COLLECTION_GROUP index declared for average()",
    !!match && orderOk,
    `match=${JSON.stringify(match)}`
  );
}

async function runAll(): Promise<void> {
  console.log("Pooled ratings Stage B — pool aggregator tests\n");
  console.log("==============================================\n");
  await statsCorrectnessSmallPool();
  await aggregateNotFold();
  await emptyPoolWritesZero();
  await drainRunsAggregatorPerMarker();
  await drainUnwiredFailsLoudly();
  await productionWiringGuard();
  await requiredCompositeIndexDeclared();

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
