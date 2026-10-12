/**
 * Firestore rules tests for a household's nutrition food choices (BUT-643)
 * and its own nutrition amounts (the amount tests further down).
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

// ---- The household's own amounts: `nutritionAmountChoices` ----------------

const amount = (key: string) =>
  new firebase.firestore.FieldPath("nutritionAmountChoices", key);

const UUID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
const FIRESTORE_ID = "AbCdEfGhIjKlMnOpQrSt";

async function writeAmount(
  uid: string,
  key: string,
  value: unknown,
  extra: unknown[] = [],
  named: string = key,
): Promise<unknown> {
  return householdAs(uid).update(
    amount(key), value,
    "nutritionAmountKey", named,
    "updatedAt", serverTs(),
    ...extra,
  );
}

test("edit member sets an amount for every recipe", async () => {
  await reseed();
  await assertSucceeds(
    writeAmount(EDITOR, "kycklingfile", { a: 600, u: "g" })
  );
});

test("admin member sets a decimal amount", async () => {
  await reseed();
  await assertSucceeds(
    writeAmount(ADMIN_MEMBER, "salt", { a: 1.5, u: "tsk" })
  );
});

test("an amount for one recipe works for a UUID and a Firestore id", async () => {
  for (const id of [UUID, FIRESTORE_ID]) {
    await reseed();
    await assertSucceeds(
      writeAmount(EDITOR, `r_${id}_kycklingfile`, { a: 450, u: "g" })
    );
  }
});

test("first amount on a household that has none", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(`households/${HOUSEHOLD_ID}`)
      .set(householdBody());
  });
  await assertSucceeds(writeAmount(EDITOR, "salt", { a: 1, u: "tsk" }));
});

test("an amount can be removed", async () => {
  await reseed({
    nutritionAmountChoices: { salt: { a: 1, u: "tsk" } },
    nutritionAmountKey: "salt",
  });
  await assertSucceeds(
    writeAmount(EDITOR, "salt", firebase.firestore.FieldValue.delete())
  );
});

test("view member and stranger cannot write an amount", async () => {
  await reseed();
  await assertFails(writeAmount(VIEWER, "salt", { a: 1, u: "tsk" }));
  await assertFails(writeAmount(STRANGER, "salt", { a: 1, u: "tsk" }));
});

test("an amount cannot ride along with another household field", async () => {
  for (const [field, value] of [
    ["name", "Nytt namn"],
    ["memberUserIds", [EDITOR]],
    ["memberPermissions", { [EDITOR]: "admin" }],
    ["sourceGroupId", "g1"],
    ["sourceGroupOwnerId", "u9"],
    ["createdBy", EDITOR],
    ["createdAt", new Date(0)],
    ["members", []],
  ] as const) {
    await reseed();
    await assertFails(
      writeAmount(EDITOR, "salt", { a: 1, u: "tsk" }, [field, value])
    );
  }
  // An admin may rename in the same write, as before; membership and the
  // group link stay out of reach.
  for (const [field, value] of [
    ["memberUserIds", [EDITOR]],
    ["memberPermissions", { [EDITOR]: "admin" }],
    ["sourceGroupId", "g1"],
  ] as const) {
    await reseed();
    await assertFails(
      writeAmount(ADMIN_MEMBER, "salt", { a: 1, u: "tsk" }, [field, value])
    );
  }
});

test("an admin may rename the household in the same write as an amount", async () => {
  await reseed();
  await assertSucceeds(
    writeAmount(ADMIN_MEMBER, "salt", { a: 1, u: "tsk" }, ["name", "Nytt namn"])
  );
});

test("an amount and a food choice cannot be written together by an edit member", async () => {
  await reseed();
  await assertFails(writeAmount(
    EDITOR, "salt", { a: 1, u: "tsk" },
    [choice("dill"), 456, "nutritionChoiceKey", "dill"],
  ));
});

test("the written amount key must be the named key", async () => {
  await reseed();
  await assertFails(
    writeAmount(EDITOR, "salt", { a: 1, u: "tsk" }, [], "dill")
  );
});

test("two amount keys in one write are refused", async () => {
  await reseed();
  await assertFails(householdAs(EDITOR).update(
    amount("salt"), { a: 1, u: "tsk" },
    amount("dill"), { a: 1, u: "msk" },
    "nutritionAmountKey", "salt",
    "updatedAt", serverTs(),
  ));
});

test("replacing the whole amount map is refused, for editor and admin", async () => {
  for (const uid of [EDITOR, ADMIN_MEMBER]) {
    await reseed({
      nutritionAmountChoices: { dill: { a: 1, u: "msk" } },
      nutritionAmountKey: "dill",
    });
    await assertFails(householdAs(uid).update({
      nutritionAmountChoices: { salt: { a: 1, u: "tsk" } },
      nutritionAmountKey: "salt",
      updatedAt: serverTs(),
    }));
  }
});

test("admin cannot write a malformed map through the rename arm", async () => {
  await reseed();
  await assertFails(householdAs(ADMIN_MEMBER).update({
    name: "Familjen Berg-Ek",
    nutritionAmountChoices: { "johan svensson": "fritext" },
    updatedAt: serverTs(),
  }));
});

test("amount keys: the longest fit is allowed, one over is refused", async () => {
  const ok60 = "a".repeat(60);
  const okUuid = `r_${UUID}_${"a".repeat(60)}`;
  const okLongestId = `r_${"X".repeat(40)}_${"a".repeat(60)}`;
  const bad61 = "a".repeat(61);
  const badId41 = `r_${"X".repeat(41)}_salt`;
  const badKey61 = `r_${UUID}_${"a".repeat(61)}`;
  for (const key of [ok60, okUuid, okLongestId]) {
    await reseed();
    await assertSucceeds(writeAmount(EDITOR, key, { a: 1, u: "g" }));
  }
  for (const key of [bad61, badId41, badKey61, "Salt", "salt-och"]) {
    await reseed();
    await assertFails(writeAmount(EDITOR, key, { a: 1, u: "g" }));
  }
});

test("an upper-case recipe id fits only the recipe shape", async () => {
  await reseed();
  await assertFails(
    writeAmount(EDITOR, `R_${FIRESTORE_ID}_salt`, { a: 1, u: "g" })
  );
  await assertFails(writeAmount(EDITOR, "kycklingFile", { a: 1, u: "g" }));
  // Upper case is allowed in the recipe id only, never in the ingredient part.
  await assertFails(
    writeAmount(EDITOR, `r_${UUID}_Salt`, { a: 1, u: "g" })
  );
  await assertFails(
    writeAmount(EDITOR, `r_${FIRESTORE_ID}_Salt`, { a: 1, u: "g" })
  );
});

test("an amount value must be exactly {a, u}", async () => {
  for (const value of [
    { a: 1 },
    { u: "g" },
    { a: 1, u: "g", note: "hej" },
    "600 g",
    600,
    null,
  ]) {
    await reseed();
    await assertFails(writeAmount(EDITOR, "salt", value));
  }
});

test("an amount must be a number above 0 and at most 100000", async () => {
  for (const a of [0, -5, 100001, "5", true]) {
    await reseed();
    await assertFails(writeAmount(EDITOR, "salt", { a, u: "g" }));
  }
  await reseed();
  await assertSucceeds(writeAmount(EDITOR, "salt", { a: 100000, u: "g" }));
});

test("only listed units are accepted", async () => {
  for (const u of ["g", "kg", "ml", "dl", "l", "msk", "tsk", "krm", "st"]) {
    await reseed();
    await assertSucceeds(writeAmount(EDITOR, "salt", { a: 1, u }));
  }
  for (const u of ["nypa", "pkt", "G", "", "hela receptet", 5]) {
    await reseed();
    await assertFails(writeAmount(EDITOR, "salt", { a: 1, u }));
  }
});

test("amount updatedAt must be the server time", async () => {
  await reseed();
  await assertFails(householdAs(EDITOR).update(
    amount("salt"), { a: 1, u: "tsk" },
    "nutritionAmountKey", "salt",
    "updatedAt", new Date(),
  ));
});

test("the amount map is capped at 300", async () => {
  const full: Record<string, unknown> = {};
  for (let i = 0; i < 300; i++) full[`k${i}`] = { a: 1, u: "g" };
  await reseed({ nutritionAmountChoices: full, nutritionAmountKey: "k0" });
  await assertFails(writeAmount(EDITOR, "salt", { a: 1, u: "tsk" }));
  await assertSucceeds(writeAmount(EDITOR, "k1", { a: 2, u: "g" }));
  await assertSucceeds(
    writeAmount(EDITOR, "k2", firebase.firestore.FieldValue.delete())
  );
});

test("a household cannot be created with amounts", async () => {
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
  await assertFails(ctx.doc(`households/hn-new-amt-${Date.now()}`).set({
    ...solo,
    nutritionAmountChoices: { salt: { a: 1, u: "tsk" } },
  }));
  await assertFails(ctx.doc(`households/hn-new-amtkey-${Date.now()}`).set({
    ...solo,
    nutritionAmountKey: "salt",
  }));
});

async function run(): Promise<void> {
  console.log("household nutrition choices and amounts rules tests\n");
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
