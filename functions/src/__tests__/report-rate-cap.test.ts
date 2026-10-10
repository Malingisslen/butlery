/**
 * BUT-2331: the server-side cap on reports per reporter.
 *
 * What this proves about `admitReport`: a report under the cap is processed
 * and pages; over the cap it is not processed and pages once per reporter per
 * UTC day (the `create()` on a deterministic `system_events` id); a `csam`
 * report is charged to its own bucket; a limiter outage is processed whatever
 * the cap says, while contention on the bucket stays a denial; and the
 * only document it ever writes is that `system_events` row, so the report
 * itself stays `new` in the moderator queue. `handleReport` is pinned on what
 * it does with each admission. It also pins both limiter configs.
 *
 * Run with: npx ts-node src/__tests__/report-rate-cap.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) admin.initializeApp({ projectId: "report-rate-cap-test" });

import {
  admitReport,
  handleReport,
  ReportAdmission,
  ReportDeps,
  REPORT_CSAM_RATE_OPERATION,
  REPORT_RATE_OPERATION,
} from "../feedback/on-report-created";
import {
  __setFirestoreForTest,
  checkRateLimit,
  RATE_LIMIT_CONFIGS,
  RateLimitCheckResult,
} from "../middleware/rate_limiter";
import { hashUid } from "../shared/hash-uid";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

interface Write {
  path: string;
  data: Record<string, unknown>;
}

/** Records `create()` calls; `createError` makes every create throw it. */
function fakeDb(createError?: unknown): {
  db: admin.firestore.Firestore;
  writes: Write[];
} {
  const writes: Write[] = [];
  const db = {
    collection: (c: string) => ({
      doc: (id: string) => ({
        create: async (data: Record<string, unknown>) => {
          if (createError) throw createError;
          writes.push({ path: `${c}/${id}`, data });
        },
      }),
    }),
  } as unknown as admin.firestore.Firestore;
  return { db, writes };
}

const ALLOWED: RateLimitCheckResult = { allowed: true, remainingTokens: 9 };
const DENIED: RateLimitCheckResult = {
  allowed: false,
  remainingTokens: 0,
  retryAfterMs: 1000,
};
const UNAVAILABLE: RateLimitCheckResult = {
  allowed: false,
  remainingTokens: 0,
  retryAfterMs: 30000,
  unavailable: true,
};

const always = (r: RateLimitCheckResult) => async () => r;
const params = (reason = "spam") => ({
  reportId: "rep1",
  reporterId: "reporter-uid",
  reason,
});

const cases: UnitCase[] = [
  {
    name: "under the cap: processed and paged, nothing written",
    fn: async () => {
      const { db, writes } = fakeDb();
      const a = await admitReport(db, params(), always(ALLOWED));
      assertEqual(a.process, true, "process");
      assertEqual(a.page, true, "page");
      assertEqual(writes.length, 0, "writes");
    },
  },
  {
    name: "asks the limiter for the reporter under reportContent",
    fn: async () => {
      const { db } = fakeDb();
      const seen: string[] = [];
      await admitReport(db, params(), async (uid, op) => {
        seen.push(`${uid}|${op}`);
        return ALLOWED;
      });
      assertEqual(seen.join(","), "reporter-uid|reportContent", "check args");
    },
  },
  {
    name: "first over-cap report of the day: not processed, paged, one row",
    fn: async () => {
      const { db, writes } = fakeDb();
      const now = new Date(Date.UTC(2026, 9, 10, 23, 59, 59));
      const a = await admitReport(db, params(), always(DENIED), now);
      assertEqual(a.process, false, "process");
      assertEqual(a.page, true, "page");
      assertEqual(writes.length, 1, "writes");
      assertEqual(
        writes[0].path,
        `system_events/report_rate_limited_${hashUid("reporter-uid")}_2026-10-10`,
        "row path",
      );
      assertEqual(writes[0].data.type, "rate_limit_violation", "row type");
      assertEqual(writes[0].data.userIdHash, hashUid("reporter-uid"), "hash");
      assertEqual(writes[0].data.firstReportId, "rep1", "report id");
      assertEqual(
        JSON.stringify(writes[0].data).includes("reporter-uid"),
        false,
        "raw uid never stored",
      );
    },
  },
  {
    name: "later over-cap report the same day: not processed, not paged",
    fn: async () => {
      const { db } = fakeDb(Object.assign(new Error("exists"), { code: 6 }));
      const a = await admitReport(db, params(), always(DENIED));
      assertEqual(a.process, false, "process");
      assertEqual(a.page, false, "page");
    },
  },
  {
    name: "over cap and the row write fails otherwise: still pages",
    fn: async () => {
      const { db } = fakeDb(Object.assign(new Error("boom"), { code: 14 }));
      const a = await admitReport(db, params(), always(DENIED));
      assertEqual(a.process, false, "process");
      assertEqual(a.page, true, "page");
    },
  },
  {
    name: "csam is charged to its own bucket, other reasons to the shared one",
    fn: async () => {
      const { db } = fakeDb();
      const ops: string[] = [];
      const record = async (_uid: string, op: string) => {
        ops.push(op);
        return ALLOWED;
      };
      await admitReport(db, params("csam"), record);
      await admitReport(db, params("spam"), record);
      assertEqual(
        ops.join(","),
        `${REPORT_CSAM_RATE_OPERATION},${REPORT_RATE_OPERATION}`,
        "operations",
      );
    },
  },
  {
    name: "limiter unavailable: processed and paged",
    fn: async () => {
      const { db, writes } = fakeDb();
      const a = await admitReport(db, params(), always(UNAVAILABLE));
      assertEqual(a.process, true, "process");
      assertEqual(a.page, true, "page");
      assertEqual(writes.length, 0, "writes");
    },
  },
  {
    name: "reportContent has its own config: 10 burst, 10 per hour, 20 per day",
    fn: () => {
      assertEqual(REPORT_RATE_OPERATION, "reportContent", "operation name");
      const c = RATE_LIMIT_CONFIGS[REPORT_RATE_OPERATION];
      assertEqual(c?.maxTokens, 10, "maxTokens");
      assertEqual(c?.refillRate, 10, "refillRate");
      assertEqual(c?.refillIntervalMs, 3600000, "refillIntervalMs");
      assertEqual(c?.dailyLimit, 20, "dailyLimit");
      const csam = RATE_LIMIT_CONFIGS[REPORT_CSAM_RATE_OPERATION];
      assertEqual(csam?.dailyLimit, 50, "csam dailyLimit");
    },
  },
  {
    name: "limiter: contention (ABORTED) is a denial, other errors are an outage",
    fn: async () => {
      const throwing = (code: number) =>
        ({
          collection: () => ({ doc: () => ({}) }),
          runTransaction: async () => {
            throw Object.assign(new Error("tx"), { code });
          },
        }) as unknown as admin.firestore.Firestore;
      try {
        __setFirestoreForTest(throwing(10));
        const aborted = await checkRateLimit("u", REPORT_RATE_OPERATION);
        assertEqual(aborted.allowed, false, "aborted allowed");
        assertEqual(aborted.unavailable, undefined, "aborted unavailable");
        __setFirestoreForTest(throwing(14));
        const down = await checkRateLimit("u", REPORT_RATE_OPERATION);
        assertEqual(down.allowed, false, "down allowed");
        assertEqual(down.unavailable, true, "down unavailable");
      } finally {
        __setFirestoreForTest(null);
      }
    },
  },
  ...handleCases(),
];

/** `handleReport` acting on each admission: what runs, and what pages. */
function handleCases(): UnitCase[] {
  const report = {
    reporterId: "reporter-uid",
    contentOwnerId: "owner",
    contentType: "recipe",
    contentId: "c1",
    reason: "spam",
  };
  const harness = (admission: ReportAdmission) => {
    const events: string[] = [];
    const pages: Record<string, unknown>[] = [];
    const deps: ReportDeps = {
      admit: async () => admission,
      capture: async () => {
        events.push("capture");
        return "captured";
      },
      process: async () => {
        events.push("process");
      },
      log: {
        info: (msg: string, data?: Record<string, unknown>) => {
          events.push(`info:${msg}`);
          if (msg === "moderation_review_needed") pages.push(data ?? {});
        },
        warn: (msg: string) => events.push(`warn:${msg}`),
        error: (msg: string) => events.push(`error:${msg}`),
      } as unknown as ReportDeps["log"],
    };
    const run = () =>
      handleReport(
        {} as admin.firestore.Firestore,
        { reportId: "rep1", eventId: "ev1", report },
        deps,
      );
    return { events, pages, run };
  };
  return [
    {
      name: "handleReport over the cap, first of the day: pages, runs nothing",
      fn: async () => {
        const h = harness({ process: false, page: true });
        await h.run();
        assertEqual(h.events.includes("capture"), false, "capture");
        assertEqual(h.events.includes("process"), false, "process");
        assertEqual(h.pages.length, 1, "pages");
        assertEqual(h.pages[0].rateLimited, true, "rateLimited");
      },
    },
    {
      name: "handleReport over the cap, later the same day: no page",
      fn: async () => {
        const h = harness({ process: false, page: false });
        await h.run();
        assertEqual(h.pages.length, 0, "pages");
        assertEqual(h.events.includes("process"), false, "process");
      },
    },
    {
      name: "handleReport under the cap: pages before the copy and strike run",
      fn: async () => {
        const h = harness({ process: true, page: true });
        await h.run();
        const page = h.events.indexOf("info:moderation_review_needed");
        assertEqual(page >= 0, true, "paged");
        assertEqual(h.pages[0].rateLimited, false, "rateLimited");
        assertEqual(page < h.events.indexOf("capture"), true, "page before capture");
        assertEqual(page < h.events.indexOf("process"), true, "page before process");
      },
    },
  ];
}

runTests("BUT-2331 report rate cap", cases);
