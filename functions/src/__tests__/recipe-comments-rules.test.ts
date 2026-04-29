/**
 * Firestore rules tests for the BUT-458 + BUT-459 hardenings of
 * `recipe_comments` and the related blocking gates on `recipe_ratings`
 * and `user_notifications`.
 *
 * Before BUT-458: any authenticated user could read every comment in
 * the global `recipe_comments` collection — recipe ownership was not
 * server-verifiable from the comment doc. BUT-458 adds denormalised
 * `recipeOwnerId` + `sharedWithUserIds` onto every new comment so the
 * read rule can restrict access to owner / shared recipients / author /
 * admin. Legacy comments without these fields fall back to author-only
 * read.
 *
 * BUT-459 layers the blocking gate on top — comment / rating /
 * notification creates targeting a user that has blocked the actor
 * are denied via `isNotBlockedBy(...)`. Notifications use the
 * existing recipient-uid field; comments + ratings use the
 * denormalised `recipeOwnerId`.
 *
 * Each test name states the behavior it proves. If a test fails, either
 * the rules regressed or the design intent changed — decide which.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/recipe-comments-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-recipe-comments";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "recipe-owner-uid";
const AUTHOR_UID = "comment-author-uid";
const SHARED_UID = "shared-recipient-uid";
const STRANGER_UID = "stranger-uid";
const BLOCKED_UID = "blocked-uid";
const ADMIN_UID = "admin-uid";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  await env.withSecurityRulesDisabled(async (ctx) => {
    // Admin record (rules-locked collection).
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
    });

    // Friendship records used by user_notification create rule.
    // friend pairs: AUTHOR<->OWNER and BLOCKED<->OWNER (so BUT-459 blocking
    // gate is the discriminator, not the friendship gate).
    for (const a of [AUTHOR_UID, BLOCKED_UID, OWNER_UID]) {
      for (const b of [AUTHOR_UID, BLOCKED_UID, OWNER_UID]) {
        if (a === b) continue;
        await ctx
          .firestore()
          .doc(`users/${a}/friends/${b}`)
          .set({ addedAt: new Date() });
      }
    }

    // Block record: OWNER has blocked BLOCKED_UID.
    // Block doc id format is `${blockerUid}_${blockedUid}` per the
    // rule helper `isNotBlockedBy(target)` (returns false when
    // /blocks/${target}_${request.auth.uid} exists).
    await ctx
      .firestore()
      .doc(`blocks/${OWNER_UID}_${BLOCKED_UID}`)
      .set({ blockedAt: new Date() });
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
// Body builders
// ----------------------------------------------------------------------------

/** Comment body that satisfies all required fields including the new denorm. */
function validCommentBody(
  authorUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    authorId: authorUid,
    text: "ser gott ut!",
    createdAt: serverTimestamp(),
    recipeOwnerId: OWNER_UID,
    sharedWithUserIds: [SHARED_UID],
    likesCount: 0,
    replyCount: 0,
    isDeleted: false,
    ...extra,
  };
}

/** Rating body with the new optional recipeOwnerId field. */
function validRatingBody(
  raterUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    userId: raterUid,
    rating: 5,
    createdAt: serverTimestamp(),
    recipeOwnerId: OWNER_UID,
    ...extra,
  };
}

/** Notification body — recipient is the second arg. */
function validNotificationBody(
  senderUid: string,
  recipientUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    userId: recipientUid,
    senderId: senderUid,
    type: "comment",
    title: "ny kommentar",
    body: "någon har kommenterat ditt recept",
    createdAt: serverTimestamp(),
    ...extra,
  };
}

// ----------------------------------------------------------------------------
// A2: recipe_comments read access (4 deny + 3 allow)
// ----------------------------------------------------------------------------

async function seedComment(
  id: string,
  body: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`recipe_comments/${id}`).set(body);
  });
}

// ALLOW: comment author can always read their own comment (covers also
// the legacy fallback path — author-only read for rows lacking
// recipeOwnerId).
test("recipe_comments: comment author can read own comment", async () => {
  await seedComment("c-author-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(ctx.firestore().doc(`recipe_comments/c-author-read`).get());
});

// ALLOW: recipe owner can read comments on their own recipe (the BUT-458
// denormalised access path).
test("recipe_comments: recipe owner can read comments on their recipe", async () => {
  await seedComment("c-owner-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`recipe_comments/c-owner-read`).get());
});

// ALLOW: a user the recipe was shared with can read its comments.
test("recipe_comments: shared recipient can read comments", async () => {
  await seedComment("c-shared-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(SHARED_UID);
  await assertSucceeds(ctx.firestore().doc(`recipe_comments/c-shared-read`).get());
});

// DENY: a random authenticated stranger cannot read a comment on a
// recipe they don't own and weren't shared.
test("recipe_comments: random user cannot read other people's comments", async () => {
  await seedComment("c-stranger-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`recipe_comments/c-stranger-read`).get());
});

// DENY: a blocked user cannot read comments on the blocker's recipe
// (defence-in-depth — the create rule already denies, but reading
// another blocked user's prior comment would still leak).
test("recipe_comments: blocked user cannot read comments on blocker's recipe", async () => {
  await seedComment("c-blocked-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(BLOCKED_UID);
  await assertFails(ctx.firestore().doc(`recipe_comments/c-blocked-read`).get());
});

// DENY: an unauthenticated client cannot read.
test("recipe_comments: unauthenticated client cannot read", async () => {
  await seedComment("c-anon-read", validCommentBody(AUTHOR_UID));
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`recipe_comments/c-anon-read`).get());
});

// DENY: a user not in sharedWithUserIds (i.e. the recipe was shared but
// not with them) cannot read.
test("recipe_comments: non-shared user cannot read despite recipe being shared", async () => {
  await seedComment(
    "c-not-shared-read",
    validCommentBody(AUTHOR_UID, { sharedWithUserIds: ["someone-else-uid"] })
  );
  const ctx = env.authenticatedContext(SHARED_UID);
  await assertFails(ctx.firestore().doc(`recipe_comments/c-not-shared-read`).get());
});

// ALLOW (admin override): admins can read any comment for moderation.
test("recipe_comments: admin can read any comment (moderation)", async () => {
  await seedComment("c-mod-read", validCommentBody(AUTHOR_UID));
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`recipe_comments/c-mod-read`).get());
});

// ----------------------------------------------------------------------------
// A3: recipe_comments create — blocking gate (BUT-459)
// ----------------------------------------------------------------------------

// ALLOW: a non-blocked user can comment on the recipe owner's recipe.
test("recipe_comments: non-blocked user can create a comment", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-create-allow`)
      .set(validCommentBody(AUTHOR_UID))
  );
});

// DENY: a user who has been blocked by the recipe owner cannot create a
// comment on that recipe (blocking-gate kicks in via recipeOwnerId).
test("recipe_comments: blocked user cannot create a comment on blocker's recipe", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-create-blocked`)
      .set(validCommentBody(BLOCKED_UID))
  );
});

// ----------------------------------------------------------------------------
// A3: recipe_ratings create — blocking gate (BUT-459)
// ----------------------------------------------------------------------------

test("recipe_ratings: non-blocked user can rate a recipe", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/recipe-1_${AUTHOR_UID}`)
      .set(validRatingBody(AUTHOR_UID))
  );
});

test("recipe_ratings: blocked user cannot rate the blocker's recipe", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_ratings/recipe-1_${BLOCKED_UID}`)
      .set(validRatingBody(BLOCKED_UID))
  );
});

// ----------------------------------------------------------------------------
// A3: user_notifications create — blocking gate (BUT-459)
// ----------------------------------------------------------------------------

test("user_notifications: non-blocked friend can send a cross-user notification", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`user_notifications/n-allow`)
      .set(validNotificationBody(AUTHOR_UID, OWNER_UID))
  );
});

test("user_notifications: blocked friend cannot notify the blocker", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`user_notifications/n-blocked`)
      .set(validNotificationBody(BLOCKED_UID, OWNER_UID))
  );
});

// regression: self-notifications still work (system events). Self-notify
// is an explicit branch in the rule that bypasses both the friendship
// gate and the new blocking gate.
test("user_notifications: self-notification still allowed", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`user_notifications/n-self`)
      .set(validNotificationBody(AUTHOR_UID, AUTHOR_UID))
  );
});

async function run(): Promise<void> {
  console.log("recipe_comments + ratings + notifications rules tests");
  console.log("(BUT-458 / BUT-459)");
  console.log("=====================================================\n");
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

