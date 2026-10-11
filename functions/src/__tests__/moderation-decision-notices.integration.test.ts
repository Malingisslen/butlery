/**
 * BUT-2353: emulator-backed tests for what a close now adds to the decision
 * record (`moderation/report-decision.ts`): the motivation key, and the inbox
 * rows for the reporter and the owner. Also the best-effort push
 * (`moderation/moderation-notices.ts`), against fake send seams, and the
 * trigger body that calls it (`moderation/on-report-decision.ts`).
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/moderation-decision-notices.integration.test.ts
 */

const PROJECT_ID = "butlery-moderation-decision-notices-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { MODERATION_DECISIONS, recordDecision } from "../moderation/report-decision";
import {
  NOTIFICATION_HISTORY,
  NOTICE_RETENTION_DAYS,
  Notice,
  noticeKey,
  pushNotices,
} from "../moderation/moderation-notices";
import { handleReportDecision, ReportDecisionEvent } from "../moderation/on-report-decision";

const RUN = Date.now().toString(36);
const REPORTER = `rep${RUN}`;
const OWNER = `own${RUN}`;
const NOW = new Date("2026-10-11T08:00:00Z");

/** The `notification_history` rules' `hasOnly` list, which a client update must keep satisfying. */
const HISTORY_KEYS = [
  "userId", "notificationId", "category", "type", "data",
  "sentAt", "delivered", "opened", "deliveredAt", "openedAt", "expireAt",
];

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
async function closedReport(
  extra: Record<string, unknown> = {},
  fixedId?: string,
): Promise<{ id: string; data: admin.firestore.DocumentData }> {
  const id = fixedId ?? `n${RUN}${seq++}`;
  const data = {
    reporterId: REPORTER,
    contentType: "recipe",
    contentId: `c${RUN}`,
    contentOwnerId: OWNER,
    reason: "spam",
    status: "closed",
    createdAt: admin.firestore.Timestamp.fromDate(NOW),
    ...extra,
  };
  await db.collection("reports").doc(id).set(data);
  return { id, data };
}

function decide(id: string, data: admin.firestore.DocumentData) {
  return recordDecision(db, {
    reportId: id,
    report: data,
    decidedAt: NOW,
    authType: "app_user",
    authId: `mod${RUN}`,
  });
}

async function motivationOf(id: string): Promise<unknown> {
  return (await db.collection(MODERATION_DECISIONS).doc(id).get()).get("motivation");
}

const reporterRowId = (reportId: string) => `moderation_${noticeKey(reportId)}_reporter`;
const ownerRowId = (reportId: string) => `moderation_${noticeKey(reportId)}_owner`;

async function row(id: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.collection(NOTIFICATION_HISTORY).doc(id).get()).data();
}

async function motivations(): Promise<void> {
  const cases: Array<[string, Record<string, unknown>, string]> = [
    ["a valid removal key is kept", { moderatorAction: "content_removed", motivation: "removed_spam" }, "removed_spam"],
    ["a key of another decision → the removal default", { moderatorAction: "content_removed", motivation: "hidden_spam" }, "removed_other"],
    ["no key on a removal → removed_other", { moderatorAction: "content_removed" }, "removed_other"],
    ["no key on a hide → hidden_rules", { moderatorAction: "profile_hidden", contentType: "profile" }, "hidden_rules"],
    ["a valid hide key is kept", { moderatorAction: "profile_hidden", contentType: "profile", motivation: "hidden_spam" }, "hidden_spam"],
    ["a valid dismissal key is kept", { motivation: "kept_unclear" }, "kept_unclear"],
    ["a non-string key → kept_no_breach", { motivation: 42 }, "kept_no_breach"],
    ["misattribution forces its own key", { reason: "misattribution", contentType: "menu_dish", motivation: "kept_unclear" }, "misattribution_name_removed"],
  ];
  for (const [name, extra, expected] of cases) {
    const { id, data } = await closedReport(extra);
    await decide(id, data);
    const got = await motivationOf(id);
    check(`motivation: ${name}`, got === expected, String(got));
  }

  const { id, data } = await closedReport({ motivation: "kept_unclear" });
  await decide(id, data);
  let stored = (await db.collection("reports").doc(id).get()).data();
  check("the close takes motivation off the report", stored !== undefined && !("motivation" in stored));
  // A second close write (or an admin re-stamp) after the record exists.
  await db.collection("reports").doc(id).update({ motivation: "kept_no_breach" });
  const again = await decide(id, data);
  stored = (await db.collection("reports").doc(id).get()).data();
  check(
    "a redelivery still takes motivation off, and keeps the first key",
    again.outcome === "already_recorded" && !("motivation" in (stored ?? {})) &&
      (await motivationOf(id)) === "kept_unclear",
  );
}

async function notices(): Promise<void> {
  const removed = await closedReport({ moderatorAction: "content_removed", motivation: "removed_spam" });
  const result = await decide(removed.id, removed.data);
  const reporterRow = await row(reporterRowId(removed.id));
  const ownerRow = await row(ownerRowId(removed.id));
  check("a removal tells the reporter", reporterRow?.userId === REPORTER);
  check("a removal tells the owner", ownerRow?.userId === OWNER);
  check(
    "the reporter row routes to /my_reports with the report id",
    reporterRow?.data?.route === "/my_reports" && reporterRow?.data?.targetId === removed.id,
    JSON.stringify(reporterRow?.data),
  );
  check(
    "the owner row routes to /my_content_decisions with the report id",
    ownerRow?.data?.route === "/my_content_decisions" && ownerRow?.data?.targetId === removed.id,
    JSON.stringify(ownerRow?.data),
  );
  check(
    "the rows carry the agreed lock-screen text and nothing about the case",
    reporterRow?.data?.title === "Din anmälan är avgjord" &&
      reporterRow?.data?.body === "Tryck för att läsa beslutet." &&
      ownerRow?.data?.title === "Det finns ett beslut om ditt innehåll" &&
      !JSON.stringify([reporterRow, ownerRow]).includes("spam"),
    JSON.stringify([reporterRow?.data, ownerRow?.data]),
  );
  check(
    "a row is unread, dated at the decision, and kept 90 days",
    reporterRow?.opened === false &&
      reporterRow?.sentAt?.toMillis() === NOW.getTime() &&
      reporterRow?.expireAt?.toMillis() - NOW.getTime() === NOTICE_RETENTION_DAYS * 86_400_000,
  );
  check(
    "a row's notificationId is its own document id, so opening it marks it",
    reporterRow?.notificationId === reporterRowId(removed.id),
  );
  const extraKeys = Object.keys(reporterRow ?? {}).filter((k) => !HISTORY_KEYS.includes(k));
  check("a row holds only keys the history rules admit", extraKeys.length === 0, extraKeys.join(","));
  check(
    "the result lists both notices for the push",
    result.notices.map((n) => n.userId).sort().join(",") === [OWNER, REPORTER].sort().join(","),
  );

  const kept = await closedReport();
  const keptResult = await decide(kept.id, kept.data);
  check(
    "a dismissal tells the reporter only",
    (await row(reporterRowId(kept.id))) !== undefined &&
      (await row(ownerRowId(kept.id))) === undefined &&
      keptResult.notices.length === 1,
  );

  const hidden = await closedReport({ moderatorAction: "profile_hidden", contentType: "profile" });
  await decide(hidden.id, hidden.data);
  check("a hide tells the owner", (await row(ownerRowId(hidden.id)))?.userId === OWNER);

  const dish = await closedReport({
    moderatorAction: "content_removed", reason: "misattribution", contentType: "menu_dish",
  });
  await decide(dish.id, dish.data);
  check(
    "a misattribution removal tells the reporter but not the sharer",
    (await row(reporterRowId(dish.id))) !== undefined &&
      (await row(ownerRowId(dish.id))) === undefined,
  );

  // The event still carries the reporter; the stored report no longer does.
  const erased = await closedReport({ moderatorAction: "content_removed" });
  await db.collection("reports").doc(erased.id).update({ reporterId: null });
  await decide(erased.id, erased.data);
  check(
    "a reporter erased since the close gets no row, read from the stored report",
    (await row(reporterRowId(erased.id))) === undefined &&
      (await row(ownerRowId(erased.id))) !== undefined,
  );

  const gone = await closedReport({ moderatorAction: "content_removed" });
  await db.collection("reports").doc(gone.id).delete();
  const goneResult = await decide(gone.id, gone.data);
  check(
    "a report deleted since the close tells nobody",
    goneResult.outcome === "recorded" && goneResult.notices.length === 0 &&
      (await row(reporterRowId(gone.id))) === undefined,
  );

  // A client-chosen report id near Firestore's 1500-byte limit: a raw id inside
  // the notice id would pass the limit and fail the record on every retry.
  const longId = `L${RUN}${"x".repeat(1489 - RUN.length)}`;
  const long = await closedReport({ moderatorAction: "content_removed" }, longId);
  const longResult = await decide(long.id, long.data);
  const longRow = await row(reporterRowId(long.id));
  check(
    "a 1490-byte report id is recorded, and its notices carry the raw id as targetId",
    Buffer.byteLength(long.id, "utf8") === 1490 && longResult.outcome === "recorded" &&
      (await db.collection(MODERATION_DECISIONS).doc(long.id).get()).exists &&
      longRow?.data?.targetId === long.id && longResult.notices.length === 2,
    `outcome=${longResult.outcome}`,
  );
  check(
    "notice ids have a fixed length whatever the report id",
    reporterRowId(long.id).length === reporterRowId("a").length,
  );

  // Redelivery: the rows the first run wrote were read and deleted by the
  // user; a redelivery must not put them back or push again.
  await db.collection(NOTIFICATION_HISTORY).doc(reporterRowId(removed.id)).delete();
  const redelivered = await decide(removed.id, removed.data);
  check(
    "a redelivery writes no rows and owes no pushes",
    redelivered.outcome === "already_recorded" && redelivered.notices.length === 0 &&
      (await row(reporterRowId(removed.id))) === undefined,
  );
}

async function pushes(): Promise<void> {
  const notice = (userId: string): Notice => ({
    id: `moderation_x_${userId}`,
    userId,
    title: "Din anmälan är avgjord",
    body: "Tryck för att läsa beslutet.",
    route: "/my_reports",
    targetId: "x",
    notificationType: "moderation_decision_reporter",
  });
  const sent: Array<{ uid: string; data: Record<string, string> | undefined }> = [];
  const prefs: Record<string, boolean | null> = { off: false, on: true, unset: null, boom: true };
  let threw = false;
  try {
    await pushNotices([notice("boom"), notice("off"), notice("on"), notice("unset")], {
      pushEnabled: async (uid) => prefs[uid],
      send: async (uid, _n, data) => {
        if (uid === "boom") throw new Error("fcm down");
        sent.push({ uid, data });
        return { successCount: 1, failureCount: 0 };
      },
    });
  } catch {
    threw = true;
  }
  check("a failing send is swallowed and the others still go", !threw);
  const uids = sent.map((s) => s.uid).sort().join(",");
  check("the master toggle off sends nothing; on or unset sends", uids === "on,unset", uids);
  const data = sent[0]?.data;
  check(
    "the push carries route, targetId, type and the row id",
    data?.route === "/my_reports" && data?.targetId === "x" &&
      data?.notificationType === "moderation_decision_reporter" &&
      data?.notificationId === "moderation_x_on",
    JSON.stringify(data),
  );
}

async function trigger(): Promise<void> {
  const { id, data } = await closedReport({ moderatorAction: "content_removed" });
  const event = (before: Record<string, unknown>): ReportDecisionEvent => ({
    data: { before: { data: () => before }, after: { data: () => data } },
    params: { reportId: id },
    time: NOW.toISOString(),
    authType: "app_user",
    authId: `mod${RUN}`,
  });
  const pushed: Notice[][] = [];
  const deps = {
    db,
    push: async (notices: Notice[]) => {
      pushed.push(notices);
    },
  };

  await handleReportDecision(event({ ...data, status: "in_review" }), deps);
  check(
    "the close pushes once, with one notice per inbox row it wrote",
    pushed.length === 1 &&
      pushed[0].map((n) => n.id).sort().join(",") === [ownerRowId(id), reporterRowId(id)].sort().join(",") &&
      (await row(reporterRowId(id))) !== undefined && (await row(ownerRowId(id))) !== undefined,
    JSON.stringify(pushed.map((p) => p.map((n) => n.id))),
  );

  await handleReportDecision(event({ ...data, status: "in_review" }), deps);
  check(
    "a redelivery hands the push no notices",
    pushed.length === 2 && pushed[1].length === 0,
    JSON.stringify(pushed.map((p) => p.length)),
  );

  await handleReportDecision(event({ ...data }), deps);
  check("an update that does not close the report never reaches the push", pushed.length === 2);
}

async function main(): Promise<void> {
  console.log("moderation decision notices integration");
  await motivations();
  await notices();
  await pushes();
  await trigger();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
