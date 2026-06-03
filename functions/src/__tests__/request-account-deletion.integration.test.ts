/**
 * BUT-1009 — emulator-backed integration test for the account-deletion cascade.
 *
 * The sibling contract test (`request-account-deletion.test.ts`) wires a HAND-
 * ROLLED fake Firestore whose every query returns an empty snapshot, so the
 * cascade walks the full step list but deletes NOTHING. It proves the
 * orchestration envelope (step names, audit-log shape, auth-delete-last) — but
 * cannot prove that any per-step delete/scrub/anonymize actually touches data.
 *
 * This test runs `runAccountDeletionWithDeps` against a REAL Firestore
 * emulator (127.0.0.1:8080, started by the BUT-1049 CI job / the local
 * `ensure-firestore-emulator.sh` hook). It seeds realistic per-collection
 * fixtures for a target uid, runs the cascade with the live emulator Firestore
 * (auth + storage are still injected fakes — this test is about the FIRESTORE
 * cascade, not auth deletion or storage wipe, both already covered by the
 * contract test), then asserts each cascade step with a POSITIVE + NEGATIVE
 * assertion:
 *
 *   - own-data collections empty for the uid; a CONTROL doc owned by a
 *     different uid in the same collection still present (proves scope).
 *   - inbound shared menu: uid scrubbed from sharedToUserIds, doc retained.
 *   - group_weekly_menu_plans: uid removed from participantUserIds; the
 *     now-empty plan deleted; the still-populated plan retained.
 *   - recipe_comments authored by uid: authorId anonymized to 'deleted'
 *     (NOT deleted — preserves thread structure).
 *   - recipe_ratings: hard-deleted.
 *   - conversations: >2 participants → uid arrayRemove'd (retained);
 *     1:1 → deleted.
 *
 * The cascade uses the Admin SDK; pointing the Admin SDK at the emulator only
 * needs `FIRESTORE_EMULATOR_HOST` set BEFORE `admin.initializeApp`. The Admin
 * SDK bypasses security rules, so seeding is plain writes (no
 * withSecurityRulesDisabled — that is a rules-unit-testing concept).
 *
 * Per-test isolation: the emulator persists data across runs (env.cleanup
 * does not wipe — see firestore-rules-tester knowledge 2026-06-03). We use a
 * per-RUN uid suffix AND clear the namespace via the emulator REST DELETE
 * endpoint in setup so a re-run starts clean.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/request-account-deletion.integration.test.ts
 */

import * as http from "http";

const PROJECT_ID = "butlery-acct-deletion-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

// MUST be set before firebase-admin is imported/initialised so the Admin SDK
// routes all traffic to the emulator instead of demanding GCP credentials.
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  runAccountDeletionWithDeps,
} = require("../account/request-account-deletion");

// Per-run suffix keeps re-runs from colliding on fixed ids even if the
// emulator wasn't cleared (defence-in-depth alongside clearEmulator()).
const RUN = Date.now().toString(36);
const TARGET = `target-${RUN}`;
const OTHER = `other-${RUN}`;
const THIRD = `third-${RUN}`;

// ---------------------------------------------------------------------------
// Injected fakes — auth + storage are NOT under test here.
// ---------------------------------------------------------------------------

function fakeAuth(): admin.auth.Auth {
  return {
    async deleteUser(_uid: string) {
      // no-op: auth deletion is covered by the contract test.
    },
  } as unknown as admin.auth.Auth;
}

function fakeStorage(): admin.storage.Storage {
  return {
    bucket() {
      return {
        async deleteFiles(_opts: { prefix: string }) {
          // no-op: storage wipe is covered by the contract test.
        },
      };
    },
  } as unknown as admin.storage.Storage;
}

// ---------------------------------------------------------------------------
// Emulator namespace reset (REST DELETE) — the emulator persists data across
// process invocations; env teardown only closes clients.
// ---------------------------------------------------------------------------

function clearEmulator(): Promise<void> {
  return new Promise((resolve, reject) => {
    const [host, portStr] = EMULATOR_HOST.split(":");
    const req = http.request(
      {
        host,
        port: Number(portStr),
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
        method: "DELETE",
      },
      (res) => {
        res.resume();
        res.on("end", () => resolve());
      },
    );
    req.on("error", reject);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

async function seedFixtures(): Promise<void> {
  // --- recipes: own (top-level) + own (subcollection) + control (other) ---
  await db.collection("recipes").doc(`r-own-${RUN}`).set({
    userId: TARGET,
    title: "min köttbullar",
  });
  await db
    .collection("users")
    .doc(TARGET)
    .collection("recipes")
    .doc(`r-sub-${RUN}`)
    .set({ title: "subrecept" });
  await db.collection("recipes").doc(`r-control-${RUN}`).set({
    userId: OTHER,
    title: "någon annans recept",
  });

  // --- menus: own subcollection + own top-level + inbound shared ---
  await db
    .collection("users")
    .doc(TARGET)
    .collection("menus")
    .doc(`m-sub-${RUN}`)
    .set({ menuTitle: "min veckomeny" });
  await db.collection("menus").doc(`m-own-${RUN}`).set({
    sharedByUserId: TARGET,
    menuTitle: "delad av mig",
    sharedAt: new Date(),
    sharedToUserIds: [OTHER],
  });
  // Inbound: someone else's menu shared TO the target. Target must be scrubbed
  // from sharedToUserIds but the menu itself must remain (it's OTHER's).
  await db.collection("menus").doc(`m-inbound-${RUN}`).set({
    sharedByUserId: OTHER,
    menuTitle: "delad till mig",
    sharedAt: new Date(),
    sharedToUserIds: [TARGET, THIRD],
  });

  // --- shopping_lists: own subcollection + control ---
  await db
    .collection("users")
    .doc(TARGET)
    .collection("shopping_lists")
    .doc(`sl-${RUN}`)
    .set({ name: "min lista" });
  await db
    .collection("users")
    .doc(OTHER)
    .collection("shopping_lists")
    .doc(`sl-control-${RUN}`)
    .set({ name: "annans lista" });

  // --- shared_content with target as a member (members subcollection) ---
  await db.collection("shared_content").doc(`sc-inbound-${RUN}`).set({
    sharedByUserId: OTHER,
    contentType: "recipe",
    sharedAt: new Date(),
    sharedToUserIds: [TARGET, THIRD],
  });
  await db
    .collection("shared_content")
    .doc(`sc-inbound-${RUN}`)
    .collection("members")
    .doc(TARGET)
    .set({ userId: TARGET });
  // shared_content OWNED by target (should be deleted with its members child).
  await db.collection("shared_content").doc(`sc-own-${RUN}`).set({
    sharedByUserId: TARGET,
    contentType: "recipe",
    sharedAt: new Date(),
    sharedToUserIds: [OTHER],
  });
  await db
    .collection("shared_content")
    .doc(`sc-own-${RUN}`)
    .collection("members")
    .doc(OTHER)
    .set({ userId: OTHER });

  // --- group_weekly_menu_plans: one empties on removal, one retains ---
  // Plan A: target is the only participant → removing target empties it → delete.
  await db.collection("group_weekly_menu_plans").doc(`gp-empty-${RUN}`).set({
    participantUserIds: [TARGET],
    participants: [{ userId: TARGET, name: "Target" }],
    memberPermissions: { [TARGET]: "owner" },
    week: "2026-W23",
  });
  // Plan B: target + other → removing target leaves other → retain & scrub.
  await db.collection("group_weekly_menu_plans").doc(`gp-shared-${RUN}`).set({
    participantUserIds: [TARGET, OTHER],
    participants: [
      { userId: TARGET, name: "Target" },
      { userId: OTHER, name: "Other" },
    ],
    memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
    week: "2026-W23",
  });

  // --- recipe_comments authored by target (anonymize, not delete) ---
  await db.collection("recipe_comments").doc(`rc-${RUN}`).set({
    recipeId: "recipe-x",
    authorId: TARGET,
    authorDisplayName: "Target",
    text: "gott!",
    isDeleted: false,
  });
  // control: another user's comment must be untouched.
  await db.collection("recipe_comments").doc(`rc-control-${RUN}`).set({
    recipeId: "recipe-x",
    authorId: OTHER,
    authorDisplayName: "Other",
    text: "också gott",
    isDeleted: false,
  });

  // --- recipe_ratings by target (hard delete) + control ---
  await db.collection("recipe_ratings").doc(`rr-${RUN}`).set({
    recipeId: "recipe-x",
    userId: TARGET,
    rating: 5,
  });
  await db.collection("recipe_ratings").doc(`rr-control-${RUN}`).set({
    recipeId: "recipe-x",
    userId: OTHER,
    rating: 3,
  });

  // --- conversations: 1:1 (delete) + >2 participants (arrayRemove, retain) ---
  await db.collection("conversations").doc(`conv-11-${RUN}`).set({
    participantIds: [TARGET, OTHER],
  });
  await db
    .collection("conversations")
    .doc(`conv-11-${RUN}`)
    .collection("messages")
    .doc("msg1")
    .set({ senderId: TARGET, text: "hej" });
  await db.collection("conversations").doc(`conv-group-${RUN}`).set({
    participantIds: [TARGET, OTHER, THIRD],
  });
  await db
    .collection("conversations")
    .doc(`conv-group-${RUN}`)
    .collection("messages")
    .doc("msg1")
    .set({ senderId: TARGET, text: "hej alla" });

  // --- collectionGroup pings/comments/ratings (BUT-1191) ---
  // These are walked by collectionGroup queries that match on author fields
  // that are NOT `userId`: pings key on `fromUserId`, comments on
  // `commentedBy`, ratings on `ratedBy`. Seed under a NON-recipe parent so the
  // test proves the catch-all collection-group traversal (not a path-scoped
  // query). All three are HARD-DELETED for the target; control docs by OTHER
  // under the same groups must survive.

  // pings: under an arbitrary parent (group_feed) so we exercise the
  // collectionGroup("pings") traversal across paths, not a fixed collection.
  await db
    .collection("group_feed")
    .doc(`gf-${RUN}`)
    .collection("pings")
    .doc(`ping-own-${RUN}`)
    .set({ fromUserId: TARGET, toUserId: OTHER, message: "pingar dig" });
  await db
    .collection("group_feed")
    .doc(`gf-${RUN}`)
    .collection("pings")
    .doc(`ping-control-${RUN}`)
    .set({ fromUserId: OTHER, toUserId: THIRD, message: "annans ping" });

  // comments: collectionGroup query keys on `commentedBy`. Seed under a
  // non-recipe parent (cook_snaps/{id}/comments) to prove path-agnostic walk.
  await db
    .collection("cook_snaps")
    .doc(`cs-${RUN}`)
    .collection("comments")
    .doc(`cmt-own-${RUN}`)
    .set({ commentedBy: TARGET, text: "snyggt!" });
  await db
    .collection("cook_snaps")
    .doc(`cs-${RUN}`)
    .collection("comments")
    .doc(`cmt-control-${RUN}`)
    .set({ commentedBy: OTHER, text: "tack" });

  // ratings: collectionGroup query keys on `ratedBy`. Seed under a non-recipe
  // parent (cook_snaps/{id}/ratings).
  await db
    .collection("cook_snaps")
    .doc(`cs-${RUN}`)
    .collection("ratings")
    .doc(`rat-own-${RUN}`)
    .set({ ratedBy: TARGET, value: 5 });
  await db
    .collection("cook_snaps")
    .doc(`cs-${RUN}`)
    .collection("ratings")
    .doc(`rat-control-${RUN}`)
    .set({ ratedBy: OTHER, value: 4 });

  // --- unified_shared_shopping_lists item-level scrub (BUT-1191) ---
  // The cascade queries `memberPermissions.{uid} != null` then rewrites the
  // `items` array, nulling assignedTo*/purchasedBy* fields on items where the
  // uid appears. The list itself is RETAINED (shared, not owned-only), other
  // members' item authorship untouched.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-${RUN}`)
    .set({
      name: "delad lista",
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      items: [
        // item 0: assigned AND purchased by target → both blocks scrubbed.
        {
          id: "i0",
          name: "mjölk",
          assignedToUserId: TARGET,
          assignedToDisplayName: "Target",
          assignedAt: new Date(),
          purchasedByUserId: TARGET,
          purchasedByDisplayName: "Target",
          purchasedAt: new Date(),
        },
        // item 1: assigned to OTHER → must be untouched (scope proof).
        {
          id: "i1",
          name: "ägg",
          assignedToUserId: OTHER,
          assignedToDisplayName: "Other",
          assignedAt: new Date(),
          purchasedByUserId: null,
          purchasedByDisplayName: null,
          purchasedAt: null,
        },
        // item 2: purchased by target only → only purchased block scrubbed.
        {
          id: "i2",
          name: "smör",
          assignedToUserId: OTHER,
          assignedToDisplayName: "Other",
          assignedAt: new Date(),
          purchasedByUserId: TARGET,
          purchasedByDisplayName: "Target",
          purchasedAt: new Date(),
        },
      ],
    });

  // --- users/{target} root doc (deleted last) ---
  await db.collection("users").doc(TARGET).set({ displayName: "Target" });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

async function exists(path: string): Promise<boolean> {
  const snap = await db.doc(path).get();
  return snap.exists;
}

async function dataAt(path: string): Promise<Record<string, unknown>> {
  const snap = await db.doc(path).get();
  if (!snap.exists) throw new Error(`expected doc ${path} to exist`);
  return snap.data() as Record<string, unknown>;
}

// ===========================================================================
// RECIPES (own-data delete + control retained)
// ===========================================================================

// I1: own top-level recipe deleted.
test("recipes: target's own top-level recipe is deleted", async () => {
  assert(!(await exists(`recipes/r-own-${RUN}`)), "own top-level recipe should be gone");
});

// I2: own subcollection recipe deleted.
test("recipes: target's own subcollection recipe is deleted", async () => {
  assert(
    !(await exists(`users/${TARGET}/recipes/r-sub-${RUN}`)),
    "own subcollection recipe should be gone",
  );
});

// I3: CONTROL recipe owned by a different uid is retained (scope proof).
test("recipes: another user's recipe is retained (correct scope)", async () => {
  assert(
    await exists(`recipes/r-control-${RUN}`),
    "control recipe owned by OTHER must survive",
  );
});

// ===========================================================================
// MENUS (own delete + inbound sharedToUserIds scrub, doc retained)
// ===========================================================================

// I4: own subcollection menu deleted.
test("menus: target's own subcollection menu is deleted", async () => {
  assert(
    !(await exists(`users/${TARGET}/menus/m-sub-${RUN}`)),
    "own subcollection menu should be gone",
  );
});

// I5: own top-level menu (sharedByUserId == target) deleted.
test("menus: target's own top-level shared menu is deleted", async () => {
  assert(!(await exists(`menus/m-own-${RUN}`)), "own top-level menu should be gone");
});

// I6: inbound menu RETAINED but target scrubbed from sharedToUserIds.
test("menus: inbound shared menu is retained with target scrubbed from sharedToUserIds", async () => {
  assert(await exists(`menus/m-inbound-${RUN}`), "inbound menu (OTHER's) must NOT be deleted");
  const data = await dataAt(`menus/m-inbound-${RUN}`);
  const shared = (data.sharedToUserIds as string[]) ?? [];
  assert(!shared.includes(TARGET), "target must be scrubbed from sharedToUserIds");
  assert(shared.includes(THIRD), "other recipients must remain in sharedToUserIds");
});

// ===========================================================================
// SHOPPING LISTS (own delete + control retained)
// ===========================================================================

// I7: own shopping list deleted.
test("shopping_lists: target's own list is deleted", async () => {
  assert(
    !(await exists(`users/${TARGET}/shopping_lists/sl-${RUN}`)),
    "own shopping list should be gone",
  );
});

// I8: another user's shopping list retained.
test("shopping_lists: another user's list is retained", async () => {
  assert(
    await exists(`users/${OTHER}/shopping_lists/sl-control-${RUN}`),
    "control shopping list owned by OTHER must survive",
  );
});

// ===========================================================================
// SHARED CONTENT (member scrub + owned delete)
// ===========================================================================

// I9: inbound shared_content retained, target scrubbed from sharedToUserIds.
test("shared_content: inbound doc retained with target scrubbed from sharedToUserIds", async () => {
  assert(
    await exists(`shared_content/sc-inbound-${RUN}`),
    "inbound shared_content (OTHER's) must survive",
  );
  const data = await dataAt(`shared_content/sc-inbound-${RUN}`);
  const shared = (data.sharedToUserIds as string[]) ?? [];
  assert(!shared.includes(TARGET), "target scrubbed from inbound sharedToUserIds");
  assert(shared.includes(THIRD), "other recipients remain in inbound sharedToUserIds");
});

// I10: target's members entry under the inbound doc deleted.
test("shared_content: target's member entry under inbound doc is deleted", async () => {
  assert(
    !(await exists(`shared_content/sc-inbound-${RUN}/members/${TARGET}`)),
    "target's member doc should be deleted",
  );
});

// I11: shared_content OWNED by target is deleted (with its members child).
test("shared_content: doc owned by target is deleted", async () => {
  assert(
    !(await exists(`shared_content/sc-own-${RUN}`)),
    "shared_content owned by target should be gone",
  );
  assert(
    !(await exists(`shared_content/sc-own-${RUN}/members/${OTHER}`)),
    "owned doc's members child should be gone",
  );
});

// ===========================================================================
// GROUP WEEKLY MENU PLANS (empty→delete, populated→scrub & retain)
// ===========================================================================

// I12: plan that empties on removal is deleted.
test("group_weekly_menu_plans: plan emptied by removal is deleted", async () => {
  assert(
    !(await exists(`group_weekly_menu_plans/gp-empty-${RUN}`)),
    "plan with only target should be deleted once emptied",
  );
});

// I13: populated plan retained, target removed from participantUserIds + participants.
test("group_weekly_menu_plans: still-populated plan retained with target removed", async () => {
  assert(
    await exists(`group_weekly_menu_plans/gp-shared-${RUN}`),
    "plan with remaining participants must survive",
  );
  const data = await dataAt(`group_weekly_menu_plans/gp-shared-${RUN}`);
  const ids = (data.participantUserIds as string[]) ?? [];
  assert(!ids.includes(TARGET), "target removed from participantUserIds");
  assert(ids.includes(OTHER), "other participant retained in participantUserIds");
  const participants = (data.participants as Array<{ userId: string }>) ?? [];
  assert(
    !participants.some((p) => p.userId === TARGET),
    "target removed from participants array",
  );
  assert(
    participants.some((p) => p.userId === OTHER),
    "other participant retained in participants array",
  );
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(!(TARGET in perms), "target removed from memberPermissions");
  assert(OTHER in perms, "other participant retained in memberPermissions");
});

// ===========================================================================
// RECIPE COMMENTS (anonymized, not deleted) + RATINGS (hard delete)
// ===========================================================================

// I14: target's comment is anonymized (retained, authorId='deleted').
test("recipe_comments: target's comment is anonymized, not deleted", async () => {
  assert(
    await exists(`recipe_comments/rc-${RUN}`),
    "comment must be retained (thread structure)",
  );
  const data = await dataAt(`recipe_comments/rc-${RUN}`);
  assert(data.authorId === "deleted", `authorId must be 'deleted', got ${data.authorId}`);
  assert(data.isDeleted === true, "isDeleted must be set true");
  assert(
    data.authorDisplayName === "[Raderad användare]",
    "display name must be anonymized",
  );
});

// I15: another user's comment is untouched (scope proof).
test("recipe_comments: another user's comment is untouched", async () => {
  const data = await dataAt(`recipe_comments/rc-control-${RUN}`);
  assert(data.authorId === OTHER, "control comment author must be unchanged");
  assert(data.isDeleted === false, "control comment must not be flagged deleted");
});

// I16: target's rating is hard-deleted.
test("recipe_ratings: target's rating is hard-deleted", async () => {
  assert(!(await exists(`recipe_ratings/rr-${RUN}`)), "target's rating should be gone");
});

// I17: another user's rating is retained.
test("recipe_ratings: another user's rating is retained", async () => {
  assert(
    await exists(`recipe_ratings/rr-control-${RUN}`),
    "control rating owned by OTHER must survive",
  );
});

// ===========================================================================
// CONVERSATIONS (1:1 delete, >2 arrayRemove & retain)
// ===========================================================================

// I18: 1:1 conversation deleted.
test("conversations: 1:1 conversation with target is deleted", async () => {
  assert(
    !(await exists(`conversations/conv-11-${RUN}`)),
    "1:1 conversation should be deleted",
  );
});

// I19: group conversation (>2) retained, target arrayRemove'd.
test("conversations: group conversation retained with target removed from participantIds", async () => {
  assert(
    await exists(`conversations/conv-group-${RUN}`),
    "group conversation must survive",
  );
  const data = await dataAt(`conversations/conv-group-${RUN}`);
  const ids = (data.participantIds as string[]) ?? [];
  assert(!ids.includes(TARGET), "target removed from group participantIds");
  assert(ids.includes(OTHER) && ids.includes(THIRD), "others retained in group");
});

// ===========================================================================
// COLLECTION-GROUP pings / comments / ratings (BUT-1191) — hard delete by
// author field, control by OTHER survives.
// ===========================================================================

// I-CG1: target's ping (collectionGroup, keyed on fromUserId) hard-deleted.
test("pings (collectionGroup): target's ping is hard-deleted", async () => {
  assert(
    !(await exists(`group_feed/gf-${RUN}/pings/ping-own-${RUN}`)),
    "target's ping (fromUserId==target) should be deleted by collectionGroup walk",
  );
});

// I-CG2: another user's ping under the same group is retained (scope proof).
test("pings (collectionGroup): another user's ping is retained", async () => {
  assert(
    await exists(`group_feed/gf-${RUN}/pings/ping-control-${RUN}`),
    "control ping (fromUserId==OTHER) must survive the collectionGroup walk",
  );
});

// I-CG3: target's comment (collectionGroup, keyed on commentedBy) hard-deleted.
test("comments (collectionGroup): target's comment is hard-deleted", async () => {
  assert(
    !(await exists(`cook_snaps/cs-${RUN}/comments/cmt-own-${RUN}`)),
    "target's comment (commentedBy==target) should be deleted by collectionGroup walk",
  );
});

// I-CG4: another user's comment under the same group is retained.
test("comments (collectionGroup): another user's comment is retained", async () => {
  assert(
    await exists(`cook_snaps/cs-${RUN}/comments/cmt-control-${RUN}`),
    "control comment (commentedBy==OTHER) must survive",
  );
});

// I-CG5: target's rating (collectionGroup, keyed on ratedBy) hard-deleted.
test("ratings (collectionGroup): target's rating is hard-deleted", async () => {
  assert(
    !(await exists(`cook_snaps/cs-${RUN}/ratings/rat-own-${RUN}`)),
    "target's rating (ratedBy==target) should be deleted by collectionGroup walk",
  );
});

// I-CG6: another user's rating under the same group is retained.
test("ratings (collectionGroup): another user's rating is retained", async () => {
  assert(
    await exists(`cook_snaps/cs-${RUN}/ratings/rat-control-${RUN}`),
    "control rating (ratedBy==OTHER) must survive",
  );
});

// ===========================================================================
// UNIFIED_SHARED_SHOPPING_LISTS item-level scrub (BUT-1191) — list retained,
// target's assigned/purchased authorship nulled, other members untouched.
// ===========================================================================

// I-SL1: the shared list document itself is RETAINED (not owned-only).
test("unified_shared_shopping_lists: shared list is retained", async () => {
  assert(
    await exists(`unified_shared_shopping_lists/ussl-${RUN}`),
    "shared list must NOT be deleted — only the target's item authorship is scrubbed",
  );
});

// I-SL2: item assigned AND purchased by target has both authorship blocks nulled.
test("unified_shared_shopping_lists: target's assigned+purchased item is scrubbed", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  const items = (data.items as Array<Record<string, unknown>>) ?? [];
  const i0 = items.find((it) => it.id === "i0");
  assert(!!i0, "item i0 must still be present in the list");
  assert(i0!.assignedToUserId === null, "i0 assignedToUserId must be nulled");
  assert(i0!.assignedToDisplayName === null, "i0 assignedToDisplayName must be nulled");
  assert(i0!.assignedAt === null, "i0 assignedAt must be nulled");
  assert(i0!.purchasedByUserId === null, "i0 purchasedByUserId must be nulled");
  assert(i0!.purchasedByDisplayName === null, "i0 purchasedByDisplayName must be nulled");
  assert(i0!.purchasedAt === null, "i0 purchasedAt must be nulled");
});

// I-SL3: item assigned to OTHER is left completely untouched (scope proof).
test("unified_shared_shopping_lists: another member's item authorship is untouched", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  const items = (data.items as Array<Record<string, unknown>>) ?? [];
  const i1 = items.find((it) => it.id === "i1");
  assert(!!i1, "item i1 must still be present");
  assert(i1!.assignedToUserId === OTHER, "i1 assignedToUserId (OTHER) must be unchanged");
  assert(
    i1!.assignedToDisplayName === "Other",
    "i1 assignedToDisplayName must be unchanged",
  );
});

// I-SL4: item purchased by target but assigned to OTHER scrubs ONLY the
// purchased block — the OTHER assignment is preserved (precise field scope).
test("unified_shared_shopping_lists: only the purchased-by-target block is scrubbed, foreign assignment kept", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  const items = (data.items as Array<Record<string, unknown>>) ?? [];
  const i2 = items.find((it) => it.id === "i2");
  assert(!!i2, "item i2 must still be present");
  assert(i2!.purchasedByUserId === null, "i2 purchasedByUserId (target) must be nulled");
  assert(
    i2!.purchasedByDisplayName === null,
    "i2 purchasedByDisplayName must be nulled",
  );
  assert(i2!.purchasedAt === null, "i2 purchasedAt must be nulled");
  assert(
    i2!.assignedToUserId === OTHER,
    "i2 assignedToUserId (OTHER) must remain — only target's authorship is scrubbed",
  );
});

// ===========================================================================
// USER ROOT DOC
// ===========================================================================

// I20: users/{target} root doc deleted.
test("users: target's root profile doc is deleted", async () => {
  assert(!(await exists(`users/${TARGET}`)), "user root doc should be gone");
});

// ===========================================================================
// ENVELOPE: cascade reported these steps as deleted (not failed).
// ===========================================================================

let RESULT: {
  success: boolean;
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
} | null = null;

// I21: the cascade reported success with no failed collections.
test("cascade: completed with no failed collections", async () => {
  assert(RESULT !== null, "result must be captured");
  assert(
    RESULT!.failedCollections.length === 0,
    `expected no failed collections, got ${JSON.stringify(RESULT!.failedCollections)} / errors ${JSON.stringify(RESULT!.errors)}`,
  );
  assert(RESULT!.success === true, "cascade success flag must be true");
});

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

async function run(): Promise<void> {
  console.log("BUT-1009: account-deletion cascade INTEGRATION tests (emulator)");
  console.log("================================================================\n");

  await clearEmulator();
  await seedFixtures();

  // Execute the cascade ONCE against the live emulator Firestore. All
  // assertions read the post-cascade state.
  RESULT = await runAccountDeletionWithDeps(
    { db, auth: fakeAuth(), storage: fakeStorage() },
    TARGET,
    "target@example.com",
    "user_request",
  );

  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(`        ${(err as Error).message}`);
    }
  }

  await clearEmulator();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
