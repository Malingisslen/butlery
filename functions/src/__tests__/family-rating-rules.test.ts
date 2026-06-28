/**
 * Firestore rules tests for the family-rating feature — the authoritative
 * security layer (commit 3). Three top-level collections plus four helpers.
 *
 * Paths:
 *   - households/{householdId}    — shared identity; member-read, admin-write.
 *   - diner_profiles/{profileId}  — household-scoped; any member CRUD, with a
 *                                    server-side consent invariant + immutable
 *                                    householdId/createdBy/createdAt.
 *   - family_ratings/{ratingId}   — household-scoped; any member CRUD, stars
 *                                    1..5 enforced, enteredByUid pinned to the
 *                                    writer on create, immutable anchors.
 *
 * Helpers under test (firestore.rules ~L235):
 *   isHouseholdMember(hid)      — authed && household doc exists && uid in
 *                                 memberUserIds.
 *   familyStarsValid(stars)     — int 1..5.
 *   dinerHasAllergenData(data)  — allergenPreferences has a tracked allergen
 *                                 or dietary entry.
 *   dinerConsentValid(data)     — minor (non-adult) needs guardianConsent;
 *                                 allergen (Art. 9) data needs
 *                                 guardianConsent.includesAllergenConsent==true.
 *
 * Membership is resolved by READING households/{hid}.memberUserIds, so every
 * diner_profiles / family_ratings test must SEED a household first (via
 * withSecurityRulesDisabled — the household create rule is admin-projection
 * strict, and we want the membership set, not to re-test create here).
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:family-rating  (from functions/)
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-family-rating";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

// Actors. MEMBER + ADMIN_MEMBER + EDITOR + VIEWER all belong to HOUSEHOLD_ID;
// STRANGER does not. ADMIN_MEMBER has 'admin' permission; EDITOR 'edit';
// VIEWER 'view'. (Admin here = household admin, NOT the /admins app-admin.)
const ADMIN_MEMBER = "fr-admin-member-uid";
const EDITOR = "fr-editor-uid";
const VIEWER = "fr-viewer-uid";
const STRANGER = "fr-stranger-uid";

const HOUSEHOLD_ID = "household-1";

// Per-run token: the emulator persists docs across npm-run invocations, so a
// fixed-id create-allow test becomes an UPDATE on the 2nd run. Suffix every
// create-allow doc id with RUN. See knowledge entry 2026-06-03.
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Wipe the namespace so fixed-id seeds are deterministic across local re-runs.
  await env.clearFirestore();
  await seedHousehold();
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
// Builders
// ----------------------------------------------------------------------------

// A consistent household doc: ADMIN_MEMBER=admin, EDITOR=edit, VIEWER=view.
// memberUserIds and memberPermissions.keys() agree (the rule's invariant).
function validHouseholdBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    name: "Familjen Andersson",
    members: [
      { userId: ADMIN_MEMBER, permission: "admin", addedAt: new Date() },
      { userId: EDITOR, permission: "edit", addedAt: new Date() },
      { userId: VIEWER, permission: "view", addedAt: new Date() },
    ],
    memberUserIds: [ADMIN_MEMBER, EDITOR, VIEWER],
    memberPermissions: {
      [ADMIN_MEMBER]: "admin",
      [EDITOR]: "edit",
      [VIEWER]: "view",
    },
    createdBy: ADMIN_MEMBER,
    createdAt: new Date(),
    updatedAt: new Date(),
    schemaVersion: 1,
    ...extra,
  };
}

// Minimal valid diner profile (adult => no consent required).
function validDinerBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    householdId: HOUSEHOLD_ID,
    name: "Mormor",
    ageBand: "adult",
    createdBy: ADMIN_MEMBER,
    createdAt: new Date(),
    updatedAt: new Date(),
    schemaVersion: 1,
    ...extra,
  };
}

// Minimal valid family rating (stars in range, enteredByUid set by test).
function validRatingBody(
  enteredByUid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    householdId: HOUSEHOLD_ID,
    memberId: "diner-1",
    memberType: "profile",
    stars: 4,
    enteredByUid,
    createdAt: new Date(),
    lastUpdatedAt: new Date(),
    schemaVersion: 1,
    ...extra,
  };
}

// Seed the household with the admin SDK (bypasses rules) so membership lookups
// resolve for the diner_profiles / family_ratings tests.
async function seedHousehold(): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .set(validHouseholdBody());
  });
}

async function seedDiner(
  profileId: string,
  body: Record<string, unknown> = validDinerBody()
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`diner_profiles/${profileId}`).set(body);
  });
}

async function seedRating(
  ratingId: string,
  body: Record<string, unknown> = validRatingBody(ADMIN_MEMBER)
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`family_ratings/${ratingId}`).set(body);
  });
}

// ============================================================================
// HOUSEHOLDS (read 3, create 6, update 6, delete 3)
// ============================================================================

// --- read ---

// H1: a member reads the household.
test("households: member can read the household", async () => {
  const ctx = env.authenticatedContext(VIEWER);
  await assertSucceeds(
    ctx.firestore().doc(`households/${HOUSEHOLD_ID}`).get()
  );
});

// H2: a non-member is denied read.
test("households: non-member cannot read the household", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`households/${HOUSEHOLD_ID}`).get());
});

// H3: unauthenticated read denied.
test("households: unauthenticated user cannot read the household", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`households/${HOUSEHOLD_ID}`).get());
});

// --- create ---

// H4: creator seeds themselves as admin, projections consistent => allowed.
test("households: creator can create a consistent admin-seeded household", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`households/h-create-ok-${RUN}`)
      .set(validHouseholdBody())
  );
});

// H5: createdBy != auth.uid => denied (cannot create a household for someone else).
test("households: create with createdBy != auth.uid is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/h-create-otherowner-${RUN}`)
      .set(validHouseholdBody({ createdBy: EDITOR }))
  );
});

// H6: creator is in members but NOT as 'admin' => denied.
test("households: create where creator is not admin is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/h-create-notadmin-${RUN}`)
      .set(
        validHouseholdBody({
          memberPermissions: {
            [ADMIN_MEMBER]: "edit",
            [EDITOR]: "edit",
            [VIEWER]: "view",
          },
        })
      )
  );
});

// H7: creator not in memberUserIds at all => denied (uid not in the list).
test("households: create where creator is absent from memberUserIds is denied", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/h-create-absent-${RUN}`)
      // createdBy=STRANGER but STRANGER is not in the member set/perms.
      .set(
        validHouseholdBody({
          createdBy: STRANGER,
        })
      )
  );
});

// H8: memberUserIds vs memberPermissions.keys() inconsistent => denied.
test("households: create with inconsistent memberUserIds vs memberPermissions is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/h-create-inconsistent-${RUN}`)
      // memberUserIds has an extra uid not present in memberPermissions.keys().
      .set(
        validHouseholdBody({
          memberUserIds: [ADMIN_MEMBER, EDITOR, VIEWER, STRANGER],
        })
      )
  );
});

// H9: missing a required field (name) => denied (hasRequiredFields).
test("households: create missing a required field is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  const body = validHouseholdBody();
  delete (body as Record<string, unknown>).name;
  await assertFails(
    ctx.firestore().doc(`households/h-create-noname-${RUN}`).set(body)
  );
});

// --- update ---

// H10: admin member updates (rename) => allowed.
test("households: admin member can update the household", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ name: "Familjen A", updatedAt: new Date() })
  );
});

// H11: editor (non-admin member) cannot update.
test("households: editor cannot update the household", async () => {
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ name: "Hijack", updatedAt: new Date() })
  );
});

// H12: viewer cannot update.
test("households: viewer cannot update the household", async () => {
  const ctx = env.authenticatedContext(VIEWER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ name: "Hijack", updatedAt: new Date() })
  );
});

// H13: non-member cannot update.
test("households: non-member cannot update the household", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ name: "Hijack", updatedAt: new Date() })
  );
});

// H14: admin modifying createdBy is denied (immutable).
test("households: admin cannot modify createdBy", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ createdBy: EDITOR, updatedAt: new Date() })
  );
});

// H15: admin modifying createdAt is denied (immutable).
test("households: admin cannot modify createdAt", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`households/${HOUSEHOLD_ID}`)
      .update({ createdAt: new Date("2000-01-01"), updatedAt: new Date() })
  );
});

// --- delete ---

// H16: admin member can delete the household.
test("households: admin member can delete the household", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`households/h-del-${RUN}`)
      .set(validHouseholdBody());
  });
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx.firestore().doc(`households/h-del-${RUN}`).delete()
  );
});

// H17: editor cannot delete the household.
test("households: editor cannot delete the household", async () => {
  const ctx = env.authenticatedContext(EDITOR);
  await assertFails(ctx.firestore().doc(`households/${HOUSEHOLD_ID}`).delete());
});

// H18: non-member cannot delete the household.
test("households: non-member cannot delete the household", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`households/${HOUSEHOLD_ID}`).delete());
});

// ============================================================================
// DINER PROFILES (read 2, create consent-invariant 7, update 5, delete 2)
// ============================================================================

// --- read / delete: member vs non-member ---

// D1: a member reads a profile in their household.
test("diner_profiles: member can read a profile in their household", async () => {
  await seedDiner("d-read-member");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx.firestore().doc(`diner_profiles/d-read-member`).get()
  );
});

// D2: a non-member cannot read a profile in another household.
test("diner_profiles: non-member cannot read a profile", async () => {
  await seedDiner("d-read-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`diner_profiles/d-read-stranger`).get()
  );
});

// --- create: consent invariant ---

// D3: minor (ageBand 'child') with NO guardianConsent => denied.
test("diner_profiles: minor without guardianConsent is denied (consent invariant)", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-minor-noconsent-${RUN}`)
      .set(validDinerBody({ name: "Lilla Olle", ageBand: "child" }))
  );
});

// D4: minor WITH guardianConsent => allowed.
test("diner_profiles: minor with guardianConsent is allowed", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`diner_profiles/d-minor-consent-${RUN}`)
      .set(
        validDinerBody({
          name: "Lilla Olle",
          ageBand: "child",
          guardianConsent: {
            byUid: ADMIN_MEMBER,
            at: new Date(),
            consentVersion: "1.0",
            includesAllergenConsent: false,
          },
        })
      )
  );
});

// D5: allergen data present but includesAllergenConsent=false => denied (Art. 9).
test("diner_profiles: tracked allergen without allergen consent is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-allergen-noconsent-${RUN}`)
      .set(
        validDinerBody({
          // adult => guardianConsent not required for minority, but allergen
          // data present forces includesAllergenConsent==true.
          allergenPreferences: {
            trackedAllergens: ["gluten"],
            trackedDietary: [],
          },
          guardianConsent: {
            byUid: ADMIN_MEMBER,
            at: new Date(),
            consentVersion: "1.0",
            includesAllergenConsent: false,
          },
        })
      )
  );
});

// D6: allergen data present WITH includesAllergenConsent=true => allowed.
test("diner_profiles: tracked allergen with allergen consent is allowed", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`diner_profiles/d-allergen-consent-${RUN}`)
      .set(
        validDinerBody({
          allergenPreferences: {
            trackedAllergens: ["gluten"],
            trackedDietary: [],
          },
          guardianConsent: {
            byUid: ADMIN_MEMBER,
            at: new Date(),
            consentVersion: "1.0",
            includesAllergenConsent: true,
          },
        })
      )
  );
});

// D7: adult ageBand with no consent at all => allowed (consent only gates minors
// and allergen data).
test("diner_profiles: adult with no consent is allowed", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`diner_profiles/d-adult-noconsent-${RUN}`)
      .set(validDinerBody())
  );
});

// D8: non-member cannot create a profile in this household.
test("diner_profiles: non-member cannot create a profile", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-create-stranger-${RUN}`)
      .set(validDinerBody())
  );
});

// D9: missing required field (ageBand) => denied.
test("diner_profiles: create missing ageBand is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  const body = validDinerBody();
  delete (body as Record<string, unknown>).ageBand;
  await assertFails(
    ctx.firestore().doc(`diner_profiles/d-create-noage-${RUN}`).set(body)
  );
});

// --- update ---

// D10: member updates an editable field (rename) => allowed.
test("diner_profiles: member can update a profile field", async () => {
  await seedDiner("d-update-ok");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`diner_profiles/d-update-ok`)
      .update({ name: "Farmor", updatedAt: new Date() })
  );
});

// D11: re-parenting (changing householdId) is denied (immutable).
test("diner_profiles: changing householdId (re-parent) is denied", async () => {
  await seedDiner("d-update-reparent");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-update-reparent`)
      .update({ householdId: "household-2", updatedAt: new Date() })
  );
});

// D12: changing createdBy is denied (immutable).
test("diner_profiles: changing createdBy is denied", async () => {
  await seedDiner("d-update-createdby");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-update-createdby`)
      .update({ createdBy: EDITOR, updatedAt: new Date() })
  );
});

// D13: changing createdAt is denied (immutable).
test("diner_profiles: changing createdAt is denied", async () => {
  await seedDiner("d-update-createdat");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-update-createdat`)
      .update({ createdAt: new Date("2000-01-01"), updatedAt: new Date() })
  );
});

// D14: a consent-invalid update — add tracked allergens WITHOUT allergen consent
// (no guardianConsent at all) => denied.
test("diner_profiles: update adding allergens without allergen consent is denied", async () => {
  await seedDiner("d-update-allergen");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`diner_profiles/d-update-allergen`)
      .update({
        allergenPreferences: { trackedAllergens: ["mjölk"], trackedDietary: [] },
        updatedAt: new Date(),
      })
  );
});

// --- delete ---

// D15: a member can delete a profile in their household.
test("diner_profiles: member can delete a profile", async () => {
  await seedDiner("d-del-member");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx.firestore().doc(`diner_profiles/d-del-member`).delete()
  );
});

// D16: a non-member cannot delete a profile.
test("diner_profiles: non-member cannot delete a profile", async () => {
  await seedDiner("d-del-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`diner_profiles/d-del-stranger`).delete()
  );
});

// ============================================================================
// FAMILY RATINGS (read 2, create 6, update 5, delete 1)
// ============================================================================

// --- read ---

// FR1: a member reads a rating in their household.
test("family_ratings: member can read a rating in their household", async () => {
  await seedRating("fr-read-member");
  const ctx = env.authenticatedContext(VIEWER);
  await assertSucceeds(
    ctx.firestore().doc(`family_ratings/fr-read-member`).get()
  );
});

// FR2: a non-member cannot read a rating.
test("family_ratings: non-member cannot read a rating", async () => {
  await seedRating("fr-read-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`family_ratings/fr-read-stranger`).get()
  );
});

// --- create ---

// FR3: stars=0 => denied (below range).
test("family_ratings: create with stars=0 is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-stars0-${RUN}`)
      .set(validRatingBody(ADMIN_MEMBER, { stars: 0 }))
  );
});

// FR4: stars=6 => denied (above range).
test("family_ratings: create with stars=6 is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-stars6-${RUN}`)
      .set(validRatingBody(ADMIN_MEMBER, { stars: 6 }))
  );
});

// FR5: stars=1 => allowed (lower boundary).
test("family_ratings: create with stars=1 is allowed", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`family_ratings/fr-stars1-${RUN}`)
      .set(validRatingBody(ADMIN_MEMBER, { stars: 1 }))
  );
});

// FR6: stars=5 => allowed (upper boundary).
test("family_ratings: create with stars=5 is allowed", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`family_ratings/fr-stars5-${RUN}`)
      .set(validRatingBody(ADMIN_MEMBER, { stars: 5 }))
  );
});

// FR7: enteredByUid != auth.uid => denied (writer pin on create).
test("family_ratings: create with enteredByUid != auth.uid is denied", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-wrongwriter-${RUN}`)
      // member, but claims EDITOR entered it.
      .set(validRatingBody(EDITOR))
  );
});

// FR8: non-member cannot create a rating.
test("family_ratings: non-member cannot create a rating", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-create-stranger-${RUN}`)
      .set(validRatingBody(STRANGER))
  );
});

// --- update ---

// FR9: changing recipeId is denied (immutable anchor).
test("family_ratings: changing recipeId is denied", async () => {
  await seedRating("fr-update-recipe");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-recipe`)
      .update({ recipeId: "recipe-2", lastUpdatedAt: new Date() })
  );
});

// FR10: changing memberId is denied (immutable anchor).
test("family_ratings: changing memberId is denied", async () => {
  await seedRating("fr-update-member");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-member`)
      .update({ memberId: "diner-2", lastUpdatedAt: new Date() })
  );
});

// FR11: changing householdId is denied (immutable anchor).
test("family_ratings: changing householdId is denied", async () => {
  await seedRating("fr-update-household");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-household`)
      .update({ householdId: "household-2", lastUpdatedAt: new Date() })
  );
});

// FR12: changing createdAt is denied (immutable anchor).
test("family_ratings: changing createdAt is denied", async () => {
  await seedRating("fr-update-createdat");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-createdat`)
      .update({ createdAt: new Date("2000-01-01"), lastUpdatedAt: new Date() })
  );
});

// FR13: update with out-of-range stars => denied (familyStarsValid on update).
test("family_ratings: update with stars out of range is denied", async () => {
  await seedRating("fr-update-badstars");
  const ctx = env.authenticatedContext(ADMIN_MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-badstars`)
      .update({ stars: 9, lastUpdatedAt: new Date() })
  );
});

// FR14: a member changing stars within range => allowed (load-bearing allow:
// without it the deny-only update tests would pass under a blanket deny).
test("family_ratings: member can change stars within range", async () => {
  await seedRating("fr-update-ok");
  const ctx = env.authenticatedContext(EDITOR);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`family_ratings/fr-update-ok`)
      .update({ stars: 2, lastUpdatedAt: new Date() })
  );
});

// --- delete ---

// FR15: a member can delete a rating; a non-member cannot.
test("family_ratings: member can delete, non-member cannot", async () => {
  await seedRating("fr-del-member");
  await seedRating("fr-del-stranger");
  const memberCtx = env.authenticatedContext(VIEWER);
  await assertSucceeds(
    memberCtx.firestore().doc(`family_ratings/fr-del-member`).delete()
  );
  const strangerCtx = env.authenticatedContext(STRANGER);
  await assertFails(
    strangerCtx.firestore().doc(`family_ratings/fr-del-stranger`).delete()
  );
});

async function run(): Promise<void> {
  console.log("family-rating rules tests (households / diner_profiles / family_ratings)\n");
  console.log("========================================\n");
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
