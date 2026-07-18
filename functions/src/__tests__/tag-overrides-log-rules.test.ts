/**
 * Firestore rules tests for the tag_overrides_log collection (BUT-1473).
 *
 * Top-level, own-data, append-only capture of allergen verdict overrides that
 * feed the tagging learning loop. Contract (mirrors parsing_corrections):
 *
 *   create — allowed only when authenticated AND
 *            request.resource.data.userId == auth.uid AND all required fields
 *            ['id','userId','recipeId','type','tag','direction','timestamp']
 *            are present. Cross-user userId or a missing field DENIES.
 *   read   — allowed for the owner (userId == auth.uid) and for admins
 *            (isAdmin()); a different non-admin user DENIES.
 *   update — always denied (immutable / append-only).
 *   delete — allowed only for the owner (GDPR Article 17); others DENY.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/tag-overrides-log-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-tag-overrides-log-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "owner-uid";
const STRANGER = "stranger-uid";
const ADMIN_UID = "admin-uid";

// Per-run token so create-allow doc ids never collide with a doc persisted by a
// prior run on the shared emulator (update is denied outright, so a leftover doc
// would otherwise turn every create-allow into a false FAIL).
const RUN = Date.now().toString(36);

let env: RulesTestEnvironment;

/** Minimal-but-valid tag_overrides_log document for `userId`. */
function validEntryBody(
  userId: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    id: "entry-1",
    userId,
    recipeId: "recipe-1",
    type: "allergen",
    tag: "gluten",
    direction: "toFree",
    triggeringIngredients: ["vetemjöl", "korn"],
    timestamp: Date.now(),
    ...extra,
  };
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Grant ADMIN_UID app-admin status (isAdmin() == exists(/admins/{uid})).
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ role: "admin" });
  });
}
async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

/** Seed an existing OWNER-owned entry (bypassing rules) for read/update/delete tests. */
async function seedEntry(entryId: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`tag_overrides_log/${entryId}`)
      .set(validEntryBody(OWNER, { id: entryId }));
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ====================================================================
// CREATE (5 assertions)
// ====================================================================

// TOL1: owner-allow — authenticated caller writes their OWN entry with all
// required fields present.
test("tag_overrides_log: owner CAN create their own entry with all required fields", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`tag_overrides_log/create-own-${RUN}`)
      .set(validEntryBody(OWNER, { id: `create-own-${RUN}` }))
  );
});

// TOL2: cross-user-deny — authenticated caller writes an entry whose userId
// names a DIFFERENT user (data-poisoning of the learning loop).
test("tag_overrides_log: user CANNOT create an entry for another user (cross-user userId)", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`tag_overrides_log/create-cross-${RUN}`)
      .set(validEntryBody(STRANGER, { id: `create-cross-${RUN}` }))
  );
});

// TOL3: unauthenticated-deny.
test("tag_overrides_log: unauthenticated user CANNOT create an entry", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`tag_overrides_log/create-anon-${RUN}`)
      .set(validEntryBody(OWNER, { id: `create-anon-${RUN}` }))
  );
});

// TOL4: missing-required-deny — a body missing 'tag' (one of the required keys).
test("tag_overrides_log: owner CANNOT create an entry missing a required field (tag)", async () => {
  const body = validEntryBody(OWNER, { id: `create-notag-${RUN}` });
  delete (body as Record<string, unknown>).tag;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`tag_overrides_log/create-notag-${RUN}`).set(body)
  );
});

// TOL5: missing-required-deny — a body missing 'direction' (a different required
// key), proving hasRequiredFields covers more than one anchor.
test("tag_overrides_log: owner CANNOT create an entry missing a required field (direction)", async () => {
  const body = validEntryBody(OWNER, { id: `create-nodir-${RUN}` });
  delete (body as Record<string, unknown>).direction;
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`tag_overrides_log/create-nodir-${RUN}`).set(body)
  );
});

// ====================================================================
// READ (4 assertions)
// ====================================================================

// TOL6: owner-allow.
test("tag_overrides_log: owner CAN read their own entry", async () => {
  await seedEntry("read-own");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`tag_overrides_log/read-own`).get());
});

// TOL7: admin-allow — admin reads across all entries for the learning-loop dashboard.
test("tag_overrides_log: admin CAN read another user's entry", async () => {
  await seedEntry("read-admin");
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`tag_overrides_log/read-admin`).get());
});

// TOL8: stranger-deny — a different non-admin user cannot read.
test("tag_overrides_log: a different non-admin user CANNOT read another user's entry", async () => {
  await seedEntry("read-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(ctx.firestore().doc(`tag_overrides_log/read-stranger`).get());
});

// TOL9: unauthenticated-deny.
test("tag_overrides_log: unauthenticated user CANNOT read an entry", async () => {
  await seedEntry("read-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`tag_overrides_log/read-anon`).get());
});

// ====================================================================
// UPDATE (2 assertions) — immutable / append-only
// ====================================================================

// TOL10: owner-deny via partial update.
test("tag_overrides_log: owner CANNOT update their own entry (immutable)", async () => {
  await seedEntry("update-partial");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx.firestore().doc(`tag_overrides_log/update-partial`).update({ tag: "milk" })
  );
});

// TOL11: owner-deny via full-body set-on-existing (the path a buggy client retry
// would hit — `allow update: if false` must block it too).
test("tag_overrides_log: owner CANNOT overwrite an existing entry via set", async () => {
  await seedEntry("update-set");
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(`tag_overrides_log/update-set`)
      .set(validEntryBody(OWNER, { id: "update-set", tag: "egg" }))
  );
});

// ====================================================================
// DELETE (3 assertions) — GDPR Article 17
// ====================================================================

// TOL12: owner-allow.
test("tag_overrides_log: owner CAN delete their own entry (GDPR Art. 17)", async () => {
  await seedEntry("delete-own");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(`tag_overrides_log/delete-own`).delete());
});

// TOL13: stranger-deny.
test("tag_overrides_log: a different user CANNOT delete another user's entry", async () => {
  await seedEntry("delete-stranger");
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(`tag_overrides_log/delete-stranger`).delete()
  );
});

// TOL14: unauthenticated-deny.
test("tag_overrides_log: unauthenticated user CANNOT delete an entry", async () => {
  await seedEntry("delete-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`tag_overrides_log/delete-anon`).delete());
});

async function run(): Promise<void> {
  console.log("tag_overrides_log rules tests (BUT-1473)\n");
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
