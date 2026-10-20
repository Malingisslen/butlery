/**
 * BUT-2222: emulator-backed tests for `getMyReportOutcomes`
 * (`moderation/my-report-outcomes.ts`), and the handler of its owner-side twin
 * `getMyContentDecisions` (`moderation/my-content-decisions.ts`).
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
import { handleGetMyContentDecisions } from "../moderation/my-content-decisions";
import { MODERATION_DECISIONS } from "../moderation/report-decision";
import { MODERATION_APPEALS } from "../moderation/appeals";

const RUN = Date.now().toString(36);
const ME = `me${RUN}`;
const OTHER = `other${RUN}`;
const DECIDED = new Date("2026-10-01T10:00:00Z");
const ANSWERED = new Date("2026-10-05T10:00:00Z");

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
  motivation?: string,
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
      decidedAt: admin.firestore.Timestamp.fromDate(DECIDED),
      expireAt: admin.firestore.Timestamp.now(),
      ...(motivation !== undefined ? { motivation } : {}),
    });
  }
  return id;
}

async function main(): Promise<void> {
  console.log("my-report-outcomes integration");

  const removed = await report(ME, "closed", "content_removed");
  const hidden = await report(ME, "closed", "profile_hidden", "hidden_spam");
  const kept = await report(ME, "closed", "no_action");
  await db.collection(MODERATION_APPEALS).doc(`${kept}_reporter`).set({
    reportId: kept,
    role: "reporter",
    appellantId: ME,
    text: "jag tycker annorlunda",
    status: "reversed",
    createdAt: admin.firestore.Timestamp.fromDate(DECIDED),
    answeredAt: admin.firestore.Timestamp.fromDate(ANSWERED),
    answeredBy: `mod${RUN}`,
  });
  await db.collection(MODERATION_APPEALS).doc(`${hidden}_owner`).set({
    reportId: hidden,
    role: "owner",
    text: "ägarens överklagan",
    status: "open",
    createdAt: admin.firestore.Timestamp.fromDate(DECIDED),
    answeredAt: null,
  });
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
    "each outcome carries exactly the BUT-2353 keys",
    outcomes.every(
      (o) =>
        Object.keys(o).sort().join(",") ===
        "appeal,appealDeadline,appealable,decidedAt,decision,motivation,reportId,revised",
    ),
    JSON.stringify(outcomes[0]),
  );
  const removedOutcome = outcomes.find((o) => o.reportId === removed);
  check(
    "a record without a motivation gets its decision's default",
    removedOutcome?.motivation === "removed_other" &&
      outcomes.find((o) => o.reportId === kept)?.motivation === "kept_no_breach",
  );
  check(
    "a stored motivation is returned",
    outcomes.find((o) => o.reportId === hidden)?.motivation === "hidden_spam",
  );
  check(
    "decidedAt is ISO and the deadline is 183 days later",
    removedOutcome?.decidedAt === DECIDED.toISOString() &&
      removedOutcome?.appealDeadline ===
        new Date(DECIDED.getTime() + 183 * 86_400_000).toISOString(),
    JSON.stringify(removedOutcome),
  );
  check("no appeal reads as null", removedOutcome?.appeal === null);
  const appealed = outcomes.find((o) => o.reportId === kept)?.appeal;
  check(
    "the reporter's own appeal is returned with its state",
    appealed?.status === "reversed" &&
      appealed.text === "jag tycker annorlunda" &&
      appealed.submittedAt === DECIDED.toISOString() &&
      appealed.answeredAt === ANSWERED.toISOString(),
    JSON.stringify(appealed),
  );
  check(
    "an appeal carries exactly its four public keys, never the stored appellant",
    Object.keys(appealed ?? {}).sort().join(",") === "answeredAt,status,submittedAt,text" &&
      !JSON.stringify(outcomes).includes("appellantId"),
    JSON.stringify(appealed),
  );
  check(
    "the OWNER's appeal on the same report is not the reporter's",
    outcomes.find((o) => o.reportId === hidden)?.appeal === null,
  );
  check(
    "no moderator id anywhere in the response, not even the appeal's answerer",
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

  let decisionsThrew: unknown;
  const decisionsCalls: string[] = [];
  try {
    await handleGetMyContentDecisions({ auth: null }, {
      rateLimit: async () => void decisionsCalls.push("rateLimit"),
      run: async () => {
        decisionsCalls.push("run");
        return { decisions: [] };
      },
    });
  } catch (err) {
    decisionsThrew = err;
  }
  check(
    "getMyContentDecisions: an unauthenticated call is refused before anything runs",
    decisionsThrew instanceof HttpsError && decisionsThrew.code === "unauthenticated" &&
      decisionsCalls.length === 0,
  );

  const decisionsSeen: string[] = [];
  await handleGetMyContentDecisions(
    { auth: { uid: ME }, data: { uid: OTHER } } as unknown as { auth: { uid: string } },
    {
      rateLimit: async (uid, op) => {
        decisionsSeen.push(`${uid}:${op}`);
      },
      run: async (uid) => {
        decisionsSeen.push(`run:${uid}`);
        return { decisions: [] };
      },
    },
  );
  check(
    "getMyContentDecisions: the caller comes from auth, a payload uid is ignored, rate-limited on its own key",
    decisionsSeen.join("|") === `${ME}:getMyContentDecisions|run:${ME}`,
    decisionsSeen.join("|"),
  );

  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
