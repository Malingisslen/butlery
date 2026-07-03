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

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteFamilyData,
} = require("../account/account-deletion-cascade");

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
  // --- system_rate_limits: BUT-1390 — top-level buckets (id `${uid}_${op}`)
  //     erased by deleteUserSubcollections via a documentId prefix range. Seed
  //     two of the target's buckets + one control owned by OTHER. ---
  await db
    .collection("system_rate_limits")
    .doc(`${TARGET}_structureRecipe`)
    .set({ tokens: 3, operationType: "structureRecipe" });
  await db
    .collection("system_rate_limits")
    .doc(`${TARGET}_ocrRecipeImage`)
    .set({ tokens: 1, operationType: "ocrRecipeImage" });
  await db
    .collection("system_rate_limits")
    .doc(`${OTHER}_structureRecipe`)
    .set({ tokens: 5, operationType: "structureRecipe" });

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

  // --- family (BUT Phase 5 item 15, §5b) ---
  // Solo household: TARGET only → whole household + its data must be deleted.
  await db.collection("households").doc(`hh-solo-${RUN}`).set({
    name: "Mitt hushåll",
    members: [{ userId: TARGET, permission: "admin" }],
    memberUserIds: [TARGET],
    memberPermissions: { [TARGET]: "admin" },
    createdBy: TARGET,
  });
  await db.collection("diner_profiles").doc(`dp-solo-${RUN}`).set({
    householdId: `hh-solo-${RUN}`,
    name: "Emma",
    createdBy: TARGET,
  });
  await db.collection("family_ratings").doc(`fr-solo-${RUN}`).set({
    householdId: `hh-solo-${RUN}`,
    recipeId: "r1",
    memberId: TARGET,
    enteredByUid: TARGET,
    stars: 4,
  });

  // Shared household: TARGET + OTHER → household survives, re-homed to OTHER.
  await db.collection("households").doc(`hh-shared-${RUN}`).set({
    name: "Delat hushåll",
    members: [
      { userId: TARGET, permission: "admin" },
      { userId: OTHER, permission: "edit" },
    ],
    memberUserIds: [TARGET, OTHER],
    memberPermissions: { [TARGET]: "admin", [OTHER]: "edit" },
    createdBy: TARGET,
  });
  // Diner created BY TARGET → must re-home to OTHER, not be orphaned/deleted.
  await db.collection("diner_profiles").doc(`dp-shared-${RUN}`).set({
    householdId: `hh-shared-${RUN}`,
    name: "Liam",
    createdBy: TARGET,
  });
  // TARGET's own verdict → deleted.
  await db.collection("family_ratings").doc(`fr-mine-${RUN}`).set({
    householdId: `hh-shared-${RUN}`,
    recipeId: "r2",
    memberId: TARGET,
    enteredByUid: TARGET,
    stars: 5,
  });
  // OTHER's own verdict → retained untouched.
  await db.collection("family_ratings").doc(`fr-other-${RUN}`).set({
    householdId: `hh-shared-${RUN}`,
    recipeId: "r2",
    memberId: OTHER,
    enteredByUid: OTHER,
    stars: 3,
  });
  // Verdict for the diner, ENTERED BY TARGET → kept but attribution scrubbed.
  await db.collection("family_ratings").doc(`fr-proxy-${RUN}`).set({
    householdId: `hh-shared-${RUN}`,
    recipeId: "r2",
    memberId: `dp-shared-${RUN}`,
    enteredByUid: TARGET,
    stars: 5,
  });

  // --- realtime_recipes (BUT-1396 follow-up) ---
  // The owner field is `ownerId` (model writes it; the Firestore rule gates
  // read/delete on `resource.data.ownerId`). The prior cascade filtered on
  // `userId`, which matched ZERO docs → a deleted user's collaborative recipes
  // were exported (Art. 15) but never erased (Art. 17). These fixtures prove
  // the `ownerId` filter erases owned docs and that scope is correct:
  //   - rt-own: ownerId == TARGET → must be deleted.
  //   - rt-control: ownerId == OTHER → must survive (scope proof, and the doc
  //     that the OLD broken `userId` filter would ALSO have skipped — so the
  //     positive deletion below is what proves the fix, the OLD filter deleted
  //     neither).
  //   - rt-participant: ownerId == OTHER but TARGET is a participant → must
  //     survive. Deletion keys on ownership (only the owner may delete per the
  //     rule); a collaborator's account deletion must not erase someone else's
  //     recipe. Proves we filter on ownerId, not participantIds.
  await db.collection("realtime_recipes").doc(`rt-own-${RUN}`).set({
    ownerId: TARGET,
    participantIds: [TARGET, OTHER],
    recipe: { title: "mitt samarbetsrecept" },
    createdAt: new Date(),
  });
  await db.collection("realtime_recipes").doc(`rt-control-${RUN}`).set({
    ownerId: OTHER,
    participantIds: [OTHER, THIRD],
    recipe: { title: "annans realtidsrecept" },
    createdAt: new Date(),
  });
  await db.collection("realtime_recipes").doc(`rt-participant-${RUN}`).set({
    ownerId: OTHER,
    participantIds: [OTHER, TARGET],
    recipe: { title: "recept jag bara redigerar" },
    createdAt: new Date(),
  });

  // --- canonical_rating_events (Increment 5, decision 12): the target's frozen
  //     pool events are erased by deleteUserSubcollections; OTHER's are a scope
  //     control that must survive. Also the residual probe must count zero for
  //     the target afterwards. ---
  await db
    .collection("users")
    .doc(TARGET)
    .collection("canonical_rating_events")
    .doc(`v1:pool-a-${RUN}`)
    .set({ poolKey: `v1:pool-a-${RUN}`, ratingValue: 4, recipeId: `r-sub-${RUN}` });
  await db
    .collection("users")
    .doc(OTHER)
    .collection("canonical_rating_events")
    .doc(`v1:pool-b-${RUN}`)
    .set({ poolKey: `v1:pool-b-${RUN}`, ratingValue: 5, recipeId: "r-other" });

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
// SYSTEM_RATE_LIMITS (BUT-1390 — GDPR erasure of top-level rate-limit buckets)
// ===========================================================================

// All of the target's buckets are erased (prefix-range delete; proves the
// load-bearing  upper-bound sentinel actually matches `${uid}_*`).
test("system_rate_limits: all of target's buckets are deleted", async () => {
  assert(
    !(await exists(`system_rate_limits/${TARGET}_structureRecipe`)),
    "target structureRecipe bucket should be gone",
  );
  assert(
    !(await exists(`system_rate_limits/${TARGET}_ocrRecipeImage`)),
    "target ocrRecipeImage bucket should be gone",
  );
});

// Another user's bucket is retained (the `_` separator + sentinel bound the
// prefix range to exactly this uid).
test("system_rate_limits: another user's bucket is retained", async () => {
  assert(
    await exists(`system_rate_limits/${OTHER}_structureRecipe`),
    "control bucket owned by OTHER must survive",
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
// FAMILY (BUT Phase 5 item 15, §5b)
// ===========================================================================

// Solo household: the whole thing is torn down.
test("family (solo): household, diner profile and rating are deleted", async () => {
  assert(
    !(await exists(`households/hh-solo-${RUN}`)),
    "solo household should be gone",
  );
  assert(
    !(await exists(`diner_profiles/dp-solo-${RUN}`)),
    "solo household's diner profile should be gone",
  );
  assert(
    !(await exists(`family_ratings/fr-solo-${RUN}`)),
    "solo household's rating should be gone",
  );
});

// Shared household survives, re-homed to the remaining member.
test("family (shared): household survives and is re-homed to the remaining member", async () => {
  const hh = await dataAt(`households/hh-shared-${RUN}`);
  const ids = Array.isArray(hh.memberUserIds) ? hh.memberUserIds : [];
  assert(!ids.includes(TARGET), "target removed from memberUserIds");
  assert(ids.includes(OTHER), "other member retained");
  assert(hh.createdBy === OTHER, "createdBy re-homed to the remaining member");
  const perms = (hh.memberPermissions ?? {}) as Record<string, unknown>;
  assert(!(TARGET in perms), "target removed from memberPermissions");
});

test("family (shared): a diner profile created by target is re-homed, never orphaned", async () => {
  const dp = await dataAt(`diner_profiles/dp-shared-${RUN}`);
  assert(dp.createdBy === OTHER, "diner profile re-homed to remaining member");
});

test("family (shared): target's own verdict is deleted, the other member's is retained", async () => {
  assert(
    !(await exists(`family_ratings/fr-mine-${RUN}`)),
    "target's own verdict should be gone",
  );
  assert(
    await exists(`family_ratings/fr-other-${RUN}`),
    "another member's verdict must NOT be deleted",
  );
});

test("family (shared): a verdict target entered for a diner is kept but attribution scrubbed", async () => {
  const fr = await dataAt(`family_ratings/fr-proxy-${RUN}`);
  assert(fr.stars === 5, "the diner's verdict value is preserved");
  assert(
    fr.enteredByUid === "deleted",
    `proxy attribution must be scrubbed, got ${fr.enteredByUid}`,
  );
});

// Retry-safety: running deleteFamilyData twice must converge on the same
// correct end state (no orphans, re-home stable) — the household membership
// scrub is the LAST mutation precisely so an interrupted run re-runs cleanly.
test("family: deleteFamilyData is idempotent on re-run (retry-safe)", async () => {
  const u = `rerun-target-${RUN}`;
  const other = `rerun-other-${RUN}`;
  const hh = `hh-rerun-${RUN}`;
  await db.collection("households").doc(hh).set({
    name: "Rerun",
    members: [
      { userId: u, permission: "admin" },
      { userId: other, permission: "edit" },
    ],
    memberUserIds: [u, other],
    memberPermissions: { [u]: "admin", [other]: "edit" },
    createdBy: u,
  });
  await db.collection("diner_profiles").doc(`dp-rerun-${RUN}`).set({
    householdId: hh,
    name: "Nora",
    createdBy: u,
  });
  await db.collection("family_ratings").doc(`fr-rerun-mine-${RUN}`).set({
    householdId: hh,
    recipeId: "r9",
    memberId: u,
    enteredByUid: u,
    stars: 4,
  });

  await deleteFamilyData(db, u);
  await deleteFamilyData(db, u); // second run must be a safe no-op

  const data = await dataAt(`households/${hh}`);
  const ids = Array.isArray(data.memberUserIds) ? data.memberUserIds : [];
  assert(!ids.includes(u) && ids.includes(other), "membership stable after re-run");
  assert(data.createdBy === other, "createdBy stable after re-run");
  const dp = await dataAt(`diner_profiles/dp-rerun-${RUN}`);
  assert(dp.createdBy === other, "diner re-home stable after re-run");
  assert(
    !(await exists(`family_ratings/fr-rerun-mine-${RUN}`)),
    "own verdict stays deleted after re-run",
  );
});

// ===========================================================================
// REALTIME_RECIPES (BUT-1396 follow-up) — owner-keyed delete by `ownerId`.
// Regression guard: the prior `userId` filter matched nothing, leaking the
// owner's collaborative recipes past account deletion (Art. 17).
// ===========================================================================

// target's owned realtime recipe is hard-deleted (this assertion fails on the
// OLD broken `userId` filter — that filter matched zero docs).
test("realtime_recipes: target's owned recipe (ownerId==target) is deleted", async () => {
  assert(
    !(await exists(`realtime_recipes/rt-own-${RUN}`)),
    "owned realtime recipe (ownerId==target) must be erased — the prior userId filter leaked it",
  );
});

// another owner's recipe is retained (scope proof).
test("realtime_recipes: another user's recipe is retained", async () => {
  assert(
    await exists(`realtime_recipes/rt-control-${RUN}`),
    "control realtime recipe owned by OTHER must survive",
  );
});

// a recipe where target is only a participant (not owner) is retained — the
// cascade keys on ownership, matching the rule's owner-only delete.
test("realtime_recipes: a recipe target only participates in is retained", async () => {
  assert(
    await exists(`realtime_recipes/rt-participant-${RUN}`),
    "recipe where target is a participant (not owner) must NOT be erased by their deletion",
  );
});

// ===========================================================================
// CANONICAL RATING EVENTS (Increment 5, decision 12) — own erased, control kept
// ===========================================================================

// I-CRE1: target's own pool event is erased by deleteUserSubcollections.
test("canonical_rating_events: target's own pool event is deleted", async () => {
  assert(
    !(await exists(`users/${TARGET}/canonical_rating_events/v1:pool-a-${RUN}`)),
    "target's own pool event should be gone",
  );
});

// I-CRE2: OTHER's pool event survives (scope proof — the cascade is uid-scoped).
test("canonical_rating_events: another user's pool event is retained", async () => {
  assert(
    await exists(`users/${OTHER}/canonical_rating_events/v1:pool-b-${RUN}`),
    "control pool event owned by OTHER must survive",
  );
});

// I-CRE3: the residual probe found no leftover events — otherwise the cascade
// would have pushed "residual_data_detected" into failedCollections (asserted
// empty by I21 below), so a surviving target event would fail the whole run.

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
