/**
 * Firestore rules tests for the beta-feedback admin dashboard (Phase 1).
 *
 * Proves the access contract the admin inbox depends on: admins read all
 * feedback, admins may only flip the triage `status` field, non-admins can
 * neither read nor triage, owners can still submit, and no client deletes.
 *
 * Prerequisite: Firestore emulator running (`firebase emulators:start
 * --only firestore`). Run with: npx ts-node src/__tests__/feedback-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-feedback";
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
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

async function seedFeedback(id: string, owner: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`feedback/${id}`).set({
      userId: owner,
      category: "bug",
      description: "crashed on save",
      recentInteractions: [],
      createdAt: new Date(),
      status: "new",
    });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

test("admin can read any feedback entry", async () => {
  await seedFeedback("f1", USER_A_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(adminCtx.firestore().doc("feedback/f1").get());
});

test("non-admin cannot read feedback (not even their own)", async () => {
  await seedFeedback("f2", USER_A_UID);
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(ownerCtx.firestore().doc("feedback/f2").get());
});

test("admin can update only the status field", async () => {
  await seedFeedback("f3", USER_A_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(
    adminCtx.firestore().doc("feedback/f3").update({ status: "triaged" })
  );
});

test("admin cannot rewrite the submission body (non-status fields)", async () => {
  await seedFeedback("f4", USER_A_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertFails(
    adminCtx.firestore().doc("feedback/f4").update({ description: "tampered" })
  );
});

test("admin cannot smuggle a body change alongside a status change", async () => {
  await seedFeedback("f4b", USER_A_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  // hasOnly(['status']) must reject a multi-field update even when one of the
  // fields is the allowed `status`.
  await assertFails(
    adminCtx
      .firestore()
      .doc("feedback/f4b")
      .update({ status: "triaged", description: "tampered" })
  );
});

test("unauthenticated client cannot read feedback", async () => {
  await seedFeedback("f4c", USER_A_UID);
  const anonCtx = env.unauthenticatedContext();
  await assertFails(anonCtx.firestore().doc("feedback/f4c").get());
});

test("non-admin cannot update feedback status", async () => {
  await seedFeedback("f5", USER_A_UID);
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().doc("feedback/f5").update({ status: "resolved" })
  );
});

test("user can create their own feedback", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_A_UID,
      category: "bug",
      description: "hi",
      recentInteractions: [],
      createdAt: new Date(),
      status: "new",
    })
  );
});

test("user cannot create feedback impersonating another user", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_B_UID,
      category: "bug",
      description: "spoofed",
      recentInteractions: [],
      createdAt: new Date(),
      status: "new",
    })
  );
});

test("nobody can delete feedback (not even admin)", async () => {
  await seedFeedback("f6", USER_A_UID);
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertFails(adminCtx.firestore().doc("feedback/f6").delete());
});

async function run(): Promise<void> {
  console.log("Feedback admin-dashboard rules tests\n");
  console.log("====================================\n");
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
