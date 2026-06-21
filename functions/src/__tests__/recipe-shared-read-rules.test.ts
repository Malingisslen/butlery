/**
 * Rules test: a recipe under /users/{ownerId}/recipes/{id} is readable by the
 * owner AND by any uid in socialData.memberPermissions (the shared-with map).
 * Non-members and strangers are denied. Writes stay owner-only.
 * Prerequisite: Firestore emulator (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/recipe-shared-read-rules.test.ts
 */
import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-recipe-shared-read-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const OWNER = "owner-uid";
const MEMBER = "member-uid";
const STRANGER = "stranger-uid";
const RECIPE = "recipe-1";
const DOC = `users/${OWNER}/recipes/${RECIPE}`;

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}
async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}
async function seedRecipe(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(DOC).set({
      core: { id: RECIPE, title: "Pannkakor", tagResult: { version: 1 } },
      socialData: { ownerId: OWNER, memberPermissions: { [MEMBER]: 2 } },
      type: "collaborative",
    });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void { tests.push({ name, fn }); }

test("owner can read own recipe", async () => {
  await seedRecipe();
  await assertSucceeds(env.authenticatedContext(OWNER).firestore().doc(DOC).get());
});
test("shared member can read the recipe", async () => {
  await seedRecipe();
  await assertSucceeds(env.authenticatedContext(MEMBER).firestore().doc(DOC).get());
});
test("stranger (not in memberPermissions) is denied read", async () => {
  await seedRecipe();
  await assertFails(env.authenticatedContext(STRANGER).firestore().doc(DOC).get());
});
test("shared member CANNOT write the recipe", async () => {
  await seedRecipe();
  await assertFails(
    env.authenticatedContext(MEMBER).firestore().doc(DOC).update({ "core.title": "hacked" })
  );
});
// SR5: unauthenticated request is always denied — isAuthenticated() guard
test("unauthenticated user cannot read any recipe", async () => {
  await seedRecipe();
  await assertFails(env.unauthenticatedContext().firestore().doc(DOC).get());
});
// SR6: recipe with no socialData field — member-lookup returns {}; stranger denied
async function seedRecipeNoSocialData(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${OWNER}/recipes/recipe-nosocial`).set({
      core: { id: "recipe-nosocial", title: "Grönsakssoppa", tagResult: { version: 1 } },
    });
  });
}
test("stranger denied on recipe with no socialData (empty-map default)", async () => {
  await seedRecipeNoSocialData();
  await assertFails(
    env.authenticatedContext(STRANGER).firestore().doc(`users/${OWNER}/recipes/recipe-nosocial`).get()
  );
});

(async () => {
  await setup();
  let failed = 0;
  for (const t of tests) {
    try { await t.fn(); console.log(`✓ ${t.name}`); }
    catch (e) { failed++; console.error(`✗ ${t.name}\n  ${e}`); }
  }
  await teardown();
  process.exit(failed === 0 ? 0 : 1);
})();
