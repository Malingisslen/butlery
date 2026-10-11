/**
 * BUT-2353: emulator-backed tests for answering an appeal
 * (`moderation/answer-appeal.ts`, `moderation/appeal-reversal.ts`) and for an
 * appellant's erasure taking their appeals with it (`moderation/appeal-erasure.ts`,
 * `moderation/erasure-hold.ts`).
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/answer-appeal.integration.test.ts
 */

const PROJECT_ID = "butlery-answer-appeal-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { MODERATION_DECISIONS } from "../moderation/report-decision";
import { AppealRole, MODERATION_APPEALS } from "../moderation/appeals";
import {
  handleAnswerAppeal,
  parseAnswerAppeal,
  runAnswerAppealWithDb,
} from "../moderation/answer-appeal";
import { Notice, noticeKey } from "../moderation/moderation-notices";
import { deleteAppealsByAppellantWithDb } from "../moderation/appeal-erasure";
import { anonymizeReportsUnlessHeldWithDb } from "../moderation/erasure-hold";

const RUN = Date.now().toString(36);
const NOW = new Date("2026-10-11T09:00:00Z");
const ADMIN = `admin${RUN}`;

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

async function codeOf(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
    return "ok";
  } catch (err) {
    return err instanceof HttpsError ? `${err.code}:${err.message}` : `other:${String(err)}`;
  }
}

let seq = 0;
/** A closed case with a decision, a strike on the owner, and an open appeal. */
async function appealed(opts: {
  role: AppealRole;
  decision?: string;
  contentType?: string;
  owner?: string;
  /** Overrides the stored appellant; null stores none. */
  appellant?: string | null;
}): Promise<{ id: string; appealId: string; reporter: string; owner: string }> {
  const id = `x${RUN}${seq++}`;
  const reporter = `rep${id}`;
  const owner = opts.owner ?? `own${id}`;
  await db.collection("reports").doc(id).set({
    reporterId: reporter,
    contentOwnerId: owner,
    contentType: opts.contentType ?? "recipe",
    contentId: `c${id}`,
    reason: "abuse",
    status: "closed",
    createdAt: admin.firestore.Timestamp.fromDate(NOW),
  });
  await db.collection(MODERATION_DECISIONS).doc(id).set({
    decision: opts.decision ?? "content_removed",
    rule: "abuse",
    motivation: "removed_abuse",
    contentType: opts.contentType ?? "recipe",
    decidedAt: admin.firestore.Timestamp.fromDate(NOW),
    expireAt: admin.firestore.Timestamp.fromDate(NOW),
  });
  await db.doc(`user_moderation/${owner}`).set({ totalReports: 3 }, { merge: true });
  await db.doc(`user_moderation/${owner}/report_history/${id}`).set({ reportId: id, reporterId: reporter });
  const appealId = `${id}_${opts.role}`;
  const appellant =
    opts.appellant !== undefined ? opts.appellant : opts.role === "reporter" ? reporter : owner;
  await db.collection(MODERATION_APPEALS).doc(appealId).set({
    reportId: id,
    role: opts.role,
    ...(appellant !== null ? { appellantId: appellant } : {}),
    text: "Snälla titta igen på detta.",
    status: "open",
    createdAt: admin.firestore.Timestamp.fromDate(NOW),
    answeredAt: null,
    answeredBy: null,
    expireAt: admin.firestore.Timestamp.fromDate(NOW),
  });
  return { id, appealId, reporter, owner };
}

const answer = (appealId: string, outcome: "upheld" | "reversed") =>
  runAnswerAppealWithDb(db, ADMIN, { appealId, outcome }, NOW);

/** The inbox row an answer to [appealId] writes. */
const answerRow = (appealId: string) => `notification_history/appeal_${noticeKey(appealId)}`;

async function get(path: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.doc(path).get()).data();
}

async function answering(): Promise<void> {
  const upheld = await appealed({ role: "reporter" });
  const result = await answer(upheld.appealId, "upheld");
  const doc = await get(`${MODERATION_APPEALS}/${upheld.appealId}`);
  check(
    "an answer records outcome, time and moderator",
    doc?.status === "upheld" && doc?.answeredAt?.toMillis() === NOW.getTime() && doc?.answeredBy === ADMIN,
  );
  const row = await get(answerRow(upheld.appealId));
  check(
    "the reporter is told on /my_reports, with the report id",
    row?.userId === upheld.reporter && row?.data?.route === "/my_reports" &&
      row?.data?.targetId === upheld.id && row?.data?.title === "Din överklagan är besvarad" &&
      row?.data?.body === "Tryck för att läsa svaret.",
    JSON.stringify(row),
  );
  check("the answer returns that notice for the push", result.notices.length === 1);
  check(
    "upholding touches no strike",
    (await get(`user_moderation/${upheld.owner}`))?.totalReports === 3 &&
      (await get(`user_moderation/${upheld.owner}/report_history/${upheld.id}`)) !== undefined,
  );
  check(
    "an appeal is answered once",
    (await codeOf(() => answer(upheld.appealId, "reversed"))) === "failed-precondition:appeal_not_open" &&
      (await get(`${MODERATION_APPEALS}/${upheld.appealId}`))?.status === "upheld",
  );
  check(
    "a missing appeal → not-found",
    (await codeOf(() => answer(`nope${RUN}_owner`, "upheld"))) === "not-found:no_appeal",
  );

  const reporterReversed = await appealed({ role: "reporter", decision: "no_action" });
  // A row under the REPORTER's uid with the same report id: the shape a
  // reversal wrongly aimed at the appellant would delete.
  const decoy = `user_moderation/${reporterReversed.reporter}/report_history/${reporterReversed.id}`;
  await db.doc(decoy).set({ reportId: reporterReversed.id });
  const reporterResult = await answer(reporterReversed.appealId, "reversed");
  check(
    "reversing the REPORTER's appeal lifts no strike from anyone",
    (await get(`user_moderation/${reporterReversed.owner}/report_history/${reporterReversed.id}`)) !== undefined &&
      (await get(decoy)) !== undefined &&
      !reporterResult.effects.strikeRemoved,
  );
}

async function reversals(): Promise<void> {
  const removal = await appealed({ role: "owner" });
  // A second, independent case on the same owner: its strike must survive.
  const neighbour = await appealed({ role: "owner", owner: removal.owner });
  const result = await answer(removal.appealId, "reversed");
  check(
    "reversing a removal deletes that report's strike row",
    (await get(`user_moderation/${removal.owner}/report_history/${removal.id}`)) === undefined,
  );
  check(
    "…and counts the strike off",
    (await get(`user_moderation/${removal.owner}`))?.totalReports === 2,
  );
  check(
    "…and keeps the moderation document to its two readable keys",
    Object.keys((await get(`user_moderation/${removal.owner}`)) ?? {}).every((k) =>
      ["totalReports", "lastReportedAt"].includes(k),
    ),
  );
  check(
    "the owner is told on /my_content_decisions",
    (await get(answerRow(removal.appealId)))?.data?.route === "/my_content_decisions",
  );
  check("the effects are reported", result.effects.strikeRemoved && !result.effects.profileUnhidden);

  check(
    "only the appealed report's strike goes",
    (await get(`user_moderation/${removal.owner}/report_history/${neighbour.id}`)) !== undefined,
  );

  const hide = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
  await db.doc(`public_profiles/${hide.owner}`).set({ displayName: "X", isHidden: true, hiddenAt: admin.firestore.Timestamp.fromDate(NOW) });
  const hideResult = await answer(hide.appealId, "reversed");
  const profile = await get(`public_profiles/${hide.owner}`);
  check(
    "reversing a hide shows the profile again and clears hiddenAt",
    profile?.isHidden === false && profile?.hiddenAt === null && profile?.displayName === "X",
    JSON.stringify(profile),
  );
  check("…and says so", hideResult.effects.profileUnhidden === true);

  // The owner was hidden by two decisions; reversing one must not show them.
  const twice = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
  await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile", owner: twice.owner });
  await db.doc(`public_profiles/${twice.owner}`).set({ isHidden: true });
  const twiceResult = await answer(twice.appealId, "reversed");
  check(
    "a profile another standing decision hid stays hidden",
    (await get(`public_profiles/${twice.owner}`))?.isHidden === true && !twiceResult.effects.profileUnhidden,
  );

  const missingProfile = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
  check(
    "a reversal on a profile document that is gone does not fail or create it",
    (await codeOf(() => answer(missingProfile.appealId, "reversed"))) === "ok" &&
      (await get(`public_profiles/${missingProfile.owner}`)) === undefined,
  );

  // An appeal that names no appellant (none is written without one).
  const unnamed = await appealed({ role: "owner", appellant: null });
  const unnamedResult = await answer(unnamed.appealId, "reversed");
  check(
    "an appeal naming no appellant tells nobody and lifts nothing, and the answer still lands",
    unnamedResult.notices.length === 0 && !unnamedResult.effects.strikeRemoved &&
      (await get(answerRow(unnamed.appealId))) === undefined &&
      (await get(`${MODERATION_APPEALS}/${unnamed.appealId}`))?.status === "reversed",
  );

  // The appellant comes from the appeal, not the report: the report names
  // someone else, and the answer still reaches the appellant.
  const renamed = await appealed({ role: "owner" });
  await db.doc(`reports/${renamed.id}`).update({ contentOwnerId: `someone${RUN}` });
  await answer(renamed.appealId, "upheld");
  check(
    "the answer goes to the appellant the appeal stores",
    (await get(answerRow(renamed.appealId)))?.userId === renamed.owner,
  );

  // The reporter's erasure deletes the report while the owner, the strike and
  // the hide all remain; the decision record survives it.
  const orphan = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
  await db.doc(`public_profiles/${orphan.owner}`).set({ isHidden: true, hiddenAt: admin.firestore.Timestamp.fromDate(NOW) });
  await db.doc(`reports/${orphan.id}`).delete();
  const orphanResult = await answer(orphan.appealId, "reversed");
  check(
    "with the report gone, a reversed owner appeal still unhides the profile and lifts the strike",
    (await get(`public_profiles/${orphan.owner}`))?.isHidden === false &&
      (await get(`user_moderation/${orphan.owner}/report_history/${orphan.id}`)) === undefined &&
      orphanResult.effects.profileUnhidden && orphanResult.effects.strikeRemoved,
    JSON.stringify(orphanResult.effects),
  );
  check(
    "…and tells the owner",
    (await get(answerRow(orphan.appealId)))?.userId === orphan.owner &&
      orphanResult.notices.map((n) => n.userId).join(",") === orphan.owner,
  );

  // Fail closed: another profile report on the same owner whose hide cannot be
  // shown to be gone keeps the profile hidden.
  for (const [label, extra] of [
    ["a closed one with no decision record", { status: "closed" }],
    ["an open one whose takedown hid the profile", { status: "actioned", moderatorAction: "profile_hidden" }],
  ] as const) {
    const kept = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
    await db.collection("reports").doc(`${kept.id}other`).set({
      reporterId: `r${kept.id}`,
      contentOwnerId: kept.owner,
      contentType: "profile",
      reason: "abuse",
      ...extra,
    });
    await db.doc(`public_profiles/${kept.owner}`).set({ isHidden: true });
    const keptResult = await answer(kept.appealId, "reversed");
    check(
      `a profile with ${label} beside it stays hidden`,
      (await get(`public_profiles/${kept.owner}`))?.isHidden === true && !keptResult.effects.profileUnhidden,
    );
  }
  const dismissedBeside = await appealed({ role: "owner", decision: "profile_hidden", contentType: "profile" });
  const beside = await appealed({ role: "reporter", decision: "no_action", contentType: "profile", owner: dismissedBeside.owner });
  await db.doc(`public_profiles/${dismissedBeside.owner}`).set({ isHidden: true });
  await answer(dismissedBeside.appealId, "reversed");
  check(
    "a closed, dismissed profile report beside it does not keep the profile hidden",
    beside.id !== dismissedBeside.id && (await get(`public_profiles/${dismissedBeside.owner}`))?.isHidden === false,
  );
}

async function handler(): Promise<void> {
  const request = (token: Record<string, unknown> | null, data: unknown) =>
    ({ auth: token ? { uid: ADMIN, token } : undefined, data }) as unknown as CallableRequest<unknown>;
  const calls: string[] = [];
  const deps = {
    rateLimit: async (uid: string, op: string) => {
      calls.push(`limit:${uid}:${op}`);
    },
    run: async (uid: string, input: { appealId: string }) => {
      calls.push(`run:${uid}:${input.appealId}`);
      return {
        notices: [{ id: "n" } as Notice],
        effects: { strikeRemoved: false, profileUnhidden: false },
      };
    },
    push: async (notices: Notice[]) => {
      calls.push(`push:${notices.length}`);
    },
  };
  const valid = { appealId: "r1_owner", outcome: "upheld" };
  check(
    "an unauthenticated answer is refused",
    (await codeOf(() => handleAnswerAppeal(request(null, valid), deps))) ===
      "unauthenticated:Authentication required",
  );
  check(
    "a non-admin cannot answer",
    (await codeOf(() => handleAnswerAppeal(request({}, valid), deps))) ===
      "permission-denied:Admin access required" && calls.length === 0,
  );
  await handleAnswerAppeal(request({ admin: true }, valid), deps);
  check(
    "an admin's answer is rate-limited, run as the admin, then pushed",
    calls.join("|") === `limit:${ADMIN}:answerAppeal|run:${ADMIN}:r1_owner|push:1`,
    calls.join("|"),
  );
  const parse = (data: unknown) => {
    try {
      parseAnswerAppeal(data);
      return "ok";
    } catch (err) {
      return err instanceof HttpsError ? err.message : "other";
    }
  };
  check("an appeal id without a role suffix is refused", parse({ appealId: "r1", outcome: "upheld" }) === "invalid_appeal_id");
  check("a path in the appeal id is refused", parse({ appealId: "a/b_owner", outcome: "upheld" }) === "invalid_appeal_id");
  check("an unknown outcome is refused", parse({ appealId: "r1_owner", outcome: "maybe" }) === "invalid_outcome");
}

async function erasure(): Promise<void> {
  const owner = `gone${RUN}`;
  const mine = await appealed({ role: "owner", owner });
  // The same person as a reporter elsewhere, on a report that is already gone.
  const filed = await appealed({ role: "reporter" });
  await db.collection(MODERATION_APPEALS).doc(filed.appealId).update({ appellantId: owner });
  await db.doc(`reports/${filed.id}`).delete();
  // The other party's appeal on the person's own report.
  await db.collection(MODERATION_APPEALS).doc(`${mine.id}_reporter`).set({
    reportId: mine.id, role: "reporter", appellantId: mine.reporter, status: "open",
  });
  const someoneElse = await appealed({ role: "owner" });

  const deleted = await deleteAppealsByAppellantWithDb(db, owner);
  check(
    "an erased person's appeals go in both roles, a deleted report's included",
    deleted === 2 &&
      (await get(`${MODERATION_APPEALS}/${mine.appealId}`)) === undefined &&
      (await get(`${MODERATION_APPEALS}/${filed.appealId}`)) === undefined,
    `deleted ${deleted}`,
  );
  check(
    "the other party's appeal on the same report is kept",
    (await get(`${MODERATION_APPEALS}/${mine.id}_reporter`)) !== undefined,
  );
  check(
    "another owner's appeal is kept",
    (await get(`${MODERATION_APPEALS}/${someoneElse.appealId}`)) !== undefined,
  );

  const held = await appealed({ role: "owner" });
  await db.doc(`erasure_holds/${held.owner}`).set({ holdUntil: admin.firestore.Timestamp.fromDate(new Date("2027-04-01")) });
  await anonymizeReportsUnlessHeldWithDb(db, held.owner);
  check(
    "under a legal hold the report keeps the uid, but the appeal still goes",
    (await get(`reports/${held.id}`))?.contentOwnerId === held.owner &&
      (await get(`${MODERATION_APPEALS}/${held.appealId}`)) === undefined,
  );

  const free = await appealed({ role: "owner" });
  await anonymizeReportsUnlessHeldWithDb(db, free.owner);
  check(
    "with no hold the report is anonymised and the appeal goes",
    (await get(`reports/${free.id}`))?.contentOwnerId === null &&
      (await get(`${MODERATION_APPEALS}/${free.appealId}`)) === undefined,
  );
}

async function main(): Promise<void> {
  console.log("answer-appeal integration");
  await answering();
  await reversals();
  await handler();
  await erasure();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
