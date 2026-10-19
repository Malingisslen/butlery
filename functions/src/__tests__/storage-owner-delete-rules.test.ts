/**
 * Storage rules tests for BUT-2294 (GA1): can the app delete its OWN uploaded
 * images?
 *
 * The offline image queue deletes the objects it uploaded whenever it must
 * take a picture back (discarded by the user, refused by the server, replaced
 * by a newer one). Every `allow write` in `storage.rules` reads
 * `request.resource`, which is null on a delete, so a delete could be refused
 * for the owner. These tests measure that and pin that nobody else can delete.
 *
 * Prerequisite: the Storage emulator must be running locally
 * (`firebase emulators:start --only storage --project demo-test`, port 9199).
 *
 * Run with: npx ts-node src/__tests__/storage-owner-delete-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, deleteObject } from "firebase/storage";

const PROJECT_ID = "butlery-rules-owner-delete";
const RULES_PATH = path.resolve(__dirname, "../../../storage.rules");

const OWNER_UID = "owner-uid";
const OTHER_UID = "other-user-uid";

let env: RulesTestEnvironment;

const IMAGE_BYTES = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const IMAGE_META = { contentType: "image/jpeg" };

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: { rules, host: "127.0.0.1", port: 9199 },
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

async function seedObject(objectPath: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), objectPath), IMAGE_BYTES, IMAGE_META);
  });
}

const PATHS: Record<string, string> = {
  "recipes": `users/${OWNER_UID}/recipes/row-1.jpg`,
  "recipes thumbnail": `users/${OWNER_UID}/recipes/thumbnails/row-1_thumb.jpg`,
  "comment_images": `users/${OWNER_UID}/comment_images/row-1.jpg`,
  "avatars": `users/${OWNER_UID}/avatars/row-1.jpg`,
};

for (const [label, objectPath] of Object.entries(PATHS)) {
  test(`${label}: the owner can delete their own uploaded image`, async () => {
    await seedObject(objectPath);
    const ctx = env.authenticatedContext(OWNER_UID);
    await assertSucceeds(deleteObject(ref(ctx.storage(), objectPath)));
  });

  test(`${label}: another signed-in user cannot delete it`, async () => {
    await seedObject(objectPath);
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(deleteObject(ref(ctx.storage(), objectPath)));
  });

  test(`${label}: a signed-out client cannot delete it`, async () => {
    await seedObject(objectPath);
    const ctx = env.unauthenticatedContext();
    await assertFails(deleteObject(ref(ctx.storage(), objectPath)));
  });
}

async function run(): Promise<void> {
  console.log("storage owner delete rules tests (BUT-2294)");
  console.log("===========================================\n");
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
