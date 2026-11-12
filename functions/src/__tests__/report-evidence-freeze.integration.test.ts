/**
 * BUT-2329: emulator-backed tests for freezing a report's text copy
 * (`moderation/freeze-report-evidence.ts`) and for every path that deletes a
 * copy leaving a frozen one alone.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/report-evidence-freeze.integration.test.ts
 */

const PROJECT_ID = "butlery-report-evidence-freeze-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import {
  FREEZE_MAX_DAYS,
  FREEZE_PERIOD_DAYS,
  frozenEvidenceRetained,
  handleFreezeReportEvidence,
  parseFreezeRequest,
  runFreezeWithDb,
} from "../moderation/freeze-report-evidence";
import { runEvidenceLifecycle } from "../moderation/on-report-evidence-lifecycle";
import { runReopenReportWithDb } from "../moderation/reopen-report";
import { MODERATION_DECISIONS } from "../moderation/report-decision";
import { EVIDENCE_RETENTION_DAYS, REPORT_EVIDENCE } from "../moderation/report-evidence";

const RUN = Date.now().toString(36);
const MOD = `mod${RUN}`;
const REPORTER = `rep${RUN}`;
const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date();
const ts = admin.firestore.Timestamp.fromDate;

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

async function refusal(fn: () => Promise<unknown>): Promise<string | null> {
  try {
    await fn();
    return null;
  } catch (err) {
    return err instanceof HttpsError ? `${err.code}:${err.message}` : String(err);
  }
}

let seq = 0;
/** An open report with a captured copy, as `captureReportEvidence` writes one. */
async function openCase(
  opts: { owner?: string; outcome?: string; capturedDaysAgo?: number; facts?: object } = {},
): Promise<{ id: string; owner: string }> {
  const id = `f${RUN}${seq++}`;
  const owner = opts.owner ?? `own${RUN}${seq}`;
  const captured = new Date(NOW.getTime() - (opts.capturedDaysAgo ?? 1) * DAY);
  await db.collection("reports").doc(id).set({
    reporterId: REPORTER,
    contentType: "message",
    contentId: `m${id}`,
    contentOwnerId: owner,
    reason: "abuse",
    status: "new",
    createdAt: ts(captured),
  });
  await db.collection(REPORT_EVIDENCE).doc(id).set({
    reportId: id,
    contentType: "message",
    contentId: `m${id}`,
    contentOwnerId: owner,
    capturedAt: ts(captured),
    expireAt: ts(new Date(captured.getTime() + EVIDENCE_RETENTION_DAYS * DAY)),
    outcome: opts.outcome ?? "captured",
    text: { content: "hotfullt meddelande" },
    truncated: false,
    ...(opts.facts ?? {}),
  });
  return { id, owner };
}

async function copy(id: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.collection(REPORT_EVIDENCE).doc(id).get()).data();
}

async function report(id: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.collection("reports").doc(id).get()).data();
}

async function auditOps(id: string): Promise<string[]> {
  const snap = await db.collection("audit_logs").where("resourceId", "==", id).get();
  return snap.docs.map((d) => d.get("operation") as string).sort();
}

/** Runs the lifecycle trigger for one write, as Firestore would deliver it. */
async function write(id: string, patch: Record<string, unknown> | null): Promise<string | null> {
  const before = await report(id);
  if (patch === null) {
    await db.collection("reports").doc(id).delete();
  } else {
    await db.collection("reports").doc(id).update(patch);
  }
  return runEvidenceLifecycle(db, id, before, await report(id));
}

const freeze = (id: string, reason = "police", now = NOW) =>
  runFreezeWithDb(db, MOD, parseFreezeRequest({ reportId: id, action: "freeze", reason }), now);
const extend = (id: string, reason = "threat", now = NOW) =>
  runFreezeWithDb(db, MOD, parseFreezeRequest({ reportId: id, action: "extend", reason }), now);
const release = (id: string, now = NOW) =>
  runFreezeWithDb(db, MOD, parseFreezeRequest({ reportId: id, action: "release" }), now);

async function parsing(): Promise<void> {
  console.log("\nparseFreezeRequest");
  const bad = (data: unknown) => {
    try {
      parseFreezeRequest(data);
      return null;
    } catch (err) {
      return err instanceof HttpsError ? err.message : String(err);
    }
  };
  check("unknown action refused", bad({ reportId: "a", action: "forever", reason: "police" }) === "invalid_action");
  check("unknown reason refused", bad({ reportId: "a", action: "freeze", reason: "annat" }) === "invalid_reason");
  check("freeze without reason refused", bad({ reportId: "a", action: "freeze" }) === "invalid_reason");
  check("bad report id refused", bad({ reportId: "a/b", action: "release" }) === "invalid_report_id");
  check("release needs no reason", bad({ reportId: "a", action: "release" }) === null);
}

async function freezing(): Promise<void> {
  console.log("\nfreeze");
  const { id } = await openCase();
  const out = await freeze(id);
  const c = await copy(id);
  const until = c?.frozen?.until?.toDate() as Date | undefined;
  check("freeze stores reason and moderator", c?.frozen?.reason === "police" && c?.frozen?.frozenBy === MOD);
  check("until is one year on", until?.getTime() === NOW.getTime() + FREEZE_PERIOD_DAYS * DAY);
  check("TTL follows until", c?.expireAt?.toMillis() === until?.getTime());
  check("callable returns until", out.action === "freeze" && out.until === until?.toISOString());
  check("audit row written", (await auditOps(id)).includes("moderation_evidence_frozen"));
  check("second freeze refused", (await refusal(() => freeze(id))) === "failed-precondition:already_frozen");

  const missing = await openCase({ outcome: "missing" });
  check("a copy without text cannot be frozen",
    (await refusal(() => freeze(missing.id))) === "failed-precondition:not_captured");
  const expired = await openCase({ capturedDaysAgo: EVIDENCE_RETENTION_DAYS + 1 });
  check("a copy past its TTL cannot be frozen",
    (await refusal(() => freeze(expired.id))) === "failed-precondition:no_copy");
  check("no copy cannot be frozen",
    (await refusal(() => freeze(`none${RUN}`))) === "failed-precondition:no_copy");
}

async function extending(): Promise<void> {
  console.log("\nextend");
  const { id } = await openCase();
  check("extend before freeze refused", (await refusal(() => extend(id))) === "failed-precondition:not_frozen");
  await freeze(id);
  const later = new Date(NOW.getTime() + 300 * DAY);
  await extend(id, "legal_claim", later);
  let c = await copy(id);
  check("extend moves until a year from now",
    c?.frozen?.until?.toMillis() === later.getTime() + FREEZE_PERIOD_DAYS * DAY);
  check("extend keeps the first freeze", c?.frozen?.firstFrozenAt?.toMillis() === NOW.getTime());
  check("extend records the new reason", c?.frozen?.reason === "legal_claim" && c?.frozen?.extensions === 1);

  await extend(id, "police", new Date(NOW.getTime() + 600 * DAY));
  const nearCap = new Date(NOW.getTime() + (FREEZE_MAX_DAYS - 195) * DAY);
  await extend(id, "police", nearCap);
  c = await copy(id);
  check("extend stops at the three-year cap",
    c?.frozen?.until?.toMillis() === NOW.getTime() + FREEZE_MAX_DAYS * DAY);
  check("extend at the cap refused",
    (await refusal(() => extend(id, "police", nearCap))) === "failed-precondition:at_cap");

  const lapsed = await openCase();
  await freeze(lapsed.id);
  check("a freeze that has run out cannot be extended",
    (await refusal(() => extend(lapsed.id, "police", new Date(NOW.getTime() + (FREEZE_PERIOD_DAYS + 1) * DAY)))) ===
      "failed-precondition:no_copy");
}

async function deletionPaths(): Promise<void> {
  console.log("\ndeletion paths keep a frozen copy");
  const closed = await openCase();
  await freeze(closed.id);
  check("close keeps frozen copy", (await write(closed.id, { status: "closed" })) === "report_closed_kept_frozen" &&
    (await copy(closed.id)) !== undefined);

  const plainClosed = await openCase();
  await write(plainClosed.id, { status: "closed" });
  check("close still deletes an unfrozen copy", (await copy(plainClosed.id)) === undefined);

  const erased = await openCase();
  await freeze(erased.id);
  await write(erased.id, { contentOwnerId: null });
  const e = await copy(erased.id);
  check("reported person's erasure keeps frozen copy with uid", e?.contentOwnerId === erased.owner);

  const gone = await openCase({ facts: { claimedCreatorIsReporter: true } });
  await freeze(gone.id);
  await write(gone.id, null);
  const g = await copy(gone.id);
  check("report deletion keeps frozen copy", g !== undefined);
  check("report deletion strips reporter facts", g !== undefined && !("claimedCreatorIsReporter" in g));

  const anon = await openCase({ facts: { claimedCreatorIsReporter: false } });
  await freeze(anon.id);
  const reason = await write(anon.id, { reporterId: admin.firestore.FieldValue.delete() });
  const a = await copy(anon.id);
  check("reporter leaving an open report strips facts on a frozen copy",
    reason === "reporter_left_frozen" && a !== undefined && !("claimedCreatorIsReporter" in a));

  const leftBefore = await openCase({ facts: { claimedCreatorIsReporter: true } });
  await write(leftBefore.id, { reporterId: null });
  await freeze(leftBefore.id);
  await write(leftBefore.id, null);
  const lb = await copy(leftBefore.id);
  check("a reporter who left before the freeze leaves no facts on the frozen copy",
    lb !== undefined && !("claimedCreatorIsReporter" in lb));

  const unfrozenAnon = await openCase({ facts: { claimedCreatorIsReporter: true } });
  await write(unfrozenAnon.id, { reporterId: admin.firestore.FieldValue.delete() });
  check("an unfrozen copy keeps its facts while its case is open",
    (await copy(unfrozenAnon.id))?.claimedCreatorIsReporter === true);

  // Reopen: a closed case with a recorded decision and a frozen copy.
  const reopened = await openCase();
  await freeze(reopened.id);
  await write(reopened.id, { status: "closed", reviewRound: 0, moderatorAction: "no_action" });
  await db.collection(MODERATION_DECISIONS).doc(reopened.id).set({
    decision: "no_action", revision: 0, decidedAt: ts(NOW),
  });
  await runReopenReportWithDb(db, MOD, reopened.id, NOW);
  check("reopen keeps a frozen copy", (await copy(reopened.id))?.frozen?.reason === "police");
}

async function releasing(): Promise<void> {
  console.log("\nrelease");
  const open = await openCase();
  await freeze(open.id);
  const out = await release(open.id);
  const c = await copy(open.id);
  check("release on an open case keeps the copy, unfrozen", out.action === "release" && !out.deleted &&
    c !== undefined && c.frozen === undefined);
  check("release restores the 180-day TTL",
    c?.expireAt?.toMillis() === c?.capturedAt?.toMillis() + EVIDENCE_RETENTION_DAYS * DAY);
  check("release audited", (await auditOps(open.id)).includes("moderation_evidence_released"));

  const closed = await openCase();
  await freeze(closed.id);
  await write(closed.id, { status: "closed" });
  await release(closed.id);
  check("release on a closed case deletes", (await copy(closed.id)) === undefined);

  const erased = await openCase();
  await freeze(erased.id);
  await write(erased.id, { contentOwnerId: null });
  await release(erased.id);
  check("release after the reported person's erasure deletes", (await copy(erased.id)) === undefined);

  const deleted = await openCase();
  await freeze(deleted.id);
  await write(deleted.id, null);
  await release(deleted.id);
  check("release after report deletion deletes", (await copy(deleted.id)) === undefined);

  const old = await openCase({ capturedDaysAgo: EVIDENCE_RETENTION_DAYS + 10 });
  await freeze(old.id, "police", new Date(NOW.getTime() - (EVIDENCE_RETENTION_DAYS + 9) * DAY));
  await release(old.id);
  check("release past the 180 days deletes", (await copy(old.id)) === undefined);
}

async function retained(): Promise<void> {
  console.log("\nerasure notice record");
  const owner = `ret${RUN}`;
  const a = await openCase({ owner });
  await openCase({ owner });
  check("no frozen copy, no record", (await frozenEvidenceRetained(db, owner)) === null);
  await freeze(a.id, "legal_claim");
  const r = await frozenEvidenceRetained(db, owner);
  check("frozen copy gives a record", r?.resourceType === REPORT_EVIDENCE && r.provisional === false);
  check("record holds until the three-year cap",
    r?.holdUntil.toMillis() === NOW.getTime() + FREEZE_MAX_DAYS * DAY);
}

async function handler(): Promise<void> {
  console.log("\ncallable");
  const { id } = await openCase();
  const deps = {
    rateLimit: async () => undefined,
    run: (uid: string, req: ReturnType<typeof parseFreezeRequest>) => runFreezeWithDb(db, uid, req, NOW),
  };
  const req = (token: Record<string, unknown> | null) => ({
    auth: token ? { uid: "u1", token } : undefined,
    data: { reportId: id, action: "freeze", reason: "police" },
  }) as unknown as CallableRequest<unknown>;
  check("signed-out caller refused",
    (await refusal(() => handleFreezeReportEvidence(req(null), deps)))?.startsWith("unauthenticated") === true);
  check("non-admin refused",
    (await refusal(() => handleFreezeReportEvidence(req({}), deps)))?.startsWith("permission-denied") === true);
  check("no write by a refused caller", (await copy(id))?.frozen === undefined);
  await handleFreezeReportEvidence(req({ admin: true }), deps);
  check("admin may freeze", (await copy(id))?.frozen?.frozenBy === "u1");
}

async function main(): Promise<void> {
  await parsing();
  await freezing();
  await extending();
  await deletionPaths();
  await releasing();
  await retained();
  await handler();
  console.log(`\n${run - failed}/${run} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
