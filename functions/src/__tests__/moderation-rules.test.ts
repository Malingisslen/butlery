/**
 * Rules tests for the moderation surfaces: the `friend_categories` admin
 * override landed in BUT-511 (commit 34ba389c6), the `public_profiles` hide
 * branch, and `user_moderation` — the strike record its own subject may read
 * (BUT-2046 follow-up). Cook-snaps and messages admin-read coverage live in
 * `cook-snaps-and-message-mod-rules.test.ts`.
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
  // This suite shares ONE emulator across its tests and nothing clears it
  // between them, so a fixture that omits a seed is a claim about every test
  // that ran before it. UM8 was written that way and was VACUOUS — it passed
  // with the rule's null arm deleted, because a predecessor's seed meant the
  // "absent" document was not absent. This clear runs ONCE, before the loop in
  // `run()`, so it isolates a run from the previous run's residue on a shared
  // emulator — it does not clear between tests, and a future test appended
  // after a seeding neighbour still inherits its state. UM8 and UM9 delete
  // positively for that reason. Clearing inside the loop is what would close
  // the class.
  await env.clearFirestore();

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
    isHidden: false,
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
// PUBLIC_PROFILES — admin moderation HIDE override (BUT-729 Phase 2)
// 5 tests covering admin allow/deny for the hide-flag update + owner
// regression guard. Hard delete is intentionally NOT granted to admins
// (would orphan auth account + dangling friendships); reversible hide is
// the takedown primitive.
// ============================================================================

// admin can flip isHidden + hiddenAt on a flagged profile.
test(
  "public_profiles: admin can hide a reported profile (isHidden + hiddenAt)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .update({ isHidden: true, hiddenAt: new Date() })
    );
  }
);

// admin update is restricted to {isHidden, hiddenAt} only — touching any
// other field via the admin branch is denied (no end-run around the rule).
test(
  "public_profiles: admin cannot update other fields via the admin branch",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertFails(
      adminCtx
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .update({ isHidden: true, displayName: "renamed by admin" })
    );
  }
);

// owner cannot un-hide themselves (or set isHidden at all). Without this
// guard, a user could just flip the moderation flag back to false.
test(
  "public_profiles: owner cannot set isHidden on their own profile",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody({ isHidden: true, hiddenAt: new Date() }));
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertFails(
      ownerCtx
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .update({ isHidden: false })
    );
  }
);

// non-admin non-owner cannot touch isHidden either (defence-in-depth).
test(
  "public_profiles: non-admin non-owner cannot set isHidden",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const strangerCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      strangerCtx
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .update({ isHidden: true })
    );
  }
);

// regression: owner can still update other profile fields. Confirms the
// new isHidden blocklist entry didn't accidentally tighten owner CRUD.
test(
  "public_profiles: owner can still update displayName (regression)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .set(validPublicProfileBody());
    });
    const ownerCtx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ownerCtx
        .firestore()
        .doc(`public_profiles/${OWNER_UID}`)
        .update({ displayName: "Anna B." })
    );
  }
);

// ============================================================================
// USER_MODERATION — the subject reads their own strike count (BUT-2046
// follow-up, 2026-09-08). UM1-UM3 are the owner/stranger/signed-out set; UM4
// carries the design (the `report_history` subcollection stays denied to its
// OWN subject, because those rows name the people who reported them); UM5 and
// UM10 are the two fail-closed cases on the parent; UM6 and UM7 close the write
// and collection-group routes; UM8 and UM9 are the absent document.
// ============================================================================

async function seedModerationRecord(): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`user_moderation/${OWNER_UID}`)
      .set({ totalReports: 3, lastReportedAt: new Date() });
    await admin
      .firestore()
      .doc(`user_moderation/${OWNER_UID}/report_history/r1`)
      .set({ reportId: "r1", reporterId: OTHER_UID, reason: "spam" });
  });
}

// UM1: the subject reads their own count — what makes the Art. 15 export
//      section return anything at all.
test("user_moderation: the subject can read their own strike record", async () => {
  await seedModerationRecord();
  await assertSucceeds(
    env.authenticatedContext(OWNER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
  );
});

// UM2: nobody else can. The count says how often this person has been
//      reported, which is not a fact about the reader.
test("user_moderation: a stranger cannot read somebody else's strike record", async () => {
  await seedModerationRecord();
  await assertFails(
    env.authenticatedContext(OTHER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
  );
});

// UM3: signed out is denied.
test("user_moderation: a signed-out client cannot read a strike record", async () => {
  await seedModerationRecord();
  await assertFails(
    env.unauthenticatedContext().firestore().doc(`user_moderation/${OWNER_UID}`).get()
  );
});

// UM4: THE one that must never regress. The read block above is safe only
//      because the rows naming the REPORTERS are unreachable — a subcollection
//      inherits nothing, so the absence of a block is what denies them. A
//      future `match /user_moderation/{uid}/{document=**}` would open this
//      without touching UM1-UM3, and this is the only test that would redden.
test(
  "user_moderation: the subject CANNOT read the reporters beneath their own record",
  async () => {
    await seedModerationRecord();
    const ownerDb = env.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      ownerDb.doc(`user_moderation/${OWNER_UID}/report_history/r1`).get()
    );
    await assertFails(
      ownerDb.collection(`user_moderation/${OWNER_UID}/report_history`).get()
    );
  }
);

// UM5: THE measured one. Before BUT-2046 the parent carried a `reportHistory`
//      ARRAY whose entries each named a reporter, and rules cannot scope a read
//      by field — so a plain owner read on an un-migrated document returns those
//      uids. The `firestore-rules-tester` gate measured exactly that on this
//      emulator before the conjunct existed. The document is denied WHOLE while
//      the field is present, which needs no promise that the migration was run.
test(
  "user_moderation: an UN-MIGRATED record is denied to its own subject",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`user_moderation/${OWNER_UID}`)
        .set({
          totalReports: 1,
          lastReportedAt: new Date(),
          reportHistory: [{ reportId: "r1", reporterId: OTHER_UID, reason: "spam" }],
        });
    });
    await assertFails(
      env.authenticatedContext(OWNER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
    );
  }
);

// UM6: no write limb exists, and its absence is what denies. Written as its own
//      test because adding `allow write: if isOwner(userId)` would otherwise
//      redden nothing — and a client that could write here would edit its own
//      strike count, which is the number the five-report threshold reads.
test("user_moderation: the subject cannot write their own strike record", async () => {
  await seedModerationRecord();
  const ownerDb = env.authenticatedContext(OWNER_UID).firestore();
  await assertFails(
    ownerDb.doc(`user_moderation/${OWNER_UID}`).set({ totalReports: 0 })
  );
  await assertFails(
    ownerDb.doc(`user_moderation/${OWNER_UID}`).update({ totalReports: 0 })
  );
  await assertFails(ownerDb.doc(`user_moderation/${OWNER_UID}`).delete());

  // The CREATE limb, which the three above do NOT reach: the seed exists, so
  // `set()` evaluated as an update. A future `allow create: if isOwner(userId)`
  // — the plausible "let the client initialise its own record" shape — would
  // redden nothing without this, and it is directly exploitable:
  // `on-report-created.ts` reads `totalReports ?? 0` and applies
  // `increment(1)`, so a client creating its own record with a large negative
  // count never reaches MODERATION_THRESHOLD. Such a document also satisfies
  // the read gate's key set, so nothing else would notice.
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`user_moderation/${OWNER_UID}`).delete();
  });
  await assertFails(
    ownerDb.doc(`user_moderation/${OWNER_UID}`).set({ totalReports: 0 })
  );
});

// UM7: the collection-group route to the same rows. Denied today, and pinned
//      because the account cascade already queries this group under the Admin
//      SDK — a client refactor toward the same query is the plausible way this
//      opens, and UM4's document-and-collection reads would not see it.
test("user_moderation: a client cannot reach report_history by collection group", async () => {
  await seedModerationRecord();
  await assertFails(
    env.authenticatedContext(OWNER_UID).firestore().collectionGroup("report_history").get()
  );
});

// UM8: the ABSENT document — the fourth case of the set, and the one written
//      last. `user_moderation/{uid}` exists only once somebody has reported
//      you, so this is every user who never has been. The first version of the
//      `reportHistory` conjunct dereferenced `resource.data` unconditionally
//      and denied it, which would have made nearly every Art. 15 bundle report
//      itself incomplete. Measured by the `firebase-backend-security` gate.
test("user_moderation: a subject with NO strike record is allowed the read", async () => {
  // The document must be REMOVED, not merely left unseeded: this file shares
  // one emulator across its tests and nothing clears it between them, so an
  // earlier test's seed makes "absent" a lie. Measured — with the document left
  // in place this case passed with the null arm deleted, i.e. it held nothing.
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`user_moderation/${OWNER_UID}`).delete();
  });
  await assertSucceeds(
    env.authenticatedContext(OWNER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
  );
});

// UM9: and a stranger is still denied the absent document, so the null arm
//      widened nothing beyond the owner.
test("user_moderation: a stranger is denied even an absent record", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`user_moderation/${OWNER_UID}`).delete();
  });
  await assertFails(
    env.authenticatedContext(OTHER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
  );
});

// UM10: a field nobody has decided about is denied the DAY it is written,
//       rather than becoming owner-readable because no human noticed. This is
//       what `hasOnly` buys over a deny-list naming `reportHistory`: the
//       deny-list covers the shape we know about, this covers the next one.
test(
  "user_moderation: an undecided field on the parent denies the whole read",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`user_moderation/${OWNER_UID}`)
        .set({
          totalReports: 2,
          lastReportedAt: new Date(),
          // Plausible on this collection, and nobody has decided whether the
          // subject may see it.
          lastReviewedBy: "moderator-uid",
        });
    });
    await assertFails(
      env.authenticatedContext(OWNER_UID).firestore().doc(`user_moderation/${OWNER_UID}`).get()
    );
  }
);

async function run(): Promise<void> {
  console.log(
    "moderation rules tests (friend_categories + public_profiles + user_moderation)\n"
  );
  console.log("============================================================\n");
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
