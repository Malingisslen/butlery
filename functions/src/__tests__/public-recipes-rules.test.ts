/**
 * Firestore rules tests for kärnflöde steg 10E: recipes on the profile.
 *
 * Contract under test:
 *   - `users/{uid}/public_recipes/{id}` is read by the owner, by any signed-in
 *     non-guest the owner has not blocked while the profile is not hidden,
 *     and by an admin. No client creates, updates or deletes it, an admin
 *     included.
 *   - Turning `core.showOnProfile` on needs a verified, matured adult. Turning
 *     it off, or a save that leaves it as it was, needs nothing more.
 *   - `public_profiles.publicRecipeCount` is not client-writable: 0 or absent on
 *     create, untouched on update.
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/public-recipes-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { Timestamp, deleteField } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-public-recipes";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "owner";
const READER = "reader";
const BLOCKED = "blocked-reader";
const GUEST = "guest";
const ADMIN = "admin-user";
const MINOR = "minor";
const NEWBIE = "newbie";
const HOUR_MS = 60 * 60 * 1000;

const ADULT = { ageCompliant: true, email_verified: true, firebase: { sign_in_provider: "password" } };

let env: RulesTestEnvironment;
let seq = 0;
const RUN = Date.now().toString(36);
const freshId = (): string => `r-${RUN}-${seq++}`;

const copyDoc = (uid: string, id: string) => `users/${uid}/public_recipes/${id}`;
const recipeDoc = (uid: string, id: string) => `users/${uid}/recipes/${id}`;

function recipeMap(owner: string, core: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    core: {
      title: "Kanelbullar",
      createdBy: owner,
      imageUrls: [],
      tagResult: {
        tags: [],
        allergenStatus: { gluten: "contains" },
        dietaryStatus: {},
        coverage: 1.0,
        unknownIngredients: [],
        generatedAt: Timestamp.fromDate(new Date()),
        generatorVersion: "test",
        isPartial: false,
        schemaVersion: 1,
      },
      ...core,
    },
    type: 0,
  };
}

async function setup(): Promise<void> {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(RULES_PATH, "utf8"), host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const old = Timestamp.fromDate(new Date(Date.now() - 48 * HOUR_MS));
    await db.doc(`admins/${ADMIN}`).set({ role: "admin" });
    await db.doc(`users/${OWNER}`).set({ createdAt: old });
    await db.doc(`users/${MINOR}`).set({ createdAt: old, isMinor: true });
    await db.doc(`users/${NEWBIE}`).set({ createdAt: Timestamp.fromDate(new Date()) });
    await db.doc(`public_profiles/${OWNER}`).set({ displayName: "Anna", isSearchable: true, publicRecipeCount: 1 });
    await db.doc(`public_profiles/hidden-owner`).set({ displayName: "Dold", isHidden: true });
    await db.doc(`blocks/${OWNER}_${BLOCKED}`).set({ blockerId: OWNER, blockedId: BLOCKED });
    await db.doc(copyDoc(OWNER, "kb")).set({ id: "kb", ownerId: OWNER, title: "Kanelbullar" });
    await db.doc(copyDoc("hidden-owner", "x")).set({ id: "x", ownerId: "hidden-owner", title: "X" });
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
const test = (name: string, fn: TestFn) => tests.push({ name, fn });

const as = (uid: string, token: Record<string, unknown> = ADULT) =>
  env.authenticatedContext(uid, token).firestore();
const guest = () =>
  env.authenticatedContext(GUEST, { firebase: { sign_in_provider: "anonymous" } }).firestore();

// ── Reading the copy ──

test("the owner reads their own copy, even while the profile is hidden", async () => {
  // A hidden owner fails the reader branch, so only the owner branch allows this.
  await assertSucceeds(as("hidden-owner").doc(copyDoc("hidden-owner", "x")).get());
});

test("a signed-in reader reads the copy and lists the profile", async () => {
  await assertSucceeds(as(READER).doc(copyDoc(OWNER, "kb")).get());
  await assertSucceeds(as(READER).collection(`users/${OWNER}/public_recipes`).get());
});

test("a guest cannot read the copy", async () => {
  await assertFails(guest().doc(copyDoc(OWNER, "kb")).get());
});

test("someone the owner blocked cannot read the copy", async () => {
  await assertFails(as(BLOCKED).collection(`users/${OWNER}/public_recipes`).get());
});

test("a hidden profile's copies are not readable", async () => {
  await assertFails(as(READER).doc(copyDoc("hidden-owner", "x")).get());
});

test("signed out, nothing is readable", async () => {
  await assertFails(env.unauthenticatedContext().firestore().doc(copyDoc(OWNER, "kb")).get());
});

test("the source recipe stays closed to a reader", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(recipeDoc(OWNER, "kb")).set(recipeMap(OWNER, { showOnProfile: true }));
  });
  await assertFails(as(READER).doc(recipeDoc(OWNER, "kb")).get());
});

// ── Writing the copy ──

test("no client writes a copy, the owner included", async () => {
  const id = freshId();
  await assertFails(as(OWNER).doc(copyDoc(OWNER, id)).set({ title: "Egen" }));
  await assertFails(as(OWNER).doc(copyDoc(OWNER, "kb")).update({ title: "Ändrad" }));
  await assertFails(as(OWNER).doc(copyDoc(OWNER, "kb")).delete());
  await assertFails(as(READER).doc(copyDoc(OWNER, id)).set({ title: "Falsk" }));
});

test("an admin reads a copy but cannot delete it", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(copyDoc(OWNER, "mod")).set({ id: "mod", ownerId: OWNER });
  });
  await assertSucceeds(as(ADMIN).doc(copyDoc(OWNER, "mod")).get());
  await assertFails(as(ADMIN).doc(copyDoc(OWNER, "mod")).delete());
  // A hidden profile fails the reader branch, so only the admin branch allows this.
  await assertSucceeds(as(ADMIN).doc(copyDoc("hidden-owner", "x")).get());
});

// ── The opt-in on the recipe ──

test("a verified adult creates a recipe shown on the profile", async () => {
  await assertSucceeds(
    as(OWNER).doc(recipeDoc(OWNER, freshId())).set(recipeMap(OWNER, { showOnProfile: true })),
  );
});

test("a verified adult turns it on and off on an existing recipe", async () => {
  const id = freshId();
  await assertSucceeds(as(OWNER).doc(recipeDoc(OWNER, id)).set(recipeMap(OWNER)));
  await assertSucceeds(as(OWNER).doc(recipeDoc(OWNER, id)).update({ "core.showOnProfile": true }));
  await assertSucceeds(as(OWNER).doc(recipeDoc(OWNER, id)).update({ "core.showOnProfile": false }));
});

test("a minor cannot turn it on", async () => {
  const id = freshId();
  const db = as(MINOR);
  await assertSucceeds(db.doc(recipeDoc(MINOR, id)).set(recipeMap(MINOR)));
  await assertFails(db.doc(recipeDoc(MINOR, id)).update({ "core.showOnProfile": true }));
  await assertFails(db.doc(recipeDoc(MINOR, freshId())).set(recipeMap(MINOR, { showOnProfile: true })));
});

test("an account without the age claim cannot turn it on", async () => {
  const db = as(OWNER, { email_verified: true, firebase: { sign_in_provider: "password" } });
  await assertFails(db.doc(recipeDoc(OWNER, freshId())).set(recipeMap(OWNER, { showOnProfile: true })));
});

test("a guest cannot turn it on", async () => {
  await assertFails(
    guest().doc(recipeDoc(GUEST, freshId())).set(recipeMap(GUEST, { showOnProfile: true })),
  );
});

test("an unverified account younger than an hour cannot turn it on", async () => {
  const db = as(NEWBIE, { ageCompliant: true, email_verified: false, firebase: { sign_in_provider: "password" } });
  await assertFails(db.doc(recipeDoc(NEWBIE, freshId())).set(recipeMap(NEWBIE, { showOnProfile: true })));
  await assertSucceeds(db.doc(recipeDoc(NEWBIE, freshId())).set(recipeMap(NEWBIE)));
});

test("a minor's ordinary save of a recipe already shown is not refused", async () => {
  const id = freshId();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(recipeDoc(MINOR, id)).set(recipeMap(MINOR, { showOnProfile: true }));
  });
  await assertSucceeds(as(MINOR).doc(recipeDoc(MINOR, id)).update({ "core.title": "Bullar" }));
  await assertSucceeds(as(MINOR).doc(recipeDoc(MINOR, id)).update({ "core.showOnProfile": false }));
});

test("a minor cannot turn it back on after deleting the field", async () => {
  const id = freshId();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(recipeDoc(MINOR, id)).set(recipeMap(MINOR, { showOnProfile: true }));
  });
  await assertSucceeds(as(MINOR).doc(recipeDoc(MINOR, id)).update({ "core.showOnProfile": deleteField() }));
  await assertFails(as(MINOR).doc(recipeDoc(MINOR, id)).update({ "core.showOnProfile": true }));
});

// ── The counter ──

test("the owner cannot change publicRecipeCount", async () => {
  await assertFails(as(OWNER).doc(`public_profiles/${OWNER}`).update({ publicRecipeCount: 50 }));
  await assertFails(as(OWNER).doc(`public_profiles/${OWNER}`).update({ publicRecipeCount: deleteField() }));
  await assertSucceeds(as(OWNER).doc(`public_profiles/${OWNER}`).update({ displayName: "Anna L" }));
});

test("another user cannot change publicRecipeCount through the friendsCount limb", async () => {
  await assertFails(as(READER).doc(`public_profiles/${OWNER}`).update({ publicRecipeCount: 2 }));
});

test("the owner cannot delete their profile, so a recreate cannot unhide it or reset the count", async () => {
  await assertFails(as("hidden-owner").doc("public_profiles/hidden-owner").delete());
  await assertFails(as(OWNER).doc(`public_profiles/${OWNER}`).delete());
});

test("a profile is created with no count or 0, never more", async () => {
  await assertSucceeds(
    as("new-a").doc("public_profiles/new-a").set({ displayName: "A", isSearchable: false }),
  );
  await assertSucceeds(
    as("new-b").doc("public_profiles/new-b").set({ displayName: "B", isSearchable: false, publicRecipeCount: 0 }),
  );
  await assertFails(
    as("new-c").doc("public_profiles/new-c").set({ displayName: "C", isSearchable: false, publicRecipeCount: 9 }),
  );
});

async function main(): Promise<void> {
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name} — ${(err as Error).message}`);
    }
  }
  await env.cleanup();
  console.log(`\n${tests.length - failed}/${tests.length} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
