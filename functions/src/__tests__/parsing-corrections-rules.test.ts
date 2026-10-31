/**
 * Firestore rules tests for the parsing_corrections collection.
 *
 * Own-data, append-only log of the corrections a user makes to an imported
 * recipe. Contract:
 *
 *   create — authenticated, userId == auth.uid, fields ['id','userId','source',
 *            'timestamp','expireAt'] present, and expireAt a timestamp ahead of
 *            now and at most 372 days ahead (the TTL policy deletes on it).
 *   read   — owner and admins.
 *   update — never.
 *   delete — owner only.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/parsing-corrections-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-parsing-corrections-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "owner-uid";
const STRANGER = "stranger-uid";
const ADMIN_UID = "admin-uid";

const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}

function validBody(
  userId: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    id: "c-1",
    userId,
    recipeId: "recipe-1",
    source: "url",
    timestamp: new Date(),
    expireAt: daysFromNow(365),
    ingredientCorrections: [],
    instructionCorrections: [],
    ...extra,
  };
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ role: "admin" });
  });
}
async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

async function seed(id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`parsing_corrections/${id}`).set(validBody(OWNER, { id }));
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

const col = (id: string) => `parsing_corrections/${id}-${RUN}`;

test("parsing_corrections: owner CAN create their own correction", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(col("own")).set(validBody(OWNER)));
});

test("parsing_corrections: user CANNOT create a correction for another user", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(col("cross")).set(validBody(STRANGER)));
});

test("parsing_corrections: unauthenticated user CANNOT create", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(col("anon")).set(validBody(OWNER)));
});

test("parsing_corrections: owner CANNOT create without a required field (source)", async () => {
  const body = validBody(OWNER);
  delete body.source;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(col("nosrc")).set(body));
});

test("parsing_corrections: owner CANNOT create without expireAt", async () => {
  const body = validBody(OWNER);
  delete body.expireAt;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(col("noexp")).set(body));
});

test("parsing_corrections: owner CANNOT create with an expireAt that is not a timestamp", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(col("strexp")).set(validBody(OWNER, { expireAt: "2027-01-01" }))
  );
});

test("parsing_corrections: owner CANNOT create with an expireAt already past", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(col("pastexp")).set(validBody(OWNER, { expireAt: daysFromNow(-1) }))
  );
});

test("parsing_corrections: owner CANNOT create with an expireAt beyond the ceiling", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(col("farexp")).set(validBody(OWNER, { expireAt: daysFromNow(400) }))
  );
});

test("parsing_corrections: owner CAN create with an expireAt a week past a year (clock skew room)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx.firestore().doc(col("skewexp")).set(validBody(OWNER, { expireAt: daysFromNow(368) }))
  );
});

test("parsing_corrections: owner CAN read their own correction", async () => {
  await seed(`read-own-${RUN}`);
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`parsing_corrections/read-own-${RUN}`).get());
});

test("parsing_corrections: admin CAN read another user's correction", async () => {
  await seed(`read-admin-${RUN}`);
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`parsing_corrections/read-admin-${RUN}`).get());
});

test("parsing_corrections: a different non-admin user CANNOT read it", async () => {
  await seed(`read-stranger-${RUN}`);
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`parsing_corrections/read-stranger-${RUN}`).get());
});

test("parsing_corrections: owner CANNOT update their correction (immutable)", async () => {
  await seed(`upd-${RUN}`);
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(`parsing_corrections/upd-${RUN}`).update({ domain: "x.se" }));
});

test("parsing_corrections: owner CAN delete their own correction", async () => {
  await seed(`del-own-${RUN}`);
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`parsing_corrections/del-own-${RUN}`).delete());
});

test("parsing_corrections: a different user CANNOT delete it", async () => {
  await seed(`del-stranger-${RUN}`);
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`parsing_corrections/del-stranger-${RUN}`).delete());
});

async function run(): Promise<void> {
  console.log("parsing_corrections rules tests\n");
  console.log("=============================\n");
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
