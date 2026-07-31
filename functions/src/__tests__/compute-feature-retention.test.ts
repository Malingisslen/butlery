/**
 * BUT-599: Feature-level retention tests.
 *
 * Coverage:
 *   1. Happy path — 3 users with mixed feature usage on the run-day:
 *      asserts per-user-per-day flag docs + the daily aggregate fields.
 *   2. Idempotent re-run on the same UTC day — write count doubles, but
 *      doc paths stay the same (set() overwrites).
 *   3. WAU-7d rollup — a user with flag=true 5 days ago is counted in
 *      wau7d.cooked even if today they had no activity.
 *   4. Skip case — a user with `lastActiveAt` 40d ago is never scanned;
 *      no flag doc is written for them.
 *   5. Probe failure graceful degradation — when a feature query throws
 *      (e.g. missing index), that flag falls back to false and the run
 *      completes.
 *   6. BUT-1724 — the `shopped` probe reads the live
 *      `users/{uid}/unified_shopping_lists` path and ignores the retired
 *      `users/{uid}/shopping_lists` name.
 *   7. BUT-1724 — a throwing `shopped` probe (missing index on that newly-read
 *      subcollection field) degrades to false without taking the run down.
 *   8. BUT-1761 — activity on a COLLABORATIVE list
 *      (`unified_shared_shopping_lists`, `lastActivityByUserId == uid`) sets
 *      `shopped`; a list touched today by someone else does not, and neither
 *      does the same user's own activity from yesterday.
 *   9. BUT-1761 — the two `shopped` legs fail independently: a throwing shared
 *      probe degrades to false on its own, and does not suppress a personal
 *      list that did flip.
 *  10. BUT-1761 — `firestore.indexes.json` declares the composite the shared
 *      leg needs. Without it the probe throws FAILED_PRECONDITION in
 *      production, `safeProbe` swallows it and the leg is a silent zero again
 *      — a fake db cannot catch that, so the declaration is asserted directly.
 *
 * Run with: npx ts-node src/__tests__/compute-feature-retention.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  runComputeFeatureRetention,
  formatUtcDate,
} from "../analytics/compute-feature-retention";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// functions/src/__tests__ → up 3 → repo root.
const INDEXES_PATH = path.resolve(
  __dirname,
  "..",
  "..",
  "..",
  "firestore.indexes.json",
);

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

function tsFromMs(ms: number) {
  return {
    toMillis: () => ms,
    toDate: () => new Date(ms),
  };
}

interface FakeUser {
  id: string;
  /** Days before `now`. Set to 99 to simulate inactive (>28d). */
  lastActiveDaysAgo: number;
}

interface ActivityRecord {
  /** Source key, e.g. "cook_snaps", "users/{uid}/recipes". */
  source: string;
  userId: string;
  /** UTC ms timestamp of the activity. */
  ts: number;
}

interface PreExistingFlagDoc {
  userId: string;
  /** UTC `yyyy-mm-dd`. */
  date: string;
  cooked?: boolean;
  imported?: boolean;
  shared?: boolean;
  mealPlanned?: boolean;
  shopped?: boolean;
}

interface DocStore {
  /** Map keyed by doc path → last-written data. */
  data: Map<string, Record<string, unknown>>;
  writeCount: number;
  commitCount: number;
}

interface FakeOpts {
  failProbeFor?: { userId: string; flag: string };
}

// Fake collection ref — supports the call shapes the SUT uses:
//   db.collection("users")...
//   db.collection("cook_snaps").where(...).where(...).where(...).limit(1).get()
//   db.collection("users").doc(uid).collection("recipes")....
//   db.collection("analytics").doc("feature_retention").collection("users").doc(`${uid}_${date}`).get()/set()
//   db.collection("analytics").doc("feature_retention").collection("daily").doc(date).set()
//   db.batch().set(ref, data) / commit()
function makeFakeDb(args: {
  users: FakeUser[];
  activity: ActivityRecord[];
  flagDocs: PreExistingFlagDoc[];
  store: DocStore;
  now: Date;
  opts?: FakeOpts;
}) {
  const { users, activity, flagDocs, store, now, opts } = args;

  // Index for fast lookup.
  const userIds = new Set(users.map((u) => u.id));

  function flagDocPath(userId: string, date: string): string {
    return `analytics/feature_retention/users/${userId}_${date}`;
  }
  // Seed the store with pre-existing flag docs (used for WAU rollup tests).
  for (const f of flagDocs) {
    store.data.set(flagDocPath(f.userId, f.date), {
      userId: f.userId,
      date: f.date,
      cooked: !!f.cooked,
      imported: !!f.imported,
      shared: !!f.shared,
      mealPlanned: !!f.mealPlanned,
      shopped: !!f.shopped,
    });
  }

  function makeUsersQuery(startAfterIdx: number, cutoffMs: number | null) {
    const filtered = users
      .filter((u) => {
        if (cutoffMs == null) return true;
        const lastMs = now.getTime() - u.lastActiveDaysAgo * MS_PER_DAY;
        return lastMs >= cutoffMs;
      })
      .map((u) => ({
        id: u.id,
        data: () => ({
          lastActiveAt: tsFromMs(
            now.getTime() - u.lastActiveDaysAgo * MS_PER_DAY,
          ),
        }),
      }));
    return {
      _cutoffMs: cutoffMs,
      where(_field: string, op: string, value: { toMillis: () => number }) {
        // Only `lastActiveAt >= activeCutoff` is used at the user level.
        if (op === ">=" && value && typeof value.toMillis === "function") {
          return makeUsersQuery(startAfterIdx, value.toMillis());
        }
        return this;
      },
      orderBy() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter(lastDoc: { id: string }) {
        const idx = filtered.findIndex((d) => d.id === lastDoc.id);
        return makeUsersQuery(idx + 1, cutoffMs);
      },
      async get() {
        const slice = filtered.slice(startAfterIdx);
        return { size: slice.length, docs: slice, empty: slice.length === 0 };
      },
    };
  }

  /**
   * Fake activity-source query. All sources expose `where(...).where(...)` +
   * `limit(1).get()`. Discriminated by the (source, userField) pair the SUT
   * binds at call site. We model each source as: filter activity records by
   * `source` + `userId` + `[start,end)` time window.
   */
  function makeActivityQuery(args: {
    source: string;
    userId: string;
    timeField: string;
    startMs: number | null;
    endMs: number | null;
    failFlag?: string | null;
  }) {
    return {
      _source: args.source,
      _userId: args.userId,
      _timeField: args.timeField,
      _startMs: args.startMs,
      _endMs: args.endMs,
      where(field: string, op: string, value: unknown) {
        // userId equality (used by cook_snaps, shared_recipes).
        if (op === "==") {
          return makeActivityQuery({ ...args, userId: value as string });
        }
        if (op === ">=" && value && typeof (value as { toMillis?: () => number }).toMillis === "function") {
          return makeActivityQuery({
            ...args,
            timeField: field,
            startMs: (value as { toMillis: () => number }).toMillis(),
          });
        }
        if (op === "<" && value && typeof (value as { toMillis?: () => number }).toMillis === "function") {
          return makeActivityQuery({
            ...args,
            endMs: (value as { toMillis: () => number }).toMillis(),
          });
        }
        return makeActivityQuery(args);
      },
      limit() {
        return this;
      },
      async get() {
        // Inject failure if requested. Matched on EITHER the source path or the
        // feature flag: a subcollection source's path is
        // `users/{uid}/{sub}`, so a caller asking to fail `shopped` /
        // `mealPlanned` / `imported` would never match on `source` alone.
        if (
          opts?.failProbeFor &&
          opts.failProbeFor.userId === args.userId &&
          (opts.failProbeFor.flag === args.source ||
            opts.failProbeFor.flag === args.failFlag)
        ) {
          throw new Error(`simulated probe failure for ${args.source}`);
        }
        const matches = activity.filter(
          (r) =>
            r.source === args.source &&
            r.userId === args.userId &&
            (args.startMs == null || r.ts >= args.startMs) &&
            (args.endMs == null || r.ts < args.endMs),
        );
        return { size: matches.length, docs: matches, empty: matches.length === 0 };
      },
    };
  }

  function makeUserDoc(uid: string) {
    return {
      collection(sub: string) {
        // sub-collection on a user → activity source.
        // The SUT binds `where("core.createdAt"...)` on recipes,
        // `where("createdAt"...)` on menus,
        // `where("updatedAt"...)` on unified_shopping_lists.
        // We model all three as activity records keyed by source name.
        //
        // The default branch keeps `users/{uid}/{sub}` addressable on
        // purpose: it is what lets `shoppedProbeUsesLivePath` seed the
        // RETIRED `shopping_lists` name and prove the SUT never reads it
        // (BUT-1724). Do not narrow it to a throw.
        const sourceKey = `users/${uid}/${sub}`;
        // Track which feature this corresponds to for failure injection.
        const flag =
          sub === "recipes"
            ? "imported"
            : sub === "menus"
            ? "mealPlanned"
            : sub === "unified_shopping_lists"
            ? "shopped"
            : sub;
        return makeActivityQuery({
          source: sourceKey,
          userId: uid,
          timeField: "",
          startMs: null,
          endMs: null,
          failFlag: flag,
        });
      },
    };
  }

  function makeAnalyticsRoot() {
    // analytics/feature_retention/{users|daily}/...
    return {
      doc(docId: string) {
        if (docId !== "feature_retention") {
          throw new Error(`unexpected analytics doc: ${docId}`);
        }
        return {
          collection(sub: string) {
            return {
              doc(id: string) {
                const fullPath = `analytics/feature_retention/${sub}/${id}`;
                return {
                  path: fullPath,
                  async get() {
                    const data = store.data.get(fullPath);
                    return {
                      exists: data != null,
                      data: () => data,
                    };
                  },
                  async set(d: Record<string, unknown>) {
                    store.data.set(fullPath, d);
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

  return {
    collection(name: string) {
      if (name === "users") {
        // The SUT calls db.collection("users").doc(uid) for the per-user
        // subcollection probe — overload accordingly.
        const q = makeUsersQuery(0, null);
        return {
          ...q,
          doc(uid: string) {
            if (!userIds.has(uid)) {
              // Tolerated — return an empty-source doc.
            }
            return makeUserDoc(uid);
          },
        };
      }
      if (name === "cook_snaps") {
        return makeActivityQuery({
          source: "cook_snaps",
          userId: "",
          timeField: "",
          startMs: null,
          endMs: null,
          failFlag: "cook_snaps",
        });
      }
      if (name === "shared_recipes") {
        return makeActivityQuery({
          source: "shared_recipes",
          userId: "",
          timeField: "",
          startMs: null,
          endMs: null,
          failFlag: "shared_recipes",
        });
      }
      // BUT-1761: the collaborative leg of `shopped`. Top-level collection
      // whose user filter is `lastActivityByUserId == uid`, which lands on the
      // same `op === "=="` branch as `cook_snaps`/`shared_recipes`, so the
      // generic activity query models it unchanged. `failFlag` is
      // `shoppedShared`, NOT `shopped` — the two legs must be failable
      // independently or a degradation test cannot tell them apart.
      if (name === "unified_shared_shopping_lists") {
        return makeActivityQuery({
          source: "unified_shared_shopping_lists",
          userId: "",
          timeField: "",
          startMs: null,
          endMs: null,
          failFlag: "shoppedShared",
        });
      }
      if (name === "analytics") {
        return makeAnalyticsRoot();
      }
      throw new Error(`unexpected collection: ${name}`);
    },
    batch() {
      const ops: Array<{ ref: { path: string }; data: Record<string, unknown> }> =
        [];
      return {
        set(ref: { path: string }, data: Record<string, unknown>) {
          ops.push({ ref, data });
        },
        async commit() {
          for (const op of ops) {
            store.data.set(op.ref.path, op.data);
            store.writeCount++;
          }
          store.commitCount++;
          ops.length = 0;
        },
      };
    },
  };
}

// ─── Test cases ──────────────────────────────────────────────────────────

async function happyPath(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30, 0, 0, 0); // 2026-04-30 UTC start
  const inDay = todayStartMs + 6 * 60 * 60 * 1000; // 06:00 UTC

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uA", lastActiveDaysAgo: 0 },
    { id: "uB", lastActiveDaysAgo: 1 },
    { id: "uC", lastActiveDaysAgo: 5 },
  ];
  // uA: cooked + imported. uB: shared. uC: nothing.
  const activity: ActivityRecord[] = [
    { source: "cook_snaps", userId: "uA", ts: inDay },
    { source: "users/uA/recipes", userId: "uA", ts: inDay },
    { source: "shared_recipes", userId: "uB", ts: inDay },
  ];
  const db = makeFakeDb({ users, activity, flagDocs: [], store, now });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);

  const uAFlags = store.data.get(
    `analytics/feature_retention/users/uA_${today}`,
  ) as Record<string, unknown> | undefined;
  const uBFlags = store.data.get(
    `analytics/feature_retention/users/uB_${today}`,
  ) as Record<string, unknown> | undefined;
  const uCFlags = store.data.get(
    `analytics/feature_retention/users/uC_${today}`,
  ) as Record<string, unknown> | undefined;
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;

  const flagsOk =
    uAFlags?.cooked === true &&
    uAFlags?.imported === true &&
    uAFlags?.shared === false &&
    uBFlags?.shared === true &&
    uBFlags?.cooked === false &&
    uCFlags?.cooked === false &&
    uCFlags?.shopped === false;

  const dau = aggregate?.dau as Record<string, number> | undefined;
  const wau7 = aggregate?.wau7d as Record<string, number> | undefined;
  const wau28 = aggregate?.wau28d as Record<string, number> | undefined;

  const aggregateOk =
    aggregate?.date === today &&
    dau?.cooked === 1 &&
    dau?.imported === 1 &&
    dau?.shared === 1 &&
    dau?.mealPlanned === 0 &&
    dau?.shopped === 0 &&
    // Today contributes to WAU windows.
    wau7?.cooked === 1 &&
    wau7?.shared === 1 &&
    wau28?.cooked === 1 &&
    wau28?.imported === 1;

  record(
    "happy path: 3 users mixed flags → per-user docs + aggregate correct",
    flagsOk && aggregateOk,
    `flagsOk=${flagsOk} aggOk=${aggregateOk} dau=${JSON.stringify(dau)}`,
  );
}

async function idempotentRerun(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30, 0, 0, 0);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [{ id: "uX", lastActiveDaysAgo: 0 }];
  const activity: ActivityRecord[] = [
    { source: "cook_snaps", userId: "uX", ts: inDay },
  ];
  const db = makeFakeDb({ users, activity, flagDocs: [], store, now });

  await runComputeFeatureRetention({ db: db as never, now });
  const sizeAfterFirst = store.data.size;
  const writesAfterFirst = store.writeCount;

  await runComputeFeatureRetention({ db: db as never, now });
  const sizeAfterSecond = store.data.size;
  const writesAfterSecond = store.writeCount;

  // Same paths overwritten: per-user flag doc + daily aggregate = 2 paths.
  const ok =
    sizeAfterFirst === 2 &&
    sizeAfterSecond === 2 &&
    writesAfterSecond === writesAfterFirst * 2;
  record(
    "idempotent re-run: same paths, write count doubles",
    ok,
    `sizes=${sizeAfterFirst}/${sizeAfterSecond} writes=${writesAfterFirst}/${writesAfterSecond}`,
  );
}

async function wau7dRollup(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30, 0, 0, 0);

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [{ id: "uHistorical", lastActiveDaysAgo: 1 }];
  // No activity TODAY — but there's a flag doc from 5 days ago (cooked=true).
  const fiveDaysAgoMs = todayStartMs - 5 * MS_PER_DAY;
  const fiveDaysAgo = formatUtcDate(fiveDaysAgoMs);
  // 10 days ago (outside 7d window, inside 28d).
  const tenDaysAgoMs = todayStartMs - 10 * MS_PER_DAY;
  const tenDaysAgo = formatUtcDate(tenDaysAgoMs);

  const flagDocs: PreExistingFlagDoc[] = [
    { userId: "uHistorical", date: fiveDaysAgo, cooked: true },
    { userId: "uHistorical", date: tenDaysAgo, mealPlanned: true },
  ];
  const db = makeFakeDb({ users, activity: [], flagDocs, store, now });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;
  const dau = aggregate?.dau as Record<string, number> | undefined;
  const wau7 = aggregate?.wau7d as Record<string, number> | undefined;
  const wau28 = aggregate?.wau28d as Record<string, number> | undefined;

  const ok =
    // Today: no activity.
    dau?.cooked === 0 &&
    dau?.mealPlanned === 0 &&
    // 5d ago cooked → in 7d window.
    wau7?.cooked === 1 &&
    // 10d ago mealPlanned → NOT in 7d window.
    wau7?.mealPlanned === 0 &&
    // Both inside 28d window.
    wau28?.cooked === 1 &&
    wau28?.mealPlanned === 1;
  record(
    "wau7d rollup: historical flag inside 7d counted, outside not",
    ok,
    `dau=${JSON.stringify(dau)} wau7=${JSON.stringify(wau7)} wau28=${JSON.stringify(wau28)}`,
  );
}

async function inactiveUserSkipped(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uActive", lastActiveDaysAgo: 1 },
    { id: "uLapsed", lastActiveDaysAgo: 40 }, // outside 28d window
  ];
  const db = makeFakeDb({ users, activity: [], flagDocs: [], store, now });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(Date.UTC(2026, 3, 30));
  const lapsedFlag = store.data.get(
    `analytics/feature_retention/users/uLapsed_${today}`,
  );
  const activeFlag = store.data.get(
    `analytics/feature_retention/users/uActive_${today}`,
  );
  const ok = lapsedFlag == null && activeFlag != null;
  record(
    "inactive user (>28d) is not scanned",
    ok,
    `lapsed=${lapsedFlag != null} active=${activeFlag != null}`,
  );
}

async function probeFailureGracefulDegrade(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [{ id: "uProbe", lastActiveDaysAgo: 0 }];
  const activity: ActivityRecord[] = [
    { source: "cook_snaps", userId: "uProbe", ts: inDay },
    { source: "shared_recipes", userId: "uProbe", ts: inDay },
  ];
  // Inject failure into the cook_snaps probe.
  const db = makeFakeDb({
    users,
    activity,
    flagDocs: [],
    store,
    now,
    opts: { failProbeFor: { userId: "uProbe", flag: "cook_snaps" } },
  });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);
  const flagDoc = store.data.get(
    `analytics/feature_retention/users/uProbe_${today}`,
  ) as Record<string, unknown> | undefined;
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;
  const dau = aggregate?.dau as Record<string, number> | undefined;

  // cooked falls back to false; shared still true; the run completes.
  const ok =
    flagDoc?.cooked === false &&
    flagDoc?.shared === true &&
    dau?.cooked === 0 &&
    dau?.shared === 1;
  record(
    "probe failure: failing flag falls back to false, run completes",
    ok,
    `flag=${JSON.stringify(flagDoc)} dau=${JSON.stringify(dau)}`,
  );
}

/**
 * BUT-1724: `shopped` must come from the LIVE personal-list path
 * `users/{uid}/unified_shopping_lists`, never from the retired
 * `users/{uid}/shopping_lists` name that nothing has written since
 * BUT-1697. Two users, one seeded on each path — the live one flips
 * `shopped`, the retired one must not.
 */
async function shoppedProbeUsesLivePath(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uLive", lastActiveDaysAgo: 0 },
    { id: "uRetired", lastActiveDaysAgo: 0 },
  ];
  const activity: ActivityRecord[] = [
    { source: "users/uLive/unified_shopping_lists", userId: "uLive", ts: inDay },
    { source: "users/uRetired/shopping_lists", userId: "uRetired", ts: inDay },
  ];
  const db = makeFakeDb({ users, activity, flagDocs: [], store, now });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);
  const liveFlags = store.data.get(
    `analytics/feature_retention/users/uLive_${today}`,
  ) as Record<string, unknown> | undefined;
  const retiredFlags = store.data.get(
    `analytics/feature_retention/users/uRetired_${today}`,
  ) as Record<string, unknown> | undefined;
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;
  const dau = aggregate?.dau as Record<string, number> | undefined;

  const ok =
    liveFlags?.shopped === true &&
    retiredFlags?.shopped === false &&
    dau?.shopped === 1;
  record(
    "shopped probe reads unified_shopping_lists, not the retired shopping_lists",
    ok,
    `live=${JSON.stringify(liveFlags)} retired=${JSON.stringify(retiredFlags)} dau=${JSON.stringify(dau)}`,
  );
}

/**
 * BUT-1724 risk half: the `shopped` probe is the only one that started reading a
 * subcollection field it never queried before (`updatedAt` on
 * `users/{uid}/unified_shopping_lists`), so a `FAILED_PRECONDITION` from a
 * missing index is its most likely production failure. When that probe throws,
 * `shopped` must degrade to false for that user and the rest of the run — the
 * other four flags, the flag doc and the daily aggregate — must still land. The
 * previous degradation case only exercised a top-level collection.
 */
async function shoppedProbeFailureDegrades(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [{ id: "uIdx", lastActiveDaysAgo: 0 }];
  // Seeded so the probe WOULD have answered true — the false below can only
  // come from the injected throw, not from an empty fixture.
  const activity: ActivityRecord[] = [
    { source: "users/uIdx/unified_shopping_lists", userId: "uIdx", ts: inDay },
    { source: "users/uIdx/menus", userId: "uIdx", ts: inDay },
  ];
  const db = makeFakeDb({
    users,
    activity,
    flagDocs: [],
    store,
    now,
    opts: { failProbeFor: { userId: "uIdx", flag: "shopped" } },
  });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);
  const flagDoc = store.data.get(
    `analytics/feature_retention/users/uIdx_${today}`,
  ) as Record<string, unknown> | undefined;
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;
  const dau = aggregate?.dau as Record<string, number> | undefined;

  const ok =
    flagDoc?.shopped === false &&
    flagDoc?.mealPlanned === true &&
    dau?.shopped === 0 &&
    dau?.mealPlanned === 1;
  record(
    "shopped probe failure (missing index) degrades to false, run completes",
    ok,
    `flag=${JSON.stringify(flagDoc)} dau=${JSON.stringify(dau)}`,
  );
}

/**
 * BUT-1761: a collaborative list lives in the TOP-LEVEL
 * `unified_shared_shopping_lists`, never under `users/{uid}`, so before this
 * fix a household that shops only on a shared list scored `shopped: false`
 * every single day. Three users pin the whole contract of the new leg:
 *
 *   uShared     — only shared-list activity today   → shopped TRUE (the fix)
 *   uPersonal   — only personal-list activity today → shopped TRUE (unbroken)
 *   uBystander  — a shared list carrying SOMEONE ELSE'S `lastActivityByUserId`
 *                 today, plus their OWN activity YESTERDAY → shopped FALSE
 *
 * The bystander row is the non-vacuity guard: it proves the leg filters on
 * both the user field and the day range rather than answering true whenever
 * the collection is non-empty.
 */
async function sharedListShoppingCountsAsShopped(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;
  const yesterday = todayStartMs - 6 * 60 * 60 * 1000;

  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uShared", lastActiveDaysAgo: 0 },
    { id: "uPersonal", lastActiveDaysAgo: 0 },
    { id: "uBystander", lastActiveDaysAgo: 0 },
  ];
  const activity: ActivityRecord[] = [
    { source: "unified_shared_shopping_lists", userId: "uShared", ts: inDay },
    {
      source: "users/uPersonal/unified_shopping_lists",
      userId: "uPersonal",
      ts: inDay,
    },
    // Same shared collection, stamped by a member who is not uBystander.
    {
      source: "unified_shared_shopping_lists",
      userId: "uHouseholdMate",
      ts: inDay,
    },
    // uBystander's own shared activity, but outside the run-day window.
    {
      source: "unified_shared_shopping_lists",
      userId: "uBystander",
      ts: yesterday,
    },
  ];
  const db = makeFakeDb({ users, activity, flagDocs: [], store, now });

  await runComputeFeatureRetention({ db: db as never, now });

  const today = formatUtcDate(todayStartMs);
  const flags = (uid: string) =>
    store.data.get(`analytics/feature_retention/users/${uid}_${today}`) as
      | Record<string, unknown>
      | undefined;
  const aggregate = store.data.get(
    `analytics/feature_retention/daily/${today}`,
  ) as Record<string, unknown> | undefined;
  const dau = aggregate?.dau as Record<string, number> | undefined;

  const ok =
    flags("uShared")?.shopped === true &&
    flags("uPersonal")?.shopped === true &&
    flags("uBystander")?.shopped === false &&
    dau?.shopped === 2;
  record(
    "shared-list activity sets shopped; another member's stamp and a prior day do not",
    ok,
    `shared=${JSON.stringify(flags("uShared"))} personal=${JSON.stringify(
      flags("uPersonal"),
    )} bystander=${JSON.stringify(flags("uBystander"))} dau=${JSON.stringify(dau)}`,
  );
}

/**
 * BUT-1761: `shopped` is now an OR over two probes, and the shared one is the
 * probe most likely to fail in production (it is the only query in this file
 * needing a DECLARED composite index, so a missing//still-building index
 * throws FAILED_PRECONDITION). Two properties have to hold:
 *
 *   A. a throwing shared probe degrades that leg to false and the run still
 *      writes the flag doc and the aggregate;
 *   B. it does NOT drag down the personal leg — a user whose personal list DID
 *      flip still scores `shopped: true` while the shared probe is throwing.
 *
 * Without B, an unbuilt index would silently re-zero the whole flag, which is
 * exactly the failure mode BUT-1724 and BUT-1761 each shipped to remove.
 */
async function sharedShoppedProbeFailureDegrades(): Promise<void> {
  const now = new Date("2026-04-30T08:00:00Z");
  const todayStartMs = Date.UTC(2026, 3, 30);
  const inDay = todayStartMs + 6 * 60 * 60 * 1000;
  const today = formatUtcDate(todayStartMs);

  // A — shared-only user, shared probe throws.
  const storeA: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const dbA = makeFakeDb({
    users: [{ id: "uIdxShared", lastActiveDaysAgo: 0 }],
    // Seeded so the probe WOULD have answered true — the false below can only
    // come from the injected throw, not from an empty fixture.
    activity: [
      {
        source: "unified_shared_shopping_lists",
        userId: "uIdxShared",
        ts: inDay,
      },
      { source: "users/uIdxShared/menus", userId: "uIdxShared", ts: inDay },
    ],
    flagDocs: [],
    store: storeA,
    now,
    opts: { failProbeFor: { userId: "uIdxShared", flag: "shoppedShared" } },
  });
  await runComputeFeatureRetention({ db: dbA as never, now });

  const flagA = storeA.data.get(
    `analytics/feature_retention/users/uIdxShared_${today}`,
  ) as Record<string, unknown> | undefined;
  const dauA = (
    storeA.data.get(`analytics/feature_retention/daily/${today}`) as
      | Record<string, unknown>
      | undefined
  )?.dau as Record<string, number> | undefined;

  // B — same failing shared probe, but this user also has a personal list.
  const storeB: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const dbB = makeFakeDb({
    users: [{ id: "uIdxBoth", lastActiveDaysAgo: 0 }],
    activity: [
      {
        source: "unified_shared_shopping_lists",
        userId: "uIdxBoth",
        ts: inDay,
      },
      {
        source: "users/uIdxBoth/unified_shopping_lists",
        userId: "uIdxBoth",
        ts: inDay,
      },
    ],
    flagDocs: [],
    store: storeB,
    now,
    opts: { failProbeFor: { userId: "uIdxBoth", flag: "shoppedShared" } },
  });
  await runComputeFeatureRetention({ db: dbB as never, now });

  const flagB = storeB.data.get(
    `analytics/feature_retention/users/uIdxBoth_${today}`,
  ) as Record<string, unknown> | undefined;

  const ok =
    flagA?.shopped === false &&
    flagA?.mealPlanned === true &&
    dauA?.shopped === 0 &&
    dauA?.mealPlanned === 1 &&
    flagB?.shopped === true;
  record(
    "shared probe failure degrades its own leg only; personal leg still flips shopped",
    ok,
    `A=${JSON.stringify(flagA)} dauA=${JSON.stringify(dauA)} B=${JSON.stringify(flagB)}`,
  );
}

interface IndexField {
  fieldPath: string;
  order?: string;
  arrayConfig?: string;
}

interface CompositeIndex {
  collectionGroup: string;
  queryScope: string;
  fields: IndexField[];
}

/**
 * BUT-1761: the shared leg is `lastActivityByUserId == uid` AND an `updatedAt`
 * range — equality plus range on two different fields, which Firestore refuses
 * to serve without a declared composite. The fake db in this file happily
 * answers the query, so only an assertion against the real
 * `firestore.indexes.json` can catch a probe that would throw
 * FAILED_PRECONDITION on every run in production and be swallowed by
 * `safeProbe` back into a structural zero.
 */
function sharedShoppingListCompositeDeclared(): void {
  const parsed = JSON.parse(fs.readFileSync(INDEXES_PATH, "utf8"));
  if (!Array.isArray(parsed.indexes)) {
    throw new Error("firestore.indexes.json has no `indexes` array");
  }
  const indexes = parsed.indexes as CompositeIndex[];

  const match = indexes.find(
    (idx) =>
      idx.collectionGroup === "unified_shared_shopping_lists" &&
      idx.fields.length === 2 &&
      idx.fields[0].fieldPath === "lastActivityByUserId" &&
      idx.fields[0].order === "ASCENDING" &&
      idx.fields[1].fieldPath === "updatedAt" &&
      idx.fields[1].order === "ASCENDING",
  );

  record(
    "firestore.indexes.json declares unified_shared_shopping_lists (lastActivityByUserId ASC, updatedAt ASC)",
    match !== undefined,
    match === undefined
      ? "no such composite found — the shared `shopped` leg would throw FAILED_PRECONDITION in production"
      : `queryScope=${match.queryScope}`,
  );

  // The probe is a plain collection query, not a collectionGroup query, so a
  // COLLECTION_GROUP-scoped index would not serve it.
  record(
    "that composite is COLLECTION-scoped, matching the probe's plain collection query",
    match?.queryScope === "COLLECTION",
    `queryScope=${match?.queryScope}`,
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-599: Feature-level retention tests\n");
  console.log("==============================================\n");
  await happyPath();
  await idempotentRerun();
  await wau7dRollup();
  await inactiveUserSkipped();
  await probeFailureGracefulDegrade();
  await shoppedProbeUsesLivePath();
  await shoppedProbeFailureDegrades();
  await sharedListShoppingCountsAsShopped();
  await sharedShoppedProbeFailureDegrades();
  sharedShoppingListCompositeDeclared();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : ""),
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
