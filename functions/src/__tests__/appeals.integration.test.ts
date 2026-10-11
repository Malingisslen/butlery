/**
 * BUT-2353: emulator-backed tests for submitting an appeal
 * (`moderation/submit-appeal.ts`), the owner's decision list
 * (`moderation/my-content-decisions.ts`) and the moderator's queue
 * (`moderation/list-open-appeals.ts`).
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/appeals.integration.test.ts
 */

const PROJECT_ID = "butlery-appeals-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { MODERATION_DECISIONS } from "../moderation/report-decision";
import { MODERATION_APPEALS } from "../moderation/appeals";
import {
  handleSubmitAppeal,
  parseSubmitAppeal,
  runSubmitAppealWithDb,
} from "../moderation/submit-appeal";
import { runGetMyContentDecisionsWithDb } from "../moderation/my-content-decisions";
import { handleListOpenAppeals, runListOpenAppealsWithDb } from "../moderation/list-open-appeals";

const RUN = Date.now().toString(36);
const REPORTER = `rep${RUN}`;
const OWNER = `own${RUN}`;
const STRANGER = `str${RUN}`;
const DECIDED = new Date("2026-10-01T10:00:00Z");
const DEADLINE_MS = DECIDED.getTime() + 183 * 86_400_000;
const EXPIRE = admin.firestore.Timestamp.fromDate(new Date("2027-10-01T10:00:00Z"));
const TEXT = "Jag håller inte med om beslutet.";

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
async function caseOf(opts: {
  decision?: string | null;
  status?: string;
  reason?: string;
  contentType?: string;
  ownerId?: string | null;
  createdAtMs?: number;
  id?: string;
} = {}): Promise<string> {
  const id = opts.id ?? `a${RUN}${seq++}`;
  await db.collection("reports").doc(id).set({
    reporterId: REPORTER,
    contentOwnerId: opts.ownerId === undefined ? OWNER : opts.ownerId,
    contentType: opts.contentType ?? "recipe",
    contentId: `content${id}`,
    reason: opts.reason ?? "spam",
    status: opts.status ?? "closed",
    createdAt: admin.firestore.Timestamp.fromMillis(opts.createdAtMs ?? Date.UTC(2026, 8, 1) + seq),
  });
  if (opts.decision !== null) {
    await db.collection(MODERATION_DECISIONS).doc(id).set({
      decision: opts.decision ?? "content_removed",
      rule: opts.reason ?? "spam",
      motivation: "removed_spam",
      contentType: opts.contentType ?? "recipe",
      moderatorId: `mod${RUN}`,
      decidedAt: admin.firestore.Timestamp.fromDate(DECIDED),
      expireAt: EXPIRE,
    });
  }
  return id;
}

const submit = (uid: string, reportId: string, role: "reporter" | "owner", now = DECIDED) =>
  runSubmitAppealWithDb(db, uid, { reportId, role, text: TEXT }, now);

async function submitting(): Promise<void> {
  const id = await caseOf();
  check("the reporter may appeal", (await codeOf(() => submit(REPORTER, id, "reporter"))) === "ok");
  const doc = (await db.collection(MODERATION_APPEALS).doc(`${id}_reporter`).get()).data();
  check(
    "the appeal holds exactly the agreed fields",
    Object.keys(doc ?? {}).sort().join(",") ===
      "answeredAt,answeredBy,appellantId,createdAt,expireAt,reportId,role,status,text",
    Object.keys(doc ?? {}).sort().join(","),
  );
  check(
    "the appeal names its appellant, and nobody else",
    doc?.appellantId === REPORTER && !JSON.stringify(doc).includes(OWNER),
  );
  check(
    "it is open, keyed to the report, and expires with the decision",
    doc?.status === "open" && doc?.reportId === id && doc?.role === "reporter" &&
      doc?.expireAt?.toMillis() === EXPIRE.toMillis() && doc?.answeredAt === null,
  );
  check(
    "a second appeal by the same party is refused and the first is kept",
    (await codeOf(async () =>
      runSubmitAppealWithDb(db, REPORTER, { reportId: id, role: "reporter", text: "annan text här" }, DECIDED),
    )) === "already-exists:appeal_exists" &&
      (await db.collection(MODERATION_APPEALS).doc(`${id}_reporter`).get()).get("text") === TEXT,
  );
  check("the owner appeals the same decision separately", (await codeOf(() => submit(OWNER, id, "owner"))) === "ok");

  check(
    "another account cannot appeal as the reporter",
    (await codeOf(async () => submit(STRANGER, await caseOf(), "reporter"))) === "permission-denied:not_a_party",
  );
  check(
    "the reporter cannot appeal as the owner",
    (await codeOf(async () => submit(REPORTER, await caseOf(), "owner"))) === "permission-denied:not_a_party",
  );
  check(
    "a report that does not exist answers like one that is not yours",
    (await codeOf(() => submit(REPORTER, `missing${RUN}`, "reporter"))) === "permission-denied:not_a_party",
  );
  check(
    "a closed report with no decision record → not-found",
    (await codeOf(async () => submit(REPORTER, await caseOf({ decision: null }), "reporter"))) ===
      "not-found:no_decision",
  );
  check(
    "a report that is not closed → not-found, even with a decision record",
    (await codeOf(async () => submit(REPORTER, await caseOf({ status: "actioned" }), "reporter"))) ===
      "not-found:no_decision",
  );
  check(
    "a record with an unknown decision → not-found",
    (await codeOf(async () => submit(OWNER, await caseOf({ decision: "banned_forever" }), "owner"))) ===
      "not-found:no_decision",
  );
  check(
    "the owner has nothing to appeal on a dismissal",
    (await codeOf(async () => submit(OWNER, await caseOf({ decision: "no_action" }), "owner"))) ===
      "not-found:no_decision",
  );
  check(
    "the sharer named on a misattribution report is not a party",
    (await codeOf(async () =>
      submit(OWNER, await caseOf({ reason: "misattribution", contentType: "menu_dish" }), "owner"),
    )) === "permission-denied:not_a_party",
  );
  check(
    "an appeal on the last day of the window is accepted",
    (await codeOf(async () => submit(REPORTER, await caseOf(), "reporter", new Date(DEADLINE_MS)))) === "ok",
  );
  check(
    "an appeal a millisecond after the window → appeal_window_closed",
    (await codeOf(async () => submit(REPORTER, await caseOf(), "reporter", new Date(DEADLINE_MS + 1)))) ===
      "failed-precondition:appeal_window_closed",
  );
}

function parsing(): void {
  const parse = (data: unknown) => {
    try {
      parseSubmitAppeal(data);
      return "ok";
    } catch (err) {
      return err instanceof HttpsError ? `${err.code}:${err.message}` : "other";
    }
  };
  const base = { reportId: "r1", role: "reporter" };
  check("ten characters after trimming are enough", parse({ ...base, text: "  0123456789  " }) === "ok");
  check(
    "nine characters after trimming are too few",
    parse({ ...base, text: "   012345678   " }) === "invalid-argument:invalid_text_length",
  );
  check("1000 characters are allowed", parse({ ...base, text: "x".repeat(1000) }) === "ok");
  check(
    "1001 characters are too many",
    parse({ ...base, text: "x".repeat(1001) }) === "invalid-argument:invalid_text_length",
  );
  check("a non-string text is refused", parse({ ...base, text: 42 }) === "invalid-argument:invalid_text_length");
  for (const bad of ["", "a/b", "__x__", ".", 7]) {
    check(
      `report id ${JSON.stringify(bad)} is refused before any read`,
      parse({ ...base, reportId: bad, text: TEXT }) === "invalid-argument:invalid_report_id",
    );
  }
  // A report id is at most 1500 bytes; the appeal id adds `_reporter` / `_owner`.
  const longId = (bytes: number) => `L${"x".repeat(bytes - 1)}`;
  check(
    "a report id whose appeal id would pass 1500 bytes is refused",
    parse({ ...base, reportId: longId(1492), text: TEXT }) === "invalid-argument:invalid_report_id" &&
      parse({ reportId: longId(1495), role: "owner", text: TEXT }) === "invalid-argument:invalid_report_id",
  );
  check(
    "a report id whose appeal id stays within 1500 bytes is accepted",
    parse({ ...base, reportId: longId(1491), text: TEXT }) === "ok",
  );
  check(
    "an unknown role is refused",
    parse({ reportId: "r1", role: "moderator", text: TEXT }) === "invalid-argument:invalid_role",
  );
  const stored = parseSubmitAppeal({ ...base, text: `  ${TEXT}  ` });
  check("the stored text is trimmed", stored.text === TEXT);
}

async function handler(): Promise<void> {
  const seen: string[] = [];
  const deps = {
    rateLimit: async (uid: string, op: string) => {
      seen.push(`${uid}:${op}`);
    },
    run: async (uid: string, input: { reportId: string }) => {
      seen.push(`run:${uid}:${input.reportId}`);
    },
  };
  check(
    "an unauthenticated appeal is refused",
    (await codeOf(() => handleSubmitAppeal({ auth: null, data: {} }, deps))) ===
      "unauthenticated:Sign-in required.",
  );
  await codeOf(() =>
    handleSubmitAppeal({ auth: { uid: REPORTER }, data: { reportId: "r1", role: "reporter", text: "kort" } }, deps),
  );
  check("a malformed appeal does not spend a rate-limit token", seen.length === 0, seen.join("|"));
  const out = await handleSubmitAppeal(
    { auth: { uid: REPORTER }, data: { reportId: "r1", role: "reporter", text: TEXT, uid: STRANGER } },
    deps,
  );
  check(
    "the caller comes from auth, and the call is rate-limited before it runs",
    out.ok === true && seen.join("|") === `${REPORTER}:submitAppeal|run:${REPORTER}:r1`,
    seen.join("|"),
  );
}

async function ownerList(): Promise<void> {
  const removed = await caseOf({ createdAtMs: Date.UTC(2026, 8, 2) });
  const hidden = await caseOf({ decision: "profile_hidden", contentType: "profile", createdAtMs: Date.UTC(2026, 8, 3) });
  const dismissed = await caseOf({ decision: "no_action" });
  const dish = await caseOf({ reason: "misattribution", contentType: "menu_dish" });
  const open = await caseOf({ status: "in_review" });
  const theirs = await caseOf({ ownerId: STRANGER });
  // Too long to carry an owner appeal: its id must not fail the whole list.
  const long = await caseOf({ id: `L${RUN}${"x".repeat(1498 - RUN.length)}` });
  await submit(OWNER, removed, "owner");
  await submit(REPORTER, hidden, "reporter");

  const { decisions } = await runGetMyContentDecisionsWithDb(db, OWNER);
  const ids = new Set(decisions.map((d) => d.reportId));
  check("a removal and a hide are listed", ids.has(removed) && ids.has(hidden));
  check(
    "a report id too long for an appeal is still listed, with no appeal",
    ids.has(long) && decisions.find((d) => d.reportId === long)?.appeal === null,
  );
  check("a dismissal is not listed", !ids.has(dismissed));
  check("a misattribution report is not listed", !ids.has(dish));
  check("an open case is not listed", !ids.has(open));
  check("another person's content is not listed", !ids.has(theirs));
  const row = decisions.find((d) => d.reportId === removed);
  check(
    "a row carries the outcome plus contentType and reason",
    Object.keys(row ?? {}).sort().join(",") ===
      "appeal,appealDeadline,contentType,decidedAt,decision,motivation,reason,reportId" &&
      row?.contentType === "recipe" && row?.reason === "spam",
    JSON.stringify(row),
  );
  check("the owner's own appeal is attached", row?.appeal?.status === "open" && row.appeal.text === TEXT);
  check(
    "the reporter's appeal is not the owner's",
    decisions.find((d) => d.reportId === hidden)?.appeal === null,
  );
  check("the reporter is never in the answer", !JSON.stringify(decisions).includes(REPORTER));
  check(
    "the owner's appeal carries its four public keys, never the stored appellant",
    Object.keys(row?.appeal ?? {}).sort().join(",") === "answeredAt,status,submittedAt,text" &&
      !JSON.stringify(decisions).includes("appellantId"),
    JSON.stringify(row?.appeal),
  );
  check(
    "newest first, as the query orders them",
    decisions.findIndex((d) => d.reportId === hidden) < decisions.findIndex((d) => d.reportId === removed),
  );
}

async function moderatorQueue(): Promise<void> {
  const first = await caseOf();
  const second = await caseOf({ decision: "profile_hidden", contentType: "profile" });
  await submit(REPORTER, first, "reporter", new Date("2026-10-02T00:00:00Z"));
  await submit(OWNER, second, "owner", new Date("2026-10-03T00:00:00Z"));
  const answered = await caseOf();
  await submit(REPORTER, answered, "reporter");
  await db.collection(MODERATION_APPEALS).doc(`${answered}_reporter`).update({ status: "upheld" });

  const { appeals } = await runListOpenAppealsWithDb(db);
  const mine = appeals.filter((a) => a.reportId.startsWith(`a${RUN}`));
  check("an answered appeal is not in the queue", !mine.some((a) => a.reportId === answered));
  const one = mine.find((a) => a.appealId === `${first}_reporter`);
  check(
    "a queue row carries the agreed fields",
    Object.keys(one ?? {}).sort().join(",") ===
      "appealId,contentId,contentType,createdAt,decidedAt,decision,motivation,reason,reportId,role,text" &&
      one?.contentId === `content${first}` && one?.decision === "content_removed" &&
      one?.motivation === "removed_spam" && one?.reason === "spam" && one?.role === "reporter" &&
      one?.decidedAt === DECIDED.toISOString(),
    JSON.stringify(one),
  );
  check(
    "oldest first",
    mine.findIndex((a) => a.reportId === first) < mine.findIndex((a) => a.reportId === second),
  );
  check("no appellant uid in the queue", !JSON.stringify(mine).includes(REPORTER) && !JSON.stringify(mine).includes(OWNER));

  // Cap: more open than one call reads is said, never hidden.
  const capped = await runListOpenAppealsWithDb(db, 1);
  check(
    "above the cap the queue says it is truncated and returns the cap",
    capped.truncated === true && capped.appeals.length === 1,
    `truncated=${capped.truncated} rows=${capped.appeals.length}`,
  );
  const whole = await runListOpenAppealsWithDb(db, 10_000);
  check("within the cap it is not truncated", whole.truncated === false);

  const request = (token: Record<string, unknown> | null) =>
    ({ auth: token ? { uid: STRANGER, token } : undefined, data: {} }) as unknown as CallableRequest<unknown>;
  const deps = { rateLimit: async () => undefined, run: async () => ({ appeals: [], truncated: false }) };
  check(
    "a signed-in non-admin cannot list appeals",
    (await codeOf(() => handleListOpenAppeals(request({}), deps))) === "permission-denied:Admin access required",
  );
  check(
    "an admin can",
    (await codeOf(() => handleListOpenAppeals(request({ admin: true }), deps))) === "ok",
  );
}

async function main(): Promise<void> {
  console.log("appeals integration");
  await submitting();
  parsing();
  await handler();
  await ownerList();
  await moderatorQueue();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
