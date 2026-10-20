/**
 * Storage rules tests for BUT-1049 (images attached to recipe comments) and
 * BUT-2411 (who can read them).
 *
 * Block in `storage.rules`:
 *
 *   match /users/{authorId}/comment_images/{imageId} {
 *     allow write: if request.auth != null
 *       && request.auth.uid == authorId              // owner-only writes
 *       && isValidImage() && isWithinSizeLimit(10);
 *   }
 *
 * Contract: the path is exactly `users/{authorId}/comment_images/{imageId}`.
 * Writes are strictly owner-scoped (no cross-user planting). The block has no
 * read limb: the owner reads and lists through the `/users/{userId}/{allPaths=**}`
 * wildcard, and everyone else sees the image through the download URL stored
 * on the comment, which does not go through these rules.
 *
 * Prerequisite: the Storage emulator must be running locally
 * (`firebase emulators:start --only storage --project demo-test`, port 9199).
 *
 * Run with: npx ts-node src/__tests__/comment-images-storage-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { ref, uploadBytes, getBytes, listAll } from "firebase/storage";

const PROJECT_ID = "butlery-rules-comment-images";
const RULES_PATH = path.resolve(__dirname, "../../../storage.rules");

const AUTHOR_UID = "comment-author-uid";
const OTHER_UID = "other-user-uid";
const VIEWER_UID = "shared-viewer-uid";

let env: RulesTestEnvironment;

// A tiny but valid JPEG (image/* content type set explicitly on upload).
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

/** Seed an object at a path bypassing rules, so read tests prove the rule
 *  rather than the absence of the object. */
async function seedObject(objectPath: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), objectPath), IMAGE_BYTES, IMAGE_META);
  });
}

const COMMENT_IMG = `users/${AUTHOR_UID}/comment_images/img-1.jpg`;

// ============================================================================
// COMMENT IMAGES — write (owner-only), read and list (owner-only) (CI1–CI10)
// ============================================================================

// CI1: ALLOW — the comment author can write an image into THEIR OWN
// comment_images namespace.
test("comment_images: author can write to their own comment_images path", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(
    uploadBytes(ref(ctx.storage(), COMMENT_IMG), IMAGE_BYTES, IMAGE_META)
  );
});

// CI2: DENY — a different authenticated user cannot write into the author's
// comment_images namespace (no cross-user planting).
test("comment_images: a different user cannot write to another user's path", async () => {
  const ctx = env.authenticatedContext(OTHER_UID);
  await assertFails(
    uploadBytes(ref(ctx.storage(), COMMENT_IMG), IMAGE_BYTES, IMAGE_META)
  );
});

// CI3: DENY — an unauthenticated client cannot write at all.
test("comment_images: unauthenticated client cannot write", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    uploadBytes(ref(ctx.storage(), COMMENT_IMG), IMAGE_BYTES, IMAGE_META)
  );
});

// CI4: DENY — a non-image content type is rejected even for the owner
// (isValidImage gate).
test("comment_images: author cannot write a non-image content type", async () => {
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertFails(
    uploadBytes(ref(ctx.storage(), COMMENT_IMG), IMAGE_BYTES, {
      contentType: "application/pdf",
    })
  );
});

// CI5: ALLOW — the author can read their own comment image.
test("comment_images: author can read their own comment image", async () => {
  await seedObject(COMMENT_IMG);
  const ctx = env.authenticatedContext(AUTHOR_UID);
  await assertSucceeds(getBytes(ref(ctx.storage(), COMMENT_IMG)));
});

// CI6: DENY (BUT-2411) — a DIFFERENT authenticated user cannot read the
// author's comment image by its storage path. Readers get the image through
// the download URL (token) stored on the comment, which skips these rules.
// Same path and call as CI5 (the author, allowed); only the actor differs.
test("comment_images: another signed-in user cannot read the image by its path", async () => {
  await seedObject(COMMENT_IMG);
  const ctx = env.authenticatedContext(VIEWER_UID);
  await assertFails(getBytes(ref(ctx.storage(), COMMENT_IMG)));
});

// CI7: DENY — an unauthenticated client cannot read comment images.
test("comment_images: unauthenticated client cannot read", async () => {
  await seedObject(COMMENT_IMG);
  const ctx = env.unauthenticatedContext();
  await assertFails(getBytes(ref(ctx.storage(), COMMENT_IMG)));
});

// CI8: DENY (control) — a NON-comment_images file under another user's
// namespace is owner-only read as well. A viewer reading the author's recipe
// image must fail.
test("comment_images: another user's recipe image is owner-only read too", async () => {
  const recipeImg = `users/${AUTHOR_UID}/recipes/r-1.jpg`;
  await seedObject(recipeImg);
  const ctx = env.authenticatedContext(VIEWER_UID);
  await assertFails(getBytes(ref(ctx.storage(), recipeImg)));
});

// CI9: DENY (BUT-2411) — a signed-in stranger cannot LIST the author's
// folder, so images of comments that were never created (failed, discarded) or
// that the stranger cannot see are not enumerable.
test("comment_images: another user cannot list the author's comment_images folder", async () => {
  await seedObject(COMMENT_IMG);
  const ctx = env.authenticatedContext(VIEWER_UID);
  await assertFails(
    listAll(ref(ctx.storage(), `users/${AUTHOR_UID}/comment_images`))
  );
});

// CI10: ALLOW (BUT-2411 control) — the author can list their own folder; the
// owner wildcard grants it. Same path, same call as CI9, only the actor differs.
test("comment_images: the author can list their own comment_images folder", async () => {
  await seedObject(COMMENT_IMG);
  const ctx = env.authenticatedContext(AUTHOR_UID);
  const listed = await assertSucceeds(
    listAll(ref(ctx.storage(), `users/${AUTHOR_UID}/comment_images`))
  );
  if (listed.items.length !== 1) {
    throw new Error(`expected the one seeded image, got ${listed.items.length}`);
  }
});

async function run(): Promise<void> {
  console.log("comment images storage rules tests (BUT-1049)");
  console.log("=============================================\n");
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
