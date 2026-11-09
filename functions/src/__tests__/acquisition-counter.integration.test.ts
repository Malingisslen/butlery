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
import * as fs from "fs";
import * as path from "path";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  MEDIUM_ALLOWLIST,
  OTHER,
  SOURCE_ALLOWLIST,
  countAcquisition,
  runAcquisitionEligibleSnapshot,
  onAcquisitionCreated,
  setAccountLookupForTest,
  getAuthAccountWith,
  NEW_USER_WINDOW_MS,
  type AuthAccount,
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

/** A signed-in account created an hour before the row it wrote. */
async function newAccount(uid: string): Promise<AuthAccount> {
  const row = await db.collection("users").doc(uid).collection("acquisition").doc("current").get();
  const ts = row.get("firstSeenAt");
  const at = ts instanceof admin.firestore.Timestamp ? ts.toMillis() : Date.now();
  return { providerData: [{ providerId: "password" }], metadata: { creationTime: new Date(at - 3600_000).toUTCString() } };
}

const deps = { db, getAccount: newAccount };
const DAY_KEYS = new Set(["date", "v", "scope", "total", "bySource", "byMedium", "unmapped", "eligible"]);

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
      doc?.date === date && doc?.v === 2 && doc?.scope === "consented-new-account-channel",
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
  const eventMs = Date.parse(`${date}T10:00:00Z`);
  const accountAtEvent = async (): Promise<AuthAccount> => ({
    providerData: [{ providerId: "password" }],
    metadata: { creationTime: new Date(eventMs - 3600_000).toUTCString() },
  });
  const outcome = await countAcquisition(
    { uid, eventTime: `${date}T10:00:00Z` },
    { db, getAccount: accountAtEvent },
  );
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
  setAccountLookupForTest(newAccount);
  await run({ params: { uid }, time: new Date().toISOString(), data: undefined });
  const doc = await day(date);
  check(
    "the exported handler counts the row on the day of firstSeenAt",
    doc?.total === 1 && doc?.bySource?.instagram === 1 &&
      (await source(uid))?.countedAt instanceof admin.firestore.Timestamp,
    `${JSON.stringify(doc)} ${JSON.stringify(await source(uid))}`,
  );
}

async function accountRules(): Promise<void> {
  const date = "2031-05-01";
  await dayRef(date).delete();
  const guest = nextUid();
  await seed(guest, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`);
  const guestOutcome = await countAcquisition(event(guest), {
    db,
    getAccount: async () => ({ providerData: [], metadata: { creationTime: new Date(`${date}T07:00:00Z`).toUTCString() } }),
  });
  check("a guest account is not counted and not stamped", guestOutcome === "guest" && (await day(date)) === undefined && !("countedAt" in ((await source(guest)) ?? {})), guestOutcome);

  const old = nextUid();
  await seed(old, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`);
  const oldOutcome = await countAcquisition(event(old), {
    db,
    getAccount: async () => ({ providerData: [{}], metadata: { creationTime: new Date("2030-01-01T00:00:00Z").toUTCString() } }),
  });
  check("an account older than the window is not a new user", oldOutcome === "not_new_user" && (await day(date)) === undefined, oldOutcome);

  const gone = nextUid();
  await seed(gone, { source: "instagram", medium: "social", campaign: "" }, `${date}T08:00:00Z`);
  const goneOutcome = await countAcquisition(event(gone), { db, getAccount: async () => null });
  check("an account that no longer exists is not counted", goneOutcome === "source_gone", goneOutcome);

  const earlyDate = "2026-11-01";
  await dayRef(earlyDate).delete();
  const early = nextUid();
  await seed(early, { source: "google-play", medium: "organic", campaign: "" }, `${earlyDate}T08:00:00Z`);
  await countAcquisition(event(early), {
    db,
    getAccount: async () => ({ providerData: [{}], metadata: { creationTime: new Date("2020-01-01T00:00:00Z").toUTCString() } }),
  });
  const earlyDoc = await day(earlyDate);
  check(
    "a day before the cut-over keeps the old scope and the old rule",
    earlyDoc?.v === 1 && earlyDoc?.scope === "consented-signed-in-utm" && earlyDoc?.bySource?.["google-play"] === 1,
    JSON.stringify(earlyDoc),
  );
}

async function windowEdges(): Promise<void> {
  const date = "2031-07-01";
  await dayRef(date).delete();
  const at = Date.parse(`${date}T12:00:00Z`);
  const acct = (createdMs: number) => async (): Promise<AuthAccount> => ({
    providerData: [{}],
    metadata: { creationTime: new Date(createdMs).toUTCString() },
  });
  const edge = nextUid();
  await seed(edge, { source: "tiktok", medium: "social", campaign: "" }, `${date}T12:00:00Z`);
  const inside = await countAcquisition(event(edge), { db, getAccount: acct(at - NEW_USER_WINDOW_MS) });
  check("an account exactly at the window edge counts", inside === "counted", inside);
  const late = nextUid();
  await seed(late, { source: "tiktok", medium: "social", campaign: "" }, `${date}T12:00:00Z`);
  const outside = await countAcquisition(event(late), { db, getAccount: acct(at - NEW_USER_WINDOW_MS - 1000) });
  check("an account one second past the window edge does not", outside === "not_new_user", outside);

  for (const [d, v] of [["2026-11-13", 1], ["2026-11-14", 2]] as const) {
    await dayRef(d).delete();
    const u = nextUid();
    await seed(u, { source: "tiktok", medium: "social", campaign: "" }, `${d}T12:00:00Z`);
    await countAcquisition(event(u), { db, getAccount: acct(Date.parse(`${d}T11:00:00Z`)) });
    check(`${d} is written under schema v${v}`, (await day(d))?.v === v, JSON.stringify(await day(d)));
  }
}

async function authLookup(): Promise<void> {
  const account: AuthAccount = { providerData: [{}], metadata: {} };
  const throwing = (code: string) => ({ getUser: async () => { throw Object.assign(new Error(code), { code }); } });
  check("an Auth account that exists is returned", (await getAuthAccountWith({ getUser: async () => account }, "u")) === account);
  check("auth/user-not-found means gone", (await getAuthAccountWith(throwing("auth/user-not-found"), "u")) === null);
  check("auth/invalid-uid means gone", (await getAuthAccountWith(throwing("auth/invalid-uid"), "u")) === null);
  let rethrown = false;
  try {
    await getAuthAccountWith(throwing("auth/internal-error"), "u");
  } catch {
    rethrown = true;
  }
  check("any other Auth error is rethrown so the trigger retries", rethrown);
}

async function indexOverride(): Promise<void> {
  const raw = JSON.parse(fs.readFileSync(path.join(__dirname, "../../../firestore.indexes.json"), "utf8"));
  const o = (raw.fieldOverrides as Array<{ collectionGroup: string; fieldPath: string; indexes: Array<{ queryScope: string }> }>)
    .find((x) => x.collectionGroup === "consent" && x.fieldPath === "purposes.analytics");
  check(
    "the consent collection-group index the eligible count needs is declared",
    !!o && o.indexes.some((i) => i.queryScope === "COLLECTION_GROUP"),
    JSON.stringify(o),
  );
}

async function eligible(): Promise<void> {
  const date = "2031-06-01";
  await dayRef(date).delete();
  const before = (await db.collectionGroup("consent").where("purposes.analytics", "==", true).count().get()).data().count;
  const uid = nextUid();
  await db.collection("users").doc(uid).collection("consent").doc("current").set({ purposes: { analytics: true } });
  const n = await runAcquisitionEligibleSnapshot({ db, now: new Date(`${date}T10:00:00Z`) });
  const doc = await day(date);
  check(
    "the eligible number is stored as a count and nothing else",
    n === before + 1 && doc?.eligible?.analyticsConsented === n && Object.keys(doc ?? {}).sort().join() === "date,eligible",
    JSON.stringify(doc),
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
  await accountRules();
  await windowEdges();
  await authLookup();
  await indexOverride();
  await eligible();
  endpoint();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
