/**
 * Integration test: the family-data storage-limitation sweep (warn → purge).
 *
 * Runs `runDormantFamilyPurge` against the Firestore emulator with an injected
 * `now`. One pass, four households exercising every branch:
 *   - active (recent rating)            → untouched, no schedule
 *   - fresh-dormant (no schedule yet)    → WARNED (scheduled + notified), data kept
 *   - grace-elapsed (schedule in past)   → PURGED (family data deleted)
 *   - in-grace (schedule in future)      → kept (waiting out the grace window)
 *
 * Run: FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *   ts-node src/__tests__/purge-dormant-family-data.integration.test.ts
 */

import * as admin from "firebase-admin";

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? "localhost:8080";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-family-purge" });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  runDormantFamilyPurge,
  purgeRunFailure,
  PURGE_CURSOR_DOC,
} = require("../family/purge-dormant-family-data");

const RUN = Date.now().toString(36);
const NOW = new Date(Date.UTC(2027, 0, 15));
const DAY = 24 * 60 * 60 * 1000;
const ts = (msFromNow: number) =>
  admin.firestore.Timestamp.fromMillis(NOW.getTime() + msFromNow);
const dormant = ts(-800 * DAY); // > 24 months ago
const recent = ts(-10 * DAY);

let failed = 0;
function assert(cond: boolean, msg: string): void {
  console.log(`  ${cond ? "PASS" : "FAIL"}  ${msg}`);
  if (!cond) failed++;
}

async function seedHousehold(
  id: string,
  opts: {
    activity: admin.firestore.Timestamp;
    scheduledAt?: admin.firestore.Timestamp;
    member: string;
  }
): Promise<void> {
  const hh: Record<string, unknown> = {
    name: "HH",
    members: [{ userId: opts.member, permission: "admin" }],
    memberUserIds: [opts.member],
    createdBy: opts.member,
    updatedAt: dormant, // household itself old; activity comes from children
  };
  if (opts.scheduledAt) hh.familyDataPurgeScheduledAt = opts.scheduledAt;
  await db.collection("households").doc(id).set(hh);
  await db.collection("diner_profiles").doc(`${id}|dp`).set({
    householdId: id,
    name: "Emma",
    createdBy: opts.member,
    updatedAt: opts.activity,
  });
  await db.collection("family_ratings").doc(`${id}|fr`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|dp`,
    memberType: "profile",
    stars: 4,
    enteredByUid: opts.member,
    lastUpdatedAt: opts.activity,
  });
}

async function exists(coll: string, id: string): Promise<boolean> {
  return (await db.collection(coll).doc(id).get()).exists;
}

// BUT-1600: an ACTIVE household (never purged) with a valid in-roster rating,
// an ORPHAN rating whose rater left the roster, and a member recipe copy whose
// denormalised family pill still counts the orphan. Both ratings are on the same
// recipe so the recompute is a clean count 2 → 1.
async function seedReconcileHousehold(
  id: string,
  member: string
): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    members: [{ userId: member, permission: "admin" }],
    memberUserIds: [member],
    createdBy: member,
    updatedAt: recent,
  });
  await db.collection("diner_profiles").doc(`${id}|dp`).set({
    householdId: id,
    name: "Emma",
    createdBy: member,
    updatedAt: recent,
  });
  // Valid: rater is the existing diner profile → kept.
  await db.collection("family_ratings").doc(`${id}|valid`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|dp`,
    memberType: "profile",
    stars: 4,
    enteredByUid: member,
    lastUpdatedAt: recent,
  });
  // Orphan: rater `ghost` is neither an account nor an existing diner → deleted.
  await db.collection("family_ratings").doc(`${id}|orphan`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|ghost`,
    memberType: "profile",
    stars: 2,
    enteredByUid: member,
    lastUpdatedAt: recent,
  });
  // Member's own recipe copy, denormalised pill still counting both ratings.
  await db
    .collection("users")
    .doc(member)
    .collection("recipes")
    .doc("r1")
    .set({ core: { familyAverage: 3, familyRatingCount: 2 } });
}

// BUT-1600 fail-closed guard: a household whose roster reads EMPTY (no
// memberUserIds, no diner profiles) but still holds a rating must NOT have that
// rating deleted. An empty keep-set means an under-populated read, not "everyone
// left" — deleting on it would irreversibly wipe every rating.
async function seedEmptyRosterHousehold(id: string): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    members: [],
    memberUserIds: [],
    createdBy: "system",
    updatedAt: recent,
  });
  await db.collection("family_ratings").doc(`${id}|stranded`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|someone`,
    memberType: "profile",
    stars: 5,
    enteredByUid: "system",
    lastUpdatedAt: recent,
  });
}

// BUT-1600: the `memberUserIds` half of the keep-set is load-bearing — an
// ACCOUNT-HOLDER orphan (memberType user, uid no longer in memberUserIds) must
// be deleted. Guards against a regression dropping the `...memberUserIds` spread
// in rosterMemberIds, which would silently keep departed-account ratings.
async function seedAccountOrphanHousehold(
  id: string,
  member: string
): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    members: [{ userId: member, permission: "admin" }],
    memberUserIds: [member],
    createdBy: member,
    updatedAt: recent,
  });
  await db.collection("family_ratings").doc(`${id}|acct-valid`).set({
    householdId: id,
    recipeId: "r1",
    memberId: member,
    memberType: "user",
    stars: 5,
    enteredByUid: member,
    lastUpdatedAt: recent,
  });
  await db.collection("family_ratings").doc(`${id}|acct-orphan`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|gone`,
    memberType: "user",
    stars: 1,
    enteredByUid: member,
    lastUpdatedAt: recent,
  });
}

// BUT-1600 asymmetric fail-closed: `memberUserIds` empty/missing WHILE a diner
// profile still exists. `roster` is non-empty (the diner id) so the empty-roster
// guard does NOT fire — but the account-id half has collapsed, so an
// account-holder (user-type) rating must still be KEPT, not deleted, because the
// account projection can't be trusted. (A diner-type orphan in the same household
// is still correctly reaped — the diner query is authoritative.)
async function seedEmptyAccountHalfHousehold(id: string): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    members: [],
    memberUserIds: [], // account half collapsed...
    createdBy: "system",
    updatedAt: recent,
  });
  await db.collection("diner_profiles").doc(`${id}|dp`).set({
    householdId: id, // ...but a diner profile survives → roster.size > 0
    name: "Emma",
    createdBy: "system",
    updatedAt: recent,
  });
  await db.collection("family_ratings").doc(`${id}|acct-rating`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|adult`, // a uid, absent from the (empty) memberUserIds
    memberType: "user",
    stars: 4,
    enteredByUid: `${id}|adult`,
    lastUpdatedAt: recent,
  });
}

// BUT-1600 unknown-type fail-closed: a rating whose memberType is missing or
// unrecognised (legacy/corrupt doc) whose memberId is off the roster must be
// KEPT, not deleted — the sweep only reaps ratings it can positively attribute
// to a trusted keep-half. Populated roster so only the type ambiguity is tested.
async function seedUnknownTypeHousehold(id: string, member: string): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    members: [{ userId: member, permission: "admin" }],
    memberUserIds: [member],
    createdBy: member,
    updatedAt: recent,
  });
  await db.collection("family_ratings").doc(`${id}|untyped`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|mystery`, // off the roster...
    // memberType intentionally omitted → unrecognised → must fail closed
    stars: 3,
    enteredByUid: member,
    lastUpdatedAt: recent,
  });
}

async function main(): Promise<void> {
  console.log("family-data dormancy sweep integration\n");
  await db.doc(PURGE_CURSOR_DOC).delete();

  const active = `hh-active-${RUN}`;
  const fresh = `hh-fresh-${RUN}`;
  const elapsed = `hh-elapsed-${RUN}`;
  const inGrace = `hh-ingrace-${RUN}`;

  await seedHousehold(active, { activity: recent, member: `m-active-${RUN}` });
  await seedHousehold(fresh, { activity: dormant, member: `m-fresh-${RUN}` });
  await seedHousehold(elapsed, {
    activity: dormant,
    scheduledAt: ts(-1 * DAY), // grace already elapsed
    member: `m-elapsed-${RUN}`,
  });
  await seedHousehold(inGrace, {
    activity: dormant,
    scheduledAt: ts(10 * DAY), // still inside grace
    member: `m-ingrace-${RUN}`,
  });
  const reactivated = `hh-reactivated-${RUN}`;
  await seedHousehold(reactivated, {
    activity: recent, // active again...
    scheduledAt: ts(5 * DAY), // ...but a purge was pending from a prior pass
    member: `m-react-${RUN}`,
  });
  const reconcile = `hh-reconcile-${RUN}`;
  await seedReconcileHousehold(reconcile, `m-reconcile-${RUN}`);
  const emptyRoster = `hh-emptyroster-${RUN}`;
  await seedEmptyRosterHousehold(emptyRoster);
  const acctOrphan = `hh-acctorphan-${RUN}`;
  await seedAccountOrphanHousehold(acctOrphan, `m-acct-${RUN}`);
  const emptyAcctHalf = `hh-emptyaccthalf-${RUN}`;
  await seedEmptyAccountHalfHousehold(emptyAcctHalf);
  const untyped = `hh-untyped-${RUN}`;
  await seedUnknownTypeHousehold(untyped, `m-untyped-${RUN}`);

  const firstRun = await runDormantFamilyPurge(db, NOW);
  assert(
    firstRun.passComplete && !(await db.doc(PURGE_CURSOR_DOC).get()).exists,
    "a run that reaches the end completes the pass and deletes the cursor"
  );

  // Active → untouched, never scheduled.
  const activeHh = (await db.collection("households").doc(active).get()).data();
  assert(
    (await exists("family_ratings", `${active}|fr`)) &&
      activeHh?.familyDataPurgeScheduledAt === undefined,
    "active household: data kept, no purge scheduled"
  );

  // Fresh-dormant → warned (scheduled + notified), data kept this pass.
  const freshHh = (await db.collection("households").doc(fresh).get()).data();
  const notif = await db
    .collection("user_notifications")
    .where("userId", "==", `m-fresh-${RUN}`)
    .where("type", "==", "family_data_retention")
    .get();
  assert(
    freshHh?.familyDataPurgeScheduledAt !== undefined &&
      (await exists("family_ratings", `${fresh}|fr`)),
    "fresh-dormant: purge scheduled, data NOT yet deleted"
  );
  assert(notif.size === 1, "fresh-dormant: member was warned (1 notification)");

  // Grace-elapsed → purged.
  assert(
    !(await exists("diner_profiles", `${elapsed}|dp`)) &&
      !(await exists("family_ratings", `${elapsed}|fr`)),
    "grace-elapsed: family data purged"
  );
  const elapsedHh = (
    await db.collection("households").doc(elapsed).get()
  ).data();
  assert(
    elapsedHh?.familyDataPurgedAt !== undefined,
    "grace-elapsed: household stamped familyDataPurgedAt"
  );

  // In-grace → kept (waiting out the window).
  assert(
    await exists("family_ratings", `${inGrace}|fr`),
    "in-grace: data kept until the grace window elapses"
  );

  // Reactivated → pending purge cancelled, data kept.
  const reactHh = (
    await db.collection("households").doc(reactivated).get()
  ).data();
  assert(
    reactHh?.familyDataPurgeScheduledAt === undefined &&
      (await exists("family_ratings", `${reactivated}|fr`)),
    "reactivated: scheduled purge cancelled, data kept"
  );

  // BUT-1600 reconciliation: orphan deleted, valid rating kept, card recomputed.
  assert(
    !(await exists("family_ratings", `${reconcile}|orphan`)),
    "reconcile: orphaned rating (departed rater) deleted"
  );
  assert(
    await exists("family_ratings", `${reconcile}|valid`),
    "reconcile: in-roster rating kept"
  );
  const reconcileCard = (
    await db
      .collection("users")
      .doc(`m-reconcile-${RUN}`)
      .collection("recipes")
      .doc("r1")
      .get()
  ).data();
  assert(
    reconcileCard?.core?.familyRatingCount === 1 &&
      reconcileCard?.core?.familyAverage === 4,
    "reconcile: recipe-card family pill recomputed to the surviving rating"
  );

  // Empty-roster fail-closed guard: rating survives (never diff-deleted against ∅).
  assert(
    await exists("family_ratings", `${emptyRoster}|stranded`),
    "empty-roster: rating kept (fail closed, not wiped on an empty keep-set)"
  );

  // Account-holder orphan: memberUserIds half of the keep-set is enforced.
  assert(
    !(await exists("family_ratings", `${acctOrphan}|acct-orphan`)),
    "account-orphan: departed-account rating (uid off memberUserIds) deleted"
  );
  assert(
    await exists("family_ratings", `${acctOrphan}|acct-valid`),
    "account-orphan: current-account rating kept"
  );

  // Asymmetric fail-closed: empty memberUserIds + a live diner must NOT wipe the
  // account-holder rating (account half untrusted while diner half keeps roster non-empty).
  assert(
    await exists("family_ratings", `${emptyAcctHalf}|acct-rating`),
    "empty-account-half: account rating kept (account projection untrusted, diner half alive)"
  );

  // Unknown/missing memberType must fail closed: kept despite being off-roster.
  assert(
    await exists("family_ratings", `${untyped}|untyped`),
    "unknown-type: off-roster rating with no memberType kept (fail closed)"
  );

  await cursorScenario();

  console.log(`\n${failed === 0 ? "ALL PASS" : `${failed} FAILED`}`);
  if (failed > 0) process.exit(1);
}

// A household whose processing THROWS: its orphan rating leads the card
// recompute to `users/bad/uid/recipes/r1`, which is not a document path.
async function seedPoisonHousehold(id: string): Promise<void> {
  await db.collection("households").doc(id).set({
    name: "HH",
    memberUserIds: ["bad/uid"],
    createdBy: "system",
    updatedAt: dormant,
  });
  await db.collection("diner_profiles").doc(`${id}|dp`).set({
    householdId: id,
    name: "Emma",
    createdBy: "system",
    updatedAt: dormant,
  });
  await db.collection("family_ratings").doc(`${id}|orphan`).set({
    householdId: id,
    recipeId: "r1",
    memberId: `${id}|ghost`,
    memberType: "profile",
    stars: 2,
    enteredByUid: "system",
    lastUpdatedAt: dormant,
  });
}

async function warnings(member: string): Promise<number> {
  return (
    await db
      .collection("user_notifications")
      .where("userId", "==", member)
      .where("type", "==", "family_data_retention")
      .get()
  ).size;
}

/**
 * BUT-1671: a pass that outgrows one run resumes where it stopped. The clock
 * advances one second per reading and the budget is 2.5 s, so each run
 * processes three households and defers the rest.
 */
async function cursorScenario(): Promise<void> {
  console.log("\nresumable pass (BUT-1671)");
  const all = await db.collection("households").get();
  await Promise.all(all.docs.map((d) => d.ref.delete()));
  await db.doc(PURGE_CURSOR_DOC).delete();

  const id = (n: number) => `c${n}-${RUN}`;
  const member = (n: number) => `m-c${n}-${RUN}`;
  for (const n of [0, 2, 3, 4]) {
    await seedHousehold(id(n), { activity: dormant, member: member(n) });
  }
  await seedPoisonHousehold(id(1));

  const steppingClock = () => {
    let t = 0;
    return () => (t += 1000);
  };
  const run1 = await runDormantFamilyPurge(db, NOW, 2500, steppingClock());
  const cursor = (await db.doc(PURGE_CURSOR_DOC).get()).data() ?? {};
  assert(
    !run1.passComplete && run1.scanned === 3 && run1.failed === 1,
    `run 1 defers after 3 households with 1 failure, got scanned ${run1.scanned} failed ${run1.failed} complete ${run1.passComplete}`
  );
  assert(
    (await warnings(member(2))) === 1,
    "the household after the failing one is still evaluated in the same run"
  );
  assert(
    cursor.lastHouseholdId === id(2) &&
      JSON.stringify(Object.keys(cursor).sort()) ===
        JSON.stringify(["lastHouseholdId", "passStartedAt", "updatedAt"]),
    `cursor holds the last household and only the three fields, got ${JSON.stringify(Object.keys(cursor))}`
  );
  assert(
    (await warnings(member(3))) === 0,
    "households past the budget are left for the next run"
  );

  // The cursor household disappears between runs (e.g. an account erasure).
  await db.collection("households").doc(id(2)).delete();
  const run2 = await runDormantFamilyPurge(db, NOW, 2500, steppingClock());
  assert(
    run2.passComplete && run2.scanned === 2 && run2.failed === 0,
    `run 2 resumes after the deleted cursor household and completes, got scanned ${run2.scanned} complete ${run2.passComplete}`
  );
  assert(
    purgeRunFailure(run1) !== null && purgeRunFailure(run2) === null,
    `a run with a failed household is recorded failed and a clean one is not, got ${purgeRunFailure(run1)} / ${purgeRunFailure(run2)}`
  );
  assert(
    !(await db.doc(PURGE_CURSOR_DOC).get()).exists,
    "a completed pass deletes the cursor"
  );
  let warnedOnce = true;
  for (const n of [0, 2, 3, 4]) warnedOnce &&= (await warnings(member(n))) === 1;
  assert(warnedOnce, "across both runs every household was warned exactly once");

  // The next pass starts over inside the grace window: nothing is purged, and
  // a household that became active since its warning is reactivated.
  await db.collection("diner_profiles").doc(`${id(3)}|dp`).update({ updatedAt: recent });
  await runDormantFamilyPurge(db, NOW, 2500, steppingClock());
  await runDormantFamilyPurge(db, NOW, 2500, steppingClock());
  assert(
    await exists("family_ratings", `${id(0)}|fr`),
    "a warned household is not purged before its date when the pass wraps"
  );
  const c3 = (await db.collection("households").doc(id(3)).get()).data();
  assert(
    c3?.familyDataPurgeScheduledAt === undefined &&
      (await exists("family_ratings", `${id(3)}|fr`)),
    "a household active again after its warning is reactivated, not purged"
  );

  // A pass older than 28 days is reported overdue.
  await db.doc(PURGE_CURSOR_DOC).set({
    lastHouseholdId: id(0),
    passStartedAt: ts(-30 * DAY),
    updatedAt: ts(-7 * DAY),
  });
  const late = await runDormantFamilyPurge(db, NOW, 2500, steppingClock());
  assert(
    late.overdue && late.passAgeDays === 30,
    `a 30-day-old pass is overdue, got ${late.passAgeDays} days overdue=${late.overdue}`
  );
  assert(
    purgeRunFailure({ ...late, failed: 0 }) !== null,
    "an overdue pass is recorded failed even with no failed household"
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
