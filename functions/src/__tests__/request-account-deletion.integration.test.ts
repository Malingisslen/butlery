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
  deleteShoppingLists,
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

  // --- shopping_lists (LEGACY name): own subcollection + control ---
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

  // --- unified_shopping_lists (BUT-1697: the LIVE personal path) ---
  // This is what FirebaseShoppingRepository writes. Each list owns an `items`
  // subcollection Firestore will not cascade, so both levels are seeded and
  // both are asserted gone. OTHER's list is the scope control.
  const targetPersonal = db
    .collection("users")
    .doc(TARGET)
    .collection("unified_shopping_lists")
    .doc(`usl-${RUN}`);
  await targetPersonal.set({ name: "min riktiga lista", ownerId: TARGET });
  await targetPersonal
    .collection("items")
    .doc(`usl-item-${RUN}`)
    .set({ name: "mjölk", bought: false });
  const otherPersonal = db
    .collection("users")
    .doc(OTHER)
    .collection("unified_shopping_lists")
    .doc(`usl-control-${RUN}`);
  await otherPersonal.set({ name: "annans riktiga lista", ownerId: OTHER });
  await otherPersonal
    .collection("items")
    .doc(`usl-control-item-${RUN}`)
    .set({ name: "ägg", bought: false });

  // --- ORPHANED items: a list the user DELETED in the app ---
  // `base_firebase_repository.delete()` removes the list document with a plain
  // `doc(id).delete()` and never recurses, so the `items` subcollection lives
  // on under a MISSING parent. A `get()` on the collection cannot see it and a
  // `count()` reports zero, which is why the sweep and the probe both use
  // `listDocuments()`. Seeded here by writing ONLY the item.
  await db
    .collection("users")
    .doc(TARGET)
    .collection("unified_shopping_lists")
    .doc(`usl-orphan-${RUN}`)
    .collection("items")
    .doc(`usl-orphan-item-${RUN}`)
    .set({ name: "kanel", bought: true });
  await db
    .collection("users")
    .doc(OTHER)
    .collection("unified_shopping_lists")
    .doc(`usl-orphan-control-${RUN}`)
    .collection("items")
    .doc(`usl-orphan-control-item-${RUN}`)
    .set({ name: "salt", bought: false });

  // --- a shared list OWNED by target whose memberPermissions lacks their key -
  // The rules place no `cannotModify` guard on the owner, so an owner can
  // persist a permission map without themselves in it. A deleter keyed only on
  // `memberPermissions.{uid}` never matches it, while the residual probe — which
  // matches on `ownerId` — does: the probe would flag a residual no code path
  // could clear. The deleter must be a superset of every probe leg.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-ownerless-${RUN}`)
    .set({
      name: "lista utan ägarnyckel",
      ownerId: TARGET,
      ownerDisplayName: "Target",
      memberPermissions: {},
      items: [],
    });

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
    // The interactive screen stamps the acting member here on every remove and
    // undo, so a departing member is routinely the last writer.
    lastModifiedBy: TARGET,
    // BUT-1971: the places the roster scrub does not reach. The target's
    // uid sits on a dish they proposed, in the votes of a dish somebody else
    // proposed, and in trail rows in both positions.
    entries: [
      { id: "e1", proposedBy: TARGET, votedInBy: [TARGET, OTHER] },
      { id: "e2", proposedBy: OTHER, votedInBy: [TARGET] },
      { id: "e3", proposedBy: OTHER, votedInBy: [OTHER] },
    ],
    editTrail: [
      { actorId: TARGET, action: "removed", entryId: "e1" },
      { actorId: OTHER, subjectId: TARGET, action: "removed", entryId: "e2" },
      { actorId: OTHER, subjectId: OTHER, action: "moved", entryId: "e3" },
    ],
  });

  // Reached ONLY by the `lastModifiedBy` handle: the target is on no roster
  // here. Mirrors the `ussl-ownerless` fixture's rule — the deleter must be a
  // superset of every probe leg, or the audit reports gdprCompliant:false
  // forever with no code path able to clear it.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-writer-only-${RUN}`)
    .set({
      participantUserIds: [OTHER],
      participants: [{ userId: OTHER, name: "Other" }],
      memberPermissions: { [OTHER]: "owner" },
      week: "2026-W24",
      lastModifiedBy: TARGET,
    });

  // Shapes `firestore.rules` accepts and no writer produces: the trail cap is
  // `.size()`, which is polymorphic, so a map passes it. The scrub cannot walk
  // them, so it deletes them outright — without that a uid inside one is never
  // erased.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-malformed-${RUN}`)
    .set({
      participantUserIds: [TARGET, OTHER],
      participants: [
        { userId: TARGET, name: "Target" },
        { userId: OTHER, name: "Other" },
      ],
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      week: "2026-W25",
      entries: { rogue: TARGET },
      editTrail: { rogue: TARGET },
    });

  // Reached ONLY by the ACL key: no roster entry, no write attribution. This is
  // the document the EXPORT can read and the erasure could not reach before the
  // permission handle joined the union.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-permission-only-${RUN}`)
    .set({
      participantUserIds: [],
      participants: [],
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      week: "2026-W26",
      entries: [{ id: "e1", proposedBy: TARGET, votedInBy: [TARGET] }],
    });

  // The two denormalised rosters DISAGREE: `participants` names the target,
  // the queryable mirror does not. Reached by the ACL key, and the only fixture
  // that stages the scrub's roster-mismatch disjunct.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-roster-desync-${RUN}`)
    .set({
      participantUserIds: [OTHER],
      participants: [
        { userId: TARGET, name: "Target" },
        { userId: OTHER, name: "Other" },
      ],
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      week: "2026-W27",
    });

  // The desync seen from the DESTRUCTIVE side: the queryable mirror names
  // only the target, while `participants` still holds another member. Deleting
  // on the mirror alone would take that member's week with it.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-desync-inverse-${RUN}`)
    .set({
      participantUserIds: [TARGET],
      participants: [
        { userId: TARGET, name: "Target" },
        { userId: OTHER, name: "Other" },
      ],
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      week: "2026-W28",
    });

  // The MIRROR holds a survivor the `participants` array does not. Deriving
  // the mirror from `participants` would collapse the delete gate to one
  // witness and destroy this member's week.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-mirror-survivor-${RUN}`)
    .set({
      participantUserIds: [TARGET, "mirror-only-member"],
      participants: [{ userId: TARGET, name: "Target" }],
      memberPermissions: { [TARGET]: "editor", "mirror-only-member": "edit" },
      week: "2026-W29",
    });

  // BUT-1971 follow-up. The document a DEPARTURE leaves behind: the target is
  // off every roster (`removeChatGroupMember` took them out when they left the
  // chat) and is not the last writer, so the three original discovery handles
  // all see nothing. Their uid survives on the dish and in the trail, which is
  // Malin's decision, and `contributorUserIds` is the only thing that can still
  // find it.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-contributor-only-${RUN}`)
    .set({
      participantUserIds: ["still-a-member"],
      participants: [{ userId: "still-a-member", name: "Kvar" }],
      memberPermissions: { "still-a-member": "admin" },
      lastModifiedBy: "still-a-member",
      contributorUserIds: [TARGET, "still-a-member"],
      entries: [{ id: "e1", proposedBy: TARGET, votedInBy: [TARGET] }],
      editTrail: [{ actorId: TARGET, subjectId: "still-a-member", at: new Date() }],
      week: "2026-W30",
    });

  // A departed contributor is NOT a witness on the destructive gate: every
  // roster is empty and the target was on it, so the document goes. This is the
  // churn the leave path creates — B leaves the group, then A deletes their
  // account — and blocking the delete here would leave a document with an empty
  // permission map, which every limb of this collection refuses. Nobody could
  // read, write, re-plan or delete that ISO week again. `cutGroupMenuPlanAccess`
  // decided the same shape the same way.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-contributor-survivor-${RUN}`)
    .set({
      participantUserIds: [TARGET],
      participants: [{ userId: TARGET, name: "Target" }],
      memberPermissions: { [TARGET]: "admin" },
      contributorUserIds: [TARGET, "departed-but-live"],
      entries: [{ id: "e1", proposedBy: "departed-but-live" }],
      week: "2026-W31",
    });

  // The delete side of the same gate. Nothing but the target is left anywhere —
  // rosters, permissions AND the contributor trail — so the document holds no
  // data about anyone else and deleting it is the correct erasure.
  await db
    .collection("group_weekly_menu_plans")
    .doc(`gp-contributor-sole-${RUN}`)
    .set({
      participantUserIds: [TARGET],
      participants: [{ userId: TARGET, name: "Target" }],
      memberPermissions: { [TARGET]: "admin" },
      contributorUserIds: [TARGET],
      week: "2026-W32",
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

  // --- unified_shared_shopping_lists scrub (BUT-1191 items, BUT-1697 list) ---
  // The cascade queries `memberPermissions.{uid} != null`, then scrubs at TWO
  // levels: the `items` array (assignedTo*/purchasedBy* nulled, addedBy*/
  // lastModifiedBy* anonymized to "deleted") and the LIST document
  // (lastActivityBy* nulled, ownerDisplayName nulled but ownerId kept).
  // The list itself is RETAINED (shared, not owned-only), other members'
  // authorship untouched.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-${RUN}`)
    .set({
      name: "delad lista",
      memberPermissions: { [TARGET]: "editor", [OTHER]: "owner" },
      ownerId: TARGET,
      ownerDisplayName: "Target",
      lastActivityByUserId: TARGET,
      lastActivityByDisplayName: "Target",
      items: [
        // item 0: assigned AND purchased by target → both blocks scrubbed.
        // Also added + last-modified by target → both anonymized.
        {
          id: "i0",
          name: "mjölk",
          assignedToUserId: TARGET,
          assignedToDisplayName: "Target",
          assignedAt: new Date(),
          purchasedByUserId: TARGET,
          purchasedByDisplayName: "Target",
          purchasedAt: new Date(),
          addedByUserId: TARGET,
          addedByDisplayName: "Target",
          lastModifiedByUserId: TARGET,
          lastModifiedByDisplayName: "Target",
        },
        // item 1: everything belongs to OTHER → must be untouched (scope proof).
        {
          id: "i1",
          name: "ägg",
          assignedToUserId: OTHER,
          assignedToDisplayName: "Other",
          assignedAt: new Date(),
          purchasedByUserId: null,
          purchasedByDisplayName: null,
          purchasedAt: null,
          addedByUserId: OTHER,
          addedByDisplayName: "Other",
          lastModifiedByUserId: OTHER,
          lastModifiedByDisplayName: "Other",
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

  // Negative control for the LIST-level scrub: a shared list the target is a
  // member of, but whose owner and last activity belong to OTHER. Every
  // list-level identity field must survive untouched.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-control-${RUN}`)
    .set({
      name: "annans delade lista",
      memberPermissions: { [TARGET]: "viewer", [OTHER]: "owner" },
      ownerId: OTHER,
      ownerDisplayName: "Other",
      lastActivityByUserId: OTHER,
      lastActivityByDisplayName: "Other",
      items: [],
    });

  // Sole-member "collaborative" list: owned by TARGET, nobody else in
  // memberPermissions. This is pure own data (every item name is theirs) and
  // after erasure no account could read it, so the cascade must DELETE it
  // rather than scrub it.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-solo-${RUN}`)
    .set({
      name: "min egna delade lista",
      memberPermissions: { [TARGET]: "admin" },
      ownerId: TARGET,
      ownerDisplayName: "Target",
      items: [{ id: "s0", name: "kaffe", addedByUserId: TARGET }],
    });

  // BUT-1725/BUT-1705: the list the target LEFT (or was removed from). No
  // memberPermissions key, not the owner, not the last activity — the two
  // handles the cascade used to query on are both absent, while every item
  // they added still carries their name. `contributorUserIds` is the only
  // thing that makes this list reachable, which is why the client unions it on
  // every item write.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-departed-${RUN}`)
    .set({
      name: "lista jag lämnat",
      memberPermissions: { [OTHER]: "owner", [THIRD]: "editor" },
      ownerId: OTHER,
      ownerDisplayName: "Other",
      lastActivityByUserId: OTHER,
      lastActivityByDisplayName: "Other",
      contributorUserIds: [OTHER, TARGET],
      items: [
        {
          id: "d0",
          name: "kanel",
          addedByUserId: TARGET,
          addedByDisplayName: "Target",
          purchasedByUserId: TARGET,
          purchasedByDisplayName: "Target",
          purchasedAt: new Date(),
        },
        {
          id: "d1",
          name: "kardemumma",
          addedByUserId: OTHER,
          addedByDisplayName: "Other",
        },
      ],
    });

  // The other half of the same gap: a list where the target is neither member
  // nor owner nor contributor, but IS the last-activity stamp. That field alone
  // carries a raw uid and a display name on a document other people keep.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-lastactivity-${RUN}`)
    .set({
      name: "lista med min sista aktivitet",
      memberPermissions: { [OTHER]: "owner" },
      ownerId: OTHER,
      ownerDisplayName: "Other",
      lastActivityByUserId: TARGET,
      lastActivityByDisplayName: "Target",
      items: [],
    });

  // Foreign list the target was never a member of — the membership query must
  // not reach it at all.
  await db
    .collection("unified_shared_shopping_lists")
    .doc(`ussl-foreign-${RUN}`)
    .set({
      name: "helt annans lista",
      memberPermissions: { [OTHER]: "owner", [THIRD]: "editor" },
      ownerId: OTHER,
      ownerDisplayName: "Other",
      items: [],
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

// I7b (BUT-1697): the LIVE personal path is erased — this is the one that
// actually holds data. A green I7 alone proved nothing about real users.
test("unified_shopping_lists: target's live personal list is deleted", async () => {
  assert(
    !(await exists(`users/${TARGET}/unified_shopping_lists/usl-${RUN}`)),
    "live personal shopping list should be gone",
  );
});

// I7c (BUT-1697): the list's `items` subcollection goes too — Firestore never
// cascades subcollections, so deleting the parent doc alone orphans the items.
test("unified_shopping_lists: the list's items subcollection is deleted", async () => {
  assert(
    !(await exists(
      `users/${TARGET}/unified_shopping_lists/usl-${RUN}/items/usl-item-${RUN}`,
    )),
    "personal shopping-list items must be deleted, not orphaned under a deleted parent",
  );
});

// The Critical case the sweep was rewritten for: items under a list document
// the user had already deleted in-app. Reverting either `listDocuments()` call
// to `get()`/`count()` makes this test fail AND the residual probe report clean
// while the item names are still on disk.
test("unified_shopping_lists: items orphaned under a deleted parent are erased", async () => {
  assert(
    !(await exists(
      `users/${TARGET}/unified_shopping_lists/usl-orphan-${RUN}/items/usl-orphan-item-${RUN}`,
    )),
    "items under a MISSING parent list must be erased — a query cannot see them, so the sweep must use listDocuments()",
  );
});

// Scope proof for the same mechanism.
test("unified_shopping_lists: another user's orphaned items are retained", async () => {
  assert(
    await exists(
      `users/${OTHER}/unified_shopping_lists/usl-orphan-control-${RUN}/items/usl-orphan-control-item-${RUN}`,
    ),
    "the orphan sweep must stay scoped to the target user",
  );
});

// The deleter-superset-of-probe case: owned, no member key. On the member-key
// query alone this list survives with every item name and the owner's display
// name intact, and the probe flags it forever.
test("unified_shared_shopping_lists: a target-owned list with no member key is handled", async () => {
  assert(
    !(await exists(`unified_shared_shopping_lists/ussl-ownerless-${RUN}`)),
    "a sole-owner list without a memberPermissions key must be deleted, not left for a probe that can never be satisfied",
  );
});

// BUT-1725: erasure must reach a list the target LEFT. Membership and
// ownership are both gone; only the contributor trail can find it, and until it
// existed the departed member's name stayed on the items forever while the
// residual probe reported the erasure clean.
test("unified_shared_shopping_lists: a list the target left is still scrubbed", async () => {
  const path = `unified_shared_shopping_lists/ussl-departed-${RUN}`;
  assert(await exists(path), "the remaining members' list must survive");

  const data = await dataAt(path);
  const items = (data.items as Record<string, unknown>[]) ?? [];
  const mine = items.find((i) => i.id === "d0")!;
  const theirs = items.find((i) => i.id === "d1")!;

  assert(
    mine.addedByDisplayName === null,
    "a departed member's name must not survive on an item they added",
  );
  assert(
    mine.addedByUserId === "deleted",
    "addedByUserId is anonymized, not nulled — nulling flips the item to personal",
  );
  assert(
    mine.purchasedByUserId === null && mine.purchasedByDisplayName === null,
    "the purchased pair must be cleared",
  );
  assert(
    theirs.addedByDisplayName === "Other",
    "another member's authorship must be untouched",
  );

  const contributors = (data.contributorUserIds as string[]) ?? [];
  assert(
    !contributors.includes(TARGET),
    "the trail that found the list is itself a raw uid and must go in the same write",
  );
  assert(
    contributors.includes(OTHER),
    "other contributors must remain, or the next erasure cannot find them",
  );
});

// BUT-1705: the same gap via the other queryable handle.
test("unified_shared_shopping_lists: a last-activity-only stamp is cleared", async () => {
  const path = `unified_shared_shopping_lists/ussl-lastactivity-${RUN}`;
  assert(await exists(path), "the owner's list must survive");

  const data = await dataAt(path);
  assert(
    data.lastActivityByUserId === null &&
      data.lastActivityByDisplayName === null,
    "a deleted account's activity stamp must not survive on someone else's list",
  );
  assert(data.ownerDisplayName === "Other", "the owner's own name is untouched");
});

// Scope proof: a list the target never touched at all must not be rewritten.
test("unified_shared_shopping_lists: an untouched foreign list is not modified", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-foreign-${RUN}`);
  assert(
    data.ownerDisplayName === "Other",
    "the foreign list must be out of every query's reach",
  );
});

// I8b: another user's live personal list and its items are retained.
test("unified_shopping_lists: another user's live list and items are retained", async () => {
  assert(
    await exists(`users/${OTHER}/unified_shopping_lists/usl-control-${RUN}`),
    "control live personal list owned by OTHER must survive",
  );
  assert(
    await exists(
      `users/${OTHER}/unified_shopping_lists/usl-control-${RUN}/items/usl-control-item-${RUN}`,
    ),
    "control live personal list items owned by OTHER must survive",
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
  // `participants` is where the departed member's DISPLAY NAME lives, and no
  // probe leg can see inside an array of maps — so if this scrub regressed,
  // the name would stay on a document the remaining members keep, and both CI
  // and the residual probe would report clean.
  assert(
    !JSON.stringify(participants).includes("Target"),
    "and their display name goes with the entry",
  );
  assert(
    participants.some((p) => p.userId === OTHER),
    "other participant retained in participants array",
  );
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(!(TARGET in perms), "target removed from memberPermissions");
  assert(OTHER in perms, "other participant retained in memberPermissions");
});

// BUT-1971 / ADR-0010. Provenance and the edit trail are the two surfaces the
// roster scrub above never touched, so before this a departing member's uid
// stayed on every dish they proposed or voted for, forever, on every group plan
// that survived their deletion.
test("group_weekly_menu_plans: provenance and trail are scrubbed too", async () => {
  const data = await dataAt(`group_weekly_menu_plans/gp-shared-${RUN}`);

  const entries =
    (data.entries as Array<Record<string, unknown>>) ?? [];
  assert(entries.length === 3, "no dish may be dropped by the scrub");
  const byId = new Map(entries.map((e) => [e.id as string, e]));

  assert(
    byId.get("e1")?.proposedBy === undefined,
    "target's authorship of a dish must be gone",
  );
  assert(
    JSON.stringify(byId.get("e1")?.votedInBy) === JSON.stringify([OTHER]),
    "target's vote goes, the other member's stays",
  );
  // The whole-field-drop control: a votes list that empties is removed, not
  // left as an empty array pointing at nothing.
  assert(
    byId.get("e2")?.votedInBy === undefined,
    "a votes list holding only the target is dropped, not emptied",
  );
  assert(
    byId.get("e2")?.proposedBy === OTHER,
    "another member's authorship is untouched",
  );
  assert(
    byId.get("e3")?.proposedBy === OTHER &&
      JSON.stringify(byId.get("e3")?.votedInBy) === JSON.stringify([OTHER]),
    "a dish the target never touched is untouched",
  );

  assert(
    data.lastModifiedBy === "deleted",
    "the document-level last-writer attribution must be tombstoned too",
  );

  const trail = (data.editTrail as Array<Record<string, unknown>>) ?? [];
  assert(
    trail.length === 2,
    `the target's OWN row goes, the other member's stays, got ${trail.length}`,
  );
  assert(
    !trail.some((r) => r.actorId === TARGET),
    "a row the target wrote is theirs and must be gone",
  );
  const aboutTarget = trail.find((r) => r.entryId === "e2");
  assert(
    aboutTarget !== undefined && aboutTarget.actorId === OTHER,
    "the row another member wrote about the target's dish survives — it is " +
      "that member's own attribution, which is what the trail exists for",
  );
  assert(
    aboutTarget?.subjectId === undefined,
    "but the target's uid is stripped out of it",
  );
});

test("group_weekly_menu_plans: a plan the target only WROTE is reached", async () => {
  assert(
    await exists(`group_weekly_menu_plans/gp-writer-only-${RUN}`),
    "the target was never on this roster, so the plan must survive",
  );
  const data = await dataAt(`group_weekly_menu_plans/gp-writer-only-${RUN}`);
  assert(
    data.lastModifiedBy === "deleted",
    "discovery must union the writer handle with the roster handle — the " +
      "residual probe counts both",
  );
  const ids = (data.participantUserIds as string[]) ?? [];
  assert(
    ids.length === 1 && ids[0] === OTHER,
    "and the roster of a plan the target was never on must be untouched",
  );
});

test("group_weekly_menu_plans: a non-list entries/trail is deleted, not skipped", async () => {
  const data = await dataAt(`group_weekly_menu_plans/gp-malformed-${RUN}`);
  assert(
    data.entries === undefined,
    "a shape the scrub cannot walk must go, or the uid inside it never does",
  );
  assert(data.editTrail === undefined, "same for the trail");
  const ids = (data.participantUserIds as string[]) ?? [];
  assert(!ids.includes(TARGET), "and the roster is still scrubbed");
});

test("group_weekly_menu_plans: a plan reached only by the ACL key is scrubbed", async () => {
  // Survival is the assertion that matters most here: without the
  // `wasParticipant` gate this document's empty roster would have made the
  // deleter destroy another group's plan.
  assert(
    await exists(`group_weekly_menu_plans/gp-permission-only-${RUN}`),
    "the target was never on this roster, so the plan must survive",
  );
  const data = await dataAt(`group_weekly_menu_plans/gp-permission-only-${RUN}`);
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(
    !(TARGET in perms),
    "discovery must include the ACL key — the export discovers on it, so the " +
      "erasure has to reach it",
  );
  assert(OTHER in perms, "and the other member's access is untouched");
  const entries = (data.entries as Array<Record<string, unknown>>) ?? [];
  assert(
    entries[0]?.proposedBy === undefined && entries[0]?.votedInBy === undefined,
    "provenance is scrubbed on a permission-only document too",
  );
});

test("group_weekly_menu_plans: a roster that disagrees with itself is scrubbed", async () => {
  const data = await dataAt(`group_weekly_menu_plans/gp-roster-desync-${RUN}`);
  const participants = (data.participants as Array<{ userId: string }>) ?? [];
  assert(
    !participants.some((p) => p.userId === TARGET),
    "the uid is inside participants[] even though the queryable mirror never " +
      "named it — the scrub must reach it anyway",
  );
  assert(
    participants.some((p) => p.userId === OTHER),
    "and the other member survives",
  );
  const ids = (data.participantUserIds as string[]) ?? [];
  assert(
    ids.length === 1 && ids[0] === OTHER,
    "the mirror is rewritten from the survivors, never emptied",
  );
});

test("group_weekly_menu_plans: an empty mirror does not delete a plan someone still holds", async () => {
  assert(
    await exists(`group_weekly_menu_plans/gp-desync-inverse-${RUN}`),
    "the other member is still in participants, so the week must survive",
  );
  const data = await dataAt(`group_weekly_menu_plans/gp-desync-inverse-${RUN}`);
  const participants = (data.participants as Array<{ userId: string }>) ?? [];
  assert(
    participants.length === 1 && participants[0].userId === OTHER,
    "and the target is scrubbed out of it rather than the document dropped",
  );
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(!(TARGET in perms), "the ACL key goes too");
  // The mirror is rebuilt from the survivors, not just filtered: filtering it
  // alone would leave an empty queryable roster beside a non-empty real one.
  const ids = (data.participantUserIds as string[]) ?? [];
  assert(
    ids.length === 1 && ids[0] === OTHER,
    `the mirror must name the surviving member, got ${JSON.stringify(ids)}`,
  );
});

test("group_weekly_menu_plans: a survivor only the mirror knows about keeps their week", async () => {
  assert(
    await exists(`group_weekly_menu_plans/gp-mirror-survivor-${RUN}`),
    "the mirror names a member `participants` does not — deleting here " +
      "destroys that member's week",
  );
  const data = await dataAt(
    `group_weekly_menu_plans/gp-mirror-survivor-${RUN}`,
  );
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(!(TARGET in perms), "and the target is still scrubbed out of it");
  assert("mirror-only-member" in perms, "while the survivor keeps access");
  // What the rosters actually become, so a later reader does not infer the
  // mirror survives: `participants` never named the survivor, so both arrays
  // end up empty.
  assert(
    ((data.participantUserIds as string[]) ?? []).length === 0,
    "the mirror is rebuilt from participants, which never named the survivor",
  );
  assert(
    ((data.participants as unknown[]) ?? []).length === 0,
    "and participants held only the target",
  );
});

test("group_weekly_menu_plans: a plan holding nothing but the erased user is deleted", async () => {
  assert(
    !(await exists(`group_weekly_menu_plans/gp-contributor-sole-${RUN}`)),
    "no roster, no permissions and no contributor but the target — there is " +
      "nobody else's data here to protect, so the document goes",
  );
});

test("group_weekly_menu_plans: a plan reached ONLY by the contributor trail is scrubbed", async () => {
  const data = await dataAt(`group_weekly_menu_plans/gp-contributor-only-${RUN}`);
  const contributors = (data.contributorUserIds as string[]) ?? [];
  assert(
    !contributors.includes(TARGET),
    "the trail entry is a uid and is erasable data in its own right",
  );
  assert(
    contributors.includes("still-a-member"),
    "while the remaining member keeps theirs",
  );
  const entries = (data.entries as Record<string, unknown>[]) ?? [];
  assert(
    entries[0]?.proposedBy === undefined,
    "the dish no longer names the deleted user",
  );
  assert(
    !((entries[0]?.votedInBy as string[]) ?? []).includes(TARGET),
    "and neither does its vote list",
  );
  const trail = (data.editTrail as Record<string, unknown>[]) ?? [];
  assert(trail.length === 0, "their own trail row is gone");
});

test("group_weekly_menu_plans: a departed contributor does NOT block the delete", async () => {
  assert(
    !(await exists(`group_weekly_menu_plans/gp-contributor-survivor-${RUN}`)),
    "every roster is empty, so nobody can open this week — keeping it would " +
      "leave a document with no readers that no client could ever repair, " +
      "which is the brick `cutGroupMenuPlanAccess` deletes rather than create",
  );
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
  // BUT-1697 scope proof for the added/last-modified pairs.
  assert(i1!.addedByUserId === OTHER, "i1 addedByUserId (OTHER) must be unchanged");
  assert(
    i1!.addedByDisplayName === "Other",
    "i1 addedByDisplayName must be unchanged",
  );
  assert(
    i1!.lastModifiedByUserId === OTHER,
    "i1 lastModifiedByUserId (OTHER) must be unchanged",
  );
  assert(
    i1!.lastModifiedByDisplayName === "Other",
    "i1 lastModifiedByDisplayName must be unchanged",
  );
});

// I-SL2b (BUT-1697): the target's addedBy*/lastModifiedBy* pairs are
// ANONYMIZED, not nulled — `isCollaborative => addedByUserId != null`, so a
// null would silently demote a shared item to personal for everyone else.
test("unified_shared_shopping_lists: target's addedBy/lastModifiedBy is anonymized, not nulled", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  const items = (data.items as Array<Record<string, unknown>>) ?? [];
  const i0 = items.find((it) => it.id === "i0");
  assert(!!i0, "item i0 must still be present");
  assert(
    i0!.addedByUserId === "deleted",
    "i0 addedByUserId must be anonymized to 'deleted', not left as the raw uid and not nulled",
  );
  assert(i0!.addedByDisplayName === null, "i0 addedByDisplayName must be nulled");
  assert(
    i0!.lastModifiedByUserId === "deleted",
    "i0 lastModifiedByUserId must be anonymized to 'deleted'",
  );
  assert(
    i0!.lastModifiedByDisplayName === null,
    "i0 lastModifiedByDisplayName must be nulled",
  );
});

// I-SL5 (BUT-1697): LIST-level scrub. The activity pair goes entirely;
// ownerDisplayName goes but ownerId STAYS (the rules read it to decide who may
// write, so nulling it would orphan the list for remaining members).
test("unified_shared_shopping_lists: list-level activity pair is nulled and ownerDisplayName removed while ownerId survives", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  assert(
    data.lastActivityByUserId === null,
    "lastActivityByUserId must be nulled",
  );
  assert(
    data.lastActivityByDisplayName === null,
    "lastActivityByDisplayName must be nulled",
  );
  assert(data.ownerDisplayName === null, "ownerDisplayName must be nulled");
  assert(
    data.ownerId === TARGET,
    "ownerId must be UNCHANGED — the Firestore rules read it for write access",
  );
});

// I-SL6 (BUT-1697): negative control — a shared list whose owner and last
// activity are OTHER's keeps every list-level identity field.
test("unified_shared_shopping_lists: another member's list-level identity is untouched", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-control-${RUN}`);
  assert(
    data.lastActivityByUserId === OTHER,
    "control lastActivityByUserId (OTHER) must be unchanged",
  );
  assert(
    data.lastActivityByDisplayName === "Other",
    "control lastActivityByDisplayName must be unchanged",
  );
  assert(data.ownerId === OTHER, "control ownerId must be unchanged");
  assert(
    data.ownerDisplayName === "Other",
    "control ownerDisplayName must be unchanged — only the deleted user's name goes",
  );
});

// I-SL7: the uid must not survive as a memberPermissions MAP KEY. It is the
// key the rules read as write authorization and the key the UI derives
// memberCount/collaborators from, so leaving it keeps a ghost member forever.
// Other members' keys and `ownerId` must be untouched.
test("unified_shared_shopping_lists: target's memberPermissions key is removed while other members' keys survive", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-${RUN}`);
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(
    perms[TARGET] === undefined,
    "memberPermissions must no longer carry the deleted uid as a key",
  );
  assert(
    perms[OTHER] === "owner",
    "the remaining member's permission entry must be unchanged",
  );
  assert(
    data.ownerId === TARGET,
    "ownerId still stays — the rules read it for the remaining members' write access",
  );
});

// I-SL7b: same on the list the target only VIEWED — the key goes there too,
// even though no other field on that doc changes.
test("unified_shared_shopping_lists: target's key is removed from a list they only viewed", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-control-${RUN}`);
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(perms[TARGET] === undefined, "viewer key must be removed");
  assert(perms[OTHER] === "owner", "owner key must survive");
});

// I-SL8: a sole-member list owned by the target is pure own data — DELETED,
// not scrubbed. Scrubbing would leave a doc no account can read.
test("unified_shared_shopping_lists: sole-member list owned by target is deleted", async () => {
  assert(
    !(await exists(`unified_shared_shopping_lists/ussl-solo-${RUN}`)),
    "a collaborative list with no other member is own data and must be deleted",
  );
});

// I-SL9: a list the target was never a member of is untouched (scope proof for
// the new delete branch — a bug there could reach foreign documents).
test("unified_shared_shopping_lists: a list the target never belonged to is untouched", async () => {
  const data = await dataAt(`unified_shared_shopping_lists/ussl-foreign-${RUN}`);
  const perms = (data.memberPermissions as Record<string, unknown>) ?? {};
  assert(perms[OTHER] === "owner", "foreign list owner key must be unchanged");
  assert(perms[THIRD] === "editor", "foreign list member key must be unchanged");
  assert(data.ownerDisplayName === "Other", "foreign list name must be unchanged");
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

// Retry-safety for the shopping sweep. `runStep` records a failure and the
// cascade continues, so any step can be re-entered by a manual remediation run
// (`admin/reset-user-data.ts`). The second call must be a clean no-op rather
// than throwing on documents the first call already removed — the per-document
// transaction and the missing-document tolerance are what make that true.
test("unified_shopping_lists: deleteShoppingLists is idempotent on re-run (retry-safe)", async () => {
  await deleteShoppingLists(db, TARGET); // second run over an already-swept user
  assert(
    !(await exists(`users/${TARGET}/unified_shopping_lists/usl-${RUN}`)),
    "list stays deleted after re-run",
  );
  assert(
    !(await exists(
      `users/${TARGET}/unified_shopping_lists/usl-orphan-${RUN}/items/usl-orphan-item-${RUN}`,
    )),
    "orphaned items stay deleted after re-run",
  );
  assert(
    await exists(`users/${OTHER}/unified_shopping_lists/usl-control-${RUN}`),
    "re-run must not widen scope to another user",
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
