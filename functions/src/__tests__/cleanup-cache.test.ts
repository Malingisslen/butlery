/**
 * cleanupExpiredCache tests — pure unit level, no emulator.
 *
 * What is being proven (BUT-1786): the walk over `globalRecipeCache` is PAGED,
 * so peak memory is one page rather than the whole collection, WITHOUT changing
 * which rows get deleted. The old implementation did a single unbounded
 * `collectionRef.get()` in a default-memory instance. (The job is deliberately
 * NOT part of a maintenance chain today — see `maintenance-dispatchers.ts` —
 * but an unbounded materialisation is a defect on its own terms, and an OOM
 * kill produces no error log at all.)
 *
 * Expiry is per-document (`cachedAt + ttlDays`, ttlDays defaulting to 90) and
 * is computed in memory, so — unlike the notification cleanup — deleting does
 * NOT advance the query window and a `startAfter` cursor is mandatory. The
 * cursor must anchor on the last SCANNED doc, never the last deleted one.
 *
 * Run with: npx ts-node src/__tests__/cleanup-cache.test.ts
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "butlery-test-cleanup-cache" });
}

import {
  runCleanupExpiredCache,
  cleanupExpiredCache,
  DEFAULT_TTL_DAYS,
  WALL_CLOCK_BUDGET_MS,
  CACHE_CLEANUP_TIMEOUT_SECONDS,
} from "../cleanup/cleanup-cache";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const NOW = new Date("2026-08-03T00:00:00.000Z");

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.error(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

interface SeedDoc {
  id: string;
  ageDays: number;
  ttlDays?: number;
}

/**
 * Minimal fake Firestore supporting exactly the call shape the SUT uses:
 *   db.collection(name).orderBy(FieldPath.documentId()).limit(n)[.startAfter(d)].get()
 *   db.batch().delete(ref) / .commit()
 * It records every page size requested so the test can prove paging happened.
 */
function makeFakeDb(seed: SeedDoc[]) {
  const store = new Map<string, { cachedAt: unknown; ttlDays?: number }>();
  for (const s of seed) {
    const cachedAtMs = NOW.getTime() - s.ageDays * MS_PER_DAY;
    store.set(s.id, {
      cachedAt: { toMillis: () => cachedAtMs },
      ...(s.ttlDays != null ? { ttlDays: s.ttlDays } : {}),
    });
  }

  const deleted: string[] = [];
  const pageSizes: number[] = [];
  const cursorsUsed: (string | undefined)[] = [];
  let committedBatches = 0;

  function makeQuery(limit: number | null, after: string | undefined): unknown {
    return {
      limit(n: number) {
        return makeQuery(n, after);
      },
      startAfter(doc: { id: string }) {
        return makeQuery(limit, doc.id);
      },
      async get() {
        cursorsUsed.push(after);
        const ids = [...store.keys()].sort();
        // Position by comparing sort keys, NEVER by `indexOf(after)`. Real
        // Firestore builds the cursor from the snapshot's orderBy values (for
        // `__name__`, the ref path) and never re-reads the anchor doc, so a
        // DELETED anchor still positions correctly; `indexOf` returns -1 and
        // silently restarts the walk at page one.
        //
        // This is a claim about the FAKE, so it is pinned by a fixture rather
        // than by this comment: `testFakeCursorModelIsFaithful` below is the
        // only shape where the two models disagree (surviving docs BEFORE a
        // deleted anchor). Without it, swapping this line back to `indexOf`
        // leaves the whole suite green — verified.
        const idx = after != null ? ids.findIndex((id) => id > after) : 0;
        const start = idx === -1 ? ids.length : idx;
        const slice = ids.slice(start, limit != null ? start + limit : undefined);
        pageSizes.push(slice.length);
        const docs = slice.map((id) => ({
          id,
          ref: { id },
          data: () => store.get(id)!,
        }));
        return { empty: docs.length === 0, size: docs.length, docs };
      },
    };
  }

  const db = {
    collection(name: string) {
      // Pin the collection. A fake that ignores its argument would stay green
      // if the SUT started walking a different collection entirely.
      if (name !== "globalRecipeCache") {
        throw new Error(`unmodelled collection: ${name}`);
      }
      return {
        orderBy(field: unknown) {
          // Pin the ORDER FIELD too. `orderBy("cachedAt")` would leave this
          // suite green while silently excluding every doc that has no
          // `cachedAt` — precisely the epoch-0 rows the SUT deliberately
          // treats as always-expired.
          if (!(field instanceof admin.firestore.FieldPath)) {
            throw new Error(`expected FieldPath.documentId(), got ${String(field)}`);
          }
          return makeQuery(null, undefined);
        },
      };
    },
    batch() {
      const pending: string[] = [];
      return {
        delete(ref: { id: string }) {
          pending.push(ref.id);
        },
        async commit() {
          committedBatches++;
          for (const id of pending) {
            store.delete(id);
            deleted.push(id);
          }
        },
      };
    },
  };

  return { db, deleted, pageSizes, cursorsUsed, store, committedBatches: () => committedBatches };
}

async function testDeletesOnlyExpired(): Promise<void> {
  // Ages are LITERAL, never derived from DEFAULT_TTL_DAYS. Writing
  // `ageDays: DEFAULT_TTL_DAYS + 1` would move with the constant and assert
  // nothing about its value — the tautology-over-the-implementation trap.
  // `b` (91d) and `f` (90d) bracket the default EXACTLY. A bracket pair pins an
  // INTERVAL, not a value: with `f` at 70d the suite was measured green for
  // every default in [70, 90], so a silent cut from 90 to 80 shipped clean.
  // Placing `f` one unit inside the boundary collapses that window to 90 —
  // measured: 91 reddens (b survives), 89 reddens (f dies), 90 is the only
  // green value.
  const fake = makeFakeDb([
    { id: "a-fresh", ageDays: 1 },
    { id: "b-old-default-ttl", ageDays: 91 },
    { id: "c-short-ttl-expired", ageDays: 40, ttlDays: 30 },
    { id: "d-long-ttl-alive", ageDays: 100, ttlDays: 180 },
    { id: "e-exactly-at-ttl", ageDays: 90, ttlDays: 90 },
    { id: "f-at-default-ttl", ageDays: 90 },
  ]);

  const res = await runCleanupExpiredCache({
    db: fake.db as never,
    now: NOW,
  });

  record(
    "deletes only entries past cachedAt + ttlDays",
    JSON.stringify(fake.deleted.sort()) ===
      JSON.stringify(["b-old-default-ttl", "c-short-ttl-expired"]),
    `deleted ${JSON.stringify(fake.deleted)}`,
  );
  // Pinned BEHAVIOURALLY rather than by comparing the constant to a literal.
  // `DEFAULT_TTL_DAYS === 90` does survive into the emitted JS and does run —
  // but TS narrows the constant to its literal type, so changing it to 80 makes
  // that comparison a COMPILE error (TS2367, "no overlap"), not a test failure,
  // and either way it pins the literal rather than what the literal does. The
  // two fixtures bracket the boundary instead: 91 days must die, 90 must live.
  // Lower the default and `f` starts dying; raise it and `b` stops dying.
  record(
    `a missing ttlDays falls back to exactly ${DEFAULT_TTL_DAYS} days (91d dies, 90d lives)`,
    fake.deleted.includes("b-old-default-ttl") &&
      !fake.deleted.includes("f-at-default-ttl"),
    `deleted ${JSON.stringify(fake.deleted)}`,
  );
  record(
    "an entry exactly AT its ttl is not yet expired",
    !fake.deleted.includes("e-exactly-at-ttl"),
  );
  record(
    "reports what it scanned and deleted",
    res.scanned === 6 && res.deleted === 2 && res.truncated === false,
    JSON.stringify(res),
  );
}

async function testWalkIsPaged(): Promise<void> {
  // 1200 docs = three pages at BATCH_LIMIT 500. None expired, so nothing is
  // deleted and the cursor is the ONLY thing that can advance the walk — which
  // is exactly the regression this guards: anchoring the cursor on a deleted
  // doc, or dropping it, loops forever or re-reads page one.
  const seed: SeedDoc[] = [];
  for (let i = 0; i < 1200; i++) {
    seed.push({ id: `doc-${String(i).padStart(5, "0")}`, ageDays: 1 });
  }
  const fake = makeFakeDb(seed);

  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "never asks for more than one page (BATCH_LIMIT) at a time",
    fake.pageSizes.every((n) => n <= 500),
    `page sizes ${JSON.stringify(fake.pageSizes)}`,
  );
  record(
    "walks the whole collection across pages",
    res.scanned === 1200,
    `scanned ${res.scanned}`,
  );
  record(
    "advances the cursor instead of re-reading page one",
    fake.cursorsUsed.length >= 3 &&
      fake.cursorsUsed[0] === undefined &&
      fake.cursorsUsed[1] !== undefined &&
      fake.cursorsUsed[1] !== fake.cursorsUsed[2],
    `cursors ${JSON.stringify(fake.cursorsUsed)}`,
  );
}

async function testCursorAnchorsOnLastScannedNotLastDeleted(): Promise<void> {
  // THE fixture that distinguishes the two cursor choices, and the reason the
  // first draft of this suite was VACUOUS: it seeded indices 0-499 as expired,
  // which made page one's last scanned doc and last deleted doc the SAME
  // document. Both `page.docs[last]` and `expired[last]` were `doc-00499`, so
  // the mutant it claimed to catch passed 10/10.
  //
  // Here indices 0-498 are expired and index 499 — the LAST doc on page one —
  // is fresh. Now `expired[last]` is `doc-00498` while `page.docs[last]` is
  // `doc-00499`. Anchoring on the deleted one re-reads `doc-00499` on page two
  // and inflates `scanned`; anchoring on the scanned one is exact.
  const seed: SeedDoc[] = [];
  for (let i = 0; i < 700; i++) {
    seed.push({
      id: `doc-${String(i).padStart(5, "0")}`,
      ageDays: i < 499 ? 100 : 1,
    });
  }
  const fake = makeFakeDb(seed);

  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "the cursor anchors on the last SCANNED doc, not the last deleted one",
    res.scanned === 700 && res.deleted === 499,
    JSON.stringify(res),
  );
  record(
    "the 201 fresh entries survive",
    fake.store.size === 201,
    `store size ${fake.store.size}`,
  );
}

async function testFullyDeletedPageDoesNotStall(): Promise<void> {
  // The companion case: EVERY doc on page one is expired. Real Firestore
  // positions a cursor from the snapshot's sort-key values without re-reading
  // the anchor, so a deleted anchor still works — the fake models that too.
  const seed: SeedDoc[] = [];
  for (let i = 0; i < 700; i++) {
    seed.push({
      id: `doc-${String(i).padStart(5, "0")}`,
      ageDays: i < 500 ? 100 : 1,
    });
  }
  const fake = makeFakeDb(seed);

  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "a fully-deleted page does not stall the walk",
    res.scanned === 700 && res.deleted === 500,
    JSON.stringify(res),
  );
  record(
    "the 200 fresh entries on the last page survive",
    fake.store.size === 200,
    `store size ${fake.store.size}`,
  );
}

async function testMalformedCachedAtDoesNotBlockTheWalk(): Promise<void> {
  // A `cachedAt` that is present but not a Timestamp throws on `.toMillis()`.
  // Unguarded, one such doc ends the run — and because the walk is
  // `__name__`-ordered with no persisted cursor, every doc sorting after it is
  // never examined again, every day, forever.
  const fake = makeFakeDb([
    { id: "a-fresh", ageDays: 1 },
    { id: "b-poison", ageDays: 1 },
    { id: "c-old", ageDays: 200 },
  ]);
  // Replace b's cachedAt with something that throws, as a client could write.
  (fake.store.get("b-poison") as { cachedAt: unknown }).cachedAt = {
    toMillis: () => {
      throw new TypeError("not a Timestamp");
    },
  };

  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "a malformed cachedAt does not abort the walk",
    res.scanned === 3,
    JSON.stringify(res),
  );
  record(
    "the doc sorting AFTER the poison row is still examined and deleted",
    fake.deleted.includes("c-old"),
    `deleted ${JSON.stringify(fake.deleted)}`,
  );
  record(
    "the malformed row is counted and treated as expired",
    res.malformed === 1 && fake.deleted.includes("b-poison"),
    JSON.stringify(res),
  );
}

async function testZeroTtlFallsBackToDefault(): Promise<void> {
  // The original used `data.ttlDays || 90`, so a stored 0 fell back to 90 days.
  // A naive `??` rewrite would let 0 through and expire the row immediately —
  // a behaviour change hiding inside a "mechanical" refactor.
  const fake = makeFakeDb([
    { id: "a-zero-ttl-young", ageDays: 10, ttlDays: 0 },
    { id: "b-zero-ttl-old", ageDays: 100, ttlDays: 0 },
  ]);

  await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "ttlDays 0 falls back to the default instead of expiring instantly",
    !fake.deleted.includes("a-zero-ttl-young") &&
      fake.deleted.includes("b-zero-ttl-old"),
    `deleted ${JSON.stringify(fake.deleted)}`,
  );
}

async function testEmptyCollection(): Promise<void> {
  const fake = makeFakeDb([]);
  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });
  record(
    "an empty collection is a clean no-op",
    res.scanned === 0 && res.deleted === 0 && fake.committedBatches() === 0,
    JSON.stringify(res),
  );
}

async function testFakeCursorModelIsFaithful(): Promise<void> {
  // Guards the FAKE, not the SUT — a paging fake that silently restarts the
  // walk reads as faithful and would let a real cursor bug through.
  //
  // The two models (`indexOf(anchor) + 1` vs `findIndex(id > anchor)`) are
  // indistinguishable unless page one has SURVIVING docs before a DELETED
  // anchor: with a live anchor `indexOf` finds it, and with a wholly-deleted
  // page `indexOf → -1 → 0` coincidentally lands on the right slice. Here
  // indices 0-98 survive and 99-499 are deleted, so the anchor `doc-00499` is
  // gone while earlier docs remain.
  const seed: SeedDoc[] = [];
  for (let i = 0; i < 700; i++) {
    seed.push({
      id: `doc-${String(i).padStart(5, "0")}`,
      ageDays: i >= 99 && i < 500 ? 100 : 1,
    });
  }
  const fake = makeFakeDb(seed);

  const res = await runCleanupExpiredCache({ db: fake.db as never, now: NOW });

  record(
    "the fake positions its cursor by sort key, not by looking the anchor up",
    res.scanned === 700 && res.deleted === 401,
    `${JSON.stringify(res)} — an indexOf-based fake reports scanned 799`,
  );
}

async function testTruncationIsVisible(): Promise<void> {
  // The budget exists to turn a silent platform kill into a visible
  // `truncated: true`. A budget of 0 forces the branch on the first iteration.
  const seed: SeedDoc[] = [];
  for (let i = 0; i < 600; i++) {
    seed.push({ id: `doc-${String(i).padStart(5, "0")}`, ageDays: 1 });
  }
  const fake = makeFakeDb(seed);

  const res = await runCleanupExpiredCache({
    db: fake.db as never,
    now: NOW,
    budgetMs: 0,
  });

  record(
    "an exhausted budget stops the walk and says so",
    res.truncated === true && res.scanned === 0,
    JSON.stringify(res),
  );
  record(
    "the in-code budget stays below the declared platform timeout",
    WALL_CLOCK_BUDGET_MS < CACHE_CLEANUP_TIMEOUT_SECONDS * 1000,
    `${WALL_CLOCK_BUDGET_MS}ms vs ${CACHE_CLEANUP_TIMEOUT_SECONDS * 1000}ms`,
  );

  // Comparing the two constants to each other does NOT pin the declaration
  // site: delete `timeoutSeconds` from the wrapper, or set it to 30, and the
  // check above stays green while the 45s guard silently becomes dead code —
  // exactly the BUT-1781 failure mode. A v2 export's `__endpoint` IS the deploy
  // manifest and is readable at import time, so assert the value the CLI will
  // actually ship.
  const endpoint = (
    cleanupExpiredCache as unknown as {
      __endpoint?: { timeoutSeconds?: number };
    }
  ).__endpoint;
  // Optional-chained on purpose: an unguarded dereference would throw and skip
  // every test function after this one, hiding the failure as a missing summary
  // line instead of one named FAIL.
  record(
    "the wrapper actually DECLARES the paired timeout in its deploy manifest",
    endpoint?.timeoutSeconds === CACHE_CLEANUP_TIMEOUT_SECONDS,
    endpoint == null
      ? "no __endpoint on the export — firebase-functions changed its deploy-manifest shape, NOT a timeout regression"
      : JSON.stringify(endpoint),
  );
}

async function main(): Promise<void> {
  console.log("cleanup-cache tests\n");
  await testDeletesOnlyExpired();
  await testWalkIsPaged();
  await testCursorAnchorsOnLastScannedNotLastDeleted();
  await testFakeCursorModelIsFaithful();
  await testTruncationIsVisible();
  await testFullyDeletedPageDoesNotStall();
  await testMalformedCachedAtDoesNotBlockTheWalk();
  await testZeroTtlFallsBackToDefault();
  await testEmptyCollection();

  console.log(`\n${totalRun - totalFailed}/${totalRun} checks passed`);
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
