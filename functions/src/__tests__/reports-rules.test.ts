/**
 * BUT-417 / BUT-548: Firestore rules tests for the moderation pipeline.
 *
 * Each test name states the behavior it proves. If a test fails, either
 * the rules changed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/reports-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-test";
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

  // Seed the admin doc with the security-rules-bypassing context.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
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

// Test 1: non-admin update to reports.*.status -> permission-denied.
test(
  "non-admin cannot update a report's status",
  async () => {
    const reportId = "r1";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c1",
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().doc(`reports/${reportId}`).update({
        status: "in_review",
      })
    );
  }
);

// Test 2: admin update new -> in_review is allowed.
test(
  "admin can advance a report from new to in_review",
  async () => {
    const reportId = "r2";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "comment",
        contentId: "c2",
        reason: "spam",
        status: "new",
        createdAt: new Date(),
      });
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`reports/${reportId}`).update({
        status: "in_review",
      })
    );
  }
);

// Test 3: admin can delete a reported comment; non-admin cannot delete someone else's comment.
test(
  "admin deletes a reported comment; non-admin cannot delete another user's comment",
  async () => {
    const commentId = "comment-authored-by-A";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`recipe_comments/${commentId}`).set({
        authorId: USER_A_UID,
        recipeId: "recipe-x",
        text: "hello",
        createdAt: new Date(),
      });
    });
    // User B (non-admin, non-author) cannot delete.
    const userBCtx = env.authenticatedContext(USER_B_UID);
    await assertFails(
      userBCtx.firestore().doc(`recipe_comments/${commentId}`).delete()
    );
    // Admin can delete.
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`recipe_comments/${commentId}`).delete()
    );
  }
);

// Test 4: forward-only state machine — admin cannot move closed -> new.
test(
  "admin cannot move a closed report back to new (forward-only)",
  async () => {
    const reportId = "r3";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`reports/${reportId}`).set({
        reporterId: USER_A_UID,
        contentType: "message",
        contentId: "m1",
        reason: "harassment",
        status: "closed",
        createdAt: new Date(),
      });
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertFails(
      adminCtx.firestore().doc(`reports/${reportId}`).update({
        status: "new",
      })
    );
  }
);

// Test 5: admins collection is rules-locked — no client write, even by admin.
test(
  "admins collection is rules-locked — no client can write",
  async () => {
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertFails(
      adminCtx.firestore().doc("admins/new-admin").set({ addedAt: new Date() })
    );
    const userCtx = env.authenticatedContext(USER_A_UID);
    await assertFails(
      userCtx.firestore().doc("admins/self-promote").set({ addedAt: new Date() })
    );
  }
);

async function run(): Promise<void> {
  console.log("BUT-417/548: moderation rules tests\n");
  console.log("===================================\n");
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
