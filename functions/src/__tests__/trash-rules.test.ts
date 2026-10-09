/**
 * Firestore rules tests for BUT-907: users/{uid}/trash.
 *
 * An own recipe the user deleted, kept 30 days behind "Återställ". Rules
 * contract under test:
 *   - Only the owner reads and creates; nobody updates; the owner or an admin
 *     deletes, and an admin still cannot read.
 *   - A create carries exactly the contract's fields, names the owner, uses
 *     the recipe's id as both document id and `sourceId`, and expires exactly
 *     30 days after a `deletedAt` taken from the client's clock, at most one
 *     hour off the server's clock.
 *   - `payload` carries no sharing state (`socialData`, `grants`,
 *     `blockHeldUserIds`, `blockHeld`).
 *   - The app's two batches: trash + recipe delete, and restore + trash delete.
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/trash-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { Timestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-trash";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "user-owner";
const OTHER = "user-other";
const ADMIN = "user-admin";
const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const trashDoc = (uid: string, id: string): string => `users/${uid}/trash/${id}`;
const recipeDoc = (uid: string, id: string): string => `users/${uid}/recipes/${id}`;

let env: RulesTestEnvironment;
let seq = 0;
/** A fresh id per create, so a create is never evaluated as an update. */
const RUN = Date.now().toString(36);
const freshId = (): string => `r-${RUN}-${seq++}`;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN}`).set({ role: "admin" });
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

/** The recipe map the app stores (`RecipeSerialization.toFirestore`), trimmed. */
function recipeMap(ownerId: string): Record<string, unknown> {
  return {
    core: {
      id: "ignored",
      title: "Kycklinggryta",
      createdBy: ownerId,
      imageUrls: [],
      tagResult: {
        tags: [],
        allergenStatus: { gluten: "free" },
        dietaryStatus: { vegan: "contains" },
        coverage: 1.0,
        unknownIngredients: [],
        generatedAt: Timestamp.fromDate(new Date()),
        generatorVersion: "test",
        isPartial: false,
        schemaVersion: 1,
      },
    },
    type: 0,
  };
}

/** The row TrashItem.toFirestore writes, Timestamps from the client's clock. */
function item(
  ownerId: string,
  id: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const deletedAt = new Date();
  return {
    kind: "recipe",
    ownerId,
    sourceId: id,
    title: "Kycklinggryta",
    thumbnailUrl: null,
    payload: { ...recipeMap(ownerId), rev: 3 },
    deletedAt: Timestamp.fromDate(deletedAt),
    expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 30 * DAY_MS)),
    ...overrides,
  };
}

async function seedTrash(uid: string, id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(trashDoc(uid, id)).set(item(uid, id));
  });
}

async function seedRecipe(uid: string, id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(recipeDoc(uid, id)).set(recipeMap(uid));
  });
}

async function createAs(uid: string, ownerPath: string, id: string, row: Record<string, unknown>) {
  return env.authenticatedContext(uid).firestore().doc(trashDoc(ownerPath, id)).set(row);
}

// ── create ──

test("the owner trashes their own recipe (the client's write shape)", async () => {
  const id = freshId();
  await assertSucceeds(createAs(OWNER, OWNER, id, item(OWNER, id)));
});

test("a thumbnail URL is accepted, and a legacy recipe without createdBy too", async () => {
  const id = freshId();
  await assertSucceeds(
    createAs(OWNER, OWNER, id, item(OWNER, id, { thumbnailUrl: "https://x/t.jpg" })),
  );
  const id2 = freshId();
  const legacy = recipeMap(OWNER);
  delete (legacy.core as Record<string, unknown>).createdBy;
  await assertSucceeds(createAs(OWNER, OWNER, id2, item(OWNER, id2, { payload: legacy })));
});

test("a legacy recipe with an empty createdBy is accepted", async () => {
  const id = freshId();
  const legacy = recipeMap(OWNER);
  (legacy.core as Record<string, unknown>).createdBy = "";
  await assertSucceeds(createAs(OWNER, OWNER, id, item(OWNER, id, { payload: legacy })));
});

test("a title that is not a string is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { title: ["a"] })));
});

test("another user cannot put anything in the owner's trash", async () => {
  const id = freshId();
  await assertFails(createAs(OTHER, OWNER, id, item(OWNER, id)));
  await assertFails(createAs(OTHER, OWNER, id, item(OTHER, id)));
});

test("an unknown field is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { note: "x" })));
});

test("ownerId other than the uid is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { ownerId: OTHER })));
});

test("sourceId other than the document id is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { sourceId: "other-recipe" })));
});

test("a 31-day expiry is refused", async () => {
  const id = freshId();
  const deletedAt = new Date();
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: Timestamp.fromDate(deletedAt),
      expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 31 * DAY_MS)),
    })),
  );
});

test("a 29-day expiry is refused", async () => {
  const id = freshId();
  const deletedAt = new Date();
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: Timestamp.fromDate(deletedAt),
      expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 29 * DAY_MS)),
    })),
  );
});

test("a deletedAt two hours in the past is refused", async () => {
  const id = freshId();
  const deletedAt = new Date(Date.now() - 2 * HOUR_MS);
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: Timestamp.fromDate(deletedAt),
      expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 30 * DAY_MS)),
    })),
  );
});

test("a deletedAt two hours ahead is refused (expiry past 721 h)", async () => {
  const id = freshId();
  const deletedAt = new Date(Date.now() + 2 * HOUR_MS);
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: Timestamp.fromDate(deletedAt),
      expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 30 * DAY_MS)),
    })),
  );
});

for (const minutes of [50, -50]) {
  test(`a phone clock ${minutes} min off the server's is accepted`, async () => {
    const id = freshId();
    const deletedAt = new Date(Date.now() + minutes * 60_000);
    await assertSucceeds(
      createAs(OWNER, OWNER, id, item(OWNER, id, {
        deletedAt: Timestamp.fromDate(deletedAt),
        expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 30 * DAY_MS)),
      })),
    );
  });
}

test("an expiry one hour past deletedAt + 30 days is refused", async () => {
  // Inside the 721 h bound, so only the equality can refuse it.
  const id = freshId();
  const deletedAt = new Date(Date.now() - 30 * 60_000);
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: Timestamp.fromDate(deletedAt),
      expireAt: Timestamp.fromDate(new Date(deletedAt.getTime() + 30 * DAY_MS + HOUR_MS)),
    })),
  );
});

test("a signed-out client can neither create, read nor delete a copy", async () => {
  const id = freshId();
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(anon.doc(trashDoc(OWNER, id)).set(item(OWNER, id)));
  await seedTrash(OWNER, id);
  await assertFails(anon.doc(trashDoc(OWNER, id)).get());
  await assertFails(anon.doc(trashDoc(OWNER, id)).delete());
});

test("timestamps sent as strings are refused", async () => {
  const id = freshId();
  const deletedAt = new Date();
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, {
      deletedAt: deletedAt.toISOString(),
      expireAt: new Date(deletedAt.getTime() + 30 * DAY_MS).toISOString(),
    })),
  );
});

for (const banned of ["socialData", "grants", "blockHeldUserIds", "blockHeld"]) {
  test(`a payload carrying ${banned} is refused`, async () => {
    const id = freshId();
    const payload = { ...recipeMap(OWNER), [banned]: { [OTHER]: "read" } };
    await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { payload })));
  });
}

test("a payload naming another owner in core.createdBy is refused", async () => {
  const id = freshId();
  await assertFails(
    createAs(OWNER, OWNER, id, item(OWNER, id, { payload: recipeMap(OTHER) })),
  );
});

test("a payload that is not a map is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { payload: "x" })));
});

test("a kind outside the list is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { kind: "shoppingList" })));
});

test("a title over 200 characters is refused; exactly 200 passes", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { title: "a".repeat(201) })));
  const id2 = freshId();
  await assertSucceeds(createAs(OWNER, OWNER, id2, item(OWNER, id2, { title: "a".repeat(200) })));
});

test("a title the app caps at 200 UTF-16 units passes, in Swedish or emoji", async () => {
  // TrashItem.capTitle counts UTF-16 code units; the rule must not count bytes.
  const id = freshId();
  await assertSucceeds(createAs(OWNER, OWNER, id, item(OWNER, id, { title: "å".repeat(200) })));
  const id2 = freshId();
  await assertSucceeds(createAs(OWNER, OWNER, id2, item(OWNER, id2, { title: "🍲".repeat(100) })));
});

test("a thumbnailUrl that is not a string is refused", async () => {
  const id = freshId();
  await assertFails(createAs(OWNER, OWNER, id, item(OWNER, id, { thumbnailUrl: 7 })));
});

// ── read ──

test("the owner reads and lists their trash", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(db.doc(trashDoc(OWNER, id)).get());
  await assertSucceeds(db.collection(`users/${OWNER}/trash`).get());
});

test("another user can neither read nor list it", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  const db = env.authenticatedContext(OTHER).firestore();
  await assertFails(db.doc(trashDoc(OWNER, id)).get());
  await assertFails(db.collection(`users/${OWNER}/trash`).get());
});

test("an admin cannot read it", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  const db = env.authenticatedContext(ADMIN).firestore();
  await assertFails(db.doc(trashDoc(OWNER, id)).get());
});

// ── update / delete ──

test("nobody can change a copy, not even the owner", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  const db = env.authenticatedContext(OWNER).firestore();
  await assertFails(db.doc(trashDoc(OWNER, id)).update({ title: "Ny" }));
});

test("the owner deletes a copy; another user cannot", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  await assertFails(env.authenticatedContext(OTHER).firestore().doc(trashDoc(OWNER, id)).delete());
  await assertSucceeds(env.authenticatedContext(OWNER).firestore().doc(trashDoc(OWNER, id)).delete());
});

test("an admin deletes a copy", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  await assertSucceeds(env.authenticatedContext(ADMIN).firestore().doc(trashDoc(OWNER, id)).delete());
});

// ── the app's batches ──

test("the owner's batch set(trash) + delete(recipe) passes", async () => {
  const id = freshId();
  await seedRecipe(OWNER, id);
  const db = env.authenticatedContext(OWNER).firestore();
  const batch = db.batch();
  batch.set(db.doc(trashDoc(OWNER, id)), item(OWNER, id));
  batch.delete(db.doc(recipeDoc(OWNER, id)));
  await assertSucceeds(batch.commit());
});

test("the same batch by another user is refused", async () => {
  const id = freshId();
  await seedRecipe(OWNER, id);
  const db = env.authenticatedContext(OTHER).firestore();
  const batch = db.batch();
  batch.set(db.doc(trashDoc(OWNER, id)), item(OWNER, id));
  batch.delete(db.doc(recipeDoc(OWNER, id)));
  await assertFails(batch.commit());
});

test("a restore batch set(recipe from the stored payload) + delete(trash) passes", async () => {
  const id = freshId();
  await seedTrash(OWNER, id);
  const db = env.authenticatedContext(OWNER).firestore();
  let stored: Record<string, unknown> | undefined;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await ctx.firestore().doc(trashDoc(OWNER, id)).get();
    stored = snap.data()?.payload as Record<string, unknown> | undefined;
  });
  if (!(stored && (stored.core as Record<string, unknown>).tagResult)) {
    throw new Error("premise: the stored payload carries core.tagResult");
  }
  const batch = db.batch();
  batch.set(db.doc(recipeDoc(OWNER, id)), stored);
  batch.delete(db.doc(trashDoc(OWNER, id)));
  await assertSucceeds(batch.commit());
});

async function run(): Promise<void> {
  console.log("Trash rules tests (BUT-907)\n");
  console.log("===========================\n");
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
