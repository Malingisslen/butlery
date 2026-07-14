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

  await runDormantFamilyPurge(db, NOW);

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

  console.log(`\n${failed === 0 ? "ALL PASS" : `${failed} FAILED`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
