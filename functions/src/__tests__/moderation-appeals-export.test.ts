/**
 * BUT-2353: `exportModerationAppeals` — the Art. 15 export of the appeals the
 * requester wrote, as reporter and as owner.
 *
 * Run: npx ts-node src/__tests__/moderation-appeals-export.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-moderation-appeals-export" });
}

import { HttpsError } from "firebase-functions/v2/https";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const exporter = require("../exports/moderation-appeals") as typeof import("../exports/moderation-appeals");

const UID = "requester-uid";
const OTHER = "other-uid";
const MOD = "moderator-uid";
const T1 = admin.firestore.Timestamp.fromDate(new Date("2026-10-02T10:00:00Z"));
const T2 = admin.firestore.Timestamp.fromDate(new Date("2026-10-03T10:00:00Z"));
const T3 = admin.firestore.Timestamp.fromDate(new Date("2026-10-04T10:00:00Z"));

function assertTrue(condition: boolean, msg: string): void {
  if (!condition) throw new Error(msg);
}

function seedReport(db: FakeFirestore, id: string, reporterId: string, ownerId: string | null): void {
  db.seed(`reports/${id}`, {
    reporterId,
    contentOwnerId: ownerId,
    reason: "spam",
    description: "anmälarens fritext",
    status: "closed",
  });
}

function seedAppeal(
  db: FakeFirestore,
  reportId: string,
  role: "reporter" | "owner",
  appellantId: string,
  extra: Record<string, unknown> = {},
): void {
  db.seed(`moderation_appeals/${reportId}_${role}`, {
    reportId,
    role,
    appellantId,
    text: `${role} skrev om ${reportId}`,
    createdAt: T1,
    status: "open",
    answeredAt: null,
    answeredBy: null,
    expireAt: T3,
    ...extra,
  });
}

const cases: UnitCase[] = [
  {
    name: "returns the requester's appeals in both roles, projected and oldest first",
    fn: async () => {
      const fake = new FakeFirestore();
      seedReport(fake, "filed", UID, OTHER);
      seedAppeal(fake, "filed", "reporter", UID, {
        createdAt: T2, status: "upheld", answeredAt: T3, answeredBy: MOD,
      });
      seedReport(fake, "against", OTHER, UID);
      seedAppeal(fake, "against", "owner", UID, { createdAt: T1 });
      fake.seed("moderation_decisions/against", { decision: "content_removed", moderatorId: MOD });

      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(
        JSON.stringify(out.appeals),
        JSON.stringify([
          { role: "owner", text: "owner skrev om against", createdAt: T1.toDate().toISOString(), status: "open", answeredAt: null },
          {
            role: "reporter", text: "reporter skrev om filed", createdAt: T2.toDate().toISOString(),
            status: "upheld", answeredAt: T3.toDate().toISOString(),
          },
        ]),
        "own appeals, allowlisted fields only",
      );
      const json = JSON.stringify(out);
      assertTrue(!json.includes(MOD), "no moderator uid (answeredBy, moderatorId)");
      assertTrue(!json.includes("appellantId") && !json.includes(UID), "no appellant uid");
      assertTrue(!json.includes(OTHER), "no other party");
      assertTrue(!json.includes("content_removed"), "no decision record");
      assertTrue(!json.includes("anmälarens fritext"), "no report content");
      assertEqual(out.gdprArticle, "Article 15 - Right of Access", "article");
    },
  },
  {
    name: "never the other party's appeal on the same report",
    fn: async () => {
      const fake = new FakeFirestore();
      // The requester reported; the owner appealed. And the reverse.
      seedReport(fake, "r1", UID, OTHER);
      seedAppeal(fake, "r1", "owner", OTHER);
      seedReport(fake, "r2", OTHER, UID);
      seedAppeal(fake, "r2", "reporter", OTHER);
      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(out.appeals.length, 0, "no rows");
    },
  },
  {
    name: "an appeal whose report is gone is still the requester's",
    fn: async () => {
      const fake = new FakeFirestore();
      seedAppeal(fake, "deleted", "owner", UID);
      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(out.appeals.map((a) => a.role).join(","), "owner", "the owner's appeal");
    },
  },
  {
    name: "no appeals gives an empty list, not an error",
    fn: async () => {
      const fake = new FakeFirestore();
      seedReport(fake, "r4", UID, OTHER);
      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(out.appeals.length, 0, "empty");
    },
  },
  {
    name: "reports other people filed against the requester cannot make it decline",
    fn: async () => {
      const fake = new FakeFirestore();
      for (let i = 0; i <= exporter.MAX_APPEALS; i++) seedReport(fake, `c${i}`, OTHER, UID);
      seedAppeal(fake, "c0", "owner", UID);
      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(out.appeals.length, 1, "the one appeal");
    },
  },
  {
    name: "declines above the cap instead of truncating",
    fn: async () => {
      const fake = new FakeFirestore();
      for (let i = 0; i <= exporter.MAX_APPEALS; i++) seedAppeal(fake, `c${i}`, "reporter", UID);
      try {
        await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      } catch (err) {
        assertTrue(err instanceof HttpsError, `expected HttpsError, got ${String(err)}`);
        const e = err as HttpsError;
        assertEqual(e.code, "failed-precondition", "decline code");
        assertEqual(
          (e.details as { error_code?: string } | undefined)?.error_code,
          exporter.TOO_LARGE_ERROR_CODE,
          "decline error_code",
        );
        assertTrue(!/\d/.test(e.message), "the decline message carries no count");
        return;
      }
      throw new Error("expected a decline, the export succeeded");
    },
  },
  {
    name: "exactly at the cap still answers",
    fn: async () => {
      const fake = new FakeFirestore();
      for (let i = 0; i < exporter.MAX_APPEALS; i++) seedAppeal(fake, `c${i}`, "reporter", UID);
      const out = await exporter.runExportModerationAppealsWithDb(fake.db, UID);
      assertEqual(out.appeals.length, exporter.MAX_APPEALS, "all rows");
    },
  },
  {
    name: "unauthenticated is refused before anything runs",
    fn: async () => {
      const calls: string[] = [];
      try {
        await exporter.handleExportModerationAppeals(
          { auth: null },
          {
            rateLimit: async () => void calls.push("rateLimit"),
            run: async () => {
              calls.push("run");
              throw new Error("must not run");
            },
          },
        );
        throw new Error("expected unauthenticated");
      } catch (err) {
        assertTrue(err instanceof HttpsError, `got ${String(err)}`);
        assertEqual((err as HttpsError).code, "unauthenticated", "code");
      }
      assertEqual(calls.join(","), "", "nothing called");
    },
  },
  {
    name: "a forged payload uid is ignored; the rate limit runs first, on its own key",
    fn: async () => {
      const calls: string[] = [];
      const request = { auth: { uid: UID }, data: { uid: OTHER } };
      await exporter.handleExportModerationAppeals(request, {
        rateLimit: async (uid, op) => void calls.push(`rateLimit:${uid}:${op}`),
        run: async (uid) => {
          calls.push(`run:${uid}`);
          return { appeals: [], gdprArticle: "Article 15 - Right of Access" };
        },
      });
      assertEqual(
        calls.join(","),
        `rateLimit:${UID}:exportModerationAppeals,run:${UID}`,
        "uid from auth, rate limit before the run",
      );
    },
  },
];

runTests("BUT-2353 exportModerationAppeals", cases);
