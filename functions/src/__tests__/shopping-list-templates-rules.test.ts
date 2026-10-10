/**
 * Firestore rules tests for `shopping_list_templates` (BUT-2355).
 *
 * The update limb checked only that the caller owned the stored template, so
 * the owner could rewrite `ownerId` to another uid and plant a public template
 * under someone else's account. These tests pin that the owner stays the
 * owner, and that the owner's ordinary edits and the read and delete limbs
 * are unchanged.
 *
 * Run with: npx ts-node src/__tests__/shopping-list-templates-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-shopping-list-templates";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const COLLECTION = "shopping_list_templates";

const OWNER = "uidOwner";
const VICTIM = "uidVictim";
const STRANGER = "uidStranger";

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

function template(
  ownerId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    ownerId,
    ownerDisplayName: "Ägare",
    name: "Veckohandling",
    items: [],
    isPublic: true,
    createdAt: new Date(),
    ...overrides,
  };
}

// Each test gets its own seeded document, so no test sees another's write.
async function seedTemplate(id: string, ownerId: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`${COLLECTION}/${id}`).set(template(ownerId));
  });
}

test("T1 the owner can edit their template's name", async () => {
  await seedTemplate("t1", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/t1`).update({ name: "Fest" }),
  );
});

test("T2 the owner can rewrite the template keeping ownerId", async () => {
  await seedTemplate("t2", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/t2`).set(template(OWNER, { name: "Ny" })),
  );
});

test("T3 the owner cannot move the template to another uid", async () => {
  await seedTemplate("t3", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t3`).update({ ownerId: VICTIM }));
});

test("T4 the owner cannot move it by rewriting the whole document", async () => {
  await seedTemplate("t4", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/t4`).set(template(VICTIM, { ownerDisplayName: "Offer" })),
  );
});

test("T5 the owner cannot drop ownerId", async () => {
  await seedTemplate("t5", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  const data = template(OWNER);
  delete data.ownerId;
  await assertFails(db.doc(`${COLLECTION}/t5`).set(data));
});

test("T6 another user cannot edit the template", async () => {
  await seedTemplate("t6", OWNER);
  const db = env.authenticatedContext(STRANGER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t6`).update({ name: "Kapad" }));
});

test("T7 creating a template under another uid is refused", async () => {
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t7-new`).set(template(VICTIM)));
});

test("T8 creating a template as yourself is allowed", async () => {
  const db = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/t8-new`).set(template(OWNER)));
});

test("T9 a public template is readable by another signed-in user", async () => {
  await seedTemplate("t9", OWNER);
  const db = env.authenticatedContext(STRANGER).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/t9`).get());
});

test("T10 the owner can delete their template", async () => {
  await seedTemplate("t10", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/t10`).delete());
});

async function run(): Promise<void> {
  console.log("shopping_list_templates rules tests\n");
  console.log("===================================\n");
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
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
