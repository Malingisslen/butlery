/**
 * Firestore rules tests for `menu_templates`.
 *
 * No rule opens this collection, so the terminal `match /{document=**}`
 * decides.
 * These tests pin that every client operation is refused, including the
 * owner's own and a document marked public.
 *
 * Run with: npx ts-node src/__tests__/menu-templates-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-menu-templates";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const COLLECTION = "menu_templates";

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
    templateName: "Veckomeny",
    menuSnapshot: { days: [] },
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

test("T1 creating a template as yourself is refused", async () => {
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t1-new`).set(template(OWNER)));
});

test("T2 the owner cannot read their own template", async () => {
  await seedTemplate("t2", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t2`).get());
});

test("T3 a public template is not readable by another signed-in user", async () => {
  await seedTemplate("t3", OWNER);
  const db = env.authenticatedContext(STRANGER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t3`).get());
});

test("T4 the owner cannot edit their template", async () => {
  await seedTemplate("t4", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/t4`).update({ templateName: "Fest" }),
  );
});

test("T5 the owner cannot move the template to another uid", async () => {
  await seedTemplate("t5", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t5`).update({ ownerId: VICTIM }));
});

test("T6 the owner cannot delete their template", async () => {
  await seedTemplate("t6", OWNER);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(`${COLLECTION}/t6`).delete());
});

test("T7 listing the collection is refused", async () => {
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(
    db.collection(COLLECTION).where("ownerId", "==", OWNER).get(),
  );
});

async function run(): Promise<void> {
  console.log("menu_templates rules tests\n");
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
