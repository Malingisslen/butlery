/**
 * Emulator-backed integration test for the WS3 idempotent `processReport`
 * core of the onReportCreated moderation trigger.
 *
 * Exercises the REAL subject (`processReport` from
 * `functions/src/feedback/on-report-created.ts`) against a live Firestore
 * emulator — not a hand-rolled re-implementation. The headline property:
 * re-delivering the SAME event must NOT double-count the strike counter or
 * duplicate the system_events row (onDocumentCreated is at-least-once).
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/on-report-created.integration.test.ts
 */

const PROJECT_ID = "butlery-on-report-created-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { processReport } = require("../feedback/on-report-created");

const RUN = Date.now().toString(36);

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function totalReports(owner: string): Promise<number> {
  const snap = await db.collection("user_moderation").doc(owner).get();
  return (snap.data()?.totalReports as number | undefined) ?? 0;
}

async function historyLength(owner: string): Promise<number> {
  const snap = await db.collection("user_moderation").doc(owner).get();
  const h = snap.data()?.reportHistory as unknown[] | undefined;
  return h?.length ?? 0;
}

async function docExists(coll: string, id: string): Promise<boolean> {
  return (await db.collection(coll).doc(id).get()).exists;
}

function report(reporterId: string, owner: string, reason = "spam") {
  return {
    reporterId,
    contentOwnerId: owner,
    contentType: "comment",
    contentId: `c-${reporterId}`,
    reason,
  };
}

async function main(): Promise<void> {
  console.log("onReportCreated idempotency integration tests (WS3)\n");
  console.log("=============================\n");

  const owner = `owner-${RUN}`;

  // First delivery of report r1 (event e1).
  await processReport(db, {
    reportId: `r1-${RUN}`,
    eventId: `e1-${RUN}`,
    report: report("alice", owner),
  });
  check("first delivery increments to 1", (await totalReports(owner)) === 1);
  check("first delivery records 1 history entry", (await historyLength(owner)) === 1);
  check(
    "first delivery writes deterministic content_report system_event",
    await docExists("system_events", `content_report_r1-${RUN}`),
  );

  // Re-deliver the SAME event (retry). Must NOT double-count or duplicate.
  await processReport(db, {
    reportId: `r1-${RUN}`,
    eventId: `e1-${RUN}`,
    report: report("alice", owner),
  });
  check("re-delivery does NOT double-count (still 1)", (await totalReports(owner)) === 1);
  check("re-delivery does NOT duplicate history (still 1)", (await historyLength(owner)) === 1);

  // A genuinely distinct report (event e2) counts.
  await processReport(db, {
    reportId: `r2-${RUN}`,
    eventId: `e2-${RUN}`,
    report: report("bob", owner),
  });
  check("distinct report increments to 2", (await totalReports(owner)) === 2);

  // Cross the moderation threshold (5) → deterministic alert doc appears.
  for (let i = 3; i <= 5; i++) {
    await processReport(db, {
      reportId: `r${i}-${RUN}`,
      eventId: `e${i}-${RUN}`,
      report: report(`user${i}`, owner),
    });
  }
  check("threshold reached at 5", (await totalReports(owner)) === 5);
  check(
    "threshold alert system_event written (deterministic id)",
    await docExists("system_events", `moderation_threshold_${owner}`),
  );

  // Report with no contentOwnerId still emits the content_report event but no
  // strike counter.
  await processReport(db, {
    reportId: `r-anon-${RUN}`,
    eventId: `e-anon-${RUN}`,
    report: {
      reporterId: "alice",
      contentType: "recipe",
      contentId: "rec-1",
      reason: "copyright",
    },
  });
  check(
    "unknown-owner report still logs content_report event",
    await docExists("system_events", `content_report_r-anon-${RUN}`),
  );

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
