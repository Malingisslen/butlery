/**
 * BUT-1528: emulator-backed tests for reopening a closed report
 * (`moderation/reopen-report.ts`), deciding it again
 * (`moderation/report-decision.ts`, `moderation/decision-revision.ts`) and the
 * moderator's list of decided reports (`moderation/list-closed-reports.ts`).
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/report-reopen.integration.test.ts
 */

const PROJECT_ID = "butlery-report-reopen-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { DECISION_RETENTION_DAYS, recordDecision, MODERATION_DECISIONS } from "../moderation/report-decision";
import { HISTORY_MAX, nextHistory } from "../moderation/decision-revision";
import { handleReopenReport, runReopenReportWithDb } from "../moderation/reopen-report";
import { runEvidenceLifecycle } from "../moderation/on-report-evidence-lifecycle";
import {
  decodeCursor,
  handleListClosedReports,
  runListClosedReportsWithDb,
  PAGE_SIZE,
} from "../moderation/list-closed-reports";
import { runGetMyContentDecisionsWithDb } from "../moderation/my-content-decisions";
import { runGetMyReportOutcomesWithDb } from "../moderation/my-report-outcomes";
import { runSubmitAppealWithDb } from "../moderation/submit-appeal";
import { noticeKey } from "../moderation/moderation-notices";

const RUN = Date.now().toString(36);
const MODERATOR = `mod${RUN}`;
const DAY = 24 * 60 * 60 * 1000;
const FILED = new Date(Date.now() - 20 * DAY);
const FIRST = new Date(Date.now() - 10 * DAY);
const SECOND = new Date(Date.now() - 1 * DAY);

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

async function get(path: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.doc(path).get()).data();
}

let seq = 0;
interface Case {
  id: string;
  reporter: string;
  owner: string;
}

/**
 * A report as filing leaves it (with its strike), closed with [action] and
 * decided once.
 */
async function decidedCase(
  action: "content_removed" | "profile_hidden" | null,
  extra: Record<string, unknown> = {},
): Promise<Case> {
  const n = seq++;
  const c = { id: `ro${RUN}${n}`, reporter: `rep${RUN}${n}`, owner: `own${RUN}${n}` };
  const data: admin.firestore.DocumentData = {
    reporterId: c.reporter,
    contentType: action === "profile_hidden" ? "profile" : "comment",
    contentId: action === "profile_hidden" ? c.owner : `c${RUN}${n}`,
    contentOwnerId: c.owner,
    reason: "harassment",
    description: "free text",
    status: "closed",
    createdAt: admin.firestore.Timestamp.fromDate(FILED),
    ...(action ? { moderatorAction: action } : {}),
    ...extra,
  };
  await db.doc(`reports/${c.id}`).set(data);
  await db.doc(`user_moderation/${c.owner}`).set({ totalReports: 1 });
  await db.doc(`user_moderation/${c.owner}/report_history/${c.id}`).set({ reportId: c.id });
  if (action === "profile_hidden") {
    await db.doc(`public_profiles/${c.owner}`).set({ isHidden: true });
  }
  await recordDecision(db, {
    reportId: c.id,
    report: data,
    decidedAt: FIRST,
    authType: "app_user",
    authId: MODERATOR,
  });
  return c;
}

/** The moderator closes the reopened report as it now stands. */
async function closeAgain(id: string, patch: Record<string, unknown> = {}) {
  const ref = db.doc(`reports/${id}`);
  await ref.update({ status: "closed", ...patch });
  const after = (await ref.get()).data()!;
  return {
    after,
    result: await recordDecision(db, {
      reportId: id,
      report: after,
      decidedAt: SECOND,
      authType: "app_user",
      authId: MODERATOR,
    }),
  };
}

async function refusal(fn: () => Promise<unknown>): Promise<string | null> {
  try {
    await fn();
    return null;
  } catch (err) {
    return err instanceof HttpsError ? err.message : String(err);
  }
}

async function auditOps(id: string): Promise<string[]> {
  const snap = await db.collection("audit_logs").where("resourceId", "==", id).get();
  return snap.docs.map((d) => d.get("operation")).sort();
}

async function firstCloseNoAction(): Promise<void> {
  const c = await decidedCase(null);
  check(
    "K1: a first close with no action takes the filing strike off",
    (await get(`user_moderation/${c.owner}/report_history/${c.id}`)) === undefined &&
      (await get(`user_moderation/${c.owner}`))?.totalReports === 0,
  );
  const kept = await decidedCase("content_removed");
  check(
    "K1: a first close with an action keeps the strike",
    (await get(`user_moderation/${kept.owner}/report_history/${kept.id}`)) !== undefined &&
      (await get(`user_moderation/${kept.owner}`))?.totalReports === 1,
  );
  check("the first close writes one audit row", (await auditOps(kept.id)).join() === "moderation_decision_recorded");
}

async function reopening(): Promise<void> {
  const c = await decidedCase("profile_hidden");
  const { round } = await runReopenReportWithDb(db, MODERATOR, c.id);
  const report = await get(`reports/${c.id}`);
  check("reopen starts round 1", round === 1 && report?.reviewRound === 1);
  check("the case is back in the queue as actioned", report?.status === "actioned");
  check("the standing action is put back on the report", report?.moderatorAction === "profile_hidden");
  check("the reopen names the decision under review", report?.reopenedDecision === "profile_hidden");
  check(
    "nothing else changes: the profile stays hidden and the strike stays",
    (await get(`public_profiles/${c.owner}`))?.isHidden === true &&
      (await get(`user_moderation/${c.owner}/report_history/${c.id}`)) !== undefined,
  );
  check(
    "reopening writes an audit row",
    (await auditOps(c.id)).includes("moderation_report_reopened"),
  );
  check(
    "a report that is not closed cannot be reopened",
    (await refusal(() => runReopenReportWithDb(db, MODERATOR, c.id))) === "not_closed",
  );
  const toReporter = await get(`notification_history/moderation_${noticeKey(c.id)}_reporter_r1`);
  const toOwner = await get(`notification_history/moderation_${noticeKey(c.id)}_owner_r1`);
  check("reopening tells nobody", toReporter === undefined && toOwner === undefined);

  const ownerView = (await runGetMyContentDecisionsWithDb(db, c.owner)).decisions.find((d) => d.reportId === c.id);
  check(
    "the owner keeps seeing the last decision while the case is reopened, not appealable",
    ownerView?.decision === "profile_hidden" && ownerView.appealable === false,
  );
  const reporterRow = (await runGetMyReportOutcomesWithDb(db, c.reporter)).outcomes.find((o) => o.reportId === c.id);
  check("the reporter's row is not appealable while reopened", reporterRow?.appealable === false);
  check(
    "an appeal on a reopened case is refused",
    (await refusal(() =>
      runSubmitAppealWithDb(db, c.reporter, { reportId: c.id, role: "reporter", text: "Jag håller inte med." }),
    )) === "no_decision",
  );

  // B1: the round-0 close event delivered again after the reopen.
  const round0 = await recordDecision(db, {
    reportId: c.id,
    report: { ...(await get(`reports/${c.id}`)), status: "closed", reviewRound: undefined },
    decidedAt: FIRST,
    authType: "app_user",
    authId: MODERATOR,
  });
  check(
    "a late round-0 delivery records nothing and leaves the reopened stamp",
    round0.outcome === "already_recorded" &&
      (await get(`reports/${c.id}`))?.moderatorAction === "profile_hidden" &&
      (await get(`reports/${c.id}`))?.reopenedDecision === "profile_hidden",
  );
}

async function refusals(): Promise<void> {
  for (const [name, status] of [["open", "open"], ["answered", "upheld"]] as const) {
    const c = await decidedCase("content_removed");
    await db.doc(`moderation_appeals/${c.id}_owner`).set({ reportId: c.id, status });
    check(
      `D1: an ${name} appeal blocks the reopen`,
      (await refusal(() => runReopenReportWithDb(db, MODERATOR, c.id))) === "appealed",
    );
  }
  const erased = await decidedCase("content_removed");
  await db.doc(`reports/${erased.id}`).update({ reporterId: null });
  check(
    "a report whose reporter erased their account cannot be reopened",
    (await refusal(() => runReopenReportWithDb(db, MODERATOR, erased.id))) === "reporter_erased",
  );
  const anon = await decidedCase("content_removed");
  await db.doc(`reports/${anon.id}`).update({ contentOwnerId: null });
  check(
    "a report whose owner is gone cannot be reopened",
    (await refusal(() => runReopenReportWithDb(db, MODERATOR, anon.id))) === "owner_erased",
  );
  check(
    "a missing report cannot be reopened",
    (await refusal(() => runReopenReportWithDb(db, MODERATOR, `missing${RUN}`))) === "report_gone",
  );
  const pending = await decidedCase("content_removed");
  await runReopenReportWithDb(db, MODERATOR, pending.id);
  await db.doc(`reports/${pending.id}`).update({ status: "closed" });
  check(
    "a close whose decision is not recorded yet cannot be reopened",
    (await refusal(() => runReopenReportWithDb(db, MODERATOR, pending.id))) === "no_decision",
  );
}

async function unchanged(): Promise<void> {
  const c = await decidedCase("content_removed");
  const before = await get(`${MODERATION_DECISIONS}/${c.id}`);
  await runReopenReportWithDb(db, MODERATOR, c.id);
  const { result } = await closeAgain(c.id);
  const row = await get(`${MODERATION_DECISIONS}/${c.id}`);
  check("an unchanged re-close is recorded", result.outcome === "recorded" && result.notices.length === 0);
  check(
    "it keeps decidedAt and expireAt and notes the confirmation",
    row?.decidedAt.toMillis() === before?.decidedAt.toMillis() &&
      row?.expireAt.toMillis() === before?.expireAt.toMillis() &&
      row?.reconfirmedAt instanceof admin.firestore.Timestamp &&
      row?.revision === 1 && row?.history === undefined,
  );
  check(
    "the stamps come off the closed report",
    (await get(`reports/${c.id}`))?.moderatorAction === undefined &&
      (await get(`reports/${c.id}`))?.reopenedDecision === undefined,
  );
  check(
    "the strike is untouched",
    (await get(`user_moderation/${c.owner}`))?.totalReports === 1,
  );
  check(
    "an unchanged re-close writes a reconfirmed row",
    (await auditOps(c.id)).includes("moderation_decision_reconfirmed"),
  );
}

async function changedToNoAction(): Promise<void> {
  const c = await decidedCase("profile_hidden");
  await runReopenReportWithDb(db, MODERATOR, c.id);
  // "Ändra till Ingen åtgärd": the app takes the action off the open report.
  await db.doc(`reports/${c.id}`).update({ moderatorAction: admin.firestore.FieldValue.delete() });
  const { result } = await closeAgain(c.id);
  const row = await get(`${MODERATION_DECISIONS}/${c.id}`);
  check("a changed decision is recorded", result.outcome === "recorded" && row?.decision === "no_action");
  check(
    "the changed close takes the decision under review off the report",
    (await get(`reports/${c.id}`))?.reopenedDecision === undefined,
  );
  check(
    "the old decision moves into history with its moderator and time",
    Array.isArray(row?.history) && row?.history.length === 1 &&
      row?.history[0].decision === "profile_hidden" &&
      row?.history[0].moderatorId === MODERATOR &&
      row?.history[0].decidedAt.toMillis() === FIRST.getTime(),
  );
  check(
    "decidedAt moves to the new decision and revisedAt is set",
    row?.decidedAt.toMillis() === SECOND.getTime() && row?.revisedAt.toMillis() === SECOND.getTime(),
  );
  check(
    "the changed record's expiry counts from the new decision",
    row?.expireAt.toMillis() === SECOND.getTime() + DECISION_RETENTION_DAYS * DAY,
  );
  check(
    "decision 3: the strike is removed",
    (await get(`user_moderation/${c.owner}/report_history/${c.id}`)) === undefined &&
      (await get(`user_moderation/${c.owner}`))?.totalReports === 0,
  );
  check("the hide is lifted", (await get(`public_profiles/${c.owner}`))?.isHidden === false);
  const ids = result.notices.map((n) => n.id).sort();
  check(
    "K3: both people are told, on rows of their own",
    ids.length === 2 && ids.every((id) => id.endsWith("_r1")) &&
      result.notices.some((n) => n.userId === c.reporter) &&
      result.notices.some((n) => n.userId === c.owner),
    ids.join(),
  );
  check(
    "the change writes a changed row",
    (await auditOps(c.id)).includes("moderation_decision_changed"),
  );

  const again = await recordDecision(db, {
    reportId: c.id,
    report: { ...(await get(`reports/${c.id}`)), status: "closed" },
    decidedAt: SECOND,
    authType: "app_user",
    authId: MODERATOR,
  });
  check("a redelivery of round 1 records nothing", again.outcome === "already_recorded" && again.notices.length === 0);

  const owner = await runGetMyContentDecisionsWithDb(db, c.owner);
  const mine = owner.decisions.find((d) => d.reportId === c.id);
  check("the owner still sees a decision changed to no action, marked revised", mine?.decision === "no_action" && mine?.revised === true);
  check("the owner cannot appeal a decision changed to no action", mine?.appealable === false);
  const reporterMine = (await runGetMyReportOutcomesWithDb(db, c.reporter)).outcomes.find((o) => o.reportId === c.id);
  check("the reporter can appeal the changed decision", reporterMine?.appealable === true);
  check(
    "the changed-decision titles name the change",
    result.notices.find((n) => n.userId === c.reporter)?.title === "Beslutet om din anmälan har ändrats" &&
      result.notices.find((n) => n.userId === c.owner)?.title === "Ett beslut om ditt innehåll har ändrats",
  );
}

async function changedToAction(): Promise<void> {
  const c = await decidedCase(null);
  await runReopenReportWithDb(db, MODERATOR, c.id);
  check("a no-action case reopens without a stamp", (await get(`reports/${c.id}`))?.moderatorAction === undefined);
  check("a no-action reopen names no_action as under review", (await get(`reports/${c.id}`))?.reopenedDecision === "no_action");
  const reporterView = await runGetMyReportOutcomesWithDb(db, c.reporter);
  check(
    "the reporter keeps seeing the last decision while the case is reopened",
    reporterView.outcomes.some((o) => o.reportId === c.id && o.decision === "no_action"),
  );
  const { result } = await closeAgain(c.id, { moderatorAction: "content_removed" });
  check("no action → removed is recorded", result.outcome === "recorded");
  check(
    "K3: the newly struck owner is told too",
    result.notices.length === 2 &&
      result.notices.some((n) => n.userId === c.reporter && n.id.endsWith("_reporter_r1")) &&
      result.notices.some((n) => n.userId === c.owner && n.id.endsWith("_owner_r1")),
    result.notices.map((n) => n.id).join(),
  );
  const strike = await get(`user_moderation/${c.owner}/report_history/${c.id}`);
  check(
    "the strike comes back, expiring 180 days after filing",
    strike !== undefined && strike.expireAt.toMillis() === FILED.getTime() + 180 * DAY &&
      (await get(`user_moderation/${c.owner}`))?.totalReports === 1,
  );

  const old = await decidedCase(null, { createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 200 * DAY)) });
  await runReopenReportWithDb(db, MODERATOR, old.id);
  await closeAgain(old.id, { moderatorAction: "content_removed" });
  const forged = await decidedCase(null, { createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3650 * DAY)) });
  await runReopenReportWithDb(db, MODERATOR, forged.id);
  await closeAgain(forged.id, { moderatorAction: "content_removed" });
  const forgedStrike = await get(`user_moderation/${forged.owner}/report_history/${forged.id}`);
  check(
    "a future createdAt cannot stretch a revived strike past 180 days from the decision",
    forgedStrike !== undefined && forgedStrike.expireAt.toMillis() === SECOND.getTime() + 180 * DAY,
  );
  check(
    "a revived strike leaves lastReportedAt alone",
    (await get(`user_moderation/${c.owner}`))?.lastReportedAt === undefined,
  );

  check(
    "a strike past its 180 days is not revived",
    (await get(`user_moderation/${old.owner}/report_history/${old.id}`)) === undefined,
  );
}

async function listing(): Promise<void> {
  // More records than a page, all at one time, so a page boundary falls on
  // the document-id tiebreak even on a fresh emulator.
  const seeded = Array.from({ length: PAGE_SIZE + 5 }, (_, i) => `ro${RUN}p${String(i).padStart(3, "0")}`);
  await Promise.all(
    seeded.map((id) =>
      db.doc(`${MODERATION_DECISIONS}/${id}`).set({
        decision: "no_action",
        rule: "other",
        decidedAt: admin.firestore.Timestamp.fromDate(FIRST),
        revision: 0,
      }),
    ),
  );
  const page = await runListClosedReportsWithDb(db, MODERATOR, null);
  check("the list has rows, newest decision first", page.reports.length > 0 &&
    page.reports.every((r, i, all) => i === 0 || (all[i - 1].decidedAt ?? "") >= (r.decidedAt ?? "")));
  const serialized = JSON.stringify(page);
  check(
    "no reporter or owner uid and no text in the list",
    !serialized.includes(`rep${RUN}`) && !serialized.includes(`own${RUN}`) && !serialized.includes("free text"),
  );
  check("the moderator is named as self", page.reports.some((r) => r.moderator === "self"));
  let pages = 0;
  let cursor = page.nextCursor ? decodeCursor(page.nextCursor) : null;
  const all = [...page.reports];
  const seen = new Set(page.reports.map((r) => r.reportId));
  let dup = false;
  while (cursor && pages < 1000) {
    const next = await runListClosedReportsWithDb(db, MODERATOR, cursor);
    for (const r of next.reports) {
      if (seen.has(r.reportId)) dup = true;
      seen.add(r.reportId);
    }
    all.push(...next.reports);
    cursor = next.nextCursor ? decodeCursor(next.nextCursor) : null;
    pages++;
  }
  // This run's rows only: an emulator kept between runs holds older ones.
  const mine = all.filter((r) => r.reportId.startsWith(`ro${RUN}`));
  const appealed = mine.find((r) => r.appealed);
  check("an appealed row is blocked", appealed?.reopenBlock === "appealed");
  const revised = mine.filter((r) => r.history.length > 0);
  check(
    "a revised row carries its earlier decision",
    revised.some((r) => r.decision === "no_action" && r.history[0].decision === "profile_hidden"),
  );
  check("paging reads past the first page", pages > 0, `pages=${pages}`);
  check("paging never repeats a row", !dup);
  check("paging returns every seeded row", seeded.every((id) => seen.has(id)));

  const full = { history: Array.from({ length: HISTORY_MAX }, (_, i) => ({ decision: `d${i}` })), decision: "new" };
  const capped = nextHistory(full);
  check(
    "history keeps the last ten decisions, oldest dropped",
    capped.length === HISTORY_MAX && capped[0].decision === "d1" && capped[HISTORY_MAX - 1].decision === "new",
  );

  const request = (auth: unknown, data: unknown) =>
    ({ auth, data } as unknown as CallableRequest<unknown>);
  const deps = { rateLimit: async () => undefined, run: async () => ({ reports: [], nextCursor: null }) };
  check(
    "a signed-in non-admin is refused",
    (await refusal(() => handleListClosedReports(request({ uid: "x", token: {} }, {}), deps))) ===
      "Admin access required",
  );
  check(
    "a forged cursor is refused",
    (await refusal(() =>
      handleListClosedReports(request({ uid: "x", token: { admin: true } }, { cursor: "a/b" }), deps),
    )) === "invalid_cursor",
  );
  const farFuture = Buffer.from(JSON.stringify([Number.MAX_SAFE_INTEGER, "abc"])).toString("base64url");
  check(
    "a cursor past year 9999 is refused as a cursor",
    (await refusal(() =>
      handleListClosedReports(request({ uid: "x", token: { admin: true } }, { cursor: farFuture }), deps),
    )) === "invalid_cursor",
  );
}

async function reopenHandler(): Promise<void> {
  const request = (auth: unknown, data: unknown) =>
    ({ auth, data } as unknown as CallableRequest<unknown>);
  const calls: string[] = [];
  const deps = {
    rateLimit: async () => undefined,
    run: async (_uid: string, id: string) => {
      calls.push(`run:${id}`);
      return { round: 1 };
    },
    captureEvidence: async (id: string) => {
      calls.push(`capture:${id}`);
      return "captured";
    },
  };
  check(
    "a non-admin cannot reopen",
    (await refusal(() => handleReopenReport(request({ uid: "x", token: {} }, { reportId: "r1" }), deps))) ===
      "Admin access required" &&
      calls.length === 0,
  );
  check(
    "a malformed report id is refused",
    (await refusal(() =>
      handleReopenReport(request({ uid: "x", token: { admin: true } }, { reportId: "a/b" }), deps),
    )) === "invalid_report_id" && calls.length === 0,
  );
  await handleReopenReport(request({ uid: "x", token: { admin: true } }, { reportId: "r1" }), deps);
  check(
    "a reopen takes a fresh copy once, after the commit",
    calls.join(",") === "run:r1,capture:r1",
    calls.join(","),
  );

  const c = await decidedCase("content_removed");
  await db.doc(`report_evidence/${c.id}`).set({ reportId: c.id, outcome: "captured" });
  await runReopenReportWithDb(db, MODERATOR, c.id);
  check("a reopen deletes a copy the close left behind", (await get(`report_evidence/${c.id}`)) === undefined);

  await db.doc(`report_evidence/${c.id}`).set({ reportId: c.id, outcome: "captured" });
  const open = { status: "actioned", contentOwnerId: c.owner };
  const closed = { status: "closed", contentOwnerId: c.owner };
  check(
    "a late close event leaves the copy of a case open again",
    (await runEvidenceLifecycle(db, c.id, open, closed)) === null &&
      (await get(`report_evidence/${c.id}`)) !== undefined,
  );
  await db.doc(`reports/${c.id}`).update({ status: "closed" });
  check(
    "a close event still deletes the copy of a closed case",
    (await runEvidenceLifecycle(db, c.id, open, closed)) === "report_closed" &&
      (await get(`report_evidence/${c.id}`)) === undefined,
  );
}

async function main(): Promise<void> {
  console.log("report-reopen integration");
  await firstCloseNoAction();
  await reopening();
  await refusals();
  await unchanged();
  await changedToNoAction();
  await changedToAction();
  await listing();
  await reopenHandler();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
