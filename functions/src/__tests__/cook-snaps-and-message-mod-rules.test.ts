/**
 * Firestore rules tests for two pre-launch hardening additions:
 *
 *   1. The new `cook_snaps` rule block (collection had no rules before — the
 *      cook-snap feature was silently failing in production via the
 *      default-deny). Friends-only read, owner CRUD, admin moderation.
 *
 *   2. The added `allow read: if isAdmin();` clause on `messages`. Base read
 *      rule restricted to conversation participants; admins (not in the
 *      conversation) couldn't preview a reported message before takedown.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules changed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/cook-snaps-and-message-mod-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-cook-snaps-and-message-mod";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "snap-owner-uid";
const FRIEND_UID = "friend-uid";
const STRANGER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  await env.withSecurityRulesDisabled(async (ctx) => {
    // Seed the admin record (collection is rules-locked; admins are added
    // server-side via Firebase Console / Admin SDK).
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
    });
    // Seed the friendship: FRIEND_UID is in OWNER_UID's friends list.
    // Only the doc's existence matters per the cook_snaps read rule.
    await ctx
      .firestore()
      .doc(`users/${OWNER_UID}/friends/${FRIEND_UID}`)
      .set({ addedAt: new Date() });
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

// A snap body that satisfies the structural validation. Keep helpers minimal —
// individual tests override fields they want to vary.
function validSnapBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    userId: OWNER_UID,
    userDisplayName: "Anna",
    photoUrl: "https://example.com/photo.jpg",
    createdAt: new Date(),
    ...extra,
  };
}

// ============================================================================
// COOK SNAPS — read access (friends-gated)
// ============================================================================

// snap-owner can read their own snap.
test("cook_snaps: owner can read own snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-own`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-own`).get());
});

// a friend of the snap-owner can read the owner's snap.
// (Friend doc seeded in setup at users/OWNER_UID/friends/FRIEND_UID.
// BUT-1214: the friend branch requires explicit visibility — post-backfill
// every readable doc carries 'sameAsRecipe'.)
test("cook_snaps: friend-of-owner can read owner's snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-friend-readable`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-friend-readable`).get()
  );
});

// a stranger (not in owner's friends list) cannot read.
// Privacy guarantee: friends-only is enforced at the rules layer.
test("cook_snaps: stranger cannot read another user's snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-private`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`cook_snaps/cs-private`).get());
});

// unauthenticated request cannot read.
test("cook_snaps: unauthenticated user cannot read any snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-anon`)
      .set(validSnapBody());
  });
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`cook_snaps/cs-anon`).get());
});

// friends-gated query — BUT-1214 split-query contract: friends' snaps are
// queried with an explicit visibility constraint (rules can't prove a
// foreign doc isn't onlyMe otherwise).
test("cook_snaps: friend-scoped query with visibility constraint succeeds", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-friend`)
      .set(validSnapBody({ recipeId: "recipe-q", visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "in", [OWNER_UID])
      .where("visibility", "==", "sameAsRecipe")
      .get()
  );
});

// BUT-1214: the PRE-1214 query shape (no visibility constraint) is now
// denied for foreign userIds — it could surface an onlyMe snap. Proves the
// repository's own/friends query split is not optional.
test("cook_snaps: friend query without visibility constraint is denied", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "in", [FRIEND_UID, OWNER_UID])
      .get()
  );
});

// BUT-1214: the viewer's own-snaps query needs NO visibility constraint —
// authors always see their own onlyMe snaps.
test("cook_snaps: own-snaps query without visibility constraint succeeds", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-own-onlyme`)
      .set(validSnapBody({ recipeId: "recipe-q3", visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q3")
      .where("userId", "==", OWNER_UID)
      .get()
  );
});

// ============================================================================
// COOK SNAPS — BUT-1214 per-snap visibility override (onlyMe)
// ============================================================================

// the author can still read their own onlyMe snap.
test("cook_snaps: owner can read own onlyMe snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-own`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-onlyme-own`).get());
});

// a friend (who CAN read sameAsRecipe snaps) is denied an onlyMe snap —
// the core BUT-1214 privacy guarantee, enforced at the rules layer.
test("cook_snaps: friend cannot read an onlyMe snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-friend`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-onlyme-friend`).get()
  );
});

// a legacy doc (no visibility field) is friend-UNREADABLE by design: any
// permissive back-compat clause (`!('visibility' in data)` / get-with-
// default) was proven on the emulator to leak onlyMe docs through
// unconstrained list queries. The backfill
// (functions/scripts/backfill-cook-snap-visibility.js) MUST therefore run
// before this rules version deploys; this test pins the deliberate
// trade-off. The owner can still read their own legacy snap.
test("cook_snaps: legacy snap without visibility is NOT friend-readable (backfill required)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-legacy`)
      .set(validSnapBody());
  });
  await assertFails(
    env.authenticatedContext(FRIEND_UID).firestore().doc(`cook_snaps/cs-legacy`).get()
  );
  await assertSucceeds(
    env.authenticatedContext(OWNER_UID).firestore().doc(`cook_snaps/cs-legacy`).get()
  );
});

// create accepts both enum values…
test("cook_snaps: owner can create an onlyMe snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-create-onlyme`)
      .set(validSnapBody({ visibility: "onlyMe" }))
  );
});

// …but rejects a forged value (would be get-readable yet query-invisible —
// an inconsistent state the validation refuses to persist).
test("cook_snaps: create with forged visibility value is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-create-forged`)
      .set(validSnapBody({ visibility: "everyone" }))
  );
});

// owner may retro-hide a snap (visibility is mutable, identity fields not).
test("cook_snaps: owner can update visibility to onlyMe", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-retro-hide`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-retro-hide`)
      .update({ visibility: "onlyMe" })
  );
});

// a forged visibility value is rejected on UPDATE too — without this the
// create-time check is trivially bypassed by create-valid-then-update.
test("cook_snaps: update with forged visibility value is rejected", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-update-forged`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-update-forged`)
      .update({ visibility: "everyone" })
  );
});

// owner may also re-share (onlyMe -> sameAsRecipe) — the rule comment
// promises visibility is mutable in BOTH directions.
test("cook_snaps: owner can update visibility back to sameAsRecipe", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-reshare`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-reshare`)
      .update({ visibility: "sameAsRecipe" })
  );
});

// unauthenticated query is denied regardless of constraints.
test("cook_snaps: unauthenticated query is denied", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("visibility", "==", "sameAsRecipe")
      .get()
  );
});

// a friend query explicitly constrained to visibility == 'onlyMe' for a
// foreign userId is denied — the deny half of the query-level visibility
// gate (the allow half is the sameAsRecipe query above).
test("cook_snaps: friend query constrained to onlyMe is denied", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "==", OWNER_UID)
      .where("visibility", "==", "onlyMe")
      .get()
  );
});

// admin moderation override still works on onlyMe snaps (reported content
// must stay reviewable regardless of visibility).
test("cook_snaps: admin can read an onlyMe snap (moderation)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-mod`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-onlyme-mod`).get());
});

// a query whose result set would include a stranger's snap is denied
// wholesale (Firestore rule semantics — per-doc evaluation; any deny
// fails the entire query). Proves the friend-list-pre-filter pattern is
// not optional at the app layer.
test("cook_snaps: query that would include a stranger's snap is denied", async () => {
  const STRANGER_OWNER = "stranger-owner-uid";
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-stranger`)
      .set(validSnapBody({ recipeId: "recipe-q2", userId: STRANGER_OWNER }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q2")
      .where("userId", "in", [FRIEND_UID, STRANGER_OWNER])
      .get()
  );
});

// ============================================================================
// COOK SNAPS — create (validated)
// ============================================================================

// authenticated user can create a snap with userId == auth.uid and all
// required fields.
test("cook_snaps: owner can create a valid snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-create-ok`).set(validSnapBody())
  );
});

// cannot impersonate — userId in body must match auth.uid.
test("cook_snaps: cannot create a snap impersonating another user", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-impersonate`)
      .set(validSnapBody({ userId: OWNER_UID }))
  );
});

// missing required field (photoUrl) is rejected.
test("cook_snaps: create without required photoUrl is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  const bodyMissing = { ...validSnapBody() } as Record<string, unknown>;
  delete bodyMissing.photoUrl;
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-no-photo`).set(bodyMissing)
  );
});

// oversized userDisplayName (>100) is rejected.
test("cook_snaps: oversized userDisplayName is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-big-name`)
      .set(validSnapBody({ userDisplayName: "x".repeat(101) }))
  );
});

// oversized caption (>200) is rejected.
test("cook_snaps: oversized caption is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-big-caption`)
      .set(validSnapBody({ caption: "x".repeat(201) }))
  );
});

// ============================================================================
// COOK SNAPS — update (owner-only, immutable identity fields)
// ============================================================================

// owner can update caption only.
test("cook_snaps: owner can update caption only", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-update`)
      .set(validSnapBody({ caption: "old" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-update`)
      .update({ caption: "new" })
  );
});

// owner cannot modify the immutable userId field.
test("cook_snaps: owner cannot modify userId", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-mutate-uid`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-mutate-uid`)
      .update({ userId: STRANGER_UID })
  );
});

// ============================================================================
// COOK SNAPS — delete (owner or admin)
// ============================================================================

// non-owner non-admin cannot delete.
test("cook_snaps: non-owner non-admin cannot delete", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-stranger-del`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-stranger-del`).delete()
  );
});

// snap-owner can delete own snap.
test("cook_snaps: owner can delete own snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-self-del`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-self-del`).delete()
  );
});

// admin can read AND delete any snap (moderation override).
//  Proves both halves of the `allow read, delete: if isAdmin();` rule.
test("cook_snaps: admin can read and delete any snap (moderation)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-mod`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-mod`).get());
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-mod`).delete());
});

// ============================================================================
// MESSAGES — admin-read moderation override (the new clause)
// ============================================================================

// Helper: seed a conversation with two participants and one message.
async function seedMessage(
  msgId: string,
  conversationId: string,
  participants: string[]
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`conversations/${conversationId}`)
      .set({ participantIds: participants, createdAt: new Date() });
    await admin
      .firestore()
      .doc(`messages/${msgId}`)
      .set({
        senderId: participants[0],
        conversationId,
        content: "Hej!",
        sentAt: new Date(),
      });
  });
}

// admin who is NOT a conversation participant can read a message.
//     Proves the new `allow read: if isAdmin();` clause works — the base
//     read rule restricts to participants only.
test("messages: admin (non-participant) can read any message", async () => {
  await seedMessage("m-mod", "conv-mod", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/m-mod`).get());
});

// regression: non-admin non-participant still denied.
test("messages: non-admin non-participant cannot read a message", async () => {
  await seedMessage("m-private", "conv-private", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`messages/m-private`).get());
});

// regression: admin can still delete (moderation
// pipeline expects both read + delete to work).
test("messages: admin can delete any message (moderation)", async () => {
  await seedMessage("m-del", "conv-del", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/m-del`).delete());
});

async function run(): Promise<void> {
  console.log("cook_snaps + messages admin-read rules tests\n");
  console.log("============================================\n");
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
