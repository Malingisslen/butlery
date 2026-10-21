/**
 * The AI-cap crossing signal (`middleware/ai_cap_signal.ts`): where a count
 * crosses, and that the guest and per-user hooks emit at the crossing only.
 * The global hook's wiring is proven on staging (tasks/ai-cap-signal-plan.md):
 * `checkGlobalLimit` reads `admin.firestore()` directly and has no seam.
 *
 * Run: npx ts-node src/__tests__/ai-cap-signal.test.ts
 */

import * as admin from "firebase-admin";
import type { CallableRequest } from "firebase-functions/v2/https";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  capCrossing,
  CapSignal,
  __setCapSignalSinkForTest,
} from "../middleware/ai_cap_signal";
import { withGuestImportQuota } from "../llm/guest-import-quota";
import {
  __resetGlobalLimitsCacheForTest,
  __setFirestoreForTest,
  checkRateLimit,
  withRateLimit,
} from "../middleware/rate_limiter";

function captured(): CapSignal[] {
  const seen: CapSignal[] = [];
  __setCapSignalSinkForTest((s) => seen.push(s));
  return seen;
}

function levelsUpTo(limit: number, through: number): string[] {
  const out: string[] = [];
  for (let n = 1; n <= through; n++) {
    const level = capCrossing(n, limit);
    if (level) out.push(`${n}:${level}`);
  }
  return out;
}

function guestRequest(
  uid: string,
  id: string,
): CallableRequest<{ guestImportId?: string }> {
  return {
    auth: { uid, token: { firebase: { sign_in_provider: "anonymous" } } },
    data: { guestImportId: id },
  } as unknown as CallableRequest<{ guestImportId?: string }>;
}

function guestHarness(dailyLimit: number) {
  const store = new FakeFirestore();
  let fail = false;
  const wrapped = withGuestImportQuota<
    { guestImportId?: string },
    { success?: boolean; estimatedCost: number }
  >(
    async () => {
      if (fail) throw new Error("refused downstream");
      return { success: true, estimatedCost: 0 };
    },
    {
      db: store.db,
      now: () => new Date(Date.UTC(2026, 9, 21, 12)),
      loadDailyLimit: async () => dailyLimit,
    },
  );
  return {
    call: (uid: string, id: string) => wrapped(guestRequest(uid, id)),
    failNext: (v: boolean) => {
      fail = v;
    },
  };
}

function todayKey(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
}

/** checkRateLimit's single-doc transaction, seeded at a given daily count. */
function perUserDb(
  dailyCount: number,
  operationType = "structureRecipe",
): admin.firestore.Firestore {
  let stored: Record<string, unknown> = {
    tokens: 10,
    lastRefill: admin.firestore.Timestamp.now(),
    operationType,
    updatedAt: admin.firestore.Timestamp.now(),
    dayKey: todayKey(),
    dailyCount,
  };
  const ref = {};
  return {
    collection: () => ({ doc: () => ref }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> =>
      fn({
        get: async () => ({ exists: true, data: () => stored }),
        update: (_r: unknown, d: Record<string, unknown>) => {
          stored = { ...stored, ...d };
        },
        set: (_r: unknown, d: Record<string, unknown>) => {
          stored = { ...d };
        },
      }),
  } as unknown as admin.firestore.Firestore;
}

async function callStructureRecipe(): Promise<void> {
  const wrapped = withRateLimit("structureRecipe", async () => "ok");
  try {
    await wrapped({
      auth: { uid: "user-1" },
    } as unknown as CallableRequest<unknown>);
  } catch {
    // checkGlobalLimit has no admin app here and fails closed; the per-user
    // signal is emitted before it.
  }
}

const cases: UnitCase[] = [
  {
    name: "limit 100: near at 80, reached at 100, nothing else",
    fn: async () => {
      assertEqual(
        levelsUpTo(100, 120).join(","),
        "80:near,100:reached",
        "crossings",
      );
    },
  },
  {
    name: "limit 20: near at 16; limit 5: near at 4",
    fn: async () => {
      assertEqual(
        levelsUpTo(20, 25).join(","),
        "16:near,20:reached",
        "limit 20",
      );
      assertEqual(levelsUpTo(5, 8).join(","), "4:near,5:reached", "limit 5");
    },
  },
  {
    name: "limit 4 and 1: the near point lands on the limit, so only reached",
    fn: async () => {
      assertEqual(levelsUpTo(4, 6).join(","), "4:reached", "limit 4");
      assertEqual(levelsUpTo(1, 3).join(","), "1:reached", "limit 1");
    },
  },
  {
    name: "a fractional limit is reached at its ceiling, the last call it admits",
    fn: async () => {
      assertEqual(
        levelsUpTo(20.5, 25).join(","),
        "17:near,21:reached",
        "limit 20.5",
      );
    },
  },
  {
    name: "a non-positive limit never crosses",
    fn: async () => {
      assertEqual(capCrossing(0, 0), null, "limit 0");
      assertEqual(capCrossing(1, -1), null, "limit -1");
    },
  },
  {
    name: "guest_day: five new imports at limit 5 emit near at 4 and reached at 5",
    fn: async () => {
      const seen = captured();
      try {
        const h = guestHarness(5);
        for (let i = 1; i <= 5; i++) await h.call(`guest-${i}`, `import-${i}`);
        assertEqual(
          seen
            .map((s) => `${s.cap}:${s.count}/${s.limit}:${s.level}`)
            .join(","),
          "guest_day:4/5:near,guest_day:5/5:reached",
          "signals",
        );
        assertEqual(
          seen.every((s) => s.userIdHash === undefined),
          true,
          "no user id",
        );
      } finally {
        __setCapSignalSinkForTest(null);
      }
    },
  },
  {
    name: "guest_day: a further call on an existing import emits nothing",
    fn: async () => {
      const seen = captured();
      try {
        const h = guestHarness(2);
        await h.call("guest-a", "import-a");
        await h.call("guest-b", "import-b");
        await h.call("guest-a", "import-a");
        assertEqual(seen.length, 1, "one reached, no repeat");
      } finally {
        __setCapSignalSinkForTest(null);
      }
    },
  },
  {
    name: "guest_day: reach, refund, reach again emits reached twice (known gap)",
    fn: async () => {
      const seen = captured();
      try {
        const h = guestHarness(2);
        await h.call("guest-a", "import-a");
        h.failNext(true);
        await h.call("guest-b", "import-b").catch(() => undefined);
        h.failNext(false);
        await h.call("guest-c", "import-c");
        assertEqual(
          seen.map((s) => `${s.count}:${s.level}`).join(","),
          "2:reached,2:reached",
          "the refund lowers the shared count, so the crossing repeats",
        );
      } finally {
        __setCapSignalSinkForTest(null);
      }
    },
  },
  {
    name: "user_day: the call that makes structureRecipe's count 80 of 100 emits near with a hash",
    fn: async () => {
      const seen = captured();
      __resetGlobalLimitsCacheForTest(async () => ({
        hourly: 1000,
        daily: 10000,
      }));
      try {
        __setFirestoreForTest(perUserDb(79));
        await callStructureRecipe();
        assertEqual(seen.length, 1, "one signal");
        assertEqual(seen[0].cap, "user_day", "cap");
        assertEqual(seen[0].level, "near", "level");
        assertEqual(seen[0].count, 80, "count");
        assertEqual(seen[0].operationType, "structureRecipe", "op");
        assertEqual(
          typeof seen[0].userIdHash === "string" &&
            seen[0].userIdHash !== "user-1",
          true,
          "hashed, never the raw uid",
        );
      } finally {
        __setCapSignalSinkForTest(null);
        __setFirestoreForTest(null);
        __resetGlobalLimitsCacheForTest();
      }
    },
  },
  {
    name: "user_day: the calls before and after a crossing emit nothing",
    fn: async () => {
      const seen = captured();
      __resetGlobalLimitsCacheForTest(async () => ({
        hourly: 1000,
        daily: 10000,
      }));
      try {
        __setFirestoreForTest(perUserDb(78));
        await callStructureRecipe();
        __setFirestoreForTest(perUserDb(80));
        await callStructureRecipe();
        assertEqual(seen.length, 0, "79 and 81 are not crossings");
      } finally {
        __setCapSignalSinkForTest(null);
        __setFirestoreForTest(null);
        __resetGlobalLimitsCacheForTest();
      }
    },
  },
  {
    name: "user_day: a direct checkRateLimit call, as the OCR retry makes, emits too",
    fn: async () => {
      const seen = captured();
      try {
        __setFirestoreForTest(perUserDb(79));
        await checkRateLimit("user-1", "structureRecipe");
        assertEqual(
          seen.map((s) => `${s.cap}:${s.count}:${s.level}`).join(","),
          "user_day:80:near",
          "signal",
        );
      } finally {
        __setCapSignalSinkForTest(null);
        __setFirestoreForTest(null);
      }
    },
  },
  {
    name: "user_day: a non-AI operation with a daily cap emits nothing at its crossing",
    fn: async () => {
      const seen = captured();
      try {
        __setFirestoreForTest(perUserDb(39, "createChatGroup"));
        await checkRateLimit("user-1", "createChatGroup");
        assertEqual(
          seen.length,
          0,
          "createChatGroup 40 of 50 is not an AI cap",
        );
      } finally {
        __setCapSignalSinkForTest(null);
        __setFirestoreForTest(null);
      }
    },
  },
];

runTests("ai-cap-signal", cases);
