/**
 * BUT-2330: emulator-backed tests for the decision record a closed report
 * leaves (`moderation/report-decision.ts`).
 *
 * The headline property: the record holds the decision, the rule, the time and
 * the moderator, and nothing that names the reporter, the reported person or
 * the content.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/report-decision.integration.test.ts
 */

const PROJECT_ID = "butlery-report-decision-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  closesReport,
  DECISION_RETENTION_DAYS,
  MODERATION_DECISIONS,
  recordModerationDecision,
} from "../moderation/report-decision";

const RUN = Date.now().toString(36);
const REPORTER = `rep${RUN}`;
const OWNER = `own${RUN}`;
const MODERATOR = `mod${RUN}`;
const NOW = new Date("2026-10-10T08:00:00Z");

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
/** Seeds a report as the closing write leaves it and returns its id and data. */
async function closedReport(
  extra: Record<string, unknown> = {},
): Promise<{ id: string; data: admin.firestore.DocumentData }> {
  const id = `r${RUN}${seq++}`;
  const data = {
    reporterId: REPORTER,
    contentType: "comment",
    contentId: `c${RUN}`,
    contentOwnerId: OWNER,
    reason: "harassment",
    description: "free text from the reporter",
    status: "closed",
    createdAt: admin.firestore.Timestamp.fromDate(NOW),
    ...extra,
  };
  await db.collection("reports").doc(id).set(data);
  return { id, data };
}

async function decide(
  id: string,
  data: admin.firestore.DocumentData,
  authType: string | undefined = "app_user",
  authId: string | undefined = MODERATOR,
) {
  return recordModerationDecision(db, {
    reportId: id,
    report: data,
    decidedAt: NOW,
    authType,
    authId,
  });
}

async function record(id: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.collection(MODERATION_DECISIONS).doc(id).get()).data();
}

function transitions(): void {
  const cases: Array<[string, unknown, unknown, boolean]> = [
    ["new → closed", { status: "new" }, { status: "closed" }, true],
    ["in_review → closed", { status: "in_review" }, { status: "closed" }, true],
    ["actioned → closed", { status: "actioned" }, { status: "closed" }, true],
    ["closed → closed", { status: "closed" }, { status: "closed" }, false],
    ["new → in_review", { status: "new" }, { status: "in_review" }, false],
    ["in_review → actioned", { status: "in_review" }, { status: "actioned" }, false],
    ["created closed", undefined, { status: "closed" }, false],
    ["deleted", { status: "new" }, undefined, false],
  ];
  for (const [name, before, after, expected] of cases) {
    check(
      `transition: ${name} → ${expected ? "record" : "skip"}`,
      closesReport(
        before as admin.firestore.DocumentData | undefined,
        after as admin.firestore.DocumentData | undefined,
      ) === expected,
    );
  }
}

async function contents(): Promise<void> {
  const { id, data } = await closedReport({ moderatorAction: "content_removed" });
  check("first close records", (await decide(id, data)) === "recorded");
  const row = await record(id);
  check("decision is the stamped action", row?.decision === "content_removed");
  check("rule is the report's reason", row?.rule === "harassment");
  check("contentType is kept", row?.contentType === "comment");
  check("moderator is the closing user", row?.moderatorId === MODERATOR);
  check(
    "decidedAt is the event time",
    row?.decidedAt instanceof admin.firestore.Timestamp &&
      row.decidedAt.toMillis() === NOW.getTime(),
  );
  check(
    `expireAt is ${DECISION_RETENTION_DAYS} days after the decision`,
    row?.expireAt instanceof admin.firestore.Timestamp &&
      row.expireAt.toMillis() - NOW.getTime() === DECISION_RETENTION_DAYS * 86_400_000,
  );
  const keys = Object.keys(row ?? {}).sort().join(",");
  check(
    "the record holds exactly the six fields",
    keys === "contentType,decidedAt,decision,expireAt,moderatorId,rule",
    keys,
  );
  const serialized = JSON.stringify(row);
  check(
    "no reporter, owner, content id or free text anywhere in the record",
    ![REPORTER, OWNER, `c${RUN}`, "free text"].some((s) => serialized.includes(s)),
  );
  const stored = (await db.collection("reports").doc(id).get()).data();
  check("the close takes moderatorAction off the report", stored !== undefined && !("moderatorAction" in stored));
  check("the rest of the report is left alone", stored?.reporterId === REPORTER);
}

async function decisions(): Promise<void> {
  const hidden = await closedReport({ contentType: "profile", moderatorAction: "profile_hidden" });
  await decide(hidden.id, hidden.data);
  check("profile_hidden is recorded", (await record(hidden.id))?.decision === "profile_hidden");

  const dismissed = await closedReport();
  await decide(dismissed.id, dismissed.data);
  check("no stamp → no_action", (await record(dismissed.id))?.decision === "no_action");

  const forged = await closedReport({ moderatorAction: "banned_forever" });
  await decide(forged.id, forged.data);
  check("an unknown stamp → no_action", (await record(forged.id))?.decision === "no_action");

  const dish = await closedReport({ reason: "misattribution", contentType: "menu_dish" });
  await decide(dish.id, dish.data);
  const dishRow = await record(dish.id);
  check(
    "a dish case keeps its own rule and type",
    dishRow?.rule === "misattribution" && dishRow?.contentType === "menu_dish",
  );

  const odd = await closedReport({ reason: "spamm", contentType: "poem" });
  await decide(odd.id, odd.data);
  const row = await record(odd.id);
  check("an unknown reason → rule other", row?.rule === "other");
  check("an unknown contentType → null", row?.contentType === null);
}

async function moderators(): Promise<void> {
  for (const authType of ["service_account", "system", "api_key", "unauthenticated", "unknown"]) {
    const { id, data } = await closedReport();
    await decide(id, data, authType, "some-principal");
    check(`a ${authType} close names no moderator`, (await record(id))?.moderatorId === null);
  }
  const missing = await closedReport();
  // Not through `decide`, whose defaults would fill the two undefineds in.
  await recordModerationDecision(db, {
    reportId: missing.id,
    report: missing.data,
    decidedAt: NOW,
    authType: undefined,
    authId: undefined,
  });
  check("no auth context names no moderator", (await record(missing.id))?.moderatorId === null);
}

async function idempotency(): Promise<void> {
  const { id, data } = await closedReport({ moderatorAction: "content_removed" });
  await decide(id, data);
  // A redelivery carries the same event data; a later write is a different
  // moderator and must not replace the first decision.
  const again = await decide(id, { ...data, moderatorAction: undefined }, "app_user", "other-mod");
  check("a second delivery reports already_recorded", again === "already_recorded");
  const row = await record(id);
  check("the first decision stands", row?.decision === "content_removed" && row?.moderatorId === MODERATOR);

  const gone = await closedReport({ moderatorAction: "content_removed" });
  await db.collection("reports").doc(gone.id).delete();
  check("a report deleted since the close still gets its record", (await decide(gone.id, gone.data)) === "recorded");
  check("…and the report is not recreated", !(await db.collection("reports").doc(gone.id).get()).exists);
}

async function main(): Promise<void> {
  console.log("report-decision integration");
  transitions();
  await contents();
  await decisions();
  await moderators();
  await idempotency();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
