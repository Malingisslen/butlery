/**
 * Firestore rules tests for P5-U27b: recipe_suggestions/{id}.
 *
 * A change to someone else's shared recipe, kept 7 days as a suggestion the
 * owner accepts or dismisses (produktregler.md:103, :241; PQ-02 = A). Rules
 * contract under test:
 *   - Only the suggester and the recipe's owner read a suggestion; a third
 *     member of the same recipe, another user and a signed-out client do not.
 *   - Only the suggester creates it, as themselves, never to their own recipe,
 *     and only for a recipe the owner has shared with them
 *     (users/{owner}/recipes/{id}.socialData.memberPermissions has their uid).
 *   - A create carries exactly the model's fields, is pending, and expires
 *     exactly 7 days after it was made, in the future and no more than 7 days
 *     (plus one hour of device clock slack) from the server's clock.
 *   - Only the owner decides it, once: pending to accepted or dismissed, with
 *     a server-set decidedAt and nothing else changed.
 *   - Nobody deletes it from a client (TTL and the deletion cascade do).
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/recipe-suggestions-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-recipe-suggestions";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "user-owner";
const MEMBER = "user-member";
const THIRD_MEMBER = "user-third-member";
const STRANGER = "user-stranger";
const RECIPE = "recipe-shared";
const UNSHARED = "recipe-unshared";
const DAY_MS = 24 * 60 * 60 * 1000;
const doc = (id: string): string => `recipe_suggestions/${id}`;

let env: RulesTestEnvironment;
let seq = 0;
/** A fresh id per create, so a create is never evaluated as an update. */
const freshId = (): string => `s-${Date.now()}-${seq++}`;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    await db.doc(`users/${OWNER}/recipes/${RECIPE}`).set({
      title: "Pannkakor",
      socialData: {
        ownerId: OWNER,
        memberPermissions: { [MEMBER]: "edit", [THIRD_MEMBER]: "view" },
      },
    });
    await db.doc(`users/${OWNER}/recipes/${UNSHARED}`).set({
      title: "Hemligt",
    });
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

/** The row the app writes (RecipeSuggestion.toFirestore). */
function suggestion(
  suggesterId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const createdAt = new Date();
  return {
    recipeId: RECIPE,
    ownerId: OWNER,
    suggesterId,
    suggesterName: "Mia",
    suggestion: { title: "Pannkakor med mer smör", editCount: 3 },
    status: "pending",
    createdAt,
    expiresAt: new Date(createdAt.getTime() + 7 * DAY_MS),
    ...overrides,
  };
}

async function seed(id: string, overrides: Record<string, unknown> = {}) {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(doc(id)).set(suggestion(MEMBER, overrides));
  });
}

// ── create ──

test("a member suggests a change to the owner's shared recipe", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  await assertSucceeds(ctx.firestore().doc(doc(freshId())).set(suggestion(MEMBER)));
});

test("a read-only member may suggest too (produktregler.md:241)", async () => {
  const ctx = env.authenticatedContext(THIRD_MEMBER);
  await assertSucceeds(
    ctx.firestore().doc(doc(freshId())).set(suggestion(THIRD_MEMBER)),
  );
});

test("nobody suggests in someone else's name", async () => {
  const ctx = env.authenticatedContext(THIRD_MEMBER);
  await assertFails(ctx.firestore().doc(doc(freshId())).set(suggestion(MEMBER)));
});

test("someone the recipe is not shared with cannot suggest", async () => {
  const ctx = env.authenticatedContext(STRANGER);
  await assertFails(
    ctx.firestore().doc(doc(freshId())).set(suggestion(STRANGER)),
  );
});

test("an unshared recipe, or one that does not exist, takes no suggestion", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(suggestion(MEMBER, { recipeId: UNSHARED })),
  );
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(suggestion(MEMBER, { recipeId: "no-such-recipe" })),
  );
});

test("a suggestion naming the wrong owner is refused", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(suggestion(MEMBER, { ownerId: STRANGER })),
  );
});

test("the owner cannot suggest to their own recipe", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(doc(freshId())).set(suggestion(OWNER)));
});

test("a new suggestion is pending, never already decided", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(suggestion(MEMBER, { status: "accepted" })),
  );
});

test("an unknown field is refused", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(suggestion(MEMBER, { participants: { [MEMBER]: "owner" } })),
  );
});

test("a suggestion cannot be kept longer than 7 days", async () => {
  const ctx = env.authenticatedContext(MEMBER);
  const createdAt = new Date();
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(
        suggestion(MEMBER, {
          createdAt,
          expiresAt: new Date(createdAt.getTime() + 30 * DAY_MS),
        }),
      ),
  );
  // Seven days, but from a createdAt a month ahead of the server's clock.
  const ahead = new Date(Date.now() + 30 * DAY_MS);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(freshId()))
      .set(
        suggestion(MEMBER, {
          createdAt: ahead,
          expiresAt: new Date(ahead.getTime() + 7 * DAY_MS),
        }),
      ),
  );
});

// ── read ──

test("the suggester and the owner read it", async () => {
  await seed("seeded-read");
  await assertSucceeds(
    env.authenticatedContext(MEMBER).firestore().doc(doc("seeded-read")).get(),
  );
  await assertSucceeds(
    env.authenticatedContext(OWNER).firestore().doc(doc("seeded-read")).get(),
  );
});

test("another member of the same recipe, a stranger and a signed-out client do not", async () => {
  await seed("seeded-private");
  for (const ctx of [
    env.authenticatedContext(THIRD_MEMBER),
    env.authenticatedContext(STRANGER),
    env.unauthenticatedContext(),
  ]) {
    await assertFails(ctx.firestore().doc(doc("seeded-private")).get());
  }
});

test("each party lists only by their own id", async () => {
  await seed("seeded-list");
  const member = env.authenticatedContext(MEMBER).firestore();
  await assertSucceeds(
    member
      .collection("recipe_suggestions")
      .where("suggesterId", "==", MEMBER)
      .where("recipeId", "==", RECIPE)
      .get(),
  );
  const owner = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(
    owner
      .collection("recipe_suggestions")
      .where("ownerId", "==", OWNER)
      .where("recipeId", "==", RECIPE)
      .get(),
  );
  const third = env.authenticatedContext(THIRD_MEMBER).firestore();
  await assertFails(
    third
      .collection("recipe_suggestions")
      .where("recipeId", "==", RECIPE)
      .get(),
  );
});

// ── decide ──

test("the owner accepts or dismisses a pending suggestion", async () => {
  await seed("seeded-accept");
  await seed("seeded-dismiss");
  const owner = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(
    owner
      .doc(doc("seeded-accept"))
      .update({ status: "accepted", decidedAt: serverTimestamp() }),
  );
  await assertSucceeds(
    owner
      .doc(doc("seeded-dismiss"))
      .update({ status: "dismissed", decidedAt: serverTimestamp() }),
  );
});

test("the suggester and others cannot decide it", async () => {
  await seed("seeded-not-theirs");
  for (const uid of [MEMBER, THIRD_MEMBER, STRANGER]) {
    await assertFails(
      env
        .authenticatedContext(uid)
        .firestore()
        .doc(doc("seeded-not-theirs"))
        .update({ status: "accepted", decidedAt: serverTimestamp() }),
    );
  }
});

test("a decision is made once, and changes nothing else", async () => {
  await seed("seeded-once", { status: "dismissed" });
  await seed("seeded-extra");
  const owner = env.authenticatedContext(OWNER).firestore();
  await assertFails(
    owner
      .doc(doc("seeded-once"))
      .update({ status: "accepted", decidedAt: serverTimestamp() }),
  );
  await assertFails(
    owner.doc(doc("seeded-extra")).update({
      status: "accepted",
      decidedAt: serverTimestamp(),
      expiresAt: new Date(Date.now() + 90 * DAY_MS),
    }),
  );
  await assertFails(
    owner
      .doc(doc("seeded-extra"))
      .update({ status: "pending", decidedAt: serverTimestamp() }),
  );
  await assertFails(
    owner
      .doc(doc("seeded-extra"))
      .update({ status: "accepted", decidedAt: new Date(2020, 0, 1) }),
  );
});

// ── delete ──

test("nobody deletes a suggestion from a client", async () => {
  await seed("seeded-delete");
  for (const uid of [OWNER, MEMBER]) {
    await assertFails(
      env.authenticatedContext(uid).firestore().doc(doc("seeded-delete")).delete(),
    );
  }
});

async function run(): Promise<void> {
  console.log("Recipe suggestions rules tests (P5-U27b)\n");
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
