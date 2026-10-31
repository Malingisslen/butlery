/**
 * Account deletion's step for alias candidates (`account/cascade/learned-aliases.ts`):
 * the uid leaves every candidate, an undecided candidate left without voters
 * is deleted, and a decided one is kept.
 *
 * Run: npx ts-node src/__tests__/learned-aliases-cleanup.test.ts
 */

import { FakeFirestore } from "./_fake-firestore";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { cleanUserFromLearnedAliases } from "../account/cascade/learned-aliases";
import type * as admin from "firebase-admin";

const UID = "erased-uid";
const OTHER = "other-uid";
const COL = "analytics/ingredients/learned_aliases";

/**
 * [store.db] whose transactions fail on reading [failing]: the shape a
 * contended or unavailable document takes. Counts every transaction run.
 */
function failingOn(store: FakeFirestore, failing: (path: string) => boolean): {
  db: admin.firestore.Firestore;
  runs: () => number;
} {
  const inner = store.db as unknown as {
    runTransaction: (fn: (tx: unknown) => Promise<unknown>) => Promise<unknown>;
  };
  let runs = 0;
  const db = new Proxy(store.db, {
    get(target, prop, receiver) {
      if (prop !== "runTransaction") return Reflect.get(target, prop, receiver);
      return (fn: (tx: unknown) => Promise<unknown>) => {
        runs++;
        return inner.runTransaction((tx) => {
          const t = tx as { get: (ref: { path: string }) => Promise<unknown> };
          const wrapped = {
            ...t,
            get: (ref: { path: string }) =>
              failing(ref.path)
                ? Promise.reject(Object.assign(new Error("unavailable"), { code: 14 }))
                : t.get(ref),
          };
          return fn(wrapped);
        });
      };
    },
  });
  return { db, runs: () => runs };
}

function candidate(status: string, userIds: string[]): Record<string, unknown> {
  return { originalName: "tomatoe", correctedName: "tomat", status, userIds, count: userIds.length };
}

const cases: UnitCase[] = [
  {
    name: "another voter left: the uid goes, the candidate stays",
    fn: async () => {
      const store = new FakeFirestore();
      store.seed(`${COL}/a`, candidate("pending", [UID, OTHER]));
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      assertEqual(JSON.stringify(store.read(`${COL}/a`)?.userIds), JSON.stringify([OTHER]), "voters");
      assertEqual(store.read(`${COL}/a`)?.count, 1, "count");
    },
  },
  {
    name: "last voter of a pending or held candidate: the candidate is deleted",
    fn: async () => {
      const store = new FakeFirestore();
      store.seed(`${COL}/p`, candidate("pending", [UID]));
      store.seed(`${COL}/h`, candidate("held_for_review", [UID]));
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      assertEqual(store.has(`${COL}/p`), false, "pending deleted");
      assertEqual(store.has(`${COL}/h`), false, "held deleted");
    },
  },
  {
    name: "last voter of a decided candidate: kept with no voters",
    fn: async () => {
      const store = new FakeFirestore();
      for (const status of ["approved", "rejected", "revoked"]) {
        store.seed(`${COL}/${status}`, candidate(status, [UID]));
      }
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      for (const status of ["approved", "rejected", "revoked"]) {
        assertEqual(store.has(`${COL}/${status}`), true, `${status} kept`);
        assertEqual(JSON.stringify(store.read(`${COL}/${status}`)?.userIds), "[]", `${status} voters`);
      }
    },
  },
  {
    name: "another person's candidate is untouched",
    fn: async () => {
      const store = new FakeFirestore();
      store.seed(`${COL}/theirs`, candidate("pending", [OTHER]));
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      assertEqual(JSON.stringify(store.read(`${COL}/theirs`)?.userIds), JSON.stringify([OTHER]), "voters");
    },
  },
  {
    name: "a vote landing before the commit keeps the candidate",
    fn: async () => {
      const store = new FakeFirestore({
        retryTransactions: 2,
        onTransactionAttempt: (_attempt, s) =>
          s.seed(`${COL}/a`, candidate("pending", [UID, OTHER])),
      });
      store.seed(`${COL}/a`, candidate("pending", [UID]));
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      assertEqual(store.has(`${COL}/a`), true, "kept");
      assertEqual(JSON.stringify(store.read(`${COL}/a`)?.userIds), JSON.stringify([OTHER]), "voters");
    },
  },
  {
    name: "more candidates than one page are all cleaned",
    fn: async () => {
      const store = new FakeFirestore();
      for (let i = 0; i < 450; i++) store.seed(`${COL}/x${i}`, candidate("pending", [UID]));
      assertEqual(await cleanUserFromLearnedAliases(store.db, UID), true, "ok");
      let left = 0;
      for (let i = 0; i < 450; i++) if (store.has(`${COL}/x${i}`)) left++;
      assertEqual(left, 0, "left");
    },
  },
  {
    name: "a document that cannot be cleaned: the others are, and the step reports false",
    fn: async () => {
      const store = new FakeFirestore();
      store.seed(`${COL}/bad`, candidate("pending", [UID]));
      for (let i = 0; i < 3; i++) store.seed(`${COL}/ok${i}`, candidate("pending", [UID]));
      const { db } = failingOn(store, (p) => p.endsWith("/bad"));
      assertEqual(await cleanUserFromLearnedAliases(db, UID), false, "ok");
      assertEqual(store.has(`${COL}/bad`), true, "bad left");
      for (let i = 0; i < 3; i++) assertEqual(store.has(`${COL}/ok${i}`), false, `ok${i} cleaned`);
    },
  },
  {
    name: "a full page where every document fails stops when the same page comes back",
    fn: async () => {
      const store = new FakeFirestore();
      for (let i = 0; i < 250; i++) store.seed(`${COL}/x${i}`, candidate("pending", [UID]));
      const { db, runs } = failingOn(store, () => true);
      assertEqual(await cleanUserFromLearnedAliases(db, UID), false, "ok");
      assertEqual(runs(), 200, "transactions run: one page, then the same page read again stops it");
    },
  },
];

runTests("learned-aliases-cleanup", cases);
