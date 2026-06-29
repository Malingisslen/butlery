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

  console.log(`\n${failed === 0 ? "ALL PASS" : `${failed} FAILED`}`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
