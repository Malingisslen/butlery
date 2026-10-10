/**
 * BUT-2222: emulator-backed tests for `getMyReportOutcomes`
 * (`moderation/my-report-outcomes.ts`).
 *
 * The headline property: a caller gets the decision on their own closed
 * reports.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/my-report-outcomes.integration.test.ts
 */

const PROJECT_ID = "butlery-my-report-outcomes-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { HttpsError } from "firebase-functions/v2/https";
import {
  handleGetMyReportOutcomes,
  runGetMyReportOutcomesWithDb,
} from "../moderation/my-report-outcomes";
import { MODERATION_DECISIONS } from "../moderation/report-decision";

const RUN = Date.now().toString(36);
const ME = `me${RUN}`;
const OTHER = `other${RUN}`;

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

let seq = 0;
async function report(
  reporterId: string | null,
  status: string,
  decision?: string,
): Promise<string> {
  const id = `r${RUN}${seq++}`;
  await db.collection("reports").doc(id).set({
    reporterId,
    status,
    contentType: "comment",
    contentId: `c${RUN}`,
    contentOwnerId: `owner${RUN}`,
    reason: "harassment",
    createdAt: admin.firestore.Timestamp.fromMillis(Date.UTC(2026, 9, 10) + seq * 1000),
  });
  if (decision !== undefined) {
    await db.collection(MODERATION_DECISIONS).doc(id).set({
      decision,
      rule: "harassment",
      contentType: "comment",
      moderatorId: `mod${RUN}`,
      decidedAt: admin.firestore.Timestamp.now(),
      expireAt: admin.firestore.Timestamp.now(),
    });
  }
  return id;
}

async function main(): Promise<void> {
  console.log("my-report-outcomes integration");

  const removed = await report(ME, "closed", "content_removed");
  const hidden = await report(ME, "closed", "profile_hidden");
  const kept = await report(ME, "closed", "no_action");
  const noRecord = await report(ME, "closed");
  const forged = await report(ME, "closed", "banned_forever");
  // An open case with a record left over from nowhere must not leak it.
  const open = await report(ME, "actioned", "content_removed");
  const theirs = await report(OTHER, "closed", "content_removed");
  const erased = await report(null, "closed", "content_removed");

  const { outcomes } = await runGetMyReportOutcomesWithDb(db, ME);
  const byId = new Map(outcomes.map((o) => [o.reportId, o.decision]));

  check("content_removed is returned", byId.get(removed) === "content_removed");
  check("profile_hidden is returned", byId.get(hidden) === "profile_hidden");
  check("no_action is returned", byId.get(kept) === "no_action");
  check("a closed report without a record is absent", !byId.has(noRecord));
  check("an unknown decision value is absent", !byId.has(forged));
  check("an open report is absent", !byId.has(open));
  check("another person's report is absent", !byId.has(theirs));
  check("a report whose reporter was erased is absent", !byId.has(erased));
  check(
    "each outcome carries reportId and decision only",
    outcomes.every((o) => Object.keys(o).sort().join(",") === "decision,reportId"),
  );
  check(
    "no moderator id anywhere in the response",
    !JSON.stringify(outcomes).includes(`mod${RUN}`),
  );

  const none = await runGetMyReportOutcomesWithDb(db, `nobody${RUN}`);
  check("a caller with no reports gets an empty list", none.outcomes.length === 0);

  let threw: unknown;
  try {
    await handleGetMyReportOutcomes({ auth: null }, {
      rateLimit: async () => undefined,
      run: async () => ({ outcomes: [] }),
    });
  } catch (err) {
    threw = err;
  }
  check(
    "an unauthenticated call is refused",
    threw instanceof HttpsError && threw.code === "unauthenticated",
  );

  const seen: string[] = [];
  await handleGetMyReportOutcomes(
    { auth: { uid: ME }, data: { uid: OTHER } } as unknown as { auth: { uid: string } },
    {
      rateLimit: async (uid, op) => {
        seen.push(`${uid}:${op}`);
      },
      run: async (uid) => {
        seen.push(`run:${uid}`);
        return { outcomes: [] };
      },
    },
  );
  check(
    "the caller comes from auth, a payload uid is ignored, and the call is rate-limited",
    seen.join("|") === `${ME}:getMyReportOutcomes|run:${ME}`,
    seen.join("|"),
  );

  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
