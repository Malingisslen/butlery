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
  // Suites share one long-lived emulator; leftovers from an earlier run
  // turn a create-only write into a denied update.
  await env.clearFirestore();
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

test("BUT-1407: accepts the full older-build client payload (all 10 keys, optional nulls)", async () => {
  // Mirrors FeedbackEntry.toMap.
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(
    ownerCtx.firestore().collection("feedback").add({
      id: "client-generated",
      userId: USER_A_UID,
      category: "bug",
      description: "crash on save",
      email: null,
      screenshotUrl: null,
      recentInteractions: [{ event: "tap" }],
      createdAt: new Date(),
      deviceInfo: null,
      status: "new",
    })
  );
});

test("BUT-1407: rejects a create with an unknown extra field", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_A_UID,
      category: "bug",
      description: "hi",
      recentInteractions: [],
      createdAt: new Date(),
      status: "new",
      isAdmin: true, // smuggled field outside the allowlist
    })
  );
});

function feedbackBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    userId: USER_A_UID,
    category: "bug",
    description: "crash on save",
    recentInteractions: [],
    createdAt: new Date(),
    status: "new",
    ...extra,
  };
}

function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}

test("accepts a create stamped with a valid expireAt", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: daysFromNow(365) }))
  );
});

test("accepts a create without expireAt (an older app build)", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(ownerCtx.firestore().collection("feedback").add(feedbackBody()));
});

test("rejects a create whose expireAt is already past", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: daysFromNow(-1) }))
  );
});

test("rejects a create whose expireAt is beyond the ceiling", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: daysFromNow(400) }))
  );
});

test("accepts a create with an explicit null expireAt (the trigger stamps it)", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertSucceeds(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: null }))
  );
});

test("rejects a create whose expireAt is a number", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: Date.now() + 30 * 864e5 }))
  );
});

test("admin cannot rewrite expireAt on a stamped row", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("feedback/f-stamped").set(feedbackBody({ expireAt: daysFromNow(30) }));
  });
  const adminCtx = env.authenticatedContext(ADMIN_UID);
  await assertFails(
    adminCtx.firestore().doc("feedback/f-stamped").update({ expireAt: daysFromNow(300) })
  );
});

test("rejects a create whose expireAt is not a timestamp", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add(feedbackBody({ expireAt: "2027-01-01" }))
  );
});

test("BUT-1407: rejects an oversized description (> 5000 chars)", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_A_UID,
      category: "bug",
      description: "x".repeat(5001),
      recentInteractions: [],
      createdAt: new Date(),
      status: "new",
    })
  );
});

test("BUT-1407: rejects an oversized recentInteractions array (> 50)", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_A_UID,
      category: "bug",
      description: "hi",
      recentInteractions: Array.from({ length: 51 }, () => ({ event: "tap" })),
      createdAt: new Date(),
      status: "new",
    })
  );
});

test("BUT-1407: rejects a create missing a required field (description)", async () => {
  const ownerCtx = env.authenticatedContext(USER_A_UID);
  await assertFails(
    ownerCtx.firestore().collection("feedback").add({
      userId: USER_A_UID,
      category: "bug",
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
