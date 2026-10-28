/**
 * Firestore rules tests for BUT-920 guest mode (Firebase anonymous sign-in).
 *
 * `isGuest()` reads `request.auth.token.firebase.sign_in_provider ==
 * 'anonymous'`. The writes that share, publish, befriend, message or report
 * carry `!isGuest()`, `isAgeCompliant()` is false for a guest whatever its
 * claims say, `shopping_list_templates` admits a guest only with
 * `isPublic == false`, and `guest_quotas` is closed to every client.
 *
 * Every pair below sends the SAME write twice, from two accounts that carry
 * identical claims (`ageCompliant` and `email_verified` both true, so the age
 * and maturity gates pass) and differ only in the sign-in provider. The first
 * must be allowed, which makes the second's denial about the provider and
 * nothing else. Each actor has its own uid, so no rate-limit stamp or seeded
 * document is shared between the two.
 *
 * `authenticatedContext(uid, tokenOptions)` spreads `tokenOptions` over a
 * default token whose `firebase` is `{ sign_in_provider: 'custom', ... }`, so
 * the guest context replaces the whole `firebase` object.
 *
 * Run with: npx ts-node src/__tests__/guest-mode-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestContext,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { deleteField, serverTimestamp } from "firebase/firestore";

const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-guest-mode";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

// The emulator keeps documents between runs; `clearFirestore()` in setup()
// empties the namespace.
const RUN = "but920";

const DAY_MS = 24 * 60 * 60 * 1000;

// The claims a full account needs on every limb below.
const FULL = { ageCompliant: true, email_verified: true };

function guestClaims(
  claims: Record<string, unknown>
): Record<string, unknown> {
  return {
    ...claims,
    firebase: { sign_in_provider: "anonymous", identities: {} },
  };
}

type Db = ReturnType<RulesTestContext["firestore"]>;

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function fullDb(uid: string): Db {
  return env.authenticatedContext(uid, FULL).firestore();
}

function guestDb(uid: string): Db {
  return env.authenticatedContext(uid, guestClaims(FULL)).firestore();
}

async function seedDoc(
  docPath: string,
  body: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(body);
  });
}

/**
 * Writes [docPath] together with the `users/{uid}/rate_limits/{type}` stamp
 * in one batch, the way `rateLimitStamped` requires.
 */
function createStamped(
  db: Db,
  uid: string,
  type: string,
  docPath: string,
  body: Record<string, unknown>,
  lastDocId: string = docPath.split("/").pop() as string
): Promise<void> {
  const batch = db.batch();
  batch.set(db.doc(docPath), body);
  batch.set(db.doc(`users/${uid}/rate_limits/${type}`), {
    lastWrite: serverTimestamp(),
    expireAt: new Date(Date.now() + 2 * DAY_MS),
    lastDocId,
  });
  return batch.commit();
}

type Write = (uid: string, db: Db) => Promise<unknown>;

/**
 * Registers the allow test and the deny test for one limb. [seed] runs for
 * each actor's own uid before its write.
 */
function guestPair(
  id: string,
  behaviour: string,
  write: Write,
  seed?: (uid: string) => Promise<void>
): void {
  const slug = id.toLowerCase();
  test(`${id} ${behaviour}: a full account is allowed`, async () => {
    const uid = `${slug}-full-${RUN}`;
    if (seed) await seed(uid);
    await assertSucceeds(write(uid, fullDb(uid)));
  });
  test(`${id} ${behaviour}: a guest with the same claims is denied`, async () => {
    const uid = `${slug}-guest-${RUN}`;
    if (seed) await seed(uid);
    await assertFails(write(uid, guestDb(uid)));
  });
}

// ====================================================================
// USERS SUBTREE: friends, friend_categories
// ====================================================================

// U1: friends create.
guestPair("U1", "users/{uid}/friends create", (uid, db) =>
  db.doc(`users/${uid}/friends/${uid}-pal`).set({
    friendId: `${uid}-pal`,
    addedAt: new Date(),
  })
);

// U2: friends update.
guestPair(
  "U2",
  "users/{uid}/friends update",
  (uid, db) =>
    db.doc(`users/${uid}/friends/${uid}-pal`).update({ nickname: "Kompis" }),
  (uid) =>
    seedDoc(`users/${uid}/friends/${uid}-pal`, {
      friendId: `${uid}-pal`,
      addedAt: new Date(),
    })
);

// U3: friend_categories create.
guestPair("U3", "users/{uid}/friend_categories create", (uid, db) =>
  db.doc(`users/${uid}/friend_categories/${uid}-cat`).set({
    ownerId: uid,
    name: "Familjen",
    friendUserIds: [],
    createdAt: new Date(),
  })
);

// ====================================================================
// PUBLIC_PROFILES
// ====================================================================

// A guest keeps a profile here, because the app reads its own profile from
// this document, but it can never be searchable.

// P1: a searchable create.
guestPair("P1", "public_profiles create with isSearchable true", (uid, db) =>
  db.doc(`public_profiles/${uid}`).set({
    displayName: "Anna",
    isSearchable: true,
  })
);

// P2: the owner's update limb, turning search on.
guestPair(
  "P2",
  "public_profiles owner update to isSearchable true",
  (uid, db) => db.doc(`public_profiles/${uid}`).update({ isSearchable: true }),
  (uid) =>
    seedDoc(`public_profiles/${uid}`, { displayName: "Anna", isSearchable: false })
);

test("P3 public_profiles: a guest may create its own profile that is not searchable", async () => {
  const uid = `p3-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid).doc(`public_profiles/${uid}`).set({
      displayName: "Gäst",
      isSearchable: false,
    })
  );
});

test("P4 public_profiles: a guest may rename its own profile that is not searchable", async () => {
  const uid = `p4-guest-${RUN}`;
  await seedDoc(`public_profiles/${uid}`, { displayName: "Gäst", isSearchable: false });
  await assertSucceeds(
    guestDb(uid).doc(`public_profiles/${uid}`).update({ displayName: "Anna" })
  );
});

test("P5 public_profiles: a guest may not create another account's profile", async () => {
  const uid = `p5-guest-${RUN}`;
  await assertFails(
    guestDb(uid).doc(`public_profiles/${uid}-other`).set({
      displayName: "Gäst",
      isSearchable: false,
    })
  );
});

// J: the writes a real guest start and upgrade make, with the payload shape
// UserProfile.toFirestoreEditable / toPrivateSettings and
// recordTermsAcceptance produce. A guest has no ageCompliant claim.
function realGuestDb(uid: string): Db {
  return env
    .authenticatedContext(uid, { firebase: { sign_in_provider: "anonymous", identities: {} } })
    .firestore();
}

function upgradedDb(uid: string): Db {
  return env
    .authenticatedContext(uid, {
      ageCompliant: true,
      firebase: { sign_in_provider: "password", identities: {} },
    })
    .firestore();
}

function guestStartWrites(uid: string, db: Db): Promise<unknown> {
  const now = new Date();
  return Promise.all([
    db.doc(`public_profiles/${uid}`).set(
      {
        displayName: "Gäst",
        displayNameLower: "gäst",
        avatarUrl: null,
        isSearchable: false,
        allowEmailSearch: false,
        publicRecipeCount: 0,
        joinedAt: now,
        lastActiveAt: now,
        isOnline: false,
        showOnlineStatus: true,
        shareActivityToFeed: false,
        activityFeedEventTypes: {},
        cookingSkillLevel: null,
        cuisineAffinities: [],
        schemaVersion: 1,
        email: deleteField(),
      },
      { merge: true }
    ),
    db.doc(`users/${uid}/settings/preferences`).set(
      {
        fcmToken: null,
        fcmTokenUpdatedAt: null,
        notificationsEnabled: true,
        preferredLocale: null,
        allergenPreferences: null,
        hasCompletedOnboarding: true,
        onboardingSkippedAt: null,
        bio: null,
        hasSeenActivityFeedHint: false,
        autoAddBoughtToPantry: false,
        useHouseholdAllergens: true,
        useMealAllergenScope: false,
        showNutritionStrip: false,
        pantryAutoAddPrompted: false,
        householdSize: null,
      },
      { merge: true }
    ),
    db.doc(`users/${uid}`).set(
      { termsAcceptedAt: serverTimestamp(), termsVersion: "1.0" },
      { merge: true }
    ),
  ]);
}

test("J1 a guest start writes its profile, settings and terms", async () => {
  const uid = `j1-guest-${RUN}`;
  await seedDoc(`users/${uid}`, { birthYear: 1990, isMinor: false });
  await assertSucceeds(guestStartWrites(uid, realGuestDb(uid)));
});

test("J2 an adult who upgraded may name the profile and make it searchable", async () => {
  const uid = `j2-guest-${RUN}`;
  await seedDoc(`users/${uid}`, { birthYear: 1990, isMinor: false });
  await guestStartWrites(uid, realGuestDb(uid));
  await assertSucceeds(
    upgradedDb(uid).doc(`public_profiles/${uid}`).set(
      { displayName: "Anna", displayNameLower: "anna", isSearchable: true },
      { merge: true }
    )
  );
});

test("J3 a minor who upgraded may name the profile but never make it searchable", async () => {
  const uid = `j3-guest-${RUN}`;
  await seedDoc(`users/${uid}`, { birthYear: 2010, isMinor: true });
  await guestStartWrites(uid, realGuestDb(uid));
  const db = upgradedDb(uid);
  await assertSucceeds(
    db.doc(`public_profiles/${uid}`).set(
      { displayName: "Anna", displayNameLower: "anna", isSearchable: false },
      { merge: true }
    )
  );
  await assertFails(
    db.doc(`public_profiles/${uid}`).set({ isSearchable: true }, { merge: true })
  );
});

// ====================================================================
// SOCIAL_REQUESTS, SHARED_CONTENT, MENUS
// ====================================================================

// S1: social_requests create.
guestPair("S1", "social_requests create", (uid, db) =>
  createStamped(db, uid, "social_requests", `social_requests/${uid}-req`, {
    type: "friend_request",
    fromUserId: uid,
    toUserId: `${uid}-to`,
    status: "pending",
    sentAt: serverTimestamp(),
  })
);

// S2: shared_content create.
guestPair("S2", "shared_content create", (uid, db) =>
  createStamped(db, uid, "shared_content", `shared_content/${uid}-share`, {
    sharedByUserId: uid,
    contentType: "recipe",
    sharedAt: serverTimestamp(),
    sharedToUserIds: [`${uid}-to`],
  })
);

// S3: shared_content collaborators create, by the share's owner.
guestPair(
  "S3",
  "shared_content collaborators create",
  (uid, db) =>
    db.doc(`shared_content/${uid}-share/collaborators/${uid}-collab`).set({
      userId: `${uid}-collab`,
      joinedAt: new Date(),
    }),
  (uid) =>
    seedDoc(`shared_content/${uid}-share`, {
      sharedByUserId: uid,
      contentType: "recipe",
      sharedAt: new Date(),
      sharedToUserIds: [`${uid}-collab`],
    })
);

// S4: menus create.
guestPair("S4", "menus create", (uid, db) =>
  db.doc(`menus/${uid}-menu`).set({
    sharedByUserId: uid,
    menuTitle: "Veckans meny",
    sharedAt: new Date(),
  })
);

// ====================================================================
// GROUP PLANS, HOUSEHOLDS, REALTIME, PINGS
// ====================================================================

// H1: group_weekly_menu_plans create.
guestPair("H1", "group_weekly_menu_plans create", (uid, db) =>
  db.doc(`group_weekly_menu_plans/${uid}-grp_2026-W40`).set({
    groupId: `${uid}-grp`,
    participants: [],
    participantUserIds: [uid],
    memberPermissions: { [uid]: "admin" },
    entries: [],
    createdAt: new Date(),
    lastModifiedAt: new Date(),
  })
);

// H2: households create.
guestPair("H2", "households create", (uid, db) =>
  db.doc(`households/${uid}-hh`).set({
    name: "Hemma",
    members: [],
    memberUserIds: [uid],
    memberPermissions: { [uid]: "admin" },
    createdBy: uid,
    createdAt: new Date(),
    updatedAt: new Date(),
  })
);

// H3: household_allergen_shares create, by a seated member.
guestPair(
  "H3",
  "household_allergen_shares create",
  (uid, db) =>
    db.doc(`household_allergen_shares/${uid}-hh_${uid}`).set({
      householdId: `${uid}-hh`,
      userId: uid,
      trackedAllergens: ["gluten"],
      trackedDietary: [],
      includeUnknownInMenu: false,
      consentGranted: true,
      consentVersion: "v1",
      consentGrantedAt: serverTimestamp(),
    }),
  (uid) =>
    seedDoc(`households/${uid}-hh`, {
      name: "Hemma",
      memberUserIds: [uid],
      memberPermissions: { [uid]: "admin" },
    })
);

// H4: realtime_resources create.
guestPair("H4", "realtime_resources create", (uid, db) =>
  db.doc(`realtime_resources/${uid}_menu1`).set({
    type: "menu",
    ownerId: uid,
    participants: { [uid]: "owner" },
    participantIds: [uid],
    createdAt: new Date(),
    lastEditedBy: uid,
  })
);

// H5: realtime_menus create.
guestPair("H5", "realtime_menus create", (uid, db) =>
  db.doc(`realtime_menus/${uid}-rm`).set({
    ownerId: uid,
    participants: {},
    participantIds: [uid],
    createdAt: new Date(),
  })
);

// H6: pings create.
guestPair("H6", "pings create", (uid, db) =>
  createStamped(
    db,
    uid,
    "pings",
    `pings/${uid}-grp/pings/${uid}-ping`,
    {
      groupId: `${uid}-grp`,
      fromUserId: uid,
      type: "nudge",
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + DAY_MS),
      acknowledged: false,
    },
    `${uid}-grp/${uid}-ping`
  )
);

// ====================================================================
// RECIPE_COMMENTS, COOK_SNAPS, ACTIVITY_EVENTS
// ====================================================================

// C1: recipe_comments create.
guestPair("C1", "recipe_comments create", (uid, db) =>
  createStamped(db, uid, "comments", `recipe_comments/${uid}-c`, {
    recipeId: "recipe-1",
    authorId: uid,
    text: "ser gott ut!",
    createdAt: serverTimestamp(),
  })
);

// C2: recipe_comments reaction ADD, on a comment shared with the caller.
// The remove limb cannot grant it: that limb accepts only a list that shrinks.
guestPair(
  "C2",
  "recipe_comments reaction add",
  (uid, db) =>
    db.doc(`recipe_comments/${uid}-react`).update({ reactions: { heart: [uid] } }),
  (uid) =>
    seedDoc(`recipe_comments/${uid}-react`, {
      recipeId: "recipe-1",
      authorId: `${uid}-author`,
      text: "ser gott ut!",
      createdAt: new Date(),
      sharedWithUserIds: [uid],
    })
);

// C3: recipe_comments likes create.
guestPair("C3", "recipe_comments likes create", (uid, db) =>
  db.doc(`recipe_comments/${uid}-liked/likes/${uid}`).set({
    userId: uid,
    likedAt: new Date(),
  })
);

// C4: cook_snaps create.
guestPair("C4", "cook_snaps create", (uid, db) =>
  createStamped(db, uid, "cook_snaps", `cook_snaps/${uid}-snap`, {
    recipeId: "recipe-1",
    userId: uid,
    userDisplayName: "Anna",
    photoUrl: "https://example.com/snap.jpg",
    createdAt: new Date(),
  })
);

// C5: activity_events create.
guestPair("C5", "activity_events create", (uid, db) =>
  createStamped(db, uid, "activity_events", `activity_events/${uid}-ev`, {
    actorId: uid,
    type: "cooked",
    recipeId: "recipe-1",
    createdAt: new Date(),
  })
);

// ====================================================================
// CONVERSATIONS, MESSAGES
// ====================================================================

// M1: conversations create (a direct conversation).
guestPair("M1", "conversations create", (uid, db) => {
  const convId = `direct_${uid}_${uid}-peer`;
  return createStamped(db, uid, "conversations", `conversations/${convId}`, {
    participantIds: [uid, `${uid}-peer`],
    createdAt: new Date(),
    metadata: { creatorId: uid },
  });
});

// M2: messages create, in a conversation that seats the sender.
guestPair(
  "M2",
  "messages create",
  (uid, db) =>
    db.doc(`messages/${uid}-msg`).set({
      senderId: uid,
      conversationId: `${uid}-conv`,
      content: "Hej!",
      sentAt: serverTimestamp(),
    }),
  (uid) =>
    seedDoc(`conversations/${uid}-conv`, {
      participantIds: [uid, `${uid}-peer`, `${uid}-peer2`],
      createdAt: new Date(),
    })
);

// ====================================================================
// SHARED SHOPPING LISTS AND RECEIVED SHARES
// ====================================================================

// L1: unified_shared_shopping_lists create.
guestPair("L1", "unified_shared_shopping_lists create", (uid, db) =>
  db.doc(`unified_shared_shopping_lists/${uid}-list`).set({
    ownerId: uid,
    memberPermissions: { [uid]: "admin" },
    items: [],
    createdAt: new Date(),
  })
);

// L2: user_shared_shopping_lists received_lists create.
guestPair("L2", "user_shared_shopping_lists received_lists create", (uid, db) =>
  createStamped(
    db,
    uid,
    "received_list",
    `user_shared_shopping_lists/${uid}-to/received_lists/${uid}-list`,
    { sharedByUserId: uid, listId: `${uid}-list`, sharedAt: new Date() }
  )
);

// L3: user_shared_menus received_menus create.
guestPair("L3", "user_shared_menus received_menus create", (uid, db) =>
  createStamped(
    db,
    uid,
    "received_menu",
    `user_shared_menus/${uid}-to/received_menus/${uid}-menu`,
    { sharedByUserId: uid, menuId: `${uid}-menu`, sharedAt: new Date() }
  )
);

// ====================================================================
// RECIPE_RATINGS, RECIPE_SUGGESTIONS
// ====================================================================

// R1: recipe_ratings create.
guestPair("R1", "recipe_ratings create", (uid, db) =>
  createStamped(db, uid, "recipe_ratings", `recipe_ratings/recipe-1_${uid}`, {
    recipeId: "recipe-1",
    userId: uid,
    rating: 5,
    createdAt: serverTimestamp(),
  })
);

// R2: recipe_ratings UPDATE. This limb carries no `!isGuest()` of its own, so
// the `!isGuest()` inside isAgeCompliant() is what this pair exercises.
guestPair(
  "R2",
  "recipe_ratings update",
  (uid, db) =>
    db.doc(`recipe_ratings/recipe-1_${uid}`).update({
      rating: 4,
      updatedAt: serverTimestamp(),
    }),
  (uid) =>
    seedDoc(`recipe_ratings/recipe-1_${uid}`, {
      recipeId: "recipe-1",
      userId: uid,
      rating: 3,
      createdAt: new Date(),
    })
);

// R3: recipe_suggestions create, on a recipe shared with the suggester.
guestPair(
  "R3",
  "recipe_suggestions create",
  (uid, db) => {
    const createdAt = new Date();
    return db.doc(`recipe_suggestions/${uid}-sug`).set({
      recipeId: "r1",
      ownerId: `${uid}-owner`,
      suggesterId: uid,
      suggestion: { title: "Mer vitlök" },
      status: "pending",
      createdAt,
      expiresAt: new Date(createdAt.getTime() + 7 * DAY_MS),
    });
  },
  (uid) =>
    seedDoc(`users/${uid}-owner/recipes/r1`, {
      socialData: { memberPermissions: { [uid]: "edit" } },
    })
);

// ====================================================================
// REPORTS, DEEP_LINKS
// ====================================================================

// X1: reports create.
guestPair("X1", "reports create", (uid, db) =>
  db.doc(`reports/${uid}-rep`).set({
    reporterId: uid,
    contentType: "recipe",
    contentId: "r1",
    contentOwnerId: `${uid}-owner`,
    reason: "spam",
    status: "new",
    createdAt: new Date(),
  })
);

// X2: deep_links create.
guestPair("X2", "deep_links create", (uid, db) =>
  db.doc(`deep_links/${uid}-link`).set({
    longUrl: "https://butlery.se/recipe/r1",
    createdAt: new Date(),
    createdBy: uid,
  })
);

// ====================================================================
// SHOPPING_LIST_TEMPLATES (a guest keeps private templates only)
// ====================================================================

function templateBody(
  ownerId: string,
  isPublic: boolean
): Record<string, unknown> {
  return {
    ownerId,
    name: "Veckohandling",
    items: [],
    isPublic,
    createdAt: new Date(),
  };
}

// T1: public create.
guestPair("T1", "shopping_list_templates public create", (uid, db) =>
  db.doc(`shopping_list_templates/${uid}-pub`).set(templateBody(uid, true))
);

// T2: guest private create is allowed.
test("T2 shopping_list_templates: a guest can create a private template", async () => {
  const uid = `t2-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid)
      .doc(`shopping_list_templates/${uid}-priv`)
      .set(templateBody(uid, false))
  );
});

// T3: making a private template public by update.
guestPair(
  "T3",
  "shopping_list_templates update to public",
  (uid, db) =>
    db.doc(`shopping_list_templates/${uid}-tpl`).update({ isPublic: true }),
  (uid) => seedDoc(`shopping_list_templates/${uid}-tpl`, templateBody(uid, false))
);

// T4: guest edit that keeps the template private is allowed.
test("T4 shopping_list_templates: a guest can rename a private template", async () => {
  const uid = `t4-guest-${RUN}`;
  await seedDoc(`shopping_list_templates/${uid}-tpl`, templateBody(uid, false));
  await assertSucceeds(
    guestDb(uid).doc(`shopping_list_templates/${uid}-tpl`).update({ name: "Fest" })
  );
});

// ====================================================================
// PERSONAL DATA a guest keeps
// ====================================================================

// D1: recipes.
test("D1 users/{uid}/recipes: a guest can create a recipe", async () => {
  const uid = `d1-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid)
      .doc(`users/${uid}/recipes/${uid}-r`)
      .set({ core: { title: "Pannkakor" } })
  );
});

// D2: personal shopping lists.
test("D2 users/{uid}/unified_shopping_lists: a guest can create a list", async () => {
  const uid = `d2-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid)
      .doc(`users/${uid}/unified_shopping_lists/${uid}-l`)
      .set({ name: "Handla", items: [] })
  );
});

// D3: pantry.
test("D3 users/{uid}/pantry: a guest can create a pantry row", async () => {
  const uid = `d3-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid)
      .doc(`users/${uid}/pantry/${uid}-p`)
      .set({ name: "mjölk", quantity: 1 })
  );
});

// D4: weekly_menu_plans.
test("D4 weekly_menu_plans: a guest can create their own week", async () => {
  const uid = `d4-guest-${RUN}`;
  await assertSucceeds(
    guestDb(uid)
      .doc(`weekly_menu_plans/${uid}_2026-W40`)
      .set({ userId: uid, entries: [], createdAt: new Date() })
  );
});

// ====================================================================
// GUEST_QUOTAS (server-only)
// ====================================================================

async function seedQuota(uid: string): Promise<void> {
  await seedDoc(`guest_quotas/${uid}`, { imports: 1, updatedAt: new Date() });
}

// Q1: the owner of the id, signed in normally, cannot read it.
test("Q1 guest_quotas: the id's own full account cannot read it", async () => {
  const uid = `q1-full-${RUN}`;
  await seedQuota(uid);
  await assertFails(fullDb(uid).doc(`guest_quotas/${uid}`).get());
});

// Q2: ... nor write it.
test("Q2 guest_quotas: the id's own full account cannot write it", async () => {
  const uid = `q2-full-${RUN}`;
  await assertFails(fullDb(uid).doc(`guest_quotas/${uid}`).set({ imports: 0 }));
});

// Q3: the guest whose quota it is cannot read it.
test("Q3 guest_quotas: the guest cannot read its own quota", async () => {
  const uid = `q3-guest-${RUN}`;
  await seedQuota(uid);
  await assertFails(guestDb(uid).doc(`guest_quotas/${uid}`).get());
});

// Q4: ... nor reset it.
test("Q4 guest_quotas: the guest cannot reset its own quota", async () => {
  const uid = `q4-guest-${RUN}`;
  await seedQuota(uid);
  await assertFails(guestDb(uid).doc(`guest_quotas/${uid}`).set({ imports: 0 }));
});

async function run(): Promise<void> {
  console.log("BUT-920: guest-mode rules tests\n");
  console.log("===============================\n");
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
