/**
 * BUT-2138: one ops-log alert when an account is stopped by the rate limiter
 * 20 times on the same UTC day.
 *
 * What this proves: the 20th denial of a day writes exactly one alert row and
 * stamps `alertedDayKey` on the counter; the 19th and 21st write none; a new
 * day starts from 1; an account already past the threshold costs no write, and
 * on the same instance no read either; the alert row carries no identifier but
 * does carry `executedAt` (what the ops-log tab orders by); a failing
 * transaction never throws; and `logRateLimitViolation` skips a denial caused
 * by our own failed check (`unavailable`).
 *
 * Run with: npx ts-node src/__tests__/violation-alert.test.ts
 */

import * as admin from "firebase-admin";
import {
  __resetViolationAlertCacheForTest,
  ABUSE_ALERT_EVENT_TYPE,
  ABUSE_ALERT_THRESHOLD,
  recordViolation,
} from "../middleware/violation_alert";
import { __setFirestoreForTest, enforceRateLimit } from "../middleware/rate_limiter";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

type Doc = Record<string, unknown>;

interface FakeDb {
  db: admin.firestore.Firestore;
  docs: Map<string, Doc>;
  created: { path: string; data: Doc }[];
  reads: () => number;
  transactions: () => number;
  attempts: () => (number | undefined)[];
}

function fakeDb(opts: { failTransactions?: boolean } = {}): FakeDb {
  const docs = new Map<string, Doc>();
  const created: { path: string; data: Doc }[] = [];
  let reads = 0;
  let transactions = 0;
  const attempts: (number | undefined)[] = [];
  let autoId = 0;
  const ref = (collection: string, id: string) => ({ path: `${collection}/${id}` });
  const db = {
    collection: (name: string) => ({
      doc: (id?: string) => ref(name, id ?? `auto${++autoId}`),
      add: async (data: Doc) => {
        created.push({ path: `${name}/auto${++autoId}`, data });
        return {};
      },
    }),
    runTransaction: async <T>(
      fn: (tx: unknown) => Promise<T>,
      options?: { maxAttempts?: number }
    ): Promise<T> => {
      transactions++;
      attempts.push(options?.maxAttempts);
      if (opts.failTransactions) throw new Error("ABORTED: contention");
      const tx = {
        get: async (r: { path: string }) => {
          reads++;
          const data = docs.get(r.path);
          return { exists: data !== undefined, data: () => data };
        },
        set: (r: { path: string }, data: Doc, o?: { merge?: boolean }) => {
          docs.set(r.path, o?.merge ? { ...(docs.get(r.path) ?? {}), ...data } : data);
        },
        update: (r: { path: string }, data: Doc) => {
          docs.set(r.path, { ...(docs.get(r.path) ?? {}), ...data });
        },
        create: (r: { path: string }, data: Doc) => {
          created.push({ path: r.path, data });
        },
      };
      return fn(tx);
    },
  } as unknown as admin.firestore.Firestore;
  return {
    db,
    docs,
    created,
    reads: () => reads,
    transactions: () => transactions,
    attempts: () => attempts,
  };
}

const DAY = "2026-9-18";
const NEXT_DAY = "2026-9-19";
const COUNTER = "system_rate_limits/user-a_violationCounter";

function alerts(fake: FakeDb) {
  return fake.created.filter((c) => c.data.type === ABUSE_ALERT_EVENT_TYPE);
}

async function deny(fake: FakeDb, times: number, day = DAY, uid = "user-a") {
  for (let i = 0; i < times; i++) {
    await recordViolation(fake.db, uid, "structureRecipe", day);
  }
}

const cases: UnitCase[] = [
  {
    name: "19 denials: counted, no alert",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, ABUSE_ALERT_THRESHOLD - 1);
      assertEqual(fake.docs.get(COUNTER)?.count as number, 19, "count");
      assertEqual(alerts(fake).length, 0, "no alert yet");
      assertEqual(fake.docs.get(COUNTER)?.alertedDayKey, undefined, "not stamped");
    },
  },
  {
    name: "the 20th denial writes exactly one alert, the 21st none",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, ABUSE_ALERT_THRESHOLD);
      assertEqual(alerts(fake).length, 1, "one alert at 20");
      assertEqual(fake.docs.get(COUNTER)?.alertedDayKey as string, DAY, "stamped");
      await deny(fake, 5);
      assertEqual(alerts(fake).length, 1, "still one alert after 25");
      assertEqual(fake.docs.get(COUNTER)?.count as number, 20, "count stops at 20");
    },
  },
  {
    name: "the alert row carries no identifier and shows in the ops tab",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, ABUSE_ALERT_THRESHOLD);
      const [alert] = alerts(fake);
      assertEqual(alert.path.startsWith("system_events/"), true, "in system_events");
      assertEqual(alert.data.severity as string, "critical", "severity");
      assertEqual(alert.data.threshold as number, 20, "threshold");
      assertEqual(alert.data.dayKey as string, DAY, "day");
      assertEqual(alert.data.operationType as string, "structureRecipe", "operation");
      assertEqual("executedAt" in alert.data, true, "executedAt for the ops tab");
      const keys = Object.keys(alert.data).sort().join(",");
      assertEqual(
        keys,
        "dayKey,executedAt,operationType,severity,threshold,timestamp,type",
        "exact key set: no uid, no hash"
      );
    },
  },
  {
    name: "past the threshold: no write, and on this instance no read either",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, ABUSE_ALERT_THRESHOLD);
      const readsAtThreshold = fake.reads();
      await deny(fake, 10);
      assertEqual(fake.reads(), readsAtThreshold, "memo skips the read");

      // A fresh instance (empty memo) reads once, writes nothing, then remembers.
      __resetViolationAlertCacheForTest();
      const before = JSON.stringify(fake.docs.get(COUNTER));
      await deny(fake, 3);
      assertEqual(fake.reads(), readsAtThreshold + 1, "one read, then memo");
      assertEqual(JSON.stringify(fake.docs.get(COUNTER)), before, "no write past 20");
    },
  },
  {
    name: "a new day starts from 1 and can alert again",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, ABUSE_ALERT_THRESHOLD);
      await deny(fake, 1, NEXT_DAY);
      assertEqual(fake.docs.get(COUNTER)?.count as number, 1, "reset");
      assertEqual(fake.docs.get(COUNTER)?.dayKey as string, NEXT_DAY, "new day");
      await deny(fake, ABUSE_ALERT_THRESHOLD - 1, NEXT_DAY);
      assertEqual(alerts(fake).length, 2, "second day's alert");
    },
  },
  {
    name: "accounts are counted separately",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, 10, DAY, "user-a");
      await deny(fake, 10, DAY, "user-b");
      assertEqual(alerts(fake).length, 0, "10 + 10 is not 20 for one account");
    },
  },
  {
    name: "the counter carries updatedAt (what the 90-day prune keys on)",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb();
      await deny(fake, 1);
      const updatedAt = fake.docs.get(COUNTER)?.updatedAt;
      assertEqual(updatedAt instanceof admin.firestore.Timestamp, true, "Timestamp");
    },
  },
  {
    name: "one attempt only, and a failing transaction never throws",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      const fake = fakeDb({ failTransactions: true });
      await deny(fake, 3);
      assertEqual(fake.transactions(), 3, "attempted each time, no memo on failure");
      assertEqual(fake.attempts().every((a) => a === 1), true, "maxAttempts: 1");
    },
  },
  {
    name: "enforceRateLimit: a real denial counts, our own failed check does not",
    fn: async () => {
      __resetViolationAlertCacheForTest();
      // An empty bucket at a fixed refill time denies without refilling.
      const fake = fakeDb();
      fake.docs.set("system_rate_limits/user-a_structureRecipe", {
        tokens: 0,
        lastRefill: admin.firestore.Timestamp.now(),
        operationType: "structureRecipe",
        updatedAt: admin.firestore.Timestamp.now(),
      });
      __setFirestoreForTest(fake.db);
      try {
        await enforceRateLimit("user-a", "structureRecipe").catch(() => undefined);
        assertEqual(fake.docs.get(COUNTER)?.count as number, 1, "real denial counted");
      } finally {
        __setFirestoreForTest(null);
      }

      __resetViolationAlertCacheForTest();
      const failing = fakeDb({ failTransactions: true });
      __setFirestoreForTest(failing.db);
      try {
        await enforceRateLimit("user-a", "structureRecipe").catch(() => undefined);
        // Only the bucket check's own transaction ran; no counter transaction.
        assertEqual(failing.transactions(), 1, "unavailable denial not counted");
      } finally {
        __setFirestoreForTest(null);
      }
    },
  },
];

runTests("BUT-2138: alert on repeated rate-limit denials", cases);
