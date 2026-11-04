/**
 * Firestore rules tests for `ingredient_change_requests`, the admin web's
 * ingredient proposals.
 *
 * Proves: only admins read or create; a create must be a pending proposal
 * by the caller, stamped with the server's time, with known columns and
 * bounded values; a withdrawal is allowed from pending, conflict and
 * inReview; no client sets a server status or field, or deletes; the run
 * lock and run records are closed to every client.
 *
 * Prerequisite: Firestore emulator running (`firebase emulators:start
 * --only firestore`). Run with:
 * npx ts-node src/__tests__/ingredient-change-requests-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// The rules-unit-testing context is the client SDK, which only accepts its
// own sentinel (see acquisition-rules.test.ts).
import { serverTimestamp, Timestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-ingredient-change-requests";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const COLLECTION = "ingredient_change_requests";

const ADMIN_UID = "admin-uid";
const OTHER_ADMIN_UID = "admin-2";
const USER_UID = "user-a";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
    await ctx.firestore().doc(`admins/${OTHER_ADMIN_UID}`).set({ addedAt: new Date() });
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

function proposal(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    ingredientId: "garlic",
    changes: {
      properties: { old: ["plant-based"], new: ["plant-based", "vegan-friendly"] },
      price_category: { old: "medium", new: "budget" },
      avg_price_sek: { old: null, new: 12.5 },
    },
    ingredientUpdatedAt: Timestamp.fromDate(new Date("2026-10-31T11:20:00Z")),
    status: "pending",
    createdBy: ADMIN_UID,
    createdAt: serverTimestamp(),
    ...extra,
  };
}

function daysFromNow(days: number): Timestamp {
  return Timestamp.fromDate(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
}

function withdrawal(uid: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    status: "withdrawn",
    withdrawnAt: serverTimestamp(),
    withdrawnBy: uid,
    expireAt: daysFromNow(365),
    ...extra,
  };
}

async function seed(id: string, data: Record<string, unknown> = {}): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`${COLLECTION}/${id}`).set({
      ingredientId: "garlic",
      changes: { status: { old: "draft", new: "validated" } },
      status: "pending",
      createdBy: ADMIN_UID,
      createdAt: new Date(),
      ...data,
    });
  });
}

function admin() {
  return env.authenticatedContext(ADMIN_UID).firestore();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// Reads

test("admin can read and list proposals", async () => {
  await seed("r1");
  await assertSucceeds(admin().doc(`${COLLECTION}/r1`).get());
  await assertSucceeds(admin().collection(COLLECTION).where("status", "==", "pending").get());
});

test("non-admin cannot read a proposal", async () => {
  await seed("r2");
  await assertFails(env.authenticatedContext(USER_UID).firestore().doc(`${COLLECTION}/r2`).get());
});

test("unauthenticated client cannot read a proposal", async () => {
  await seed("r3");
  await assertFails(env.unauthenticatedContext().firestore().doc(`${COLLECTION}/r3`).get());
});

// Create

test("admin can create a valid proposal", async () => {
  await assertSucceeds(admin().doc(`${COLLECTION}/c1`).set(proposal()));
});

test("admin can create a minimal proposal (no optional fields)", async () => {
  const body = proposal({ changes: { swedish: { old: "vitlok", new: "vitlök" } } });
  delete body.ingredientUpdatedAt;
  await assertSucceeds(admin().doc(`${COLLECTION}/c2`).set(body));
});

test("admin can add a note and a batchId", async () => {
  await assertSucceeds(
    admin().doc(`${COLLECTION}/c3`).set(proposal({ note: "kollat mot ICA", batchId: "b-1" }))
  );
});

test("every editable column with a valid value is accepted", async () => {
  const changes: Record<string, unknown> = {};
  for (const c of ["swedish", "english", "group", "notes_sv", "notes_en",
    "typical_storage", "typical_unit", "price_category",
    "carbon_footprint_category", "status"]) {
    changes[c] = { old: "", new: "x" };
  }
  for (const c of ["properties", "aliases_sv", "aliases_en", "search_terms",
    "season_availability"]) {
    changes[c] = { old: [], new: ["x"] };
  }
  changes.avg_price_sek = { old: 10, new: null };
  await assertSucceeds(admin().doc(`${COLLECTION}/c4`).set(proposal({ changes })));
});

test("non-admin cannot create a proposal", async () => {
  const userDb = env.authenticatedContext(USER_UID).firestore();
  await assertFails(userDb.doc(`${COLLECTION}/c5`).set(proposal({ createdBy: USER_UID })));
});

test("unauthenticated client cannot create a proposal", async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc(`${COLLECTION}/c6`).set(proposal()));
});

test("createdBy must be the caller", async () => {
  await assertFails(admin().doc(`${COLLECTION}/c7`).set(proposal({ createdBy: OTHER_ADMIN_UID })));
});

test("createdAt must be the server's time", async () => {
  await assertFails(admin().doc(`${COLLECTION}/c8`).set(proposal({ createdAt: new Date() })));
});

test("a create must start as pending", async () => {
  for (const status of ["applied", "conflict", "rejected", "withdrawn", "inReview"]) {
    await assertFails(admin().doc(`${COLLECTION}/c9-${status}`).set(proposal({ status })));
  }
});

test("an unknown top-level field is refused", async () => {
  await assertFails(admin().doc(`${COLLECTION}/c10`).set(proposal({ expireAt: daysFromNow(10) })));
});

test("a create cannot carry a server field or a kind", async () => {
  for (const [key, value] of [
    ["prNumber", 7], ["csvValue", { swedish: "x" }], ["reason", "csv-mismatch"],
    ["kind", "ingredient"], ["kind", "occasionList"],
  ] as const) {
    await assertFails(admin().doc(`${COLLECTION}/sf-${key}-${String(value).slice(0, 8)}`).set(proposal({ [key]: value })));
  }
});

test("an unknown column is refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/c11`).set(proposal({ changes: { id: { old: "a", new: "b" } } }))
  );
  await assertFails(
    admin().doc(`${COLLECTION}/c11b`).set(proposal({ changes: { verified_by: { old: "", new: "x" } } }))
  );
});

test("empty changes are refused", async () => {
  await assertFails(admin().doc(`${COLLECTION}/c12`).set(proposal({ changes: {} })));
});

test("a change must carry exactly old and new", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/c13`).set(proposal({ changes: { swedish: { new: "x" } } }))
  );
  await assertFails(
    admin().doc(`${COLLECTION}/c13b`).set(
      proposal({ changes: { swedish: { old: "a", new: "b", extra: 1 } } })
    )
  );
});

test("wrong value types are refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/c14`).set(proposal({ changes: { properties: { old: [], new: "egg" } } }))
  );
  await assertFails(
    admin().doc(`${COLLECTION}/c14b`).set(proposal({ changes: { swedish: { old: null, new: "x" } } }))
  );
  await assertFails(
    admin().doc(`${COLLECTION}/c14c`).set(proposal({ changes: { avg_price_sek: { old: null, new: "12" } } }))
  );
});

test("oversized values are refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/c15`).set(
      proposal({ changes: { notes_sv: { old: "", new: "x".repeat(301) } } })
    )
  );
  const tooMany = Array.from({ length: 31 }, (_, i) => `alias-${i}`);
  await assertFails(
    admin().doc(`${COLLECTION}/c15b`).set(proposal({ changes: { aliases_sv: { old: [], new: tooMany } } }))
  );
  await assertFails(admin().doc(`${COLLECTION}/c15c`).set(proposal({ note: "x".repeat(501) })));
  await assertFails(admin().doc(`${COLLECTION}/c15d`).set(proposal({ batchId: "b".repeat(101) })));
  await assertFails(admin().doc(`${COLLECTION}/c15e`).set(proposal({ ingredientId: "" })));
});

// One named deny per column, so a column whose check is lost or misnamed in
// changesOk fails its own test.
const TEXT_COLUMNS = ["swedish", "english", "group", "notes_sv", "notes_en",
  "typical_storage", "typical_unit", "price_category",
  "carbon_footprint_category", "status"];
const LIST_COLUMNS = ["properties", "aliases_sv", "aliases_en", "search_terms",
  "season_availability"];

for (const column of TEXT_COLUMNS) {
  test(`${column}: a non-string new value is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/t-${column}`).set(proposal({ changes: { [column]: { old: "a", new: ["x"] } } }))
    );
  });
  test(`${column}: a non-string old value is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/tso-${column}`).set(proposal({ changes: { [column]: { old: ["x"], new: "a" } } }))
    );
  });
  test(`${column}: an oversized old value is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/to-${column}`).set(
        proposal({ changes: { [column]: { old: "x".repeat(301), new: "a" } } })
      )
    );
  });
}

for (const column of LIST_COLUMNS) {
  test(`${column}: a non-list new value is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/l-${column}`).set(proposal({ changes: { [column]: { old: [], new: "egg" } } }))
    );
  });
  test(`${column}: a non-list old value is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/lso-${column}`).set(proposal({ changes: { [column]: { old: "egg", new: [] } } }))
    );
  });
  test(`${column}: an oversized old list is refused`, async () => {
    const tooMany = Array.from({ length: 31 }, (_, i) => `v-${i}`);
    await assertFails(
      admin().doc(`${COLLECTION}/lo-${column}`).set(
        proposal({ changes: { [column]: { old: tooMany, new: [] } } })
      )
    );
  });
  test(`${column}: an extra key beside old and new is refused`, async () => {
    await assertFails(
      admin().doc(`${COLLECTION}/lx-${column}`).set(
        proposal({ changes: { [column]: { old: [], new: [], extra: [] } } })
      )
    );
  });
}

test("avg_price_sek: a non-number old value is refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/p1`).set(proposal({ changes: { avg_price_sek: { old: "10", new: 12 } } }))
  );
});

test("avg_price_sek: an extra key beside old and new is refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/p2`).set(
      proposal({ changes: { avg_price_sek: { old: 1, new: 2, extra: 3 } } })
    )
  );
});

test("a known column next to an unknown one is refused", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/m1`).set(
      proposal({ changes: { swedish: { old: "a", new: "b" }, verified_by: { old: "", new: "x" } } })
    )
  );
});

test("changes that are not a map are refused", async () => {
  await assertFails(admin().doc(`${COLLECTION}/m2`).set(proposal({ changes: ["swedish"] })));
});

test("ingredientUpdatedAt must be a timestamp", async () => {
  await assertFails(
    admin().doc(`${COLLECTION}/u1`).set(proposal({ ingredientUpdatedAt: "2026-01-01" }))
  );
});

test("ingredientId must be a string of at most 100 characters", async () => {
  await assertFails(admin().doc(`${COLLECTION}/i1`).set(proposal({ ingredientId: "x".repeat(101) })));
  await assertFails(admin().doc(`${COLLECTION}/i2`).set(proposal({ ingredientId: ["garlic"] })));
});

test("note and batchId must be strings", async () => {
  await assertFails(admin().doc(`${COLLECTION}/n1`).set(proposal({ note: ["x"] })));
  await assertFails(admin().doc(`${COLLECTION}/n2`).set(proposal({ batchId: ["x"] })));
});

test("an admin can create 50 proposals in one batch", async () => {
  const db = admin();
  const batch = db.batch();
  for (let i = 0; i < 50; i++) {
    batch.set(
      db.collection(COLLECTION).doc(`batch-${i}`),
      proposal({ ingredientId: `ing-${i}`, batchId: "bulk-1", changes: { status: { old: "draft", new: "validated" } } })
    );
  }
  await assertSucceeds(batch.commit());
});

// Withdraw

test("admin can withdraw a pending proposal", async () => {
  await seed("w1");
  await assertSucceeds(admin().doc(`${COLLECTION}/w1`).update(withdrawal(ADMIN_UID)));
});

test("another admin can withdraw it in their own name", async () => {
  await seed("w2");
  const other = env.authenticatedContext(OTHER_ADMIN_UID).firestore();
  await assertSucceeds(other.doc(`${COLLECTION}/w2`).update(withdrawal(OTHER_ADMIN_UID)));
});

test("withdrawnBy must be the caller", async () => {
  await seed("w3");
  await assertFails(admin().doc(`${COLLECTION}/w3`).update(withdrawal(OTHER_ADMIN_UID)));
});

test("withdrawnAt must be the server's time", async () => {
  await seed("w4");
  await assertFails(
    admin().doc(`${COLLECTION}/w4`).update(withdrawal(ADMIN_UID, { withdrawnAt: new Date() }))
  );
});

test("a withdrawal needs a retention stamp within about a year", async () => {
  await seed("w5");
  const noStamp = withdrawal(ADMIN_UID);
  delete noStamp.expireAt;
  await assertFails(admin().doc(`${COLLECTION}/w5`).update(noStamp));
  await assertFails(
    admin().doc(`${COLLECTION}/w5`).update(withdrawal(ADMIN_UID, { expireAt: daysFromNow(400) }))
  );
});

test("a withdrawal cannot smuggle in a change to the proposal", async () => {
  await seed("w6");
  await assertFails(
    admin().doc(`${COLLECTION}/w6`).update(
      withdrawal(ADMIN_UID, { changes: { status: { old: "draft", new: "verified" } } })
    )
  );
});

test("a client cannot set a server status", async () => {
  await seed("w7");
  for (const status of ["applied", "conflict", "rejected", "inReview", "pending"]) {
    await assertFails(admin().doc(`${COLLECTION}/w7`).update(withdrawal(ADMIN_UID, { status })));
  }
});

test("an applied or withdrawn proposal cannot be withdrawn", async () => {
  await seed("w8", { status: "applied" });
  await assertFails(admin().doc(`${COLLECTION}/w8`).update(withdrawal(ADMIN_UID)));
  await seed("w9", { status: "withdrawn" });
  await assertFails(admin().doc(`${COLLECTION}/w9`).update(withdrawal(ADMIN_UID)));
});

test("a proposal in conflict or in review can be withdrawn", async () => {
  await seed("w11", {
    status: "conflict", reason: "csv-mismatch", csvValue: { status: "verified" }, expireAt: daysFromNow(90),
  });
  await assertSucceeds(admin().doc(`${COLLECTION}/w11`).update(withdrawal(ADMIN_UID)));
  await seed("w12", { status: "inReview", prNumber: 12, expireAt: daysFromNow(90) });
  await assertSucceeds(admin().doc(`${COLLECTION}/w12`).update(withdrawal(ADMIN_UID)));
});

test("a rejected proposal cannot be withdrawn", async () => {
  await seed("w13", { status: "rejected", reason: "unknown-property", expireAt: daysFromNow(365) });
  await assertFails(admin().doc(`${COLLECTION}/w13`).update(withdrawal(ADMIN_UID)));
});

// One deny per server field, each moving only that field beside a valid
// withdrawal.
test("a withdrawal cannot change prNumber, csvValue, reason or kind", async () => {
  await seed("w14", { status: "inReview", prNumber: 12, expireAt: daysFromNow(90) });
  await assertFails(admin().doc(`${COLLECTION}/w14`).update(withdrawal(ADMIN_UID, { prNumber: 13 })));
  await seed("w15", { status: "conflict", reason: "csv-mismatch", csvValue: { status: "verified" }, expireAt: daysFromNow(90) });
  await assertFails(admin().doc(`${COLLECTION}/w15`).update(withdrawal(ADMIN_UID, { csvValue: { status: "draft" } })));
  await assertFails(admin().doc(`${COLLECTION}/w15`).update(withdrawal(ADMIN_UID, { reason: "missing-row" })));
  await assertFails(admin().doc(`${COLLECTION}/w15`).update(withdrawal(ADMIN_UID, { kind: "occasionList" })));
});

test("a client cannot move a proposal into review", async () => {
  await seed("w16");
  await assertFails(admin().doc(`${COLLECTION}/w16`).update({ status: "inReview", prNumber: 1 }));
});

test("a non-admin cannot withdraw", async () => {
  await seed("w10");
  const userDb = env.authenticatedContext(USER_UID).firestore();
  await assertFails(userDb.doc(`${COLLECTION}/w10`).update(withdrawal(USER_UID)));
});

// Delete

test("nobody can delete a proposal (not even admin)", async () => {
  await seed("d1");
  await assertFails(admin().doc(`${COLLECTION}/d1`).delete());
});

// The run lock and run records of createIngredientChangePr

for (const col of ["ingredient_change_locks", "ingredient_change_runs"]) {
  test(`${col}: no client reads or writes it, admin included`, async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`${col}/seeded`).set({ owner: "run-1", expiresAt: new Date() });
    });
    await assertFails(admin().doc(`${col}/seeded`).get());
    await assertFails(admin().collection(col).get());
    await assertFails(env.authenticatedContext(USER_UID).firestore().doc(`${col}/seeded`).get());
    await assertFails(admin().doc(`${col}/new-${col}`).set({ owner: "x" }));
    await assertFails(admin().doc(`${col}/seeded`).update({ owner: "x" }));
    await assertFails(admin().doc(`${col}/seeded`).delete());
  });
}

// Step D: word-list proposals (`kind: occasionList`)

function wordList(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    kind: "occasionList",
    listKey: "christmas.titleWords",
    oldWords: ["julskinka", "lutfisk", "jansson", "julbord"],
    newWords: ["julskinka", "lutfisk", "jansson", "julbord", "all'arrabbiata", "go-to", "20 min", "entrecôte"],
    status: "pending",
    createdBy: ADMIN_UID,
    createdAt: serverTimestamp(),
    ...extra,
  };
}

test("admin can create a valid word-list proposal, with a note and a batch id", async () => {
  await assertSucceeds(admin().doc(`${COLLECTION}/o1`).set(wordList()));
  await assertSucceeds(admin().doc(`${COLLECTION}/o2`).set(wordList({ note: "Fler julord.", batchId: "b1" })));
});

test("a word-list proposal may start from an empty old list, never end in an empty new one", async () => {
  await assertSucceeds(admin().doc(`${COLLECTION}/o3`).set(wordList({ oldWords: [] })));
  await assertFails(admin().doc(`${COLLECTION}/o4`).set(wordList({ newWords: [] })));
});

test("non-admin cannot create a word-list proposal", async () => {
  await assertFails(
    env.authenticatedContext(USER_UID).firestore().doc(`${COLLECTION}/o5`).set(wordList({ createdBy: USER_UID })),
  );
});

test("a word-list proposal needs kind occasionList; an ingredient proposal carries no kind", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o6`).set(wordList({ kind: "ingredient" })));
  await assertFails(admin().doc(`${COLLECTION}/o7`).set(wordList({ kind: "other" })));
  await assertFails(admin().doc(`${COLLECTION}/o8`).set(proposal({ kind: "ingredient" })));
  await assertFails(admin().doc(`${COLLECTION}/o9`).set(proposal({ kind: "occasionList" })));
});

test("only a known list key is accepted; a tag or the stem is not a list", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o10`).set(wordList({ listKey: "christmas.tag" })));
  await assertFails(admin().doc(`${COLLECTION}/o11`).set(wordList({ listKey: "christmas.titleStem" })));
  await assertFails(admin().doc(`${COLLECTION}/o12`).set(wordList({ listKey: "christmas" })));
  await assertSucceeds(admin().doc(`${COLLECTION}/o13`).set(wordList({ listKey: "titleKeywords.snabblagatSet" })));
});

test("at most 200 words, each at most 60 characters", async () => {
  const many = (n: number) => Array.from({ length: n }, (_, i) => `ord${i}`);
  await assertSucceeds(admin().doc(`${COLLECTION}/o14`).set(wordList({ newWords: many(200) })));
  await assertFails(admin().doc(`${COLLECTION}/o15`).set(wordList({ newWords: many(201) })));
  await assertFails(admin().doc(`${COLLECTION}/o16`).set(wordList({ oldWords: many(201) })));
  await assertSucceeds(admin().doc(`${COLLECTION}/o17`).set(wordList({ newWords: ["a".repeat(60)] })));
  await assertFails(admin().doc(`${COLLECTION}/o18`).set(wordList({ newWords: ["a".repeat(61)] })));
});

test("a word must be lower case letters, digits, apostrophe or hyphen with single spaces", async () => {
  for (const bad of ["Jul", "", " jul", "jul ", "jul  skinka", "jul,skinka", "jul\nskinka", "jul@x", "jul`", "[jul]", "jul\u202e"]) {
    try {
      await assertFails(admin().doc(`${COLLECTION}/bad`).set(wordList({ newWords: ["sill", bad] })));
    } catch (err) {
      throw new Error(`accepted ${JSON.stringify(bad)}: ${err}`);
    }
  }
  await assertFails(admin().doc(`${COLLECTION}/num`).set(wordList({ newWords: ["sill", 7] })));
  await assertFails(admin().doc(`${COLLECTION}/str`).set(wordList({ newWords: "sill" })));
});

test("a word-list proposal cannot carry a server field or another status or author", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o19`).set(wordList({ prNumber: 5 })));
  await assertFails(admin().doc(`${COLLECTION}/o20`).set(wordList({ csvValue: {} })));
  await assertFails(admin().doc(`${COLLECTION}/o21`).set(wordList({ ingredientId: "garlic" })));
  await assertFails(admin().doc(`${COLLECTION}/o22`).set(wordList({ status: "inReview" })));
  await assertFails(admin().doc(`${COLLECTION}/o23`).set(wordList({ createdBy: OTHER_ADMIN_UID })));
  await assertFails(admin().doc(`${COLLECTION}/o24`).set(wordList({ note: "x".repeat(501) })));
});

test("a word-list proposal's createdAt must be the server's time", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o26`).set(wordList({ createdAt: new Date() })));
});

test("a word-list proposal's batchId must be a string of at most 100 characters", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o27`).set(wordList({ batchId: "b".repeat(101) })));
});

test("a word-list proposal's batchId cannot be a list", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o28`).set(wordList({ batchId: ["b1"] })));
});

test("a word-list proposal's note cannot be a list", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o29`).set(wordList({ note: ["x"] })));
});

test("an empty string is not an empty old word list", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o30`).set(wordList({ oldWords: "" })));
});

test("an empty map is not an empty old word list", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o31`).set(wordList({ oldWords: {} })));
});

test("old words are held to the same word shape as new words", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o32`).set(wordList({ oldWords: ["sill", "Jul"] })));
});

test("an old word may not hide a comma", async () => {
  await assertFails(admin().doc(`${COLLECTION}/o33`).set(wordList({ oldWords: ["sill", "jul,skinka"] })));
});

test("a full list of 200 words of 60 characters is accepted, old and new", async () => {
  const full = Array.from({ length: 200 }, (_, i) => `${String(i).padStart(3, "0")}${"å".repeat(57)}`);
  await assertSucceeds(admin().doc(`${COLLECTION}/o34`).set(wordList({ oldWords: full, newWords: full })));
});

test("a word-list proposal is withdrawn like an ingredient proposal, and its words cannot be edited", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`${COLLECTION}/o25`).set({ ...wordList(), createdAt: new Date() });
  });
  await assertFails(admin().doc(`${COLLECTION}/o25`).update({ newWords: ["sill"] }));
  await assertFails(admin().doc(`${COLLECTION}/o25`).update(withdrawal(ADMIN_UID, { newWords: ["sill"] })));
  await assertSucceeds(admin().doc(`${COLLECTION}/o25`).update(withdrawal(ADMIN_UID)));
});

async function run(): Promise<void> {
  console.log("Ingredient change request rules tests\n");
  console.log("=====================================\n");
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
