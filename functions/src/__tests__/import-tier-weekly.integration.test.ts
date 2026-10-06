/**
 * BUT-2243 — emulator-backed test for the weekly import tier job
 * (`analytics/import-tier-weekly.ts`).
 *
 * The range query, the `.select()` projection, the snapshot doc and the alarm
 * row run against a real Firestore emulator. Pure arithmetic (z, thresholds)
 * is pinned by `import-tier-weekly.test.ts`.
 *
 * Isolation: a project id of its own, and every collection the job reads or
 * writes is emptied first, because the rules lane shares one emulator.
 *
 * Run: npx ts-node src/__tests__/import-tier-weekly.integration.test.ts
 * Local prerequisite: bash .claude/hooks/ensure-firestore-emulator.sh
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "butlery-import-tier-weekly-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";

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

// Monday 2026-03-09 08:00 UTC: the job measures 2026-W10 (03-02..03-09)
// against 2026-W09 (02-23..03-02).
const NOW = new Date("2026-03-09T08:00:00Z");
const W10_START = new Date("2026-03-02T00:00:00Z");
const W10_END = new Date("2026-03-09T00:00:00Z");
const IN_W10 = new Date("2026-03-04T12:00:00Z");
const IN_W09 = new Date("2026-02-25T12:00:00Z");
const AFTER_W10 = new Date("2026-03-09T01:00:00Z");
const BEFORE_W09 = new Date("2026-02-22T12:00:00Z");

async function emptyCollection(
  db: admin.firestore.Firestore,
  ref: admin.firestore.CollectionReference
): Promise<void> {
  const snap = await ref.get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function main(): Promise<void> {
  console.log("importTierWeekly integration tests (BUT-2243)\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: EMULATOR_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID });
  const db = admin.firestore();
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { runImportTierWeekly } = require("../analytics/import-tier-weekly");

  const events = db.collection("parse_events");
  const weekly = db.collection("analytics").doc("import_tiers").collection("weekly");
  await emptyCollection(db, events);
  await emptyCollection(db, weekly);
  await emptyCollection(db, db.collection("system_events"));

  const rows: Array<Record<string, unknown>> = [];
  const add = (n: number, at: Date, fields: Record<string, unknown>): void => {
    for (let i = 0; i < n; i++) {
      rows.push({
        userId: "user-should-not-be-read",
        url: "https://example.se/recept",
        domain: "example.se",
        timestamp: admin.firestore.Timestamp.fromDate(at),
        ...fields,
      });
    }
  };
  const structured = { outcome: "recipe", successfulTier: "SchemaOrg", usedLlm: false };
  const viaAi = { outcome: "recipe", successfulTier: "LLM", usedLlm: true, estimatedCostUsd: 0.001 };

  // link: structured 100% -> 50%, AI 0% -> 50%, n = 40 both weeks.
  add(40, IN_W09, { channel: "link", ...structured });
  add(20, IN_W10, { channel: "link", ...structured });
  add(20, IN_W10, { channel: "link", ...viaAi });
  // Outside both weeks: would turn link's failure share if they were counted.
  add(30, AFTER_W10, { channel: "link", outcome: "failure", usedLlm: false });
  add(30, BEFORE_W09, { channel: "link", outcome: "failure", usedLlm: false });
  // text: the same swing at n = 10, below the floor.
  add(10, IN_W09, { channel: "text", ...structured });
  add(10, IN_W10, { channel: "text", ...viaAi });
  // photo: no previous week, mean cost $0.01 over 20 events.
  add(20, IN_W10, { channel: "photo", outcome: "recipe", successfulTier: "LLM", usedLlm: true, estimatedCostUsd: 0.01 });
  // voice: one row on each edge of W10; only the start is inside.
  add(1, W10_START, { channel: "voice", outcome: "recipe", usedLlm: false });
  add(1, W10_END, { channel: "voice", outcome: "recipe", usedLlm: false });
  // no channel, one without an outcome.
  add(2, IN_W10, { outcome: "failure", usedLlm: false });
  add(1, IN_W10, {});

  for (let i = 0; i < rows.length; i += 400) {
    const batch = db.batch();
    rows.slice(i, i + 400).forEach((r) => batch.set(events.doc(), r));
    await batch.commit();
  }

  // Record the keys of every document the job reads.
  const seen = new Set<string>();
  const proto = admin.firestore.QueryDocumentSnapshot.prototype;
  const originalData = proto.data;
  proto.data = function (this: admin.firestore.QueryDocumentSnapshot) {
    const d = originalData.call(this);
    Object.keys(d).forEach((k) => seen.add(k));
    return d;
  };
  let result;
  try {
    result = await runImportTierWeekly({ db, now: NOW });
  } finally {
    proto.data = originalData;
  }
  check(
    "the read fetches channel but never userId, url or domain",
    seen.has("channel") && !seen.has("userId") && !seen.has("url") && !seen.has("domain"),
    [...seen].sort().join(",")
  );

  const snap = await weekly.doc("2026-W10").get();
  check("snapshot doc written under the measured week's label", snap.exists);
  const doc = snap.data() ?? {};
  const link = doc.byChannel?.link ?? {};
  check("link counts only W10 events", link.events === 40, `events=${link.events}`);
  check("link structured share 0.5", link.structuredShare === 0.5, `${link.structuredShare}`);
  check("link AI share 0.5", link.aiShare === 0.5, `${link.aiShare}`);
  check("link failure share 0", link.failureShare === 0, `${link.failureShare}`);
  check("previous week counted from raw events", doc.previous?.byChannel?.link?.structuredShare === 1);
  check("previous week label", doc.previous?.isoWeek === "2026-W09", `${doc.previous?.isoWeek}`);
  const unknown = doc.byChannel?.unknown ?? {};
  check("null channel lands in `unknown`", unknown.events === 3, `events=${unknown.events}`);
  check(
    "a missing outcome stays out of the failure denominator",
    unknown.failureN === 2 && unknown.failureShare === 1,
    JSON.stringify(unknown)
  );
  check(
    "a row at the week's start counts, one at its end does not",
    doc.byChannel?.voice?.events === 1,
    `voice events=${doc.byChannel?.voice?.events}`
  );
  check("design goals stored beside the values", doc.designGoals?.aiCallsPerImport === 0);
  const serialised = JSON.stringify(doc);
  check(
    "no user id, url or domain reaches the snapshot",
    !serialised.includes("user-should-not-be-read") &&
      !serialised.includes("example.se"),
  );

  const kinds = (result.shifts as Array<{ channel: string; kind: string }>)
    .map((s) => `${s.channel}:${s.kind}`)
    .sort();
  check(
    "alarms: link structured + AI, photo cost; text stays quiet below n = 20",
    JSON.stringify(kinds) === JSON.stringify(["link:ai", "link:structured", "photo:cost"]),
    JSON.stringify(kinds)
  );

  await runImportTierWeekly({ db, now: NOW });
  const alarms = await db
    .collection("system_events")
    .where("type", "==", "import_tier_shift")
    .get();
  check("a rerun leaves exactly one alarm row", alarms.size === 1, `rows=${alarms.size}`);
  const alarm = alarms.docs[0];
  check(
    "alarm row id and timestamps",
    alarm?.id === "import_tier_shift_2026-W10" &&
      alarm.data().executedAt instanceof admin.firestore.Timestamp &&
      alarm.data().timestamp instanceof admin.firestore.Timestamp,
    alarm?.id
  );
  check(
    "no user id, url or domain reaches the alarm row",
    !JSON.stringify(alarm?.data()).includes("example.se") &&
      !JSON.stringify(alarm?.data()).includes("user-should-not-be-read"),
  );

  // W10 holds 74 rows. A cap of 73 truncates it; 74 does not.
  await emptyCollection(db, db.collection("system_events"));
  await emptyCollection(db, weekly);
  const atCap = await runImportTierWeekly({ db, now: NOW, rowCap: 74 });
  check("control: a cap equal to the week's rows does not truncate", atCap.current.truncated === false && atCap.shifts.length > 0);
  await emptyCollection(db, db.collection("system_events"));
  const cut = await runImportTierWeekly({ db, now: NOW, rowCap: 73 });
  const cutDoc = (await weekly.doc("2026-W10").get()).data() ?? {};
  const cutAlarms = await db.collection("system_events").where("type", "==", "import_tier_shift").get();
  check(
    "a truncated week is stored as truncated and raises no alarm",
    cut.current.truncated === true && cutDoc.truncated === true && cut.shifts.length === 0 && cutAlarms.size === 0,
    `truncated=${cut.current.truncated}, shifts=${cut.shifts.length}, alarms=${cutAlarms.size}`
  );

  console.log(`\n${run - failed}/${run} passed`);
  if (failed > 0) process.exit(1);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
