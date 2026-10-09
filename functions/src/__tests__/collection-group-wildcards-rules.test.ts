/**
 * BUT-1512: Firestore rules tests for the owner-field-shape convention behind
 * every `{path=**}/<name>/{id}` collection-group wildcard in firestore.rules.
 *
 * The `members` wildcard already has its own dedicated suite
 * (`members-collection-group-rules.test.ts`, BUT-463). This suite covers the
 * remaining catch-all wildcards that gate reads on an owner FIELD/LIST (or,
 * for `engagements`, the owner DOC-ID) — each one silently trusts that every
 * present AND future subcollection of that name carries the expected owner shape:
 *
 *   {path=**}/friend_categories/{categoryId} → allow read if auth.uid in resource.data.friendUserIds (LIST)
 *   {path=**}/engagements/{userId}  → allow read  if auth.uid == userId (DOC-ID)
 *   {path=**}/comments/{commentId}  → allow read,delete if resource.data.commentedBy == auth.uid
 *   {path=**}/ratings/{ratingId}    → allow read,delete if resource.data.ratedBy   == auth.uid
 *   {path=**}/recipes/{recipeId}    → allow read  if isAdmin()   (admin-only, not owner-shaped)
 *   {path=**}/likes/{likeId}        → allow read  if resource.data.userId == auth.uid (BUT-2114)
 *   {path=**}/pings/{pingId}        → allow read,delete if resource.data.fromUserId == auth.uid
 *                                                          || resource.data.toUserId == auth.uid
 *
 * Each wildcard is exercised on a NOVEL parent path so that ONLY the catch-all
 * can match — the same isolation trick the members suite uses. That makes the
 * catch-all the single gate under test, so a future leaky narrower rule can't
 * mask a regression here. Two failure shapes are proven for every field-shaped
 * rule: an owner-field-MISSING doc is denied, and a FOREIGN-owner doc is denied.
 * `recipes` is admin-gated rather than owner-shaped, so it asserts admin-allow /
 * non-admin-deny instead.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/collection-group-wildcards-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-cg-wildcards-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "owner-uid";
const OTHER = "other-uid";
const ADMIN = "admin-uid";

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
  // isAdmin() checks for a doc at admins/{uid}; seed one so the recipes
  // collection-group admin-read case has a real admin principal.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN}`).set({ addedAt: Date.now() });
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

/** Seed a document at an arbitrary path, bypassing rules. */
async function seed(docPath: string, data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(data);
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ── friend_categories: gate is `auth.uid in resource.data.friendUserIds` ──
// A member of the category's friendUserIds LIST may read it across all users
// (enables the collectionGroup('friend_categories').where('friendUserIds',
// arrayContains: uid) query). The catch-all grants READ ONLY — owner CRUD is
// governed by the scoped users/{uid}/friend_categories rule, not this one.

test("friend_categories: a member (uid in friendUserIds) reads the row", async () => {
  await seed(`cg_wild/fc1/friend_categories/x`, { friendUserIds: [OWNER, OTHER] });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`cg_wild/fc1/friend_categories/x`).get()
  );
});

test("friend_categories: a NON-member is denied", async () => {
  await seed(`cg_wild/fc2/friend_categories/x`, { friendUserIds: [OTHER] });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`cg_wild/fc2/friend_categories/x`).get()
  );
});

test("friend_categories: a row missing friendUserIds is denied", async () => {
  await seed(`cg_wild/fc3/friend_categories/x`, { name: "no members list" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`cg_wild/fc3/friend_categories/x`).get()
  );
});

test("friend_categories: unauthenticated request denied", async () => {
  await seed(`cg_wild/fc4/friend_categories/x`, { friendUserIds: [OWNER] });
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`cg_wild/fc4/friend_categories/x`).get()
  );
});

test("friend_categories: the catch-all is READ-ONLY — a member cannot delete via it", async () => {
  await seed(`cg_wild/fc5/friend_categories/x`, { friendUserIds: [OWNER] });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`cg_wild/fc5/friend_categories/x`).delete()
  );
});

// ── engagements: gate is the DOC-ID {userId}, not a data field ──
// The rule proves ownership from the wildcard segment, so a doc carrying no
// data field at all still reads iff its id equals auth.uid; a mismatched id
// is denied regardless of any userId field the doc happens to hold.

test("engagements: owner reads a row whose DOC-ID equals their uid", async () => {
  await seed(`cg_wild/e1/engagements/${OWNER}`, { kind: "view" });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`cg_wild/e1/engagements/${OWNER}`).get()
  );
});

test("engagements: stranger CANNOT read a row keyed to another uid", async () => {
  await seed(`cg_wild/e2/engagements/${OWNER}`, { kind: "view" });
  const ctx = env.authenticatedContext(OTHER);
  await assertFails(
    ctx.firestore().doc(`cg_wild/e2/engagements/${OWNER}`).get()
  );
});

test("engagements: a foreign-uid field cannot override the doc-id gate", async () => {
  // Doc keyed to OTHER but carrying `userId: OWNER` — the rule ignores the
  // field and keys off the id, so OWNER is still denied.
  await seed(`cg_wild/e3/engagements/${OTHER}`, { userId: OWNER });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`cg_wild/e3/engagements/${OTHER}`).get()
  );
});

test("engagements: unauthenticated request denied", async () => {
  await seed(`cg_wild/e4/engagements/${OWNER}`, { kind: "view" });
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().doc(`cg_wild/e4/engagements/${OWNER}`).get()
  );
});

// ── comments: gate is resource.data.commentedBy == auth.uid (read, delete) ──

test("comments: owner reads their own row (commentedBy == uid)", async () => {
  await seed(`cg_wild/c1/comments/x`, { commentedBy: OWNER, text: "hi" });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/c1/comments/x`).get());
});

test("comments: owner-field-MISSING doc is denied", async () => {
  await seed(`cg_wild/c2/comments/x`, { text: "no owner field" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/c2/comments/x`).get());
});

test("comments: FOREIGN-owner doc is denied", async () => {
  await seed(`cg_wild/c3/comments/x`, { commentedBy: OTHER, text: "theirs" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/c3/comments/x`).get());
});

test("comments: owner can DELETE their own row", async () => {
  await seed(`cg_wild/c4/comments/x`, { commentedBy: OWNER, text: "mine" });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/c4/comments/x`).delete());
});

test("comments: owner CANNOT delete a foreign row", async () => {
  await seed(`cg_wild/c5/comments/x`, { commentedBy: OTHER, text: "theirs" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/c5/comments/x`).delete());
});

// ── ratings: gate is resource.data.ratedBy == auth.uid (read, delete) ──

test("ratings: owner reads their own row (ratedBy == uid)", async () => {
  await seed(`cg_wild/r1/ratings/x`, { ratedBy: OWNER, value: 5 });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/r1/ratings/x`).get());
});

test("ratings: owner-field-MISSING doc is denied", async () => {
  await seed(`cg_wild/r2/ratings/x`, { value: 5 });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/r2/ratings/x`).get());
});

test("ratings: FOREIGN-owner doc is denied", async () => {
  await seed(`cg_wild/r3/ratings/x`, { ratedBy: OTHER, value: 5 });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/r3/ratings/x`).get());
});

test("ratings: owner can DELETE their own row", async () => {
  await seed(`cg_wild/r4/ratings/x`, { ratedBy: OWNER, value: 5 });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/r4/ratings/x`).delete());
});

test("ratings: owner CANNOT delete a foreign row", async () => {
  await seed(`cg_wild/r5/ratings/x`, { ratedBy: OTHER, value: 5 });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/r5/ratings/x`).delete());
});

// ── recipes: gate is isAdmin() — admin-only read, not owner-shaped ──

test("recipes: admin can read any recipe via the catch-all", async () => {
  await seed(`cg_wild/rec1/recipes/x`, { title: "Soppa" });
  const ctx = env.authenticatedContext(ADMIN);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/rec1/recipes/x`).get());
});

test("recipes: non-admin authenticated user is denied", async () => {
  await seed(`cg_wild/rec2/recipes/x`, { title: "Soppa" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/rec2/recipes/x`).get());
});

test("recipes: unauthenticated request denied", async () => {
  await seed(`cg_wild/rec3/recipes/x`, { title: "Soppa" });
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`cg_wild/rec3/recipes/x`).get());
});

// ── likes: gate is resource.data.userId == auth.uid (read only, BUT-2114) ──
// The Art. 15 export reads `collectionGroup('likes').where('userId', ==, uid)`
// (FirebaseDataExportRepository.exportLikesByUser). `recipe_comments` has a
// nested `likes` rule; `cook_snaps` has none.

function likeBody(userId: string): Record<string, unknown> {
  return { userId, likedAt: new Date() };
}

async function seedLikes(): Promise<void> {
  await seed(`recipe_comments/cgl_c1/likes/${OWNER}`, likeBody(OWNER));
  await seed(`recipe_comments/cgl_c1/likes/${OTHER}`, likeBody(OTHER));
  await seed(`cook_snaps/cgl_s1/likes/${OWNER}`, likeBody(OWNER));
  await seed(`cook_snaps/cgl_s1/likes/${OTHER}`, likeBody(OTHER));
}

// L1: the production read shape, filtered and limited as the repository sends it.
test("likes: owner's filtered collection-group query returns their rows under recipe_comments AND cook_snaps", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OWNER);
  const snap = await assertSucceeds(
    ctx.firestore().collectionGroup("likes")
      .where("userId", "==", OWNER).limit(1000).get()
  );
  const paths = snap.docs.map((d) => d.ref.path);
  for (const want of [
    `recipe_comments/cgl_c1/likes/${OWNER}`,
    `cook_snaps/cgl_s1/likes/${OWNER}`,
  ]) {
    if (!paths.includes(want)) {
      throw new Error(`expected ${want} in ${JSON.stringify(paths)}`);
    }
  }
  if (snap.docs.some((d) => d.data().userId !== OWNER)) {
    throw new Error(`foreign row returned: ${JSON.stringify(paths)}`);
  }
});

// L2
test("likes: a collection-group query filtered on ANOTHER uid is refused", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().collectionGroup("likes").where("userId", "==", OTHER).get()
  );
});

// L3
test("likes: an UNFILTERED collection-group query is refused", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().collectionGroup("likes").get());
});

// L4
test("likes: unauthenticated filtered collection-group query is refused", async () => {
  await seedLikes();
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx.firestore().collectionGroup("likes").where("userId", "==", OWNER).get()
  );
});

// L5: the doc id equals the caller's uid, so this also pins that the gate is
// the FIELD, not the id.
test("likes: a row LACKING userId is denied, even when its id is the caller's uid", async () => {
  await seed(`cg_wild/l5/likes/${OWNER}`, { likedAt: new Date() });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/l5/likes/${OWNER}`).get());
});

// L6: fail-closed control for L5, L7 and the write denies below.
test("likes: owner reads their own row on a novel parent path", async () => {
  await seed(`cg_wild/l6/likes/${OWNER}`, likeBody(OWNER));
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/l6/likes/${OWNER}`).get());
});

// L7
test("likes: FOREIGN-owner row on a novel parent path is denied", async () => {
  await seed(`cg_wild/l7/likes/${OTHER}`, likeBody(OTHER));
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/l7/likes/${OTHER}`).get());
});

// L8
test("likes: the catch-all is READ-ONLY — owner cannot CREATE their own like on a novel path", async () => {
  const p = `foo/l8/likes/${OWNER}`;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = await ctx.firestore().doc(p).get();
    if (s.exists) throw new Error(`${p} must be absent so this lands on create`);
  });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(p).set(likeBody(OWNER)));
});

// L9
test("likes: the catch-all is READ-ONLY — owner cannot DELETE their own like on a novel path", async () => {
  await seed(`foo/l9/likes/${OWNER}`, likeBody(OWNER));
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`foo/l9/likes/${OWNER}`).delete());
});

// L10
test("likes: the catch-all is READ-ONLY — owner cannot UPDATE their own like on a novel path", async () => {
  await seed(`foo/l10/likes/${OWNER}`, likeBody(OWNER));
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`foo/l10/likes/${OWNER}`).update({ likedAt: new Date() })
  );
});

// L11: cook_snaps has no nested likes rule, so no client write reaches its rows.
test("likes: owner cannot DELETE their own like under cook_snaps", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cgl_s1/likes/${OWNER}`).delete()
  );
});

// L12
test("likes: a stranger cannot get another user's like under cook_snaps", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OTHER);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cgl_s1/likes/${OWNER}`).get()
  );
});

// L13: unchanged behaviour of the nested recipe_comments rule.
test("likes: direct get of ANOTHER user's comment like is still allowed (nested rule)", async () => {
  await seedLikes();
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(`recipe_comments/cgl_c1/likes/${OTHER}`).get()
  );
});

// L14: hasUserLikedComment gets the caller's like id whether or not it exists.
test("likes: get of an ABSENT own comment like is still allowed (nested rule)", async () => {
  const p = `recipe_comments/cgl_c2/likes/${OWNER}`;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(p).delete();
  });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(p).get());
});

// ── pings: gate is fromUserId == uid OR toUserId == uid (read, delete) ──

test("pings: sender (fromUserId) reads their own row", async () => {
  await seed(`cg_wild/p1/pings/x`, { fromUserId: OWNER, toUserId: OTHER });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/p1/pings/x`).get());
});

test("pings: recipient (toUserId) reads a row addressed to them", async () => {
  await seed(`cg_wild/p2/pings/x`, { fromUserId: OTHER, toUserId: OWNER });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/p2/pings/x`).get());
});

test("pings: owner-fields-MISSING doc is denied", async () => {
  await seed(`cg_wild/p3/pings/x`, { note: "no party fields" });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/p3/pings/x`).get());
});

test("pings: uninvolved user (neither party) is denied", async () => {
  await seed(`cg_wild/p4/pings/x`, { fromUserId: OTHER, toUserId: ADMIN });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/p4/pings/x`).get());
});

test("pings: a party can DELETE their own row", async () => {
  await seed(`cg_wild/p5/pings/x`, { fromUserId: OWNER, toUserId: OTHER });
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`cg_wild/p5/pings/x`).delete());
});

test("pings: an uninvolved user CANNOT delete a row", async () => {
  await seed(`cg_wild/p6/pings/x`, { fromUserId: OTHER, toUserId: ADMIN });
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`cg_wild/p6/pings/x`).delete());
});

async function run(): Promise<void> {
  console.log("Collection-group wildcard owner-shape rules tests (BUT-1512)\n");
  console.log("=============================\n");
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
