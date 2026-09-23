/**
 * Firestore rules tests for P5-U26b: users/{uid}/overwritten_versions.
 *
 * A version of the user's own week menu or recipe that another person's save
 * overwrote, kept 30 days behind "Återställ" (produktregler.md:104, :109;
 * PQ-01 = A). Rules contract under test:
 *   - Only the owner reads, creates and deletes; nobody updates.
 *   - Another user, and a signed-out client, can do none of it.
 *   - A create must carry exactly the model's fields, name the owner, be a
 *     week menu or own recipe, and expire exactly 30 days after it was
 *     overwritten, in the future and no more than 30 days (plus one hour of
 *     device clock slack) from the server's clock. So no client can keep a
 *     version longer than 30 days.
 *
 * Prerequisite: Firestore emulator running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/overwritten-versions-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-overwritten-versions";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER = "user-owner";
const OTHER = "user-other";
const DAY_MS = 24 * 60 * 60 * 1000;
const doc = (uid: string, id: string): string =>
  `users/${uid}/overwritten_versions/${id}`;

let env: RulesTestEnvironment;
let seq = 0;
/** A fresh id per create, so a create is never evaluated as an update. */
const freshId = (): string => `v-${Date.now()}-${seq++}`;

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

/** The row the app writes (OverwrittenVersion.toFirestore). */
function kept(
  ownerId: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const overwrittenAt = new Date();
  return {
    ownerId,
    entity: "weekMenu",
    resourceType: "menu",
    resourceId: "menu-1",
    version: { menuTitle: "Min vecka", editCount: 2 },
    overwrittenBy: OTHER,
    overwrittenByName: "Per",
    overwrittenAt,
    expiresAt: new Date(overwrittenAt.getTime() + 30 * DAY_MS),
    ...overrides,
  };
}

async function seed(uid: string, id: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin.firestore().doc(doc(uid, id)).set(kept(uid));
  });
}

// ── create ──

test("the owner keeps their own week menu version", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(doc(OWNER, freshId())).set(kept(OWNER)));
});

test("the owner keeps their own recipe version", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(kept(OWNER, { entity: "recipeOwn", resourceType: "recipe" })),
  );
});

test("another user cannot keep a version under the owner", async () => {
  const ctx = env.authenticatedContext(OTHER);
  await assertFails(ctx.firestore().doc(doc(OWNER, freshId())).set(kept(OWNER)));
  await assertFails(ctx.firestore().doc(doc(OWNER, freshId())).set(kept(OTHER)));
});

test("a row naming someone else as owner is refused", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(ctx.firestore().doc(doc(OWNER, freshId())).set(kept(OTHER)));
});

test("a signed-out client can neither keep nor read", async () => {
  await seed(OWNER, "seeded-anon");
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(doc(OWNER, freshId())).set(kept(OWNER)));
  await assertFails(ctx.firestore().doc(doc(OWNER, "seeded-anon")).get());
});

test("an expiry longer than 30 days is refused", async () => {
  const ctx = env.authenticatedContext(OWNER);
  const overwrittenAt = new Date();
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(
        kept(OWNER, {
          overwrittenAt,
          expiresAt: new Date(overwrittenAt.getTime() + 31 * DAY_MS),
        }),
      ),
  );
});

test("a future-dated overwrite that pushes expiry past 30 days from now is refused", async () => {
  // overwrittenAt in the future moves expiresAt beyond request.time + 30 d.
  const ctx = env.authenticatedContext(OWNER);
  const overwrittenAt = new Date(Date.now() + 2 * DAY_MS);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(
        kept(OWNER, {
          overwrittenAt,
          expiresAt: new Date(overwrittenAt.getTime() + 30 * DAY_MS),
        }),
      ),
  );
});

test("an already expired version is refused", async () => {
  const ctx = env.authenticatedContext(OWNER);
  const overwrittenAt = new Date(Date.now() - 31 * DAY_MS);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(
        kept(OWNER, {
          overwrittenAt,
          expiresAt: new Date(overwrittenAt.getTime() + 30 * DAY_MS),
        }),
      ),
  );
});

test("a version without an expiry is refused", async () => {
  const ctx = env.authenticatedContext(OWNER);
  const row = kept(OWNER);
  delete row.expiresAt;
  await assertFails(ctx.firestore().doc(doc(OWNER, freshId())).set(row));
});

test("other entities, and unknown fields, are refused", async () => {
  const ctx = env.authenticatedContext(OWNER);
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(kept(OWNER, { entity: "recipeShared" })),
  );
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(kept(OWNER, { resourceType: "shopping_list" })),
  );
  await assertFails(
    ctx
      .firestore()
      .doc(doc(OWNER, freshId()))
      .set(kept(OWNER, { note: "extra" })),
  );
});

// ── read ──

test("the owner reads and lists their own versions", async () => {
  await seed(OWNER, "seeded-read");
  const ctx = env.authenticatedContext(OWNER);
  await assertSucceeds(ctx.firestore().doc(doc(OWNER, "seeded-read")).get());
  await assertSucceeds(
    ctx
      .firestore()
      .collection(`users/${OWNER}/overwritten_versions`)
      .where("entity", "==", "weekMenu")
      .get(),
  );
});

test("another user can neither read nor list them", async () => {
  await seed(OWNER, "seeded-private");
  const ctx = env.authenticatedContext(OTHER);
  await assertFails(ctx.firestore().doc(doc(OWNER, "seeded-private")).get());
  await assertFails(
    ctx.firestore().collection(`users/${OWNER}/overwritten_versions`).get(),
  );
});

// ── update / delete ──

test("nobody can change a kept version", async () => {
  await seed(OWNER, "seeded-update");
  const owner = env.authenticatedContext(OWNER);
  await assertFails(
    owner
      .firestore()
      .doc(doc(OWNER, "seeded-update"))
      .update({ expiresAt: new Date(Date.now() + 90 * DAY_MS) }),
  );
});

test("the owner forgets a version; another user cannot", async () => {
  await seed(OWNER, "seeded-delete");
  const other = env.authenticatedContext(OTHER);
  await assertFails(other.firestore().doc(doc(OWNER, "seeded-delete")).delete());
  const owner = env.authenticatedContext(OWNER);
  await assertSucceeds(owner.firestore().doc(doc(OWNER, "seeded-delete")).delete());
});

async function run(): Promise<void> {
  console.log("Overwritten versions rules tests (P5-U26b)\n");
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
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
