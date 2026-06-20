/**
 * Firestore rules tests for the admin-dashboard read surface (Phase 3/4).
 *
 * Proves the access contract the new admin tabs depend on: an admin may read
 * the analytics rollups, north-star metrics, cleanup-job logs, the users
 * collection (for counting), parsing corrections across all users, and recipes
 * via collection-group — while non-admins and anonymous clients are denied on
 * every one of those paths.
 *
 * Prerequisite: Firestore emulator running (`firebase emulators:start
 * --only firestore`). Run with: npx ts-node src/__tests__/admin-dashboard-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-admin-dashboard";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const ADMIN_UID = "admin-uid";
const USER_A_UID = "user-a";
const USER_B_UID = "user-b";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
    // Analytics rollup (DAU/WAU per feature)
    await db.doc("analytics/feature_retention/daily/2026-06-19").set({
      date: "2026-06-19",
      dau: { cooked: 0, imported: 0, shared: 0, mealPlanned: 0, shopped: 0 },
      computedAt: new Date(),
    });
    // North-star weekly snapshot
    await db.doc("metrics/weekly_north_star/snapshots/2026-W25").set({
      wau: 0,
      totalCooks: 0,
      computedAt: new Date(),
    });
    // Cleanup-job run log
    await db.doc("system_events/evt1").set({
      type: "notification_cleanup",
      totalDeleted: 12,
      executedAt: new Date(),
    });
    // A user account + one recipe (for count / collection-group reads)
    await db.doc(`users/${USER_A_UID}`).set({ displayName: "A" });
    await db.doc(`users/${USER_A_UID}/recipes/r1`).set({
      core: { title: "Soppa", tagResult: {} },
      sourceArtefact: { type: "url" },
    });
    // Parsing correction owned by user A
    await db.doc("parsing_corrections/c1").set({
      id: "c1",
      userId: USER_A_UID,
      source: "url",
      domain: "koket.se",
      timestamp: new Date(),
    });
    // A parse event (per-attempt drill-down source)
    await db.doc("parse_events/pe1").set({
      domain: "koket.se",
      success: false,
      timestamp: new Date(),
    });
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// --- analytics ---
test("admin can read an analytics rollup doc", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(
    ctx.firestore().doc("analytics/feature_retention/daily/2026-06-19").get()
  );
});
test("non-admin cannot read analytics", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ctx.firestore().doc("analytics/feature_retention/daily/2026-06-19").get()
  );
});
test("anonymous cannot read analytics", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc("analytics/feature_retention/daily/2026-06-19").get()
  );
});

// --- metrics ---
test("admin can read a north-star metrics snapshot", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(
    ctx.firestore().doc("metrics/weekly_north_star/snapshots/2026-W25").get()
  );
});
test("non-admin cannot read metrics", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ctx.firestore().doc("metrics/weekly_north_star/snapshots/2026-W25").get()
  );
});

// --- system_events ---
test("admin can read a system_events log entry", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc("system_events/evt1").get());
});
test("non-admin cannot read system_events", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertFails(ctx.firestore().doc("system_events/evt1").get());
});

// --- users (count proxy: list read) ---
test("admin can list the users collection (for counting)", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().collection("users").get());
});
test("non-admin cannot list the users collection", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertFails(ctx.firestore().collection("users").get());
});
test("owner can still read their own user doc", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(ctx.firestore().doc(`users/${USER_A_UID}`).get());
});

// --- parsing_corrections ---
test("admin can read another user's parsing correction", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc("parsing_corrections/c1").get());
});
test("owner can still read their own parsing correction", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(ctx.firestore().doc("parsing_corrections/c1").get());
});
test("non-owner non-admin cannot read a parsing correction", async () => {
  const ctx = env.authenticatedContext(USER_B_UID);
  await assertFails(ctx.firestore().doc("parsing_corrections/c1").get());
});

// --- parse_events (drill-down source) ---
test("admin can read a parse event", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc("parse_events/pe1").get());
});
test("admin can query parse_events by domain", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection("parse_events")
      .where("domain", "==", "koket.se")
      .get()
  );
});
test("non-admin cannot read parse_events", async () => {
  const ctx = env.authenticatedContext(USER_A_UID);
  await assertFails(ctx.firestore().doc("parse_events/pe1").get());
});

// --- recipes via collection-group ---
test("admin can collection-group query recipes", async () => {
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().collectionGroup("recipes").get());
});
test("non-admin cannot collection-group query recipes", async () => {
  const ctx = env.authenticatedContext(USER_B_UID);
  await assertFails(ctx.firestore().collectionGroup("recipes").get());
});

async function run(): Promise<void> {
  console.log("Admin-dashboard rules tests\n");
  console.log("===========================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await teardown();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
