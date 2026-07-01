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

// Test isolation: the Firestore emulator persists documents across separate
// `npm run` invocations (env.cleanup() only closes clients, it does NOT wipe
// stored data). An `assertSucceeds(set(...))` against a FIXED doc id that
// already exists from a prior run is evaluated as an UPDATE, not a CREATE —
// and the recipe_comments update rule only permits text/counter changes, so a
// full-body re-set is denied and the create-allow test fails on the 2nd+ run.
// A per-run suffix keeps every create-allow target a brand-new doc id.
// (See firestore-rules-tester knowledge file, 2026-06-03 entry.)
const RUN = Date.now().toString(36);

// BUT-1386 (ADR-0002): recipe_comments + recipe_ratings create require
// `isAgeCompliant()` (custom claim `ageCompliant == true`).
// BUT-1419: recipe_comments create ADDITIONALLY requires `isAccountMatured()`
// (email_verified OR user-doc createdAt >= 60min); recipe_ratings was already
// maturity-gated by BUT-659. Every authed context that performs a create on a
// gated path therefore carries BOTH `ageCompliant:true` and `email_verified:true`
// so each test keeps isolating its intended gate (blocking / imageUrls /
// impersonation), not the age or maturity gate. Without maturity every comment
// create-allow fails closed — that is the BUT-1419 regression this file proves.
// (user_notifications creates are NOT age- or maturity-gated and stay claimless.)
const AGE_OK_MATURED = { ageCompliant: true, email_verified: true };

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

// ALLOW: a non-blocked, matured, age-compliant user can comment on the recipe
// owner's recipe.
test("recipe_comments: non-blocked user can create a comment", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-create-allow-${RUN}`)
      .set(validCommentBody(AUTHOR_UID))
  );
});

// BUT-1419 DENY: a fresh, unverified account (email_verified false, no matured
// user doc) cannot create a comment even when age-compliant. This is the
// load-bearing deny for the new maturity gate — proves a "register → blast →
// abandon" bot is blocked from comments the same way it is from DMs. FRESH_UID
// has NO seeded users/{uid} doc, so isAccountMatured()'s second branch (createdAt
// >= 60min) is also false; the write fails closed.
test("recipe_comments: fresh unverified account cannot create a comment", async () => {
  const FRESH_UID = "fresh-comment-author-uid";
  const ctx = env.authenticatedContext(FRESH_UID, {
    ageCompliant: true,
    email_verified: false,
  });
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-fresh-${RUN}`)
      .set(validCommentBody(FRESH_UID, { recipeOwnerId: FRESH_UID }))
  );
});

// BUT-1419 ALLOW: an age-compliant author whose email is verified is matured
// immediately (verified-email bypasses the 60min wait) and can create a comment.
// The allow-with-maturity companion to the fresh-account deny above; without it a
// blanket-deny regression of the maturity gate would pass the deny test silently.
test("recipe_comments: verified-email account can create a comment immediately", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-verified-${RUN}`)
      .set(validCommentBody(AUTHOR_UID))
  );
});

// DENY: a user who has been blocked by the recipe owner cannot create a
// comment on that recipe (blocking-gate kicks in via recipeOwnerId).
test("recipe_comments: blocked user cannot create a comment on blocker's recipe", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID, AGE_OK_MATURED);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-create-blocked`)
      .set(validCommentBody(BLOCKED_UID))
  );
});

// ----------------------------------------------------------------------------
// A4: recipe_comments create — imageUrls validator (BUT-1049)
//
// The create rule does NOT restrict the field-set (it uses hasAll, a subset
// check), so imageUrls was already accepted unvalidated. BUT-1049 adds a
// conditional validator: when present, imageUrls must be a list of size <= 3.
// The author identity check (auth.uid == authorId) is unchanged and must
// still gate every create.
// ----------------------------------------------------------------------------

// ALLOW: author creates a comment with a valid imageUrls list (<= 3 strings).
test("recipe_comments: author can create a comment with <=3 image URLs", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-ok-${RUN}`)
      .set(
        validCommentBody(AUTHOR_UID, {
          imageUrls: [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg",
            "https://example.com/c.jpg",
          ],
        })
      )
  );
});

// ALLOW (back-compat): a comment with no imageUrls field still creates — the
// validator only fires when the field is present.
test("recipe_comments: author can create a comment with no imageUrls (back-compat)", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-absent-${RUN}`)
      .set(validCommentBody(AUTHOR_UID))
  );
});

// ALLOW: an empty imageUrls list is a valid list of size 0.
test("recipe_comments: author can create a comment with an empty imageUrls list", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-empty-${RUN}`)
      .set(validCommentBody(AUTHOR_UID, { imageUrls: [] }))
  );
});

// DENY: more than 3 image URLs exceeds the size cap.
test("recipe_comments: create with >3 image URLs is denied", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-toomany`)
      .set(
        validCommentBody(AUTHOR_UID, {
          imageUrls: [
            "https://example.com/a.jpg",
            "https://example.com/b.jpg",
            "https://example.com/c.jpg",
            "https://example.com/d.jpg",
          ],
        })
      )
  );
});

// DENY: imageUrls of the wrong type (a string, not a list) is rejected by the
// `is list` guard.
test("recipe_comments: create with non-list imageUrls is denied", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-wrongtype`)
      .set(
        validCommentBody(AUTHOR_UID, {
          imageUrls: "https://example.com/a.jpg",
        })
      )
  );
});

// DENY (existing author check still holds): a stranger setting authorId to
// themselves but writing a valid imageUrls list onto another user's recipe
// comment must still be gated by the unchanged auth.uid == authorId check.
// Here the blocked user (who the owner blocked) tries to create a comment with
// images — the impersonation/blocking gate is unaffected by the new validator.
test("recipe_comments: blocked user cannot create an image comment on blocker's recipe", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID, AGE_OK_MATURED);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-blocked`)
      .set(
        validCommentBody(BLOCKED_UID, {
          imageUrls: ["https://example.com/a.jpg"],
        })
      )
  );
});

// DENY (author check): a user cannot create a comment whose authorId is
// someone else's, regardless of a valid imageUrls list.
test("recipe_comments: cannot create an image comment impersonating another author", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, AGE_OK_MATURED);
  await assertFails(
    ctx
      .firestore()
      .doc(`recipe_comments/c-img-impersonate`)
      .set(
        validCommentBody(AUTHOR_UID, {
          imageUrls: ["https://example.com/a.jpg"],
        })
      )
  );
});

// ----------------------------------------------------------------------------
// A3: recipe_ratings create — blocking gate (BUT-459)
// ----------------------------------------------------------------------------

test("recipe_ratings: non-blocked user can rate a recipe", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID, AGE_OK_MATURED);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`recipe_ratings/recipe-1_${AUTHOR_UID}_${RUN}`)
      .set(validRatingBody(AUTHOR_UID))
  );
});

test("recipe_ratings: blocked user cannot rate the blocker's recipe", async () => {
  const ctx = env.authenticatedContext(BLOCKED_UID, AGE_OK_MATURED);
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
      .doc(`user_notifications/n-allow-${RUN}`)
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
      .doc(`user_notifications/n-self-${RUN}`)
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

