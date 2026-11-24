/**
 * Firestore rules tests for BUT-2486 part 5: users/{uid}/meal_boxes.
 *
 * Cooked food kept as boxes in the fridge or freezer. Rules contract:
 *   - Only the owner reads, writes and deletes; a guest (anonymous sign-in)
 *     does so on its own uid, as for the pantry.
 *   - A write carries only the model's keys, each within its bound, and
 *     `updatedAt` is the server's time.
 *   - `count` may be absent: a lunch take recreates a deleted box without one.
 *
 * Every write map below is the one the app sends
 * (`FirebaseMealBoxRepository.toFirestore`, `takeWriteMap`, `setCount`,
 * `foldTakes`), so a refusal here is a refusal in production.
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/meal-boxes-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// The client SDK's sentinels: the test context only recognises its own.
import { deleteField, serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-meal-boxes";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "user-owner";
const OTHER = "user-other";
const GUEST = "user-guest";
const doc = (uid: string, id: string): string => `users/${uid}/meal_boxes/${id}`;

let env: RulesTestEnvironment;
let seq = 0;
const freshId = (): string => `box${Date.now()}${seq++}`;

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

/** `FirebaseMealBoxRepository.toFirestore` (add). */
function added(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    recipeTitle: "Chili",
    location: "fridge",
    storedOn: new Date(),
    count: 2,
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

/** `FirebaseMealBoxRepository.takeWriteMap`, written with merge. */
function take(portions: number | null): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    recipeTitle: "Chili",
    location: "freezer",
    storedOn: new Date(),
    takes: { "2026-11-25": portions === null ? deleteField() : portions },
    updatedAt: serverTimestamp(),
  };
}

const owner = () => env.authenticatedContext(OWNER).firestore();

async function seed(uid: string, id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(doc(uid, id)).set({
      recipeId: "recipe-1",
      recipeTitle: "Chili",
      location: "fridge",
      storedOn: new Date(),
      count: 3,
      takes: { "2026-11-20": 1 },
      updatedAt: new Date(),
    });
  });
}

// ── the app's own writes ──

test("the owner adds a box", async () => {
  await assertSucceeds(owner().doc(doc(OWNER, freshId())).set(added()));
});

test("a box without a recipe id is accepted", async () => {
  const data = added();
  delete data.recipeId;
  await assertSucceeds(owner().doc(doc(OWNER, freshId())).set(data));
});

test("a lunch take on an existing box is accepted", async () => {
  const id = freshId();
  await seed(OWNER, id);
  await assertSucceeds(owner().doc(doc(OWNER, id)).set(take(2), { merge: true }));
});

test("a lunch take recreates a deleted box without a count", async () => {
  await assertSucceeds(
    owner().doc(doc(OWNER, freshId())).set(take(1), { merge: true }),
  );
});

test("giving a lunch back removes its take", async () => {
  const id = freshId();
  await seed(OWNER, id);
  await assertSucceeds(owner().doc(doc(OWNER, id)).set(take(null), { merge: true }));
});

test("the owner corrects the count", async () => {
  const id = freshId();
  await seed(OWNER, id);
  await assertSucceeds(
    owner().doc(doc(OWNER, id)).update({ count: 0, updatedAt: serverTimestamp() }),
  );
});

test("eaten lunches are folded into the count", async () => {
  const id = freshId();
  await seed(OWNER, id);
  await assertSucceeds(
    owner()
      .doc(doc(OWNER, id))
      .update({
        "count": 2,
        "takes.2026-11-20": deleteField(),
        "updatedAt": serverTimestamp(),
      }),
  );
});

test("the owner reads and deletes their boxes", async () => {
  const id = freshId();
  await seed(OWNER, id);
  await assertSucceeds(owner().collection(`users/${OWNER}/meal_boxes`).limit(200).get());
  await assertSucceeds(owner().doc(doc(OWNER, id)).delete());
});

test("a guest keeps boxes on its own uid", async () => {
  const guest = env
    .authenticatedContext(GUEST, {
      firebase: { sign_in_provider: "anonymous", identities: {} },
    })
    .firestore();
  await assertSucceeds(guest.doc(doc(GUEST, freshId())).set(added()));
  await assertFails(guest.doc(doc(OWNER, freshId())).set(added()));
});

// ── who ──

test("another user can neither read, write nor delete", async () => {
  const id = freshId();
  await seed(OWNER, id);
  const other = env.authenticatedContext(OTHER).firestore();
  await assertFails(other.doc(doc(OWNER, id)).get());
  await assertFails(other.doc(doc(OWNER, freshId())).set(added()));
  await assertFails(other.doc(doc(OWNER, id)).set(take(1), { merge: true }));
  await assertFails(other.doc(doc(OWNER, id)).delete());
});

test("a signed-out client can do nothing", async () => {
  const id = freshId();
  await seed(OWNER, id);
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(anon.doc(doc(OWNER, id)).get());
  await assertFails(anon.doc(doc(OWNER, freshId())).set(added()));
});

// ── bounds, one variable at a time ──

const refused: [string, Record<string, unknown>][] = [
  ["an unknown key", { note: "x" }],
  ["a count above 99", { count: 100 }],
  ["a negative count", { count: -1 }],
  ["a count that is not an int", { count: "2" }],
  ["a fractional count", { count: 2.5 }],
  ["takes as a list", { takes: [1] }],
  ["takes as a string", { takes: "abc" }],
  ["a recipe id that is not a string", { recipeId: ["r"] }],
  ["a title that is not a string", { recipeTitle: ["Chili"] }],
  ["an unknown location", { location: "pantry" }],
  ["an empty title", { recipeTitle: "" }],
  ["a title over 200 characters", { recipeTitle: "x".repeat(201) }],
  ["a recipe id over 128 characters", { recipeId: "r".repeat(129) }],
  ["a storedOn that is not a timestamp", { storedOn: "2026-11-24" }],
  ["an updatedAt from the device", { updatedAt: new Date() }],
  ["takes that is not a map", { takes: 3 }],
  [
    "more than 60 takes",
    {
      takes: Object.fromEntries(
        Array.from({ length: 61 }, (_, i) => [`k${i}`, 1]),
      ),
    },
  ],
];

for (const [what, override] of refused) {
  test(`${what} is refused`, async () => {
    await assertFails(owner().doc(doc(OWNER, freshId())).set(added(override)));
  });
}

test("the boundary values are accepted", async () => {
  await assertSucceeds(
    owner()
      .doc(doc(OWNER, freshId()))
      .set(
        added({
          count: 99,
          recipeTitle: "x".repeat(200),
          recipeId: "r".repeat(128),
          takes: Object.fromEntries(
            Array.from({ length: 60 }, (_, i) => [`k${i}`, 1]),
          ),
        }),
      ),
  );
  await assertSucceeds(owner().doc(doc(OWNER, freshId())).set(added({ count: 0 })));
});

async function run(): Promise<void> {
  console.log("Meal boxes rules tests (BUT-2486 part 5)\n");
  console.log("========================================\n");
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
