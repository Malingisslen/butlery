/**
 * BUT-1477: per-user daily cap on LLM-backed operations.
 *
 * What this proves: the minute bucket alone lets a patient caller make
 * thousands of LLM calls per day; `evaluateDailyCap` (the decision the
 * checkRateLimit transaction persists/enforces) must (1) deny the request
 * once today's counter reaches the configured dailyLimit even though bucket
 * tokens remain, (2) reset the counter across a UTC-day rollover, (3) leave
 * operations without a dailyLimit unenforced while still tracking the
 * counter, and (4) report a retry-after that lands exactly at next UTC
 * midnight.
 *
 * It ALSO proves the enforcement wiring inside checkRateLimit's transaction
 * (via the __setFirestoreForTest seam), not just the pure decision function:
 * (5) an allowed request persists dayKey + dailyCount = prior + 1 back to the
 * stored doc (drop the increment and the cap never fires), (6) a denied
 * request returns BEFORE consuming minute-bucket tokens or writing the doc
 * (the documented "a denied request must not eat bucket capacity" contract),
 * and (7) the first-ever request seeds the counter at 1. Deleting the
 * `if (!dailyCap.allowed)` block in checkRateLimit turns these cases red.
 *
 * Run with: npx ts-node src/__tests__/rate-limiter-daily-cap.test.ts
 */

import * as admin from "firebase-admin";
import {
  __setFirestoreForTest,
  checkRateLimit,
  evaluateDailyCap,
  RATE_LIMIT_CONFIGS,
  RateLimitConfig,
} from "../middleware/rate_limiter";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const cappedConfig: RateLimitConfig = {
  maxTokens: 10,
  refillRate: 3,
  refillIntervalMs: 60000,
  dailyLimit: 100,
};

const uncappedConfig: RateLimitConfig = {
  maxTokens: 30,
  refillRate: 10,
  refillIntervalMs: 60000,
};

// Fixed mid-day instant so midnight math is deterministic.
const NOON_UTC = new Date(Date.UTC(2026, 6, 7, 12, 0, 0));
const TODAY_KEY = "2026-6-7"; // getUTCMonth() is 0-based, matching production.

const cases: UnitCase[] = [
  {
    name: "under the cap: allowed, counter carried forward for increment",
    fn: async () => {
      const result = evaluateDailyCap(
        { dayKey: TODAY_KEY, dailyCount: 42 },
        cappedConfig,
        NOON_UTC
      );
      assertEqual(result.allowed, true, "allowed under cap");
      assertEqual(result.priorDailyCount, 42, "prior count preserved");
      assertEqual(result.dayKey, TODAY_KEY, "day key stamped");
    },
  },
  {
    name: "at the cap: denied even though minute-bucket tokens remain",
    fn: async () => {
      const result = evaluateDailyCap(
        { dayKey: TODAY_KEY, dailyCount: 100 },
        cappedConfig,
        NOON_UTC
      );
      assertEqual(result.allowed, false, "denied at cap");
    },
  },
  {
    name: "denial retry-after lands exactly at next UTC midnight",
    fn: async () => {
      const result = evaluateDailyCap(
        { dayKey: TODAY_KEY, dailyCount: 100 },
        cappedConfig,
        NOON_UTC
      );
      // Noon → 12h until midnight UTC.
      assertEqual(
        result.retryAfterMs,
        12 * 60 * 60 * 1000,
        "retryAfterMs = ms until next UTC midnight"
      );
    },
  },
  {
    name: "UTC-day rollover resets the counter (yesterday's cap doesn't bleed)",
    fn: async () => {
      const result = evaluateDailyCap(
        { dayKey: "2026-6-6", dailyCount: 100 },
        cappedConfig,
        NOON_UTC
      );
      assertEqual(result.allowed, true, "allowed after rollover");
      assertEqual(result.priorDailyCount, 0, "counter reset to 0");
      assertEqual(result.dayKey, TODAY_KEY, "new day key stamped");
    },
  },
  {
    name: "pre-BUT-1477 doc (no counter fields) reads as a fresh day",
    fn: async () => {
      const result = evaluateDailyCap(undefined, cappedConfig, NOON_UTC);
      assertEqual(result.allowed, true, "allowed on legacy/first doc");
      assertEqual(result.priorDailyCount, 0, "counter starts at 0");
    },
  },
  {
    name: "operation without dailyLimit is never denied, counter still tracked",
    fn: async () => {
      const result = evaluateDailyCap(
        { dayKey: TODAY_KEY, dailyCount: 999999 },
        uncappedConfig,
        NOON_UTC
      );
      assertEqual(result.allowed, true, "no enforcement without dailyLimit");
      assertEqual(result.priorDailyCount, 999999, "counter still carried");
    },
  },

  // ---- checkRateLimit transaction wiring (real config: structureRecipe,
  // maxTokens 10 / dailyLimit 100) ----
  {
    name: "checkRateLimit: allowed request persists dayKey + incremented dailyCount",
    fn: async () => {
      const fake = fakeRateLimitDb({
        tokens: 10,
        lastRefill: admin.firestore.Timestamp.now(),
        operationType: "structureRecipe",
        updatedAt: admin.firestore.Timestamp.now(),
        dayKey: liveTodayKey(),
        dailyCount: 41,
      });
      __setFirestoreForTest(fake.db);
      try {
        const result = await checkRateLimit("user-a", "structureRecipe");
        assertEqual(result.allowed, true, "allowed under the cap");
        assertEqual(fake.writes.length, 1, "exactly one doc write");
        const written = fake.writes[0];
        assertEqual(
          written.dailyCount as number,
          42,
          "dailyCount persisted as prior + 1"
        );
        assertEqual(
          written.dayKey as string,
          liveTodayKey(),
          "dayKey persisted alongside the counter"
        );
        assertEqual(
          written.tokens as number,
          9,
          "one minute-bucket token consumed"
        );
      } finally {
        __setFirestoreForTest(null);
      }
    },
  },
  {
    name: "checkRateLimit: request that reaches the cap is allowed; the next is denied without a write or token spend",
    fn: async () => {
      const fake = fakeRateLimitDb({
        tokens: 10,
        lastRefill: admin.firestore.Timestamp.now(),
        operationType: "structureRecipe",
        updatedAt: admin.firestore.Timestamp.now(),
        dayKey: liveTodayKey(),
        dailyCount: 99, // dailyLimit is 100
      });
      __setFirestoreForTest(fake.db);
      try {
        const first = await checkRateLimit("user-a", "structureRecipe");
        assertEqual(first.allowed, true, "call 1 (100th today) still allowed");
        assertEqual(
          fake.getStored()?.dailyCount as number,
          100,
          "counter reached the cap"
        );

        const second = await checkRateLimit("user-a", "structureRecipe");
        assertEqual(second.allowed, false, "call 2 denied at the cap");
        if (!second.reason?.includes("Daily limit")) {
          throw new Error(
            `deny reason must name the daily limit, got: ${second.reason}`
          );
        }
        assertEqual(
          fake.writes.length,
          1,
          "denied request wrote nothing (no doc update)"
        );
        assertEqual(
          fake.getStored()?.tokens as number,
          9,
          "denied request did not consume a minute-bucket token"
        );
        if (second.retryAfterMs === undefined || second.retryAfterMs <= 0) {
          throw new Error("denied result must carry a positive retryAfterMs");
        }
      } finally {
        __setFirestoreForTest(null);
      }
    },
  },
  {
    name: "checkRateLimit: first-ever request seeds dailyCount at 1 with today's key",
    fn: async () => {
      const fake = fakeRateLimitDb(undefined);
      __setFirestoreForTest(fake.db);
      try {
        const result = await checkRateLimit("user-b", "structureRecipe");
        assertEqual(result.allowed, true, "first request allowed");
        assertEqual(fake.writes.length, 1, "doc created");
        assertEqual(
          fake.writes[0].dailyCount as number,
          1,
          "counter seeded at 1"
        );
        assertEqual(
          fake.writes[0].dayKey as string,
          liveTodayKey(),
          "day key stamped on creation"
        );
      } finally {
        __setFirestoreForTest(null);
      }
    },
  },

  // ---- BUT-1573: the production dailyLimit values are the load-bearing
  // per-user LLM-spend caps. Pin them so deleting or weakening one regresses a
  // test instead of shipping silently. If a value is deliberately retuned,
  // update these expectations in the same change. ----
  {
    name: "RATE_LIMIT_CONFIGS: structureRecipe daily cap is 100",
    fn: async () => {
      assertEqual(
        RATE_LIMIT_CONFIGS.structureRecipe.dailyLimit,
        100,
        "structureRecipe.dailyLimit"
      );
    },
  },
  {
    name: "RATE_LIMIT_CONFIGS: ocrRecipeImage daily cap is 50",
    fn: async () => {
      assertEqual(
        RATE_LIMIT_CONFIGS.ocrRecipeImage.dailyLimit,
        50,
        "ocrRecipeImage.dailyLimit"
      );
    },
  },
  {
    name: "RATE_LIMIT_CONFIGS: importRecipe daily cap is 100",
    fn: async () => {
      assertEqual(
        RATE_LIMIT_CONFIGS.importRecipe.dailyLimit,
        100,
        "importRecipe.dailyLimit"
      );
    },
  },
];

/** Same shape as production's utcDayKey (0-based month), for live `new Date()`. */
function liveTodayKey(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
}

interface FakeDbHandle {
  db: admin.firestore.Firestore;
  /** Payloads passed to transaction.set/update, in order. */
  writes: Record<string, unknown>[];
  getStored: () => Record<string, unknown> | undefined;
}

/**
 * Minimal Firestore double for the checkRateLimit transaction: one rate-limit
 * doc, transaction.get returns it, set/update record the payload and mutate
 * the stored doc (so back-to-back calls see each other's writes, like the
 * real transaction commit). Mirrors llm-sample-capture.test.ts's fakeDb.
 */
function fakeRateLimitDb(
  initial: Record<string, unknown> | undefined
): FakeDbHandle {
  let stored: Record<string, unknown> | undefined = initial
    ? { ...initial }
    : undefined;
  const writes: Record<string, unknown>[] = [];
  const docRef = {}; // identity token; the fake tracks a single doc
  const db = {
    collection: (_name: string) => ({
      doc: (_id: string) => docRef,
    }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      const tx = {
        get: async (_ref: unknown) => ({
          exists: stored !== undefined,
          data: () => stored,
        }),
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
  return { db, writes, getStored: () => stored };
}

runTests("BUT-1477: per-user daily LLM cap", cases);
