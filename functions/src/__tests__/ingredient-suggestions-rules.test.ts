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
 * BUT-2038 closed most of that open item: the limb now carries a `hasOnly`
 * allowlist, a value pin on `status`, and a length bound on every free-text
 * field plus the array. The allow fixtures already sent `status: 'pending'`, so
 * the value pin did NOT turn them red — which is why C9
 * exists: without it, `hasOnly` admits any value of a field that is in the
 * declared type, and nothing would refuse a forged approval.
 *
 * Deliberately absent, and decided rather than open — Malin's call, 2026-09-09:
 * `rateLimitWrite`. It only READS
 * `users/{uid}/rate_limits/{type}`, which the writing repository must stamp in
 * the same batch, and no code in `lib/` creates a suggestion — so the limiter
 * would bound nothing. Whoever builds the client path adds both halves.
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
 * SUITE: a list case appended after them failed with a
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
  // create rule broke.
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


// C7 (BUT-2038) — `hasOnly`. A field outside the SUBMISSION half of the
// declared type is refused, so a client cannot store data the Art. 15 export's
// allowlist would then silently drop from its own subject's bundle. The type's
// three optional content fields are IN the allowlist; C12 pins that.
test("a create carrying a field outside the declared type is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/extra-field`).set({
      ...validBody(USER_UID),
      somethingNobodyDecidedAbout: "x",
    })
  );
});

// C12 (BUT-2038) — the submission half's OPTIONAL fields are accepted. Without
// this the allowlist could be narrowed back to the five required fields and
// every case above would stay green, while the future client path broke
// silently and fail-closed.
test("a create carrying the type's optional content fields is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/with-optionals`).set({
      ...validBody(CREATOR_UID),
      suggestedCategory: "grönsaker",
      suggestedProperties: ["vegansk", "glutenfri"],
      recipeContext: "Från ett recept på rotsaksgratäng",
    })
  );
});

// C13-C15 (BUT-2038) — the three optional fields' BOUNDS. C12 proves they are
// accepted; measured, each bound could be deleted and C12 stayed green, because
// its fixture sits well inside all three. An allow without a deny is not
// coverage.
test("a suggestedCategory over 100 characters is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/cat-too-long`).set({
      ...validBody(USER_UID),
      suggestedCategory: "a".repeat(101),
    })
  );
});

test("a recipeContext over 500 characters is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/ctx-too-long`).set({
      ...validBody(USER_UID),
      recipeContext: "a".repeat(501),
    })
  );
});

test("more than 20 suggestedProperties is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/props-too-many`).set({
      ...validBody(USER_UID),
      suggestedProperties: Array.from({ length: 21 }, (_, i) => `p${i}`),
    })
  );
});

// C17-C19 (BUT-2038) — the at-bound twins. C13-C15 pin the DIRECTION (over the
// bound denies); only these pin the NUMBER. Measured: tightening all three to
// `<` left the suite green, because C12's fixture sits at 9 characters and 2
// entries. `ingredientName` and `originalName` already have this twin.
test("a suggestedCategory of exactly 100 characters is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/cat-at-bound`).set({
      ...validBody(CREATOR_UID),
      suggestedCategory: "a".repeat(100),
    })
  );
});

test("a recipeContext of exactly 500 characters is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/ctx-at-bound`).set({
      ...validBody(CREATOR_UID),
      recipeContext: "a".repeat(500),
    })
  );
});

test("exactly 20 suggestedProperties is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/props-at-bound`).set({
      ...validBody(CREATOR_UID),
      suggestedProperties: Array.from({ length: 20 }, (_, i) => `p${i}`),
    })
  );
});

// C16 (BUT-2038) — what the guard shape does with a PRESENT-NULL optional, and
// it is fail-closed today. `!('f' in data) || data.f.size() <= N` reaches
// `.size()` on a null and CEL-errors, so the create is refused.
//
// Pinned because it is a live trap for whoever builds the client writer: a
// serialiser that emits `recipeContext: null` for "no context" would have every
// create on this collection refused, and the rule would look correct while doing
// it. If that behaviour is ever changed, this case is what names the decision.
test("an optional field present but null is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/null-optional`).set({
      ...validBody(USER_UID),
      recipeContext: null,
    })
  );
});

// C8 (BUT-2038) — the moderator fields specifically. They are written by the
// Admin SDK and the console, which bypass rules; a client setting them poisons
// `onSuggestionStatusChanged`'s audit trail.
test("a create setting reviewedBy or reviewNotes is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/forged-reviewer`).set({
      ...validBody(USER_UID),
      reviewedBy: "some-moderator",
    })
  );
  await assertFails(
    db.doc(`${COLLECTION}/forged-notes`).set({
      ...validBody(USER_UID),
      reviewNotes: "looks fine to me",
    })
  );
});

// C9 (BUT-2038) — `status` by VALUE, which `hasOnly` cannot do. The field is IN
// the declared type, so an allowlist admits any value and only this refuses a
// forged approval. Its control is C1, which sends 'pending' and passes.
test("a create claiming an approved status is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/forged-status`).set({
      ...validBody(USER_UID),
      status: "approved",
    })
  );
});

// C10 (BUT-2038) — `notifiedAt`, the field whose client-set presence made the
// moderator step skip permanently for that row.
test("a create pre-setting notifiedAt is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/forged-notified`).set({
      ...validBody(USER_UID),
      notifiedAt: new Date().toISOString(),
    })
  );
});

// C11 (BUT-2038) — `originalName`, which was unbounded before this ticket.
// Boundary pair, same shape as C5/C6.
test("an originalName over 100 characters is refused", async () => {
  const db = env.authenticatedContext(USER_UID).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/orig-too-long`).set({
      ...validBody(USER_UID),
      originalName: "a".repeat(101),
    })
  );
});

test("an originalName of exactly 100 characters is allowed", async () => {
  const db = env.authenticatedContext(CREATOR_UID).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/orig-exactly-100`).set({
      ...validBody(CREATOR_UID),
      originalName: "a".repeat(100),
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
