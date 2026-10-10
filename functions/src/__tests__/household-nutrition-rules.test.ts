/**
 * Firestore rules tests for a household's nutrition food choices (BUT-643).
 *
 * `households/{hid}.nutritionFoodChoices` maps an ingredient key to a
 * Livsmedelsverket food id. Each write names the one key it changes in
 * `nutritionChoiceKey`. An admin or edit member may write; a view member and a
 * stranger may not.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:household-nutrition  (from functions/)
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import firebase from "firebase/compat/app";

const PROJECT_ID = "butlery-rules-household-nutrition";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const ADMIN_MEMBER = "hn-admin-uid";
const EDITOR = "hn-editor-uid";
const VIEWER = "hn-viewer-uid";
const STRANGER = "hn-stranger-uid";
const HOUSEHOLD_ID = "hn-household";

let env: RulesTestEnvironment;

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

const serverTs = () => firebase.firestore.FieldValue.serverTimestamp();
const choice = (key: string) =>
  new firebase.firestore.FieldPath("nutritionFoodChoices", key);

function householdBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    name: "Familjen Berg",
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

// Every test starts from the same stored household with one existing choice.
async function reseed(extra: Record<string, unknown> = {}): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`households/${HOUSEHOLD_ID}`).set(
      householdBody({
        nutritionFoodChoices: { koriander: 123 },
        nutritionChoiceKey: "koriander",
        ...extra,
      })
    );
  });
}

function householdAs(uid: string) {
  return env.authenticatedContext(uid).firestore()
    .doc(`households/${HOUSEHOLD_ID}`);
}

test("edit member sets a new choice", async () => {
  await reseed();
  await assertSucceeds(householdAs(EDITOR).update(
    choice("färsk_basilika"), 456,
    "nutritionChoiceKey", "färsk_basilika",
    "updatedAt", serverTs(),
  ));
});

test("admin member changes an existing choice", async () => {
  await reseed();
  await assertSucceeds(householdAs(ADMIN_MEMBER).update(
    choice("koriander"), 789,
    "nutritionChoiceKey", "koriander",
    "updatedAt", serverTs(),
  ));
});

test("edit member clears a choice", async () => {
  await reseed();
  await assertSucceeds(householdAs(EDITOR).update(
    choice("koriander"), firebase.firestore.FieldValue.delete(),
    "nutritionChoiceKey", "koriander",
    "updatedAt", serverTs(),
  ));
});

test("first choice on a household that has none", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`households/${HOUSEHOLD_ID}`)
      .set(householdBody());
  });
  await assertSucceeds(householdAs(EDITOR).update(
    choice("koriander"), 123,
    "nutritionChoiceKey", "koriander",
    "updatedAt", serverTs(),
  ));
});

test("view member cannot write a choice", async () => {
  await reseed();
  await assertFails(householdAs(VIEWER).update(
    choice("dill"), 456,
    "nutritionChoiceKey", "dill",
    "updatedAt", serverTs(),
  ));
});

test("stranger cannot read or write", async () => {
  await reseed();
  await assertFails(householdAs(STRANGER).get());
  await assertFails(householdAs(STRANGER).update(
    choice("dill"), 456,
    "nutritionChoiceKey", "dill",
    "updatedAt", serverTs(),
  ));
});

test("a choice cannot ride along with another household field", async () => {
  for (const [field, value] of [
    ["name", "Nytt namn"],
    ["memberUserIds", [EDITOR]],
    ["memberPermissions", { [EDITOR]: "admin" }],
    ["members", []],
    ["createdBy", EDITOR],
    ["createdAt", new Date()],
    ["sourceGroupId", "g1"],
    ["sourceGroupOwnerId", EDITOR],
  ] as const) {
    await reseed();
    await assertFails(householdAs(EDITOR).update(
      choice("dill"), 456,
      "nutritionChoiceKey", "dill",
      "updatedAt", serverTs(),
      field, value,
    ));
  }
});

test("the written key must be the named key", async () => {
  await reseed();
  await assertFails(householdAs(EDITOR).update(
    choice("dill"), 456,
    "nutritionChoiceKey", "persilja",
    "updatedAt", serverTs(),
  ));
});

test("two keys in one write are refused", async () => {
  await reseed();
  await assertFails(householdAs(EDITOR).update(
    choice("dill"), 456,
    choice("persilja"), 457,
    "nutritionChoiceKey", "dill",
    "updatedAt", serverTs(),
  ));
});

test("replacing the whole map is refused", async () => {
  // Two stored choices: emptying the map changes both keys, while clearing
  // ONE key (the allowed shape) changes only the named one.
  await reseed({ nutritionFoodChoices: { koriander: 123, dill: 124 } });
  await assertFails(householdAs(EDITOR).update({
    nutritionFoodChoices: {},
    nutritionChoiceKey: "koriander",
    updatedAt: serverTs(),
  }));
});

test("a key outside the allowed shape is refused", async () => {
  for (const key of ["Koriander", "johan svensson", "a.b", "x".repeat(61)]) {
    await reseed();
    await assertFails(householdAs(EDITOR).update(
      choice(key), 456,
      "nutritionChoiceKey", key,
      "updatedAt", serverTs(),
    ));
  }
});

test("a key of exactly 60 characters is allowed", async () => {
  // NutritionKey.storageKey cuts long ingredient names to 60.
  const key = "x".repeat(60);
  await reseed();
  await assertSucceeds(householdAs(EDITOR).update(
    choice(key), 456,
    "nutritionChoiceKey", key,
    "updatedAt", serverTs(),
  ));
});

test("a value that is not a positive int is refused", async () => {
  for (const value of ["456", 4.5, 0, -1, { id: 1 }]) {
    await reseed();
    await assertFails(householdAs(EDITOR).update(
      choice("dill"), value,
      "nutritionChoiceKey", "dill",
      "updatedAt", serverTs(),
    ));
  }
});

test("updatedAt must be the server time", async () => {
  await reseed();
  await assertFails(householdAs(EDITOR).update(
    choice("dill"), 456,
    "nutritionChoiceKey", "dill",
    "updatedAt", new Date(2020, 0, 1),
  ));
});

test("the map is capped at 300 choices", async () => {
  const full: Record<string, number> = {};
  for (let i = 0; i < 300; i++) full[`k${i}`] = i + 1;
  await reseed({ nutritionFoodChoices: full, nutritionChoiceKey: "k0" });
  await assertFails(householdAs(EDITOR).update(
    choice("dill"), 456,
    "nutritionChoiceKey", "dill",
    "updatedAt", serverTs(),
  ));
  await assertSucceeds(householdAs(EDITOR).update(
    choice("k1"), 999,
    "nutritionChoiceKey", "k1",
    "updatedAt", serverTs(),
  ));
});

test("admin rename still works and leaves the choices alone", async () => {
  await reseed();
  await assertSucceeds(householdAs(ADMIN_MEMBER).update({
    name: "Familjen Berg-Ek",
    updatedAt: new Date(),
  }));
});

test("admin cannot replace the map through the rename arm", async () => {
  await reseed();
  await assertFails(householdAs(ADMIN_MEMBER).update({
    name: "Familjen Berg-Ek",
    nutritionFoodChoices: { "johan svensson": "fritext" },
    updatedAt: serverTs(),
  }));
});

test("a household cannot be created with choices", async () => {
  const ctx = env.authenticatedContext(ADMIN_MEMBER).firestore();
  const solo = {
    name: "Vårt hushåll",
    members: [{ userId: ADMIN_MEMBER, permission: "admin", addedAt: new Date() }],
    memberUserIds: [ADMIN_MEMBER],
    memberPermissions: { [ADMIN_MEMBER]: "admin" },
    createdBy: ADMIN_MEMBER,
    createdAt: new Date(),
    updatedAt: new Date(),
    schemaVersion: 1,
  };
  await assertSucceeds(
    ctx.doc(`households/hn-new-ok-${Date.now()}`).set(solo)
  );
  // One field per write: either refusal alone would hide the other's.
  await assertFails(ctx.doc(`households/hn-new-map-${Date.now()}`).set({
    ...solo,
    nutritionFoodChoices: { dill: 1 },
  }));
  await assertFails(ctx.doc(`households/hn-new-key-${Date.now()}`).set({
    ...solo,
    nutritionChoiceKey: "dill",
  }));
});

async function run(): Promise<void> {
  console.log("household nutrition choices rules tests\n");
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
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
  await env.cleanup();
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
