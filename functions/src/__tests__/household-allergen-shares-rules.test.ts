/**
 * Firestore rules tests for `household_allergen_shares` (BUT-1693; plan
 * tasks/household-share-erasure-plan.md).
 *
 * The collection had no rules block, so every client read and write was denied
 * by the terminal catch-all. The block these tests pin is what makes the Art. 15
 * export and the account-deletion work reachable before the feature flag
 * `enable_household_allergen_sharing` is switched on. The Dart suites cannot see
 * any of it: `fake_cloud_firestore` enforces no rules.
 *
 * Create cases write to ids no fixture seeds and no ALLOW test writes before
 * them, so they evaluate CREATE rather than UPDATE.
 *
 * Run with: npx ts-node src/__tests__/household-allergen-shares-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-household-allergen-shares";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const COLLECTION = "household_allergen_shares";

const A = "uidA";
const B = "uidB";
const C = "uidC";
const D = "uidD";
const E = "uidE";
const G = "uidG";
// An auth uid carrying '_', for the id-separator guard on userId.
const F = "uid_F";

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

const SEEDED_CONSENT_AT = new Date("2026-09-01T10:00:00Z");

function share(
  householdId: string,
  userId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    householdId,
    userId,
    trackedAllergens: ["gluten", "mjölk"],
    trackedDietary: [],
    includeUnknownInMenu: false,
    consentGranted: true,
    consentVersion: "v1",
    consentGrantedAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

async function seed(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("households/h1").set({ memberUserIds: [A, B] });
    await db.doc("households/h2").set({ memberUserIds: [C] });
    await db.doc("households/h3").set({ memberUserIds: [D, E] });
    await db.doc("households/h4").set({ memberUserIds: [A] });
    await db.doc("households/h5").set({ memberUserIds: [B] });
    await db.doc("households/h7").set({ memberUserIds: [B] });
    await db.doc("households/h8").set({ memberUserIds: [F] });
    await db.doc("households/h9").set({ memberUserIds: [G] });
    await db.doc("households/hx_y").set({ memberUserIds: [D] });
    await db
      .doc(`${COLLECTION}/h1_${A}`)
      .set(share("h1", A, { consentGrantedAt: SEEDED_CONSENT_AT }));
    await db
      .doc(`${COLLECTION}/h1_${B}`)
      .set(share("h1", B, { consentGrantedAt: SEEDED_CONSENT_AT }));
    await db.doc(`${COLLECTION}/h4_${A}`).set(share("h4", A));
    // A is not a member of h5: a share left behind by someone who left.
    await db
      .doc(`${COLLECTION}/h5_${A}`)
      .set(share("h5", A, { consentGrantedAt: SEEDED_CONSENT_AT }));
    // Corrupt body with no userId, still A's by path.
    await db.doc(`${COLLECTION}/h6_${A}`).set({ trackedAllergens: ["ägg"] });
    // A stored record that is not a consent.
    await db
      .doc(`${COLLECTION}/h7_${B}`)
      .set(share("h7", B, { consentGranted: false, consentGrantedAt: SEEDED_CONSENT_AT }));
    // An id with three '_'-separated parts, A's uid in the second.
    await db.doc(`${COLLECTION}/h1_${A}_x`).set({ trackedAllergens: ["ägg"] });
  });
}

// --- READ ---------------------------------------------------------------

test("R1 a household member may read another member's share", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h1_${B}`).get());
});

test("R2 a non-member may not read a share", async () => {
  const db = env.authenticatedContext(C).firestore();
  await assertFails(db.doc(`${COLLECTION}/h1_${A}`).get());
});

test("R3 the export's own query (userId == caller) is allowed", async () => {
  const db = env.authenticatedContext(A).firestore();
  const snap = await assertSucceeds(
    db.collection(COLLECTION).where("userId", "==", A).get(),
  );
  const ids = snap.docs.map((d) => d.id).sort();
  const expected = [`h1_${A}`, `h4_${A}`, `h5_${A}`].sort();
  if (JSON.stringify(ids) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(ids)}`);
  }
});

// B is a member of h1 and may read h1_A directly (R1). This query is
// refused because rules are not filters, so one unreadable match refuses the
// whole query.
test("R4 a userId list spanning a household the caller is not in is refused", async () => {
  const db = env.authenticatedContext(B).firestore();
  await assertFails(db.collection(COLLECTION).where("userId", "==", A).get());
});

test("R5 a member may list the household's shares (getByHousehold)", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(
    db.collection(COLLECTION).where("householdId", "==", "h1").get(),
  );
});

test("R6 a non-member may not list a household's shares", async () => {
  const db = env.authenticatedContext(C).firestore();
  await assertFails(
    db.collection(COLLECTION).where("householdId", "==", "h1").get(),
  );
});

test("R7 an unfiltered list is refused", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(db.collection(COLLECTION).get());
});

test("R8 a signed-out read is refused", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(db.doc(`${COLLECTION}/h1_${A}`).get());
});

// The repository reads a member's own id before every first grant.
test("R9 a member may read their own share id before it exists", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h3_${E}`).get());
});

test("R10 nobody may probe whether another user has shared", async () => {
  const db = env.authenticatedContext(D).firestore();
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).get());
});

test("R11 a signed-out read of a missing id is refused", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).get());
});

test("R12 a missing id with a third '_' part is not readable by the uid in its second", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await ctx.firestore().doc(`${COLLECTION}/h3_${E}_x`).get();
    if (snap.exists) throw new Error(`fixture: h3_${E}_x must not exist`);
  });
  const db = env.authenticatedContext(E).firestore();
  await assertFails(db.doc(`${COLLECTION}/h3_${E}_x`).get());
});

// --- CREATE -------------------------------------------------------------

test("C1 a member may create their own share with valid consent", async () => {
  const db = env.authenticatedContext(D).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h3_${D}`).set(share("h3", D)));
});

test("C2 creating a share in another member's name is refused", async () => {
  const db = env.authenticatedContext(D).firestore();
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E)));
});

test("C3 creating a share in a household one is not in is refused", async () => {
  const db = env.authenticatedContext(D).firestore();
  await assertFails(db.doc(`${COLLECTION}/h2_${D}`).set(share("h2", D)));
});

test("C4 a share without consentGranted == true is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { consentGranted: false })),
  );
});

test("C5 a field outside the model is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { note: "x" })),
  );
});

test("C6 a consent timestamp a day in the past is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(
      share("h3", E, { consentGrantedAt: new Date(Date.now() - 86400000) }),
    ),
  );
});

test("C7 a consent timestamp a day in the future is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(
      share("h3", E, { consentGrantedAt: new Date(Date.now() + 86400000) }),
    ),
  );
});

test("C8 a document id that does not match the body is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(db.doc(`${COLLECTION}/wrong-id`).set(share("h3", E)));
});

test("C9 a share missing consentVersion is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  const body = share("h3", E);
  delete body.consentVersion;
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).set(body));
});

test("C10 an empty consentVersion is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { consentVersion: "" })),
  );
});

test("C11 an oversized allergen list is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(
      share("h3", E, { trackedAllergens: Array.from({ length: 51 }, (_, i) => `a${i}`) }),
    ),
  );
});

test("C13 a share without consentGrantedAt is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  const body = share("h3", E);
  delete body.consentGrantedAt;
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).set(body));
});

test("C12 a signed-out create is refused", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E)));
});

test("C14 a trackedAllergens that is not a list is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { trackedAllergens: "gluten" })),
  );
});

test("C15 a trackedDietary that is not a list is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { trackedDietary: "vegan" })),
  );
});

test("C16 an oversized dietary list is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(
      share("h3", E, { trackedDietary: Array.from({ length: 21 }, (_, i) => `d${i}`) }),
    ),
  );
});

test("C17 an includeUnknownInMenu that is not a bool is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { includeUnknownInMenu: "false" })),
  );
});

test("C18 a consentVersion that is not a string is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { consentVersion: ["v1"] })),
  );
});

test("C19 a consentVersion over 20 characters is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { consentVersion: "v".repeat(21) })),
  );
});

test("C20 an updatedAt that is not a timestamp is refused", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h3_${E}`).set(share("h3", E, { updatedAt: "2026-09-15" })),
  );
});

test("C21 a householdId containing '_' is refused", async () => {
  const db = env.authenticatedContext(D).firestore();
  await assertFails(db.doc(`${COLLECTION}/hx_y_${D}`).set(share("hx_y", D)));
});

test("C22 a userId containing '_' is refused", async () => {
  const db = env.authenticatedContext(F).firestore();
  await assertFails(db.doc(`${COLLECTION}/h8_${F}`).set(share("h8", F)));
});

test("C23 a share at every size bound is allowed", async () => {
  const db = env.authenticatedContext(G).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/h9_${G}`).set(
      share("h9", G, {
        trackedAllergens: Array.from({ length: 50 }, (_, i) => `a${i}`),
        trackedDietary: Array.from({ length: 20 }, (_, i) => `d${i}`),
        consentVersion: "v".repeat(20),
      }),
    ),
  );
});

// --- UPDATE -------------------------------------------------------------

test("U1 the owner may edit preferences, carrying the stored consent", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/h1_${A}`).set(
      share("h1", A, { trackedAllergens: ["ägg"], consentGrantedAt: SEEDED_CONSENT_AT }),
    ),
  );
});

test("U2 the owner may not re-date the consent record", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h1_${A}`).set(share("h1", A, { consentGrantedAt: new Date() })),
  );
});

test("U3 another member may not edit a member's share", async () => {
  const db = env.authenticatedContext(B).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h1_${A}`).set(
      share("h1", A, { trackedAllergens: [], consentGrantedAt: SEEDED_CONSENT_AT }),
    ),
  );
});

test("U4 the owner may not change the consent version on an edit", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h1_${A}`).set(
      share("h1", A, { consentVersion: "v2", consentGrantedAt: SEEDED_CONSENT_AT }),
    ),
  );
});

test("U5 a former member may not edit a share in a household they left", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h5_${A}`).set(
      share("h5", A, { trackedAllergens: [], consentGrantedAt: SEEDED_CONSENT_AT }),
    ),
  );
});

test("U6 the owner may not add a field outside the model on an edit", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h1_${A}`).set(
      share("h1", A, { note: "x", consentGrantedAt: SEEDED_CONSENT_AT }),
    ),
  );
});

test("U7 an edit may not turn a stored non-consent into a consent", async () => {
  const db = env.authenticatedContext(B).firestore();
  await assertFails(
    db.doc(`${COLLECTION}/h7_${B}`).set(share("h7", B, { consentGrantedAt: SEEDED_CONSENT_AT })),
  );
});

test("U8 the owner may edit without an updatedAt", async () => {
  const db = env.authenticatedContext(B).firestore();
  const body = share("h1", B, { consentGrantedAt: SEEDED_CONSENT_AT });
  delete body.updatedAt;
  await assertSucceeds(db.doc(`${COLLECTION}/h1_${B}`).set(body));
});

// --- DELETE -------------------------------------------------------------

test("D1 the owner may delete their own share", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h4_${A}`).delete());
});

test("D2 another member may not delete a member's share", async () => {
  const db = env.authenticatedContext(B).firestore();
  await assertFails(db.doc(`${COLLECTION}/h1_${A}`).delete());
});

test("D3 a former member may still delete their share", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h5_${A}`).delete());
});

test("D4 the owner may delete a corrupt row that has no userId", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h6_${A}`).delete());
});

test("D5 a signed-out delete is refused", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(db.doc(`${COLLECTION}/h1_${B}`).delete());
});

test("D6 an id with a third '_' part is not deletable by the uid in its second", async () => {
  const db = env.authenticatedContext(A).firestore();
  await assertFails(db.doc(`${COLLECTION}/h1_${A}_x`).delete());
});

test("D7 withdrawing a share that does not exist is allowed", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertSucceeds(db.doc(`${COLLECTION}/h2_${E}`).delete());
});

async function run(): Promise<void> {
  console.log("household_allergen_shares rules tests\n");
  console.log("=====================================\n");
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
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

// Placed last on purpose: it is the one create case that SUCCEEDS at h3_E, and
// every create case above requires that document to be absent.
test("C24 a consent timestamp 9 minutes in the past is accepted", async () => {
  const db = env.authenticatedContext(E).firestore();
  await assertSucceeds(
    db.doc(`${COLLECTION}/h3_${E}`).set(
      share("h3", E, { consentGrantedAt: new Date(Date.now() - 9 * 60000) }),
    ),
  );
});

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
