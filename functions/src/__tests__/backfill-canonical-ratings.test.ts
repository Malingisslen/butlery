/**
 * Pooled-ratings backfill tests (decision 14 / Increment 8).
 *
 * Covers the core `runCanonicalRatingsBackfill` against an in-memory Firestore +
 * fake auth. Proves the contracts a one-shot history-merge must not get wrong:
 *   1. Mirrors an eligible rating → one event at the SERVER-computed poolKey.
 *   2. Tamper defence: a client-written key on the rating doc is ignored; the
 *      key is recomputed from the rater's own recipe content.
 *   3. dryRun writes nothing but still counts what it WOULD write.
 *   4. Immature/unverified account → skippedImmature, no event (decision 7).
 *   5. Rater has no own recipe copy → skippedNoRecipe.
 *   6. Fail-closed key (computeKey → null) → skippedNoKey, no event.
 *   7. Idempotent: an already-identical event → skippedIdentical, no re-write.
 *   8. Invalid rating (NaN / out-of-range / missing uid) → skippedInvalid.
 *
 * The callable wrapper's admin gate + flag-off refusal (AC10) are enforced by
 * `requireAdmin` (shared tests) and `isPooledRatingsEnabled` (pooled-ratings-flag
 * tests) respectively; this suite exercises the migration logic itself.
 *
 * Run with: npx ts-node src/__tests__/backfill-canonical-ratings.test.ts
 */

import {
  runCanonicalRatingsBackfill,
} from "../migrations/backfill-canonical-ratings";
import { __resetMaturedMemoForTests } from "../ratings/canonical-rating-aggregation";

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

interface FakeRating {
  id: string;
  userId?: string;
  recipeId?: string;
  rating?: number;
  createdAt?: unknown;
  /** A hostile client-written key — the backfill MUST ignore it (test 2). */
  poolKey?: string;
}

/** users/{uid}/recipes/{recipeId} → core content, or absent. */
type RecipeStore = Record<string, { title: string; ingredients: string[] }>;
/** users/{uid}/canonical_rating_events/{poolKey} → event data. */
type EventStore = Record<string, Record<string, unknown>>;

/**
 * Minimal in-memory Firestore matching only the surface the backfill +
 * the reused mirror helpers (recipeContentToKey) touch.
 */
function makeFakeDb(
  ratings: FakeRating[],
  recipes: RecipeStore,
  events: EventStore
) {
  const recipeSnap = (uid: string, recipeId: string) => {
    const core = recipes[`${uid}/${recipeId}`];
    return { exists: !!core, data: () => (core ? { core } : undefined) };
  };
  const eventKey = (uid: string, poolKey: string) => `${uid}/${poolKey}`;

  // A doc ref that can point at a recipe doc OR an event doc depending on the
  // collection segment used to reach it.
  const makeDoc = (segments: string[]) => ({
    collection(name: string) {
      return makeCollection([...segments, name]);
    },
    async get() {
      // users/{uid}/recipes/{recipeId}
      if (segments[0] === "users" && segments[2] === "recipes") {
        return recipeSnap(segments[1], segments[3]);
      }
      // users/{uid}/canonical_rating_events/{poolKey}
      if (segments[0] === "users" && segments[2] === "canonical_rating_events") {
        const data = events[eventKey(segments[1], segments[3])];
        return { exists: !!data, data: () => data };
      }
      return { exists: false, data: () => undefined };
    },
    __segments: segments,
  });

  function makeCollection(segments: string[]) {
    return {
      _startAfter: null as string | null,
      doc(id: string) {
        return makeDoc([...segments, id]);
      },
      orderBy() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter(id: string) {
        this._startAfter = id;
        return this;
      },
      async get() {
        // Only recipe_ratings is queried as a collection scan.
        if (segments[0] === "recipe_ratings") {
          let rows = [...ratings].sort((a, b) => a.id.localeCompare(b.id));
          if (this._startAfter) {
            rows = rows.filter((r) => r.id > this._startAfter!);
          }
          return {
            empty: rows.length === 0,
            size: rows.length,
            docs: rows.map((r) => ({ id: r.id, data: () => r })),
          };
        }
        return { empty: true, size: 0, docs: [] };
      },
    };
  }

  const batch = () => {
    const ops: Array<{ path: string; data: Record<string, unknown> }> = [];
    return {
      set(ref: { __segments: string[] }, data: Record<string, unknown>) {
        ops.push({
          path: eventKey(ref.__segments[1], ref.__segments[3]),
          data,
        });
      },
      async commit() {
        for (const op of ops) events[op.path] = op.data;
      },
      get __writes() {
        return ops;
      },
    };
  };

  return {
    collection(name: string) {
      return makeCollection([name]);
    },
    batch,
    __events: events,
  };
}

/** Fake auth: matured = emailVerified true. */
function fakeAuth(users: Record<string, { emailVerified: boolean; creationMsAgo?: number }>) {
  return {
    async getUser(uid: string) {
      const u = users[uid];
      if (!u) {
        const err = new Error("no user") as Error & { code: string };
        err.code = "auth/user-not-found";
        throw err;
      }
      return {
        emailVerified: u.emailVerified,
        metadata: {
          creationTime: new Date(
            NOW - (u.creationMsAgo ?? 0)
          ).toUTCString(),
        },
      } as never;
    },
  } as never;
}

const NOW = 1_800_000_000_000;
const nowFn = () => NOW;
// A stub key function so tests control the derived key deterministically and can
// prove it comes from RECIPE CONTENT, never the rating's client-written field.
const keyFromContent = (title: string, ingredients: string[]): string | null => {
  if (!title || ingredients.length === 0) return null;
  return `v1:${title.toLowerCase()}|${ingredients.length}`;
};

async function main() {
  const maturedUser = { emailVerified: true };

  // ── 1. Mirrors an eligible rating ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [{ id: "r_u1", userId: "u1", recipeId: "rec1", rating: 4 }],
      { "u1/rec1": { title: "Köttbullar", ingredients: ["a", "b"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    const ev = events["u1/v1:köttbullar|2"];
    record(
      "1 mirrors eligible rating to server-computed poolKey",
      res.mirrored === 1 &&
        !!ev &&
        ev.ratingValue === 4 &&
        ev.recipeId === "rec1" &&
        ev.poolKey === "v1:köttbullar|2",
      JSON.stringify({ mirrored: res.mirrored, ev })
    );
  }

  // ── 2. Tamper defence: client key on the rating doc is ignored ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [
        {
          id: "r_u1",
          userId: "u1",
          recipeId: "rec1",
          rating: 5,
          poolKey: "v1:HIJACKED", // hostile client value
        },
      ],
      { "u1/rec1": { title: "Pannkakor", ingredients: ["x", "y", "z"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "2 ignores client-written key, uses recipe-content key",
      res.mirrored === 1 &&
        !!events["u1/v1:pannkakor|3"] &&
        !events["u1/v1:HIJACKED"],
      JSON.stringify(Object.keys(events))
    );
  }

  // ── 3. dryRun writes nothing ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [{ id: "r_u1", userId: "u1", recipeId: "rec1", rating: 3 }],
      { "u1/rec1": { title: "Soppa", ingredients: ["a"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: true,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "3 dryRun counts but writes nothing",
      res.mirrored === 1 && res.dryRun === true && Object.keys(events).length === 0,
      JSON.stringify({ mirrored: res.mirrored, events: Object.keys(events) })
    );
  }

  // ── 4. Immature account skipped ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [{ id: "r_u2", userId: "u2", recipeId: "rec1", rating: 4 }],
      { "u2/rec1": { title: "Gröt", ingredients: ["a"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      // unverified + created 1 minute ago (< 60 min maturity window)
      auth: fakeAuth({ u2: { emailVerified: false, creationMsAgo: 60_000 } }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "4 immature account → skippedImmature, no event",
      res.mirrored === 0 &&
        res.skippedImmature === 1 &&
        Object.keys(events).length === 0,
      JSON.stringify(res)
    );
  }

  // ── 5. No own recipe copy ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [{ id: "r_u1", userId: "u1", recipeId: "missing", rating: 4 }],
      {}, // no recipe stored
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "5 no own recipe copy → skippedNoRecipe",
      res.mirrored === 0 && res.skippedNoRecipe === 1,
      JSON.stringify(res)
    );
  }

  // ── 6. Fail-closed key ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [{ id: "r_u1", userId: "u1", recipeId: "rec1", rating: 4 }],
      { "u1/rec1": { title: "", ingredients: [] } }, // → keyFromContent null
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "6 fail-closed key → skippedNoKey, no event",
      res.mirrored === 0 &&
        res.skippedNoKey === 1 &&
        Object.keys(events).length === 0,
      JSON.stringify(res)
    );
  }

  // ── 7. Idempotent: identical existing event skipped ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {
      "u1/v1:köttbullar|2": {
        poolKey: "v1:köttbullar|2",
        ratingValue: 4,
        recipeId: "rec1",
      },
    };
    const db = makeFakeDb(
      [{ id: "r_u1", userId: "u1", recipeId: "rec1", rating: 4 }],
      { "u1/rec1": { title: "Köttbullar", ingredients: ["a", "b"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "7 identical existing event → skippedIdentical, no re-write",
      res.mirrored === 0 && res.skippedIdentical === 1,
      JSON.stringify(res)
    );
  }

  // ── 8. Invalid rating ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const db = makeFakeDb(
      [
        { id: "r_a", userId: "u1", recipeId: "rec1", rating: NaN },
        { id: "r_b", userId: "u1", recipeId: "rec1", rating: 9 },
        { id: "r_c", userId: undefined, recipeId: "rec1", rating: 4 },
      ],
      { "u1/rec1": { title: "Köttbullar", ingredients: ["a", "b"] } },
      events
    );
    const res = await runCanonicalRatingsBackfill(db as never, {
      dryRun: false,
      maxRatings: 100,
      auth: fakeAuth({ u1: maturedUser }),
      now: nowFn,
      computeKey: keyFromContent,
    });
    record(
      "8 invalid ratings (NaN / >5 / no uid) → skippedInvalid, no event",
      res.mirrored === 0 &&
        res.skippedInvalid === 3 &&
        Object.keys(events).length === 0,
      JSON.stringify(res)
    );
  }

  // ── 9. Cursor resume across invocations processes every rating exactly once ──
  {
    __resetMaturedMemoForTests();
    const events: EventStore = {};
    const ratings: FakeRating[] = [
      { id: "a_u1", userId: "u1", recipeId: "a", rating: 3 },
      { id: "b_u1", userId: "u1", recipeId: "b", rating: 4 },
      { id: "c_u1", userId: "u1", recipeId: "c", rating: 5 },
    ];
    const recipes: RecipeStore = {
      "u1/a": { title: "A", ingredients: ["i"] },
      "u1/b": { title: "B", ingredients: ["i"] },
      "u1/c": { title: "C", ingredients: ["i"] },
    };
    let cursor: string | undefined = undefined;
    let calls = 0;
    let totalMirrored = 0;
    // maxRatings:1 forces one rating per invocation → true multi-invocation paging.
    for (;;) {
      const db = makeFakeDb(ratings, recipes, events);
      const res = await runCanonicalRatingsBackfill(db as never, {
        dryRun: false,
        maxRatings: 1,
        startAfter: cursor,
        auth: fakeAuth({ u1: maturedUser }),
        now: nowFn,
        computeKey: keyFromContent,
      });
      totalMirrored += res.mirrored;
      calls += 1;
      if (!res.hasMore) break;
      cursor = res.nextCursor ?? undefined;
      if (calls > 10) break; // guard against an infinite no-progress loop
    }
    record(
      "9 cursor resume pages the whole corpus, each rating once, terminates",
      calls === 3 &&
        totalMirrored === 3 &&
        !!events["u1/v1:a|1"] &&
        !!events["u1/v1:b|1"] &&
        !!events["u1/v1:c|1"],
      JSON.stringify({ calls, totalMirrored, keys: Object.keys(events) })
    );
  }

  // ── 10. Collision pool (one user, two copies → same key) converges, no oscillation ──
  {
    const recipes: RecipeStore = {
      "u1/a": { title: "Sås", ingredients: ["x", "y"] }, // key v1:sås|2
      "u1/b": { title: "Sås", ingredients: ["p", "q"] }, // same key v1:sås|2
    };
    const ratings: FakeRating[] = [
      { id: "a_u1", userId: "u1", recipeId: "a", rating: 3 },
      { id: "b_u1", userId: "u1", recipeId: "b", rating: 5 },
    ];
    const events: EventStore = {};
    // Run twice from scratch; the winner must be deterministic (last doc-id = b)
    // and the second run a pure no-op — not a flip back to a.
    __resetMaturedMemoForTests();
    const r1 = await runCanonicalRatingsBackfill(
      makeFakeDb(ratings, recipes, events) as never,
      { dryRun: false, maxRatings: 100, auth: fakeAuth({ u1: maturedUser }), now: nowFn, computeKey: keyFromContent }
    );
    const afterRun1 = { ...events["u1/v1:sås|2"] };
    __resetMaturedMemoForTests();
    const r2 = await runCanonicalRatingsBackfill(
      makeFakeDb(ratings, recipes, events) as never,
      { dryRun: false, maxRatings: 100, auth: fakeAuth({ u1: maturedUser }), now: nowFn, computeKey: keyFromContent }
    );
    const afterRun2 = events["u1/v1:sås|2"];
    record(
      "10 collision pool converges (deduped, last-by-doc-id winner, stable re-run)",
      r1.mirrored === 1 && // one pool, not two
        afterRun1.recipeId === "b" &&
        afterRun1.ratingValue === 5 &&
        r2.mirrored === 0 &&
        r2.skippedIdentical === 1 && // re-run is a no-op, no flip
        afterRun2.recipeId === "b" &&
        afterRun2.ratingValue === 5,
      JSON.stringify({ r1, r2, afterRun1, afterRun2 })
    );
  }

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? ` — ${totalFailed} FAILED` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

main().catch((e) => {
  console.error("test harness crashed:", e);
  process.exit(1);
});
