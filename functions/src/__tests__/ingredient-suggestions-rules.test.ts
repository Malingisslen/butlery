/**
 * BUT-2028: Firestore rules tests for `ingredient_suggestions`.
 *
 * The collection had NO rules coverage until this file, which mattered little
 * while nothing read it and everything is written by the Admin SDK. It matters
 * now: the Art. 15 export section added in BUT-2028 runs a CLIENT list query
 * (`where('userId','==',uid)`), and the read limb below is the only server-side
 * control on it. The Dart suites cannot see that — `fake_cloud_firestore`
 * enforces no rules — so a later tightening of the read limb would make the
 * section return its failure envelope for every user, forever, with every Dart
 * test still green.
 *
 * The LIST cases are the load-bearing half. Rules are not filters: a list is
 * refused unless the rule proves every returnable document is readable, which
 * an equality against `request.auth.uid` on the field the rule tests does and a
 * different field would not (the BUT-1971 `contributorUserIds` failure). One
 * case sends the query the export actually sends; the rest are the shapes that
 * must be refused, including a collection-group read, which has no match block.
 *
 * The create limb is client-reachable and its field validation had no test at
 * all, so the ownership check, the required-field list and both sides of the
 * length bound are pinned here.
 *
 * What the limb does NOT do — no `hasOnly` allowlist, no document-size bound,
 * no `rateLimitWrite`, so a client can write unbounded rows and set
 * `reviewedBy` or `notifiedAt` itself — is BUT-2038, not a contract, and
 * the cases below do not assert it either way. One caveat, measured: `status`
 * IS in `hasRequiredFields`, so both allow fixtures must send it. Closing that
 * half of the open item by refusing a client-set `status` turns those two
 * green cases red, and that is the fix landing, not a regression.
 *
 * Run with: npx ts-node src/__tests__/ingredient-suggestions-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-ingredient-suggestions";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const COLLECTION = "ingredient_suggestions";

const USER_UID = "user-uid";
const OTHER_UID = "other-uid";
/**
 * The create cases that are ALLOWED write real documents into the same
 * collection the list cases read, so those use a principal of their own. The
 * denied ones write nothing and need none. With `USER_UID` the create
 * cases themselves still passed — what held only by registration order was the
 * SUITE: a list case appended after them saw four rows and failed with a
 * message about the export query, pointing at the wrong limb.
 * `clearFirestore()` in setup fixes the cross-RUN version of this and nothing
 * about the intra-run one.
 */
const CREATOR_UID = "creator-uid";

/**
 * An arbitrary page size, chosen to match what the export sends today. Nothing
 * couples it to the Dart cap: the block carries no `request.query` reference at
 * all, so the limbs allow or deny identically at any limit.
 */
const EXPORT_LIMIT = 501;

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // `env.cleanup()` disposes the test environment; it does not empty the
  // emulator. Without this, a document an earlier run created survives into the
  // next one, so an ALLOWED create case lands on an existing document and
  // evaluates the UPDATE limb (`if false`) instead — failing while claiming the
  // create rule broke. Measured with the clear commented out: the second run
  // fails exactly the two allowed creates.
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

function validBody(uid: string): Record<string, unknown> {
  return {
    userId: uid,
    ingredientName: "svartkål",
    originalName: "Svartkål (grönkål?)",
    status: "pending",
    createdAt: new Date(),
  };
}

/**
 * Seeds through the rules-bypassing context, so a create-rule change cannot
 * silently turn a read test into a test of the create limb.
 */
async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`${COLLECTION}/mine-1`).set(validBody(USER_UID));
    await db.doc(`${COLLECTION}/mine-2`).set(validBody(USER_UID));
    await db.doc(`${COLLECTION}/theirs`).set(validBody(OTHER_UID));
    // No `userId` at all. An equality filter cannot return it, so it must not
    // reach the owner's list — and a `get` on it must not error the rule open.
    await db.doc(`${COLLECTION}/no-owner`).set({
      ingredientName: "rabarber",
      status: "pending",
    });
  });
}

// --- LIST: the shape the Art. 15 export sends ---------------------------

// L1
test("the export's own query is allowed and returns only the caller's rows", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  const snap = await assertSucceeds(
    db.collection(COLLECTION).where("userId", "==", USER_UID).limit(EXPORT_LIMIT).get()
  );
  const ids = snap.docs.map((d) => d.id).sort();
  if (ids.length !== 2 || ids[0] !== "mine-1" || ids[1] !== "mine-2") {
    throw new Error(
      `expected exactly the caller's two rows, got ${JSON.stringify(ids)}`
    );
  }
});

// L2
test("an unfiltered list is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(db.collection(COLLECTION).limit(EXPORT_LIMIT).get());
});

// L3
test("listing somebody else's rows is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.collection(COLLECTION).where("userId", "==", OTHER_UID).get()
  );
});

// L4
test("a signed-out list is refused", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(
    db.collection(COLLECTION).where("userId", "==", USER_UID).get()
  );
});

// L5 — a plausible refactor of the export, which must NOT quietly work: there
// is no collection-group match block, so this is denied rather than scoped.
test("a collectionGroup list is refused even filtered on the caller", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.collectionGroup(COLLECTION).where("userId", "==", USER_UID).get()
  );
});

// --- GET ----------------------------------------------------------------

// G1
test("the owner may read their own suggestion", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/mine-1`).get());
});

// G2
test("reading another user's suggestion is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(db.doc(`${COLLECTION}/theirs`).get());
});

// G3 — `resource` is null for a missing document, so the limb's field deref
// must deny rather than evaluate to true.
test("reading a missing document is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(db.doc(`${COLLECTION}/does-not-exist`).get());
});

// G4
test("a row with no userId is unreadable by anyone signed in", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(db.doc(`${COLLECTION}/no-owner`).get());
});

// --- CREATE -------------------------------------------------------------

// C1
test("a signed-in client may create a suggestion keyed to itself", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/fresh`).set(validBody(CREATOR_UID))
  );
});

// C2
test("creating a suggestion in somebody else's name is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/forged`).set(validBody(OTHER_UID))
  );
});

// C3
test("a signed-out client cannot create", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(
    db.doc(`${COLLECTION}/anon`).set(validBody(USER_UID))
  );
});

// C4 — the `hasRequiredFields` half of the limb, which had no test.
test("a create missing a required field is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  const body = validBody(USER_UID);
  delete body.originalName;
  await assertFails(db.doc(`${COLLECTION}/incomplete`).set(body));
});

// C5 — the length bound, at the first value that must fail.
test("an ingredientName over 100 characters is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/too-long`).set({
      ...validBody(USER_UID),
      ingredientName: "a".repeat(101),
    })
  );
});

// C6 — the boundary on the allowed side, so C5 is pinned to the bound rather
// than to "long strings fail".
test("an ingredientName of exactly 100 characters is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/at-bound`).set({
      ...validBody(CREATOR_UID),
      ingredientName: "a".repeat(100),
    })
  );
});

// --- UPDATE / DELETE ----------------------------------------------------

// U1 — the owner cannot amend their own row, so no client can rewrite a
// moderation verdict after the fact.
test("the owner cannot update their own suggestion", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/mine-1`).update({ status: "approved" })
  );
});

// U2 — deliberate: the Art. 17 route for this collection is the Admin-SDK
// cascade (`deleteIngredientSuggestions`), not a client delete.
test("the owner cannot delete their own suggestion", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(db.doc(`${COLLECTION}/mine-2`).delete());
});

async function run(): Promise<void> {
  console.log("BUT-2028: ingredient_suggestions rules tests\n");
  console.log("===========================================\n");
  await setup();
  await seed();
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
