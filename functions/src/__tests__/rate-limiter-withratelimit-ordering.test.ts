/**
 * BUT-1577: withRateLimit checks the PER-USER limit before it touches the
 * shared global LLM counter.
 *
 * checkGlobalLimit atomically *increments* the shared system/llmLimits budget.
 * If withRateLimit ran it before the per-user gate, a user whose own limit
 * denies the request would still burn shared budget for everyone — an abuse
 * vector (one hammering capped account starves the global cap). The production
 * order was fixed to run the per-user check first and only reach the global
 * increment once that check allows.
 *
 * These cases pin that ordering so a future refactor that swaps it back goes
 * red:
 *   (1) a per-user-DENIED request throws the per-user 429, never enters
 *       checkGlobalLimit (its limits-loader never fires), and never runs the
 *       handler or writes the global counter;
 *   (2) a per-user-ALLOWED request DOES reach checkGlobalLimit (its limits
 *       loader — checkGlobalLimit's earliest observable side effect — fires,
 *       and the failure surfaced is the GLOBAL one, not the per-user one).
 *
 * __setFirestoreForTest feeds checkRateLimit's per-user doc. checkGlobalLimit
 * reads admin.firestore() directly (no test app exists here, so it fail-closes
 * to a global denial); we observe only whether it was ENTERED — via its loader
 * seam — which is all the ordering claim needs, and case (1) proves it is not
 * entered at all on a per-user denial.
 *
 * Run with: npx ts-node src/__tests__/rate-limiter-withratelimit-ordering.test.ts
 */

import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import {
  __resetGlobalLimitsCacheForTest,
  __setFirestoreForTest,
  withRateLimit,
} from "../middleware/rate_limiter";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

/** Same shape as production's utcDayKey (0-based month), for live `new Date()`. */
function liveTodayKey(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
}

/** A minimal authenticated CallableRequest carrying just the uid withRateLimit reads. */
function authedRequest(uid: string): CallableRequest<unknown> {
  return { auth: { uid } } as unknown as CallableRequest<unknown>;
}

interface PerUserDbHandle {
  db: admin.firestore.Firestore;
  writes: Record<string, unknown>[];
}

/**
 * Per-user rate-limit doc double (checkRateLimit's transaction). Same shape as
 * rate-limiter-daily-cap.test.ts's fake: one doc, get returns it, set/update
 * record + mutate it.
 */
function fakePerUserDb(
  initial: Record<string, unknown> | undefined
): PerUserDbHandle {
  let stored = initial ? { ...initial } : undefined;
  const writes: Record<string, unknown>[] = [];
  const docRef = {};
  const db = {
    collection: () => ({ doc: () => docRef }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      const tx = {
        get: async () => ({ exists: stored !== undefined, data: () => stored }),
        update: (_ref: unknown, data: Record<string, unknown>) => {
          stored = { ...stored, ...data };
          writes.push(data);
        },
        set: (_ref: unknown, data: Record<string, unknown>) => {
          stored = { ...data };
          writes.push(data);
        },
      };
      return fn(tx);
    },
  } as unknown as admin.firestore.Firestore;
  return { db, writes };
}

const cases: UnitCase[] = [
  {
    name: "per-user DENIED: throws the per-user 429, never reaches the global counter or the handler",
    fn: async () => {
      // structureRecipe dailyLimit is 100; seed the counter AT the cap so the
      // first call is denied by the per-user check.
      const perUser = fakePerUserDb({
        tokens: 10,
        lastRefill: admin.firestore.Timestamp.now(),
        operationType: "structureRecipe",
        updatedAt: admin.firestore.Timestamp.now(),
        dayKey: liveTodayKey(),
        dailyCount: 100,
      });
      __setFirestoreForTest(perUser.db);

      let globalChecked = false;
      // If checkGlobalLimit is entered it loads limits first — this loader is
      // its earliest observable side effect. It must NOT fire on a denial.
      __resetGlobalLimitsCacheForTest(async () => {
        globalChecked = true;
        return { hourly: 1000, daily: 10000 };
      });

      let handlerRan = false;
      const wrapped = withRateLimit("structureRecipe", async () => {
        handlerRan = true;
        return "ok";
      });

      try {
        let threw: unknown;
        try {
          await wrapped(authedRequest("user-denied"));
        } catch (e) {
          threw = e;
        }
        if (!(threw instanceof HttpsError)) {
          throw new Error(`expected an HttpsError, got: ${String(threw)}`);
        }
        assertEqual(threw.code, "resource-exhausted", "429 resource-exhausted");
        // The per-user message, NOT the global "Systemets kapacitetsgräns" one —
        // proves the denial came from the per-user gate, not the global one.
        if (!threw.message.includes("för många förfrågningar")) {
          throw new Error(
            `deny must be the per-user message, got: ${threw.message}`
          );
        }
        assertEqual(
          globalChecked,
          false,
          "checkGlobalLimit was never entered (global counter untouched)"
        );
        assertEqual(handlerRan, false, "handler never ran on a denied request");
      } finally {
        __setFirestoreForTest(null);
        __resetGlobalLimitsCacheForTest();
      }
    },
  },
  {
    name: "per-user ALLOWED: passes the per-user gate and reaches checkGlobalLimit (global is the second gate)",
    fn: async () => {
      const perUser = fakePerUserDb({
        tokens: 10,
        lastRefill: admin.firestore.Timestamp.now(),
        operationType: "structureRecipe",
        updatedAt: admin.firestore.Timestamp.now(),
        dayKey: liveTodayKey(),
        dailyCount: 41, // well under the cap → per-user check allows
      });
      __setFirestoreForTest(perUser.db);

      let globalChecked = false;
      // checkGlobalLimit loads its limits before anything else; this loader
      // firing proves the request got PAST the per-user gate and into the
      // global one.
      __resetGlobalLimitsCacheForTest(async () => {
        globalChecked = true;
        return { hourly: 1000, daily: 10000 };
      });

      let handlerRan = false;
      const wrapped = withRateLimit("structureRecipe", async () => {
        handlerRan = true;
        return "handler-result";
      });

      try {
        // No test Firebase app exists, so checkGlobalLimit's own Firestore
        // transaction fail-closes to a global denial — the point being that we
        // only reach it AFTER the per-user allow.
        let threw: unknown;
        try {
          await wrapped(authedRequest("user-allowed"));
        } catch (e) {
          threw = e;
        }
        assertEqual(
          globalChecked,
          true,
          "checkGlobalLimit was entered after the per-user allow"
        );
        if (!(threw instanceof HttpsError)) {
          throw new Error(`expected the global HttpsError, got: ${String(threw)}`);
        }
        // The GLOBAL message, not the per-user one — confirms the per-user gate
        // was passed and the failure is the second (global) gate.
        if (!threw.message.includes("Systemets kapacitetsgräns")) {
          throw new Error(
            `expected the global-limit message, got: ${threw.message}`
          );
        }
        assertEqual(
          handlerRan,
          false,
          "handler does not run while the global gate denies"
        );
      } finally {
        __setFirestoreForTest(null);
        __resetGlobalLimitsCacheForTest();
      }
    },
  },
];

runTests("BUT-1577: withRateLimit per-user-before-global ordering", cases);
