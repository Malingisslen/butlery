/**
 * BUT-1997: emulator-backed tests for the anonymous acquisition tally
 * (`analytics/acquisition-counter.ts`), calling the trigger body directly.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/acquisition-counter.integration.test.ts
 */

const PROJECT_ID = "butlery-acquisition-counter-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  MEDIUM_ALLOWLIST,
  OTHER,
  SOURCE_ALLOWLIST,
  countAcquisition,
  onAcquisitionCreated,
} from "../analytics/acquisition-counter";

type Data = admin.firestore.DocumentData;

const RUN = Date.now().toString(36);
let seq = 0;
const nextUid = () => `acq${RUN}u${seq++}`;

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

const deps = { db };
const DAY_KEYS = new Set(["date", "v", "scope", "total", "bySource", "byMedium", "unmapped"]);

function dayRef(date: string) {
  return db.collection("analytics").doc("acquisition").collection("daily").doc(date);
}

async function day(date: string): Promise<Data | undefined> {
  return (await dayRef(date).get()).data();
}

/** Seeds a user's attribution row and, unless [consent] is null, their consent doc. */
async function seed(
  uid: string,
  attribution: Data,
  firstSeenIso: string,
  consent: Data | null = { purposes: { analytics: true } },
): Promise<void> {
  const user = db.collection("users").doc(uid);
  if (consent !== null) await user.collection("consent").doc("current").set(consent);
  await user.collection("acquisition").doc("current").set({
    ...attribution,
    firstSeenAt: admin.firestore.Timestamp.fromDate(new Date(firstSeenIso)),
  });
}

async function source(uid: string): Promise<Data | undefined> {
  return (await db.collection("users").doc(uid).collection("acquisition").doc("current").get()).data();
}

const event = (uid: string) => ({ uid, eventTime: new Date().toISOString() });

/** Every string anywhere in [value], keys included. */
function strings(value: unknown, out: string[] = []): string[] {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) value.forEach((v) => strings(v, out));
  else if (value && typeof value === "object" && !(value instanceof admin.firestore.Timestamp)) {
    for (const [k, v] of Object.entries(value)) {
      out.push(k);
      strings(v, out);
    }
  }
  return out;
}

async function counted(): Promise<void> {
  const date = "2031-01-01";
  await dayRef(date).delete();
  const uid = nextUid();
  await seed(uid, { source: "Instagram ", medium: "social", campaign: "spring" }, `${date}T12:00:00Z`);

  const outcome = await countAcquisition(event(uid), deps);
  const doc = await day(date);
  check("a consenting user's row is counted", outcome === "counted", outcome);
  check(
    "the day document holds the allowlisted buckets",
    doc?.total === 1 && doc?.bySource?.instagram === 1 && doc?.byMedium?.social === 1 &&
      doc?.unmapped?.source === 0 && doc?.unmapped?.medium === 0 &&
      doc?.date === date && doc?.v === 1 && doc?.scope === "consented-signed-in-utm",
    JSON.stringify(doc),
  );
  check(
    "the source row is stamped countedAt",
    (await source(uid))?.countedAt instanceof admin.firestore.Timestamp,
    JSON.stringify(await source(uid)),
  );

  const again = await countAcquisition(event(uid), deps);
  check(
    "the same event processed twice is counted once",
    again === "already_counted" && (await day(date))?.total === 1,
    `${again} ${JSON.stringify(await day(date))}`,
  );
}

async function concurrentRedelivery(): Promise<void> {
  const date = "2031-01-02";
  await dayRef(date).delete();
  const uid = nextUid();
  await seed(uid, { source: "google", medium: "cpc", campaign: "" }, `${date}T08:00:00Z`);
  const outcomes = await Promise.all([countAcquisition(event(uid), deps), countAcquisition(event(uid), deps)]);
  check(
    "two concurrent deliveries count once",
    (await day(date))?.total === 1 && outcomes.filter((o) => o === "counted").length === 1,
    `${outcomes} ${JSON.stringify(await day(date))}`,
  );
}

async function sourceGone(): Promise<void> {
  const date = "2031-01-03";
  await dayRef(date).delete();
  const uid = nextUid();
  await seed(uid, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`);
  await db.collection("users").doc(uid).collection("acquisition").doc("current").delete();
  let outcome = "threw";
  try {
    outcome = await countAcquisition(event(uid), deps);
  } catch (err) {
    outcome = `threw ${String(err)}`;
  }
  check(
    "a row erased before the trigger ran is not counted and does not throw",
    outcome === "source_gone" && (await day(date)) === undefined,
    `${outcome} ${JSON.stringify(await day(date))}`,
  );
}

async function consent(): Promise<void> {
  const date = "2031-01-04";
  await dayRef(date).delete();
  const cases: Array<[string, Data | null]> = [
    ["no consent document", null],
    ["analytics consent false", { purposes: { analytics: false } }],
    ["analytics consent the string \"true\"", { purposes: { analytics: "true" } }],
    ["consent without purposes", { consentVersion: "1" }],
  ];
  for (const [label, consentDoc] of cases) {
    const uid = nextUid();
    await seed(uid, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`, consentDoc);
    const outcome = await countAcquisition(event(uid), deps);
    const row = await source(uid);
    check(
      `${label} → not counted, not stamped`,
      outcome === "no_consent" && (await day(date)) === undefined && !("countedAt" in (row ?? {})),
      `${outcome} ${JSON.stringify(await day(date))} ${JSON.stringify(row)}`,
    );
  }
}

async function normalisation(): Promise<void> {
  const date = "2031-01-05";
  await dayRef(date).delete();
  const email = "malin.gisslen@example.com";
  const inputs: Data[] = [
    { source: email, medium: email, campaign: email },
    { source: "x".repeat(300), medium: "social", campaign: "c" },
    { source: "instagram🍲", medium: "📧", campaign: "" },
    { source: "", medium: "", campaign: "" },
    { source: 42, medium: { nested: email }, campaign: ["a"] },
    { medium: "social" },
  ];
  const uids: string[] = [];
  for (const attribution of inputs) {
    const uid = nextUid();
    uids.push(uid);
    await seed(uid, attribution, `${date}T08:00:00Z`);
    await countAcquisition(event(uid), deps);
  }
  const doc = (await day(date)) ?? {};
  check(
    "malformed, unknown and personal values all count as other",
    doc.total === inputs.length && doc.bySource?.[OTHER] === inputs.length &&
      Object.keys(doc.bySource ?? {}).length === 1,
    JSON.stringify(doc),
  );
  check(
    "present values that miss the allowlist are counted as unmapped",
    doc.unmapped?.source === 4 && doc.unmapped?.medium === 3,
    JSON.stringify(doc.unmapped),
  );
  check(
    "the day document carries only its own keys",
    Object.keys(doc).every((k) => DAY_KEYS.has(k)),
    JSON.stringify(Object.keys(doc)),
  );
  const mapKeysOk =
    Object.keys(doc.bySource ?? {}).every((k) => k === OTHER || SOURCE_ALLOWLIST.has(k)) &&
    Object.keys(doc.byMedium ?? {}).every((k) => k === OTHER || MEDIUM_ALLOWLIST.has(k));
  check("every map key is allowlisted or other", mapKeysOk, JSON.stringify(doc));
  const all = strings(doc);
  check(
    "no uid and no raw value appears anywhere in the aggregate",
    !all.some((s) => uids.some((u) => s.includes(u)) || s.includes(email) || s.includes("xxxx")),
    JSON.stringify(all),
  );
}

async function utcBuckets(): Promise<void> {
  const late = "2031-02-20";
  const early = "2031-02-21";
  await dayRef(late).delete();
  await dayRef(early).delete();
  const a = nextUid();
  const b = nextUid();
  await seed(a, { source: "tiktok", medium: "social", campaign: "" }, `${late}T23:59:59Z`);
  await seed(b, { source: "tiktok", medium: "social", campaign: "" }, `${early}T00:00:00Z`);
  await countAcquisition(event(a), deps);
  await countAcquisition(event(b), deps);
  check(
    "23:59:59Z and 00:00:00Z fall on their own UTC days",
    (await day(late))?.total === 1 && (await day(early))?.total === 1,
    `${JSON.stringify(await day(late))} ${JSON.stringify(await day(early))}`,
  );
}

async function missingFirstSeenAt(): Promise<void> {
  const date = "2031-03-10";
  await dayRef(date).delete();
  const uid = nextUid();
  await db.collection("users").doc(uid).collection("consent").doc("current")
    .set({ purposes: { analytics: true } });
  await db.collection("users").doc(uid).collection("acquisition").doc("current")
    .set({ source: "google", medium: "cpc", campaign: "" });
  const outcome = await countAcquisition({ uid, eventTime: `${date}T10:00:00Z` }, deps);
  check(
    "a row without firstSeenAt is bucketed on the event's UTC date",
    outcome === "counted" && (await day(date))?.total === 1,
    `${outcome} ${JSON.stringify(await day(date))}`,
  );
}

/** The deployed handler, not the core: the uid comes from the path and the day from firstSeenAt. */
async function enabledHandler(): Promise<void> {
  const date = "2031-04-01";
  await dayRef(date).delete();
  const uid = nextUid();
  await seed(uid, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`);
  const run = (onAcquisitionCreated as unknown as {
    run: (event: unknown) => Promise<unknown>;
  }).run;
  await run({ params: { uid }, time: new Date().toISOString(), data: undefined });
  const doc = await day(date);
  check(
    "the exported handler counts the row on the day of firstSeenAt",
    doc?.total === 1 && doc?.bySource?.instagram === 1 &&
      (await source(uid))?.countedAt instanceof admin.firestore.Timestamp,
    `${JSON.stringify(doc)} ${JSON.stringify(await source(uid))}`,
  );
}

function endpoint(): void {
  const ep = (onAcquisitionCreated as unknown as {
    __endpoint: { eventTrigger?: { retry?: unknown; eventFilterPathPatterns?: { document?: string } } };
  }).__endpoint;
  check("a failed count is retried", ep.eventTrigger?.retry === true, String(ep.eventTrigger?.retry));
  check(
    "the trigger fires on the `current` row only",
    ep.eventTrigger?.eventFilterPathPatterns?.document === "users/{uid}/acquisition/current",
    JSON.stringify(ep.eventTrigger),
  );
}

async function main(): Promise<void> {
  console.log("acquisition counter integration");
  await counted();
  await concurrentRedelivery();
  await sourceGone();
  await consent();
  await normalisation();
  await utcBuckets();
  await missingFirstSeenAt();
  await enabledHandler();
  endpoint();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
