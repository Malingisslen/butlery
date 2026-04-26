/**
 * BUT-511 + BUT-728: Firestore rules tests for the moderation-delete
 * coverage matrix. Four content types — friend_categories, public_profiles,
 * unified_shared_shopping_lists, cook_snaps — each gained an `isAdmin()`
 * read+delete override (or, for cook_snaps, a brand-new full rule block).
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

function validPublicProfileBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    displayName: "Anna",
    email: "anna@example.com",
    isSearchable: true,
    ...extra,
  };
}

function validSharedShoppingListBody(
  ownerId: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    ownerId,
    memberPermissions: { [ownerId]: "admin" },
    items: [],
    createdAt: new Date(),
    ...extra,
  };
}

function validCookSnapBody(
  userId: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-123",
    userId,
    userDisplayName: "Anna",
    photoUrl: "https://example.com/photo.jpg",
    createdAt: new Date(),
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

// ============================================================================
// PUBLIC_PROFILES — admin moderation delete override (BUT-728)
// Read is intentionally public to all authenticated users; only the new
// admin-delete branch is novel.
// ============================================================================

// PP1: admin can delete a flagged public profile owned by someone else.
test(
  "public_profiles: admin can delete a flagged profile (moderation override)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`public_profiles/${OWNER_UID}`).delete()
    );
  }
);

// PP2: owner can still delete their own public profile — regression guard.
test(
  "public_profiles: owner can still delete their own profile",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx.firestore().doc(`public_profiles/${OWNER_UID}`).delete()
    );
  }
);

// PP3: non-admin non-owner is denied delete (read is intentionally public).
//      Guards against the new admin clause silently widening the delete door.
test(
  "public_profiles: non-admin non-owner is denied delete",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      strangerCtx.firestore().doc(`public_profiles/${OWNER_UID}`).delete()
    );
  }
);

// ============================================================================
// UNIFIED_SHARED_SHOPPING_LISTS — admin moderation read+delete (BUT-728)
// This is the most consequential override of the three: without it, admins
// who aren't members can't even READ a flagged list to triage it.
// ============================================================================

// SL1: admin who is NOT a member can read AND delete the list (moderation
//      pipeline). This is the headline assertion — the existing read rule
//      requires owner OR membership, so without the admin override the
//      moderator review view would 403.
test(
  "shared_shopping_lists: non-member admin can read and delete a flagged list",
  async () => {
    const listId = "list-flagged";
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .set(validSharedShoppingListBody(OWNER_UID));
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .get()
    );
    await assertSucceeds(
      adminCtx
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .delete()
    );
  }
);

// SL2: owner can still delete their own shared list — regression guard.
test(
  "shared_shopping_lists: owner can still delete their own list",
  async () => {
    const listId = "list-owned";
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .set(validSharedShoppingListBody(OWNER_UID));
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .delete()
    );
  }
);

// SL3: non-admin non-member stranger is denied read+delete. Guards against
//      the new admin override opening the door for plain authenticated users.
test(
  "shared_shopping_lists: non-admin non-member is denied read and delete",
  async () => {
    const listId = "list-private";
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .set(validSharedShoppingListBody(OWNER_UID));
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .get()
    );
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`unified_shared_shopping_lists/${listId}`)
        .delete()
    );
  }
);

// ============================================================================
// COOK_SNAPS — full new rule block (BUT-728)
// 12 assertions across 12 tests — entire contract has zero prior coverage.
// ============================================================================

// CS1: any authenticated user can read any cook_snap (public social feature).
test(
  "cook_snaps: authenticated user can read any cook snap",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-public")
        .set(validCookSnapBody(OWNER_UID));
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertSucceeds(
      strangerCtx.firestore().doc("cook_snaps/cs-public").get()
    );
  }
);

// CS2: unauthenticated request is denied read.
test(
  "cook_snaps: unauthenticated user cannot read a cook snap",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-anon-blocked")
        .set(validCookSnapBody(OWNER_UID));
    });
    const anonCtx = env.unauthenticatedContext();
    await assertFails(
      anonCtx.firestore().doc("cook_snaps/cs-anon-blocked").get()
    );
  }
);

// CS3: owner can create with all required fields present.
test(
  "cook_snaps: owner can create a snap with all required fields",
  async () => {
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc("cook_snaps/cs-create-ok")
        .set(validCookSnapBody(OWNER_UID))
    );
  }
);

// CS4: create denied when userId doesn't match the auth uid (impersonation
//      guard — without this, any authed user could attribute snaps to anyone).
test(
  "cook_snaps: create denied when userId does not match auth uid",
  async () => {
    const otherCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      otherCtx
        .firestore()
        .doc("cook_snaps/cs-impersonate")
        .set(validCookSnapBody(OWNER_UID)) // userId says OWNER, auth says OTHER
    );
  }
);

// CS5: create denied when a required field is missing (here: photoUrl).
test(
  "cook_snaps: create denied when a required field is missing",
  async () => {
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    const body = validCookSnapBody(OWNER_UID);
    delete (body as Record<string, unknown>).photoUrl;
    await assertFails(
      ownerCtx.firestore().doc("cook_snaps/cs-missing-field").set(body)
    );
  }
);

// CS6: create denied when caption exceeds 200 chars (server-side defense in
//      depth against clients that bypass CookSnap._sanitizeCaption).
test(
  "cook_snaps: create denied when caption exceeds 200 characters",
  async () => {
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    const longCaption = "a".repeat(201);
    await assertFails(
      ownerCtx
        .firestore()
        .doc("cook_snaps/cs-long-caption")
        .set(validCookSnapBody(OWNER_UID, { caption: longCaption }))
    );
  }
);

// CS7: owner can update their own cook snap (full doc rewrite via set()).
test(
  "cook_snaps: owner can update their own cook snap",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-update-ok")
        .set(validCookSnapBody(OWNER_UID));
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc("cook_snaps/cs-update-ok")
        .set(validCookSnapBody(OWNER_UID, { caption: "Det blev gott!" }))
    );
  }
);

// CS8: update denied when trying to switch userId to another uid. The rule
//      pins both `resource.data.userId` AND `request.resource.data.userId`
//      against the auth uid precisely to block this attack.
test(
  "cook_snaps: update denied when attempting to switch userId to another user",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-userid-switch")
        .set(validCookSnapBody(OWNER_UID));
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    // Owner tries to rewrite their own snap with userId = OTHER_UID.
    await assertFails(
      ownerCtx
        .firestore()
        .doc("cook_snaps/cs-userid-switch")
        .set(validCookSnapBody(OTHER_UID))
    );
  }
);

// CS9: owner can delete their own cook snap.
test(
  "cook_snaps: owner can delete their own cook snap",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-delete-ok")
        .set(validCookSnapBody(OWNER_UID));
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx.firestore().doc("cook_snaps/cs-delete-ok").delete()
    );
  }
);

// CS10: non-owner non-admin is denied delete.
test(
  "cook_snaps: non-owner non-admin cannot delete another user's cook snap",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-stranger-delete")
        .set(validCookSnapBody(OWNER_UID));
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      strangerCtx.firestore().doc("cook_snaps/cs-stranger-delete").delete()
    );
  }
);

// CS11: admin can read AND delete any cook snap (moderation override).
test(
  "cook_snaps: admin can read and delete any cook snap (moderation override)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc("cook_snaps/cs-admin-mod")
        .set(validCookSnapBody(OWNER_UID));
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc("cook_snaps/cs-admin-mod").get()
    );
    await assertSucceeds(
      adminCtx.firestore().doc("cook_snaps/cs-admin-mod").delete()
    );
  }
);

// CS12: rate limit — a second create within 5 seconds is rejected. Seed the
//       owner's rate_limits/{cook_snaps} doc with a `lastWrite` of now, then
//       attempt a fresh create. The helper denies until 5s elapse.
test(
  "cook_snaps: rate limit blocks a second create within 5 seconds",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/rate_limits/cook_snaps`)
        .set({ lastWrite: new Date() });
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertFails(
      ownerCtx
        .firestore()
        .doc("cook_snaps/cs-rate-limited")
        .set(validCookSnapBody(OWNER_UID))
    );
  }
);

async function run(): Promise<void> {
  console.log("BUT-511 + BUT-728: moderation rules tests\n");
  console.log("=========================================\n");
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
