/**
 * Regression tests for the `friend_categories` admin moderation override
 * landed in BUT-511 (commit 34ba389c6). Cook-snaps and messages
 * admin-read coverage live in `cook-snaps-and-message-mod-rules.test.ts`.
 *
 * Each test name states the behavior it proves. If a test fails, either
 * the rules regressed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore --project demo-test`)
 * or kicked off by `.claude/hooks/ensure-firestore-emulator.sh`.
 *
 * Run with: npx ts-node src/__tests__/moderation-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-moderation";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "owner-uid";
const OTHER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  // Seed the admin record. The /admins/{uid} collection is rules-locked, so
  // we use the security-rules-disabled context to simulate a server-side
  // grant performed via Firebase Console.
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

// ----------------------------------------------------------------------------
// Builders — one per collection. Keep them minimal-but-valid so any future
// validator tightening surfaces here, not in tests that aren't about shape.
// ----------------------------------------------------------------------------

function validFriendCategoryBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    ownerId: OWNER_UID,
    name: "Familjen",
    friendUserIds: [],
    createdAt: new Date(),
    updatedAt: new Date(),
    ...extra,
  };
}

// ============================================================================
// FRIEND_CATEGORIES — admin moderation override (BUT-511 follow-up)
// 3 tests covering admin-allow, owner regression guard, non-admin deny.
// ============================================================================

// FC1: admin can read AND delete a flagged friend_category they don't own
//      (moderation pipeline contract — BUT-511 added the override).
test(
  "friend_categories: admin can read and delete a flagged group (moderation override)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-flagged`)
        .set(validFriendCategoryBody());
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-flagged`)
        .get()
    );
    await assertSucceeds(
      adminCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-flagged`)
        .delete()
    );
  }
);

// FC2: owner can still create / read / delete their own category — regression
//      guard against the BUT-511 override accidentally tightening owner CRUD.
test(
  "friend_categories: owner can still create, read, and delete their own group",
  async () => {
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-owned`)
        .set(validFriendCategoryBody())
    );
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-owned`)
        .get()
    );
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-owned`)
        .delete()
    );
  }
);

// FC3: non-admin non-member stranger is denied read+delete on someone else's
//      category. Confirms the admin override didn't open the door for plain
//      authenticated users.
test(
  "friend_categories: non-admin non-member is denied read and delete",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-private`)
        .set(validFriendCategoryBody());
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-private`)
        .get()
    );
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`users/${OWNER_UID}/friend_categories/fc-private`)
        .delete()
    );
  }
);

async function run(): Promise<void> {
  console.log("friend_categories admin moderation rules tests\n");
  console.log("==============================================\n");
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
