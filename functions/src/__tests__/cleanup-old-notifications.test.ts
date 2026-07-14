/**
 * BUT-1595 — drain-loop unit tests for `cleanupCollection`
 * (follow-up to BUT-1563, which added the multi-page drain but shipped it
 * untested).
 *
 * `cleanupCollection` (in `cleanup/cleanup-old-notifications.ts`) pages through
 * every expired doc, deleting a page then re-querying — the committed deletes
 * drop rows out of the `< cutoff` filter, so each pass shrinks the window until
 * a short/empty page ends the drain. These tests pin that contract plus the
 * bounded-iteration guard that stops a pathological non-shrinking page from
 * looping until the platform timeout.
 *
 * Run: npx ts-node src/__tests__/cleanup-old-notifications.test.ts
 *
 * Fake admin shape driven by an in-memory store (BATCH_LIMIT = 500), no real
 * Firestore — same pattern as purge-audit-logs.test.ts. The real
 * `batchDeleteDocs` runs against the fake `batch()`/`ref.delete()` shape.
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-notif-cleanup" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { cleanupCollection } = require("../cleanup/cleanup-old-notifications");

const BATCH_LIMIT = 500;

interface FakeDoc {
  id: string;
  ts: number;
}

interface FakeStore {
  docs: FakeDoc[];
  /** When false, ref.delete() is a no-op — models a non-shrinking page. */
  shrink: boolean;
  deletedCalls: number;
}

interface QueryPredicates {
  cutoffMs?: number;
  limitN?: number;
}

/** Timestamp-like the fake `where('ts','<',cutoff)` reads via toMillis(). */
function fakeCutoff(ms: number): { toMillis(): number } {
  return { toMillis: () => ms };
}

function makeFakeDb(store: FakeStore) {
  function makeQuery(pred: QueryPredicates) {
    return {
      where(field: string, op: string, value: { toMillis(): number }) {
        if (op !== "<") {
          throw new Error(`makeFakeDb: unexpected where op ${op}`);
        }
        return makeQuery({ ...pred, cutoffMs: value.toMillis() });
      },
      limit(n: number) {
        return makeQuery({ ...pred, limitN: n });
      },
      async get() {
        let matches = store.docs;
        if (pred.cutoffMs !== undefined) {
          matches = matches.filter((d) => d.ts < pred.cutoffMs!);
        }
        if (pred.limitN !== undefined) {
          matches = matches.slice(0, pred.limitN);
        }
        return {
          empty: matches.length === 0,
          size: matches.length,
          docs: matches.map((m) => ({
            ref: {
              delete: async () => {
                store.deletedCalls++;
                if (store.shrink) {
                  const i = store.docs.findIndex((d) => d.id === m.id);
                  if (i >= 0) store.docs.splice(i, 1);
                }
              },
            },
          })),
        };
      },
    };
  }

  return {
    collection(_name: string) {
      return makeQuery({});
    },
    batch() {
      const ops: Array<{ delete(): Promise<void> }> = [];
      return {
        delete(ref: { delete(): Promise<void> }) {
          ops.push(ref);
        },
        async commit() {
          for (const r of ops) await r.delete();
        },
      };
    },
  };
}

function seed(count: number, shrink: boolean): FakeStore {
  return {
    docs: Array.from({ length: count }, (_, i) => ({ id: `d-${i}`, ts: 0 })),
    shrink,
    deletedCalls: 0,
  };
}

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

// Cutoff is in the future so every seeded doc (ts=0) is "expired".
const CUTOFF = fakeCutoff(Date.now());

async function happyPathMultiPageDrainWithShortFinalPage(): Promise<void> {
  // 1200 docs → pages 500, 500, 200. The 200-doc final page is < BATCH_LIMIT,
  // so the drain exits on the short-final-page condition. All 1200 deleted.
  const store = seed(1200, true);
  const result = await cleanupCollection(
    makeFakeDb(store) as never,
    "notification_history",
    "sentAt",
    CUTOFF as never
  );
  record(
    "happy path: multi-page drain deletes every expired doc, exits on short final page",
    result.deletedCount === 1200 &&
      result.collection === "notification_history" &&
      store.docs.length === 0 &&
      store.deletedCalls === 1200,
    `deletedCount=${result.deletedCount} remaining=${store.docs.length}`
  );
}

async function exactMultipleExitsOnEmptyPage(): Promise<void> {
  // 1000 docs → pages 500, 500, then a full-but-consumed window yields an
  // EMPTY page → exits on the snapshot.empty condition (distinct from the
  // short-final-page exit above).
  const store = seed(1000, true);
  const result = await cleanupCollection(
    makeFakeDb(store) as never,
    "notification_delivery",
    "sentAt",
    CUTOFF as never
  );
  record(
    "exact-multiple drain exits on an empty page after the last full page",
    result.deletedCount === 1000 && store.docs.length === 0,
    `deletedCount=${result.deletedCount} remaining=${store.docs.length}`
  );
}

async function emptyCollectionExit(): Promise<void> {
  // 0 docs → first query is empty → exits immediately, deletes nothing.
  const store = seed(0, true);
  const result = await cleanupCollection(
    makeFakeDb(store) as never,
    "notification_engagement",
    "timestamp",
    CUTOFF as never
  );
  record(
    "empty collection → no-op drain returns 0",
    result.deletedCount === 0 && store.deletedCalls === 0,
    `deletedCount=${result.deletedCount} deletedCalls=${store.deletedCalls}`
  );
}

async function boundedIterationGuardStopsNonShrinkingPage(): Promise<void> {
  // Pathological case: a full page (500) that never shrinks (delete is a
  // no-op). Without the guard this loops until the platform timeout. With
  // maxIterations=5 it stops after exactly 5 passes and returns — the key
  // assertion is that this call TERMINATES at all.
  const store = seed(BATCH_LIMIT, false);
  const result = await cleanupCollection(
    makeFakeDb(store) as never,
    "notification_history",
    "sentAt",
    CUTOFF as never,
    5
  );
  record(
    "bounded-iteration guard: non-shrinking full page stops after maxIterations (no infinite loop)",
    result.deletedCount === BATCH_LIMIT * 5 &&
      store.docs.length === BATCH_LIMIT &&
      store.deletedCalls === BATCH_LIMIT * 5,
    `deletedCount=${result.deletedCount} remaining=${store.docs.length}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-1595: cleanup-old-notifications drain-loop tests\n");
  console.log("==========================================\n");
  await happyPathMultiPageDrainWithShortFinalPage();
  await exactMultipleExitsOnEmptyPage();
  await emptyCollectionExit();
  await boundedIterationGuardStopsNonShrinkingPage();

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
