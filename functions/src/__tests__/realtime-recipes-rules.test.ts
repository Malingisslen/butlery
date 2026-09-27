/**
 * Firestore rules tests for Q6-08 = A (produktbeslut 2026-09-27):
 * `realtime_recipes/{recipeId}` and its `presence` subcollection.
 *
 * produktregler.md:241: a member cannot edit a recipe someone else owns; the
 * change is kept as a suggestion (recipe_suggestions, pinned by
 * recipe-suggestions-rules.test.ts). Rules contract under test:
 *   - Only the owner updates the realtime recipe document: its content
 *     (`recipe`) and who takes part (`participants`, `participantIds`).
 *     A participant, editor or viewer, does neither.
 *   - The owner still cannot change `ownerId` or `createdAt`.
 *   - Participants keep what they legitimately do: read the document and
 *     write their own presence row. Nobody writes someone else's presence.
 *   - A stranger reads and writes nothing.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rule changed or the design intent changed — decide which.
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/realtime-recipes-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-realtime-recipes";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "rt-recipe-owner";
const EDITOR = "rt-recipe-editor";
const VIEWER = "rt-recipe-viewer";
const STRANGER = "rt-recipe-stranger";
const RECIPE = "rt-recipe-1";
const DOC = `realtime_recipes/${RECIPE}`;

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

/** The shape RealtimeRecipe.toFirestore() writes, reseeded per test. */
async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(DOC).set({
      type: "recipe",
      ownerId: OWNER,
      ownerDisplayName: "Olle",
      participants: { [OWNER]: "owner", [EDITOR]: "editor", [VIEWER]: "viewer" },
      participantIds: [OWNER, EDITOR, VIEWER],
      createdAt: new Date("2026-09-01T10:00:00Z"),
      lastEditedAt: new Date("2026-09-01T10:00:00Z"),
      lastEditedBy: OWNER,
      lastEditedByDisplayName: "Olle",
      editCount: 1,
      isActive: true,
      metadata: {},
      recipe: { title: "Pannkakor", ingredients: ["3 dl mjöl"], instructions: ["Vispa"] },
      activeEditors: [],
    });
  });
}

const db = (uid: string) => env.authenticatedContext(uid).firestore();

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

test("the owner updates the recipe content", async () => {
  await seed();
  await assertSucceeds(
    db(OWNER).doc(DOC).update({ "recipe.title": "Olles pannkakor", editCount: 2 }),
  );
});

test("an editor participant cannot write the owner's recipe content", async () => {
  await seed();
  await assertFails(db(EDITOR).doc(DOC).update({ "recipe.title": "Mias pannkakor" }));
});

test("an editor participant cannot overwrite the whole document either", async () => {
  await seed();
  await assertFails(
    db(EDITOR).doc(DOC).set(
      {
        recipe: { title: "Mias", ingredients: [], instructions: [] },
        lastEditedBy: EDITOR,
      },
      { merge: true },
    ),
  );
});

test("a viewer participant cannot write the recipe content", async () => {
  await seed();
  await assertFails(db(VIEWER).doc(DOC).update({ "recipe.instructions": ["Stek"] }));
});

test("a participant cannot change who takes part", async () => {
  await seed();
  await assertFails(
    db(EDITOR).doc(DOC).update({
      [`participants.${STRANGER}`]: "editor",
      participantIds: [OWNER, EDITOR, VIEWER, STRANGER],
    }),
  );
});

test("a participant cannot touch bookkeeping fields alone either", async () => {
  await seed();
  await assertFails(db(EDITOR).doc(DOC).update({ lastEditedBy: EDITOR }));
});

test("the owner still cannot change ownerId", async () => {
  await seed();
  await assertFails(db(OWNER).doc(DOC).update({ ownerId: EDITOR }));
});

test("a stranger cannot write the recipe", async () => {
  await seed();
  await assertFails(db(STRANGER).doc(DOC).update({ "recipe.title": "x" }));
});

test("a participant still reads the recipe", async () => {
  await seed();
  await assertSucceeds(db(EDITOR).doc(DOC).get());
  await assertSucceeds(db(VIEWER).doc(DOC).get());
});

test("a stranger does not read the recipe", async () => {
  await seed();
  await assertFails(db(STRANGER).doc(DOC).get());
});

test("a participant still writes their own presence", async () => {
  await seed();
  await assertSucceeds(
    db(EDITOR).doc(`${DOC}/presence/${EDITOR}`).set({
      userId: EDITOR,
      displayName: "Mia",
      lastSeen: Date.now(),
      isActive: true,
    }),
  );
});

test("a participant cannot write someone else's presence", async () => {
  await seed();
  await assertFails(
    db(EDITOR).doc(`${DOC}/presence/${VIEWER}`).set({ userId: VIEWER, isActive: true }),
  );
});

(async () => {
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`✓ ${t.name}`);
    } catch (e) {
      failed++;
      console.error(`✗ ${t.name}\n  ${e}`);
    }
  }
  await teardown();
  console.log(`\n${tests.length - failed}/${tests.length} passed`);
  process.exit(failed === 0 ? 0 : 1);
})();
