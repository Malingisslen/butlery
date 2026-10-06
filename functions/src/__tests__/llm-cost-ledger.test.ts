/**
 * BUT-2243: the server-side AI cost ledger (`middleware/llm_cost_ledger.ts`).
 *
 * The ledger is the only writer of `users/{uid}/rate_limits/llm_cost`; these
 * cases pin what it adds, when it resets, and when it refuses. That the OCR
 * callable's `estimatedCost` already includes its in-process retry is pinned
 * separately by `ocr-retry.test.ts`; here the wrapper is shown to record
 * whatever total the handler returns.
 *
 * Run with: npx ts-node src/__tests__/llm-cost-ledger.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import {
  LLM_COST_CEILINGS,
  ceilingsFor,
  utcDayKey,
  utcMonthKey,
  withCostLedger,
  LedgerDeps,
} from "../middleware/llm_cost_ledger";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

interface FakeDb {
  deps: (now: Date) => LedgerDeps;
  stored: () => Record<string, unknown> | undefined;
  paths: string[];
  reads: () => number;
  transactions: () => number;
}

function fakeDb(
  initial?: Record<string, unknown>,
  opts: { failGet?: boolean; failTransaction?: boolean } = {}
): FakeDb {
  let stored = initial ? { ...initial } : undefined;
  let reads = 0;
  let transactions = 0;
  const paths: string[] = [];
  const ref = (segments: string[]): unknown => ({
    collection: (c: string) => ({ doc: (d: string) => ref([...segments, c, d]) }),
    get: async () => {
      reads++;
      paths.push(segments.join("/"));
      if (opts.failGet) throw new Error("boom");
      return { exists: stored !== undefined, data: () => stored };
    },
    path: segments.join("/"),
  });
  const db = {
    collection: (c: string) => ({ doc: (d: string) => ref([c, d]) }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      transactions++;
      if (opts.failTransaction) throw new Error("contention");
      const tx = {
        get: async (r: { path: string }) => {
          reads++;
          paths.push(r.path);
          return { exists: stored !== undefined, data: () => stored };
        },
        set: (r: { path: string }, data: Record<string, unknown>) => {
          paths.push(r.path);
          stored = { ...data };
        },
      };
      return fn(tx);
    },
  } as unknown as admin.firestore.Firestore;
  return {
    deps: (now) => ({ db: () => db, now: () => now }),
    stored: () => stored,
    paths,
    reads: () => reads,
    transactions: () => transactions,
  };
}

function authed(uid: string): CallableRequest<unknown> {
  return { auth: { uid } } as unknown as CallableRequest<unknown>;
}

function approx(actual: unknown, expected: number, msg: string): void {
  if (typeof actual !== "number" || Math.abs(actual - expected) > 1e-12) {
    throw new Error(`${msg}: expected ${expected}, got ${String(actual)}`);
  }
}

async function expectHttpsError(
  run: () => Promise<unknown>,
  code: string
): Promise<HttpsError> {
  try {
    await run();
  } catch (e) {
    if (e instanceof HttpsError && e.code === code) return e;
    throw new Error(`expected HttpsError(${code}), got ${String(e)}`);
  }
  throw new Error(`expected HttpsError(${code}), nothing was thrown`);
}

const JAN_31_2359 = new Date("2026-01-31T23:59:00Z");
const FEB_01_0001 = new Date("2026-02-01T00:01:00Z");
const FEB_02_1200 = new Date("2026-02-02T12:00:00Z");

const cases: UnitCase[] = [
  {
    name: "day and month keys are ISO UTC strings (shared fixture with the app's ServerLlmCost)",
    fn: () => {
      assertEqual(utcDayKey(JAN_31_2359), "2026-01-31", "day key");
      assertEqual(utcMonthKey(JAN_31_2359), "2026-01", "month key");
      assertEqual(utcDayKey(FEB_01_0001), "2026-02-01", "day key after midnight");
      assertEqual(utcMonthKey(FEB_01_0001), "2026-02", "month key after midnight");
    },
  },
  {
    name: "ceilings are $0.50 a day and $10 a month, looked up through ceilingsFor",
    fn: () => {
      assertEqual(LLM_COST_CEILINGS.perDayUsd, 0.5, "per day");
      assertEqual(LLM_COST_CEILINGS.perMonthUsd, 10, "per month");
      assertEqual(ceilingsFor("anyone"), LLM_COST_CEILINGS, "same object for every uid");
    },
  },
  {
    name: "a structureRecipe-shaped call adds exactly its estimatedCost to today and the month",
    fn: async () => {
      const db = fakeDb();
      const wrapped = withCostLedger(
        async () => ({ success: true, estimatedCost: 0.0012 }),
        db.deps(FEB_02_1200)
      );
      const result = await wrapped(authed("u1"));
      assertEqual(result.estimatedCost, 0.0012, "result passes through");
      const s = db.stored();
      approx(s?.costToday, 0.0012, "costToday");
      approx(s?.costThisMonth, 0.0012, "costThisMonth");
      assertEqual(s?.operationsThisMonth, 1, "one operation");
      assertEqual(s?.dayKey, "2026-02-02", "dayKey");
      assertEqual(s?.monthKey, "2026-02", "monthKey");
      assertEqual(
        db.paths.every((p) => p === "users/u1/rate_limits/llm_cost"),
        true,
        `every access is the ledger doc, got ${JSON.stringify(db.paths)}`
      );
      const expire = s?.expireAt as admin.firestore.Timestamp;
      assertEqual(
        expire.toMillis(),
        FEB_02_1200.getTime() + 40 * 24 * 60 * 60 * 1000,
        "expireAt is now + 40 days"
      );
    },
  },
  {
    name: "a second call the same day accumulates and refreshes expireAt",
    fn: async () => {
      const db = fakeDb({
        costToday: 0.01,
        dayKey: "2026-02-02",
        costThisMonth: 0.2,
        monthKey: "2026-02",
        operationsThisMonth: 7,
        expireAt: admin.firestore.Timestamp.fromMillis(0),
      });
      await withCostLedger(async () => ({ estimatedCost: 0.003 }), db.deps(FEB_02_1200))(authed("u1"));
      const s = db.stored();
      approx(s?.costToday, 0.013, "costToday");
      approx(s?.costThisMonth, 0.203, "costThisMonth");
      assertEqual(s?.operationsThisMonth, 8, "operations");
      assertEqual(
        (s?.expireAt as admin.firestore.Timestamp).toMillis() > FEB_02_1200.getTime(),
        true,
        "expireAt moved forward"
      );
    },
  },
  {
    name: "the OCR total (scan + in-process retry) is recorded as one sum",
    fn: async () => {
      const db = fakeDb();
      await withCostLedger(async () => ({ estimatedCost: 0.012 + 0.003 }), db.deps(FEB_02_1200))(authed("u1"));
      approx(db.stored()?.costToday, 0.015, "costToday");
    },
  },
  {
    name: "day and month roll over together across 31 Jan 23:59 -> 1 Feb 00:01 UTC",
    fn: async () => {
      const db = fakeDb();
      await withCostLedger(async () => ({ estimatedCost: 0.4 }), db.deps(JAN_31_2359))(authed("u1"));
      await withCostLedger(async () => ({ estimatedCost: 0.002 }), db.deps(FEB_01_0001))(authed("u1"));
      const s = db.stored();
      approx(s?.costToday, 0.002, "costToday restarts");
      approx(s?.costThisMonth, 0.002, "costThisMonth restarts");
      assertEqual(s?.operationsThisMonth, 1, "operations restart");
    },
  },
  {
    name: "a new day in the same month restarts today but keeps the month",
    fn: async () => {
      const db = fakeDb();
      await withCostLedger(async () => ({ estimatedCost: 0.4 }), db.deps(FEB_01_0001))(authed("u1"));
      await withCostLedger(async () => ({ estimatedCost: 0.002 }), db.deps(FEB_02_1200))(authed("u1"));
      const s = db.stored();
      approx(s?.costToday, 0.002, "costToday restarts");
      approx(s?.costThisMonth, 0.402, "costThisMonth keeps counting");
    },
  },
  {
    name: "at the daily ceiling: resource-exhausted with reason llm_cost_day, handler not run, nothing written",
    fn: async () => {
      const db = fakeDb({ costToday: 0.5, dayKey: "2026-02-02", costThisMonth: 0.5, monthKey: "2026-02" });
      let ran = false;
      const err = await expectHttpsError(
        () => withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(authed("u1")),
        "resource-exhausted"
      );
      assertEqual((err.details as { reason?: string })?.reason, "llm_cost_day", "reason");
      assertEqual(err.message.includes("i morgon"), true, `message names no clock time: ${err.message}`);
      assertEqual(ran, false, "handler not run");
      assertEqual(db.transactions(), 0, "no write");
    },
  },
  {
    name: "just under the daily ceiling the call runs",
    fn: async () => {
      const db = fakeDb({ costToday: 0.4999, dayKey: "2026-02-02", costThisMonth: 0.4999, monthKey: "2026-02" });
      let ran = false;
      await withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(authed("u1"));
      assertEqual(ran, true, "handler ran");
    },
  },
  {
    name: "yesterday's full day does not block today",
    fn: async () => {
      const db = fakeDb({ costToday: 0.9, dayKey: "2026-02-01", costThisMonth: 0.9, monthKey: "2026-02" });
      let ran = false;
      await withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(authed("u1"));
      assertEqual(ran, true, "handler ran");
    },
  },
  {
    name: "at the monthly ceiling: reason llm_cost_month even with nothing spent today",
    fn: async () => {
      const db = fakeDb({ costToday: 0.3, dayKey: "2026-02-01", costThisMonth: 10, monthKey: "2026-02" });
      let ran = false;
      const err = await expectHttpsError(
        () => withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(authed("u1")),
        "resource-exhausted"
      );
      assertEqual((err.details as { reason?: string })?.reason, "llm_cost_month", "reason");
      assertEqual(err.message.includes("nästa månad"), true, `message: ${err.message}`);
      assertEqual(ran, false, "handler not run");
    },
  },
  {
    name: "concurrent calls just under the ceiling all pass: the overshoot is the burst",
    fn: async () => {
      const db = fakeDb({ costToday: 0.49, dayKey: "2026-02-02", costThisMonth: 0.49, monthKey: "2026-02" });
      const wrapped = withCostLedger(async () => ({ estimatedCost: 0.01 }), db.deps(FEB_02_1200));
      // All five checks resolve before any record does, so each reads 0.49.
      await Promise.all([1, 2, 3, 4, 5].map(() => wrapped(authed("u1"))));
      approx(db.stored()?.costToday, 0.54, "five recorded, total past the ceiling");
    },
  },
  {
    name: "an unauthenticated call is refused before any read",
    fn: async () => {
      const db = fakeDb();
      let ran = false;
      await expectHttpsError(
        () => withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(
          {} as CallableRequest<unknown>
        ),
        "unauthenticated"
      );
      assertEqual(db.reads(), 0, "zero reads");
      assertEqual(ran, false, "handler not run");
    },
  },
  {
    name: "a zero cost (kill switch, empty input) writes nothing",
    fn: async () => {
      const db = fakeDb();
      await withCostLedger(async () => ({ estimatedCost: 0 }), db.deps(FEB_02_1200))(authed("u1"));
      assertEqual(db.transactions(), 0, "no transaction");
      assertEqual(db.stored(), undefined, "no doc");
    },
  },
  {
    name: "a failed record does not fail the call",
    fn: async () => {
      const db = fakeDb(undefined, { failTransaction: true });
      const result = await withCostLedger(async () => ({ estimatedCost: 0.002, recipe: "r" }), db.deps(FEB_02_1200))(authed("u1"));
      assertEqual(result.recipe, "r", "result returned");
      assertEqual(db.transactions(), 1, "the record was attempted");
    },
  },
  {
    name: "a failed ceiling read fails closed: unavailable, handler not run",
    fn: async () => {
      const db = fakeDb(undefined, { failGet: true });
      let ran = false;
      await expectHttpsError(
        () => withCostLedger(async () => { ran = true; return { estimatedCost: 0.001 }; }, db.deps(FEB_02_1200))(authed("u1")),
        "unavailable"
      );
      assertEqual(ran, false, "handler not run");
    },
  },
  {
    name: "both AI callables are wrapped, ledger outside the rate limiter",
    fn: () => {
      // The callables cannot be invoked here without Vertex, so the wiring is
      // pinned on the source: without it every case above passes and no call
      // is ever counted.
      for (const [file, op] of [
        ["structure-recipe.ts", "structureRecipe"],
        ["ocr-recipe-image.ts", "ocrRecipeImage"],
      ]) {
        const src = fs.readFileSync(path.join(__dirname, "..", "llm", file), "utf8");
        const wired = `withCostLedger(withRateLimit("${op}",`;
        assertEqual(src.split(wired).length - 1, 1, `${file} wraps ${op} once`);
      }
    },
  },
];

runTests("BUT-2243: server-side AI cost ledger", cases);
