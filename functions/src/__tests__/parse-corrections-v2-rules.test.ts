/**
 * BUT-595: Firestore rules tests for `parse_corrections_v2`.
 *
 * Contract: the collection is server-write-only. Clients (signed-in or not)
 * cannot read, create, update, or delete documents under any circumstances.
 * Only the admin SDK (used inside the `logParseCorrection` callable) can
 * write to it.
 *
 * Failure of any assertion here means a client could either bypass the
 * server-side PII scrubber or exfiltrate other users' correction data.
 *
 * Run with: npx ts-node src/__tests__/parse-corrections-v2-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-parse-corrections-v2";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-uid";
const OTHER_UID = "other-uid";

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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function validBody(): Record<string, unknown> {
  return {
    correctedField: "title",
    fromValue: "Köttbullar",
    toValue: "Köttbullar med gräddsås",
    sourceTier: "llm",
    domain: "ica.se",
    userIdHash: "a".repeat(64),
    recipeIdHash: "b".repeat(64),
    schemaVersion: "v2-perfield",
  };
}

// PCV2-1: signed-in user cannot create a doc.
test("parse_corrections_v2: authenticated user cannot create", async () => {
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().collection("parse_corrections_v2").add(validBody())
  );
});

// PCV2-2: anonymous user cannot create.
test("parse_corrections_v2: unauthenticated user cannot create", async () => {
  const anon = env.unauthenticatedContext();
  await assertFails(
    anon.firestore().collection("parse_corrections_v2").add(validBody())
  );
});

// PCV2-3: signed-in user cannot read an existing doc (even one the admin
// SDK seeded). This is the "not even your own" contract — clients have no
// query API for this collection.
test("parse_corrections_v2: authenticated user cannot read", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc("parse_corrections_v2/seeded-doc")
      .set(validBody());
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc("parse_corrections_v2/seeded-doc").get()
  );
});

// PCV2-4: anonymous user cannot read.
test("parse_corrections_v2: unauthenticated user cannot read", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc("parse_corrections_v2/seeded-doc-2")
      .set(validBody());
  });
  const anon = env.unauthenticatedContext();
  await assertFails(
    anon.firestore().doc("parse_corrections_v2/seeded-doc-2").get()
  );
});

// PCV2-5: signed-in user cannot update.
test("parse_corrections_v2: authenticated user cannot update", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc("parse_corrections_v2/seeded-doc-3")
      .set(validBody());
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc("parse_corrections_v2/seeded-doc-3")
      .set({ ...validBody(), toValue: "tampered" })
  );
});

// PCV2-6: signed-in user cannot delete.
test("parse_corrections_v2: authenticated user cannot delete", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc("parse_corrections_v2/seeded-doc-4")
      .set(validBody());
  });
  const ctx = env.authenticatedContext(USER_UID);
  await assertFails(
    ctx.firestore().doc("parse_corrections_v2/seeded-doc-4").delete()
  );
});

// PCV2-7: signed-in user cannot list/query.
test("parse_corrections_v2: authenticated user cannot list", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc("parse_corrections_v2/seeded-doc-5")
      .set(validBody());
  });
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    ctx
      .firestore()
      .collection("parse_corrections_v2")
      .where("sourceTier", "==", "llm")
      .get()
  );
});

// PCV2-8: admin SDK (security-rules-disabled context) CAN write — sanity
// check that the rules are blocking only the client surface.
test(
  "parse_corrections_v2: admin SDK (server-side) can write — contract verified",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await assertSucceeds(
        admin
          .firestore()
          .collection("parse_corrections_v2")
          .add(validBody())
      );
    });
  }
);

async function run(): Promise<void> {
  console.log("BUT-595: parse_corrections_v2 rules tests\n");
  console.log("==========================================\n");
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
