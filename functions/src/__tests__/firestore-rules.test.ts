/**
 * BUT-448: Firestore rules tests for the `recipes` and `users` collection
 * groups — the two highest-blast-radius collections in the app.
 *
 * Recipes live at `/users/{userId}/recipes/{recipeId}` (user-scoped).
 * The user document itself is at `/users/{userId}` and the privacy-sensitive
 * preferences live at `/users/{userId}/settings/preferences`.
 *
 * Each test name states the behavior it proves. Failure => either the rules
 * regressed or the product contract changed; decide which before editing.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/firestore-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-recipes-users";
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

// Convenience: a tagResult shape that satisfies the validator. Keeping it
// minimal — coverage 0..1, no unknown fields, valid TriState map.
function validRecipeBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    core: {
      title: "Köttbullar",
      tagResult: {
        tags: [],
        allergenStatus: { gluten: "free" },
        dietaryStatus: { vegan: "contains" },
        coverage: 1.0,
        unknownIngredients: [],
        generatedAt: new Date(),
        generatorVersion: "test",
        isPartial: false,
        schemaVersion: 1,
      },
    },
    ...extra,
  };
}

// Per-run token: prevents emulator-persistence collisions when tests re-run
// against a live emulator that retains documents from previous runs.
// (See knowledge file: 2026-06-03 — EMULATOR PERSISTS DATA ACROSS npm run INVOCATIONS)
const RUN = Date.now().toString(36);

// ============================================================================
// RECIPES (10 assertions across 8 tests)
// ============================================================================

// R1: owner can create their own recipe with a valid tagResult.
test(
  "recipes: owner can create a recipe with valid tagResult",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r1`)
        .set(validRecipeBody())
    );
  }
);

// R2: non-owner cannot create a recipe under another user's tree.
test(
  "recipes: non-owner cannot create a recipe under another user",
  async () => {
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-stranger`)
        .set(validRecipeBody())
    );
  }
);

// R3: signed-out user cannot read another user's private recipe.
test(
  "recipes: unauthenticated user cannot read a private recipe",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-private`)
        .set(validRecipeBody());
    });
    const anonCtx = env.unauthenticatedContext();
    await assertFails(
      anonCtx.firestore().doc(`users/${OWNER_UID}/recipes/r-private`).get()
    );
  }
);

// R4: non-owner cannot read another user's recipe even when authenticated.
//     (Recipes are user-private; sharing flows through `shared_content`.)
test(
  "recipes: authenticated non-owner cannot read another user's recipe",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-secret`)
        .set(validRecipeBody());
    });
    const otherCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      otherCtx.firestore().doc(`users/${OWNER_UID}/recipes/r-secret`).get()
    );
  }
);

// R5: owner cannot write a recipe with a malformed tagResult (allergen-safety
//     critical — the rules layer is the last line of defence against
//     client-side tampering).
test(
  "recipes: owner cannot write a tagResult with invalid coverage",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-bad-coverage`)
        .set({
          core: {
            title: "Bad",
            tagResult: {
              tags: [],
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 5, // out of [0, 1]
              unknownIngredients: [],
              generatedAt: new Date(),
              generatorVersion: "test",
              schemaVersion: 1,
            },
          },
        })
    );
  }
);

// R6: cookCount can only move by +1 or stay equal (covers two assertions:
//     legal +1 succeeds, illegal +5 fails, on the same seeded doc).
test(
  "recipes: cookCount may bump by +1 but not by +5",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-cook`)
        .set({
          core: {
            title: "Cookable",
            cookCount: 3,
          },
        });
    });
    const ctx = env.authenticatedContext(OWNER_UID);
    // Legal: bump by 1
    await assertSucceeds(
      ctx.firestore().doc(`users/${OWNER_UID}/recipes/r-cook`).set({
        core: {
          title: "Cookable",
          cookCount: 4,
        },
      })
    );
    // Illegal: jump by 5
    await assertFails(
      ctx.firestore().doc(`users/${OWNER_UID}/recipes/r-cook`).set({
        core: {
          title: "Cookable",
          cookCount: 9,
        },
      })
    );
  }
);

// R7: admin moderation override — admin can read + delete a flagged recipe
//     even though they don't own it (moderation pipeline contract).
test(
  "recipes: admin can read and delete a flagged recipe (moderation override)",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-flagged`)
        .set(validRecipeBody());
    });
    const adminCtx = env.authenticatedContext(ADMIN_UID);
    await assertSucceeds(
      adminCtx.firestore().doc(`users/${OWNER_UID}/recipes/r-flagged`).get()
    );
    await assertSucceeds(
      adminCtx.firestore().doc(`users/${OWNER_UID}/recipes/r-flagged`).delete()
    );
  }
);

// R8: non-owner non-admin cannot delete another user's recipe.
test(
  "recipes: non-owner non-admin cannot delete another user's recipe",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-doomed`)
        .set(validRecipeBody());
    });
    const otherCtx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      otherCtx.firestore().doc(`users/${OWNER_UID}/recipes/r-doomed`).delete()
    );
  }
);

// R9: BUT-1249 — owner can CREATE a recipe doc that carries a root-level
//     `schemaVersion: 1` field. BUT-648 added schemaVersion to models; the
//     recipes rule has NO root-level hasOnly() validator, so the field passes
//     through isValidTagResult (which only gates core.tagResult, not the doc
//     root). This test guards against a future top-level validator being added
//     that would silently reject the field and break all recipe creates.
test(
  "recipes: owner can create a recipe with root-level schemaVersion:1 (BUT-1249)",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-sv-create-${RUN}`)
        .set(validRecipeBody({ schemaVersion: 1 }))
    );
  }
);

// R10: BUT-1249 — owner can UPDATE (overwrite) a recipe doc and keep the
//      root-level `schemaVersion: 1` field. Exercises the update rule branch
//      separately from create (the two branches are distinct in the rules:
//      `allow create` and `allow update` are written independently).
test(
  "recipes: owner can update a recipe keeping root-level schemaVersion:1 (BUT-1249)",
  async () => {
    // Seed the doc via admin SDK so the update rule is exercised (not create).
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-sv-update-${RUN}`)
        .set(validRecipeBody({ schemaVersion: 1 }));
    });
    const ctx = env.authenticatedContext(OWNER_UID);
    // Update: change a title field inside core while keeping schemaVersion at root.
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/recipes/r-sv-update-${RUN}`)
        .set(validRecipeBody({ schemaVersion: 1, updatedAt: new Date() }))
    );
  }
);

// ============================================================================
// USERS (10+ assertions across 7 tests)
// ============================================================================

// U1: owner can write their own root user doc.
test(
  "users: owner can write their own /users/{uid} doc",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}`)
        .set({ displayName: "Anna" })
    );
  }
);

// U2: non-owner cannot write another user's root doc.
test(
  "users: non-owner cannot write another user's root doc",
  async () => {
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}`)
        .set({ displayName: "Hijack" })
    );
  }
);

// U3: signed-out user cannot read another user's root doc.
test(
  "users: unauthenticated user cannot read /users/{uid}",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc(`users/${OWNER_UID}`).set({
        displayName: "Anna",
      });
    });
    const anon = env.unauthenticatedContext();
    await assertFails(anon.firestore().doc(`users/${OWNER_UID}`).get());
  }
);

// U4: non-owner cannot read another user's root doc.
test(
  "users: authenticated non-owner cannot read another user's root doc",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin.firestore().doc(`users/${OWNER_UID}`).set({
        displayName: "Anna",
      });
    });
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(ctx.firestore().doc(`users/${OWNER_UID}`).get());
  }
);

// U5: owner can write their settings/preferences with a valid birthYear.
//     (Smoke check that the settings subcollection is wired to the owner.)
test(
  "users: owner can create settings/preferences with valid birthYear",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    const validYear = new Date().getFullYear() - 25;
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          birthYear: validYear,
        })
    );
  }
);

// U6: non-owner cannot read or write another user's settings/preferences,
//     including birthYear (private setting under GDPR Art 8).
test(
  "users: non-owner cannot read or write another user's settings/preferences",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          birthYear: new Date().getFullYear() - 30,
        });
    });
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/settings/preferences`)
        .get()
    );
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/settings/preferences`)
        .set({ notificationsEnabled: false }, { merge: true })
    );
  }
);

// U7: owner can read+write a non-recipe subcollection (pantry) — guards
//     against an accidental scope tightening that breaks owner access.
test(
  "users: owner can read and write their own pantry subcollection",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/pantry/item-1`)
        .set({ name: "salt", quantity: 1 })
    );
    await assertSucceeds(
      ctx.firestore().doc(`users/${OWNER_UID}/pantry/item-1`).get()
    );
  }
);

// ============================================================================
// ONBOARDING PROGRESS (BUT-675) — 5 assertions across 5 tests
// Resume-onboarding state at /users/{uid}/onboarding/{progressDoc}.
// Owner-only read/write. No schema validator on the rule, so tests
// focus purely on identity scoping.
// ============================================================================

// O1: owner can read their own onboarding progress.
test(
  "onboarding: owner can read their own progress doc",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set({
          step: "allergens",
          completedAt: new Date(),
          completed: false,
        });
    });
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx.firestore().doc(`users/${OWNER_UID}/onboarding/progress`).get()
    );
  }
);

// O2: owner can write (create + update) their own onboarding progress.
//     Covers both branches of `write` since there's no separate
//     create/update split in the rule.
test(
  "onboarding: owner can create and update their own progress doc",
  async () => {
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set({
          step: "allergens",
          completedAt: new Date(),
          completed: false,
        })
    );
    // Update path — same rule branch, exercised separately so a future
    // tightening that splits write into create-only is caught.
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set(
          {
            step: "first_recipe",
            completed: true,
          },
          { merge: true }
        )
    );
  }
);

// O3: signed-out user cannot read another user's onboarding progress.
//     Privacy-sensitive: leaks which onboarding stage a user reached.
test(
  "onboarding: signed-out user cannot read someone else's progress",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set({
          step: "allergens",
          completedAt: new Date(),
          completed: false,
        });
    });
    const ctx = env.unauthenticatedContext();
    await assertFails(
      ctx.firestore().doc(`users/${OWNER_UID}/onboarding/progress`).get()
    );
  }
);

// O4: signed-in stranger cannot read another user's onboarding progress.
//     Catches a wildcard `isAuthenticated()` regression that drops the
//     `request.auth.uid == userId` clause.
test(
  "onboarding: signed-in stranger cannot read another user's progress",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set({
          step: "allergens",
          completedAt: new Date(),
          completed: false,
        });
    });
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx.firestore().doc(`users/${OWNER_UID}/onboarding/progress`).get()
    );
  }
);

// O5: signed-in stranger cannot write another user's onboarding progress.
//     Forging completion state on someone else's account would let a
//     malicious actor short-circuit allergen capture for the victim.
test(
  "onboarding: signed-in stranger cannot write another user's progress",
  async () => {
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${OWNER_UID}/onboarding/progress`)
        .set({
          step: "first_recipe",
          completedAt: new Date(),
          completed: true,
        })
    );
  }
);

async function run(): Promise<void> {
  console.log("BUT-448: recipes + users rules tests\n");
  console.log("====================================\n");
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
