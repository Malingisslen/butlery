/**
 * `onRecipeCommentDeleted` and `onCookSnapDeleted` (BUT-2337) — unit tests
 * with a fake bucket, no emulator.
 *
 * A deleted row takes the images under its author's own folder with it, and
 * nothing else: another account's files, another folder of the author's, and
 * a path that climbs out are refused.
 *
 * Run: npx ts-node src/__tests__/cleanup-row-images.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cleanup-row-images" });
}

const {
  handleCommentDeleted,
  handleCookSnapDeleted,
  onRecipeCommentDeleted,
  onCookSnapDeleted,
  // eslint-disable-next-line @typescript-eslint/no-require-imports
} = require("../cleanup/cleanup-row-images");

const UID = "author-uid";
const OTHER = "other-uid";

let failed = 0;
let passed = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? `\n        ${detail}` : ""}`);
  }
}

const url = (p: string): string =>
  `https://firebasestorage.googleapis.com/v0/b/bucket/o/${encodeURIComponent(p)}?alt=media&token=t`;

class FakeBucket {
  deleted: string[] = [];
  failOn = new Map<string, number | string>();
  file(path: string) {
    return {
      delete: async () => {
        const code = this.failOn.get(path);
        if (code !== undefined) {
          throw Object.assign(new Error(`delete failed: ${path}`), { code });
        }
        this.deleted.push(path);
      },
    };
  }
}

async function commentImagesAreDeleted(): Promise<void> {
  const bucket = new FakeBucket();
  const a = `users/${UID}/comment_images/comment_1_aaaa.jpg`;
  const b = `users/${UID}/comment_images/comment_2_bbbb.png`;
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [url(a), url(b)],
  });
  check(
    "a deleted comment's images are deleted",
    JSON.stringify(bucket.deleted.sort()) === JSON.stringify([a, b].sort()),
    JSON.stringify(bucket.deleted),
  );
  check("…and counted", result?.deleted === 2 && result?.failed === 0);
}

async function commentGuardRefusesOtherPaths(): Promise<void> {
  const bucket = new FakeBucket();
  const own = `users/${UID}/comment_images/ok.jpg`;
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [
      url(`users/${OTHER}/comment_images/theirs.jpg`),
      url(`users/${UID}/recipes/photo.jpg`),
      url(`users/${UID}/avatars/me.jpg`),
      url(`users/${UID}/comment_images/../recipes/photo.jpg`),
      url(`users/${UID}/comment_images/`),
      "https://example.com/not-storage.jpg",
      42,
      url(own),
    ],
  });
  check(
    "only the author's own comment image is deleted",
    JSON.stringify(bucket.deleted) === JSON.stringify([own]),
    JSON.stringify(bucket.deleted),
  );
  check(
    "…and the six refused URLs are counted as failed",
    result?.failed === 6,
    JSON.stringify(result),
  );
}

async function commentWithoutImagesOrAuthor(): Promise<void> {
  const bucket = new FakeBucket();
  check(
    "a comment without images does nothing",
    (await handleCommentDeleted(bucket, "c1", { authorId: UID, text: "x" })) ===
      null && bucket.deleted.length === 0,
  );
  check(
    "a comment without an author keeps its images",
    (await handleCommentDeleted(bucket, "c1", {
      imageUrls: [url(`users/${UID}/comment_images/a.jpg`)],
    })) === null && bucket.deleted.length === 0,
  );
  check(
    "a delete event without data does nothing",
    (await handleCommentDeleted(bucket, "c1", undefined)) === null,
  );
}

async function commentDeleteFailuresDoNotStopTheRest(): Promise<void> {
  const bucket = new FakeBucket();
  const gone = `users/${UID}/comment_images/gone.jpg`;
  const broken = `users/${UID}/comment_images/broken.jpg`;
  const fine = `users/${UID}/comment_images/fine.jpg`;
  bucket.failOn.set(gone, 404);
  bucket.failOn.set(broken, 503);
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [url(gone), url(broken), url(fine)],
  });
  check(
    "a 404 and a failed delete do not stop the next image",
    JSON.stringify(bucket.deleted) === JSON.stringify([fine]),
    JSON.stringify(bucket.deleted),
  );
  check(
    "…the 404 is not a failure, the 503 is",
    result?.failed === 1 && result?.deleted === 1,
    JSON.stringify(result),
  );
}

async function cookSnapPhotosAndThumbnailsAreDeleted(): Promise<void> {
  const bucket = new FakeBucket();
  const cover = `users/${UID}/recipes/snap_1.jpg`;
  const second = `users/${UID}/recipes/snap_2.jpg`;
  const thumb = `users/${UID}/recipes/thumbnails/snap_1_thumb.jpg`;
  const result = await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrl: url(cover),
    photoUrls: [url(cover), url(second)],
    thumbnailUrl: url(thumb),
  });
  const deleted = new Set(bucket.deleted);
  check(
    "a deleted cook snap's photos are deleted, the repeated cover once",
    deleted.has(cover) &&
      deleted.has(second) &&
      bucket.deleted.filter((p) => p === cover).length === 1,
    JSON.stringify(bucket.deleted),
  );
  check(
    "…with their thumbnails",
    deleted.has(thumb) &&
      deleted.has(`users/${UID}/recipes/thumbnails/snap_2_thumb.jpg`),
    JSON.stringify(bucket.deleted),
  );
  check("…and nothing failed", result?.failed === 0, JSON.stringify(result));
}

async function cookSnapGuardRefusesOtherPaths(): Promise<void> {
  const bucket = new FakeBucket();
  await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrls: [
      url(`users/${OTHER}/recipes/theirs.jpg`),
      url(`users/${UID}/comment_images/c.jpg`),
      url(`users/${UID}/recipes/%2e%2e/avatars/me.jpg`),
    ],
  });
  check(
    "a cook snap naming another account's or another folder's file deletes nothing",
    bucket.deleted.length === 0,
    JSON.stringify(bucket.deleted),
  );
  check(
    "a cook snap without an owner keeps its photos",
    (await handleCookSnapDeleted(bucket, "s1", {
      photoUrls: [url(`users/${UID}/recipes/a.jpg`)],
    })) === null && bucket.deleted.length === 0,
  );
}

async function cookSnapUrlListIsCapped(): Promise<void> {
  const bucket = new FakeBucket();
  const paths = Array.from(
    { length: 10 },
    (_, i) => `users/${UID}/recipes/thumbnails/p${i}.jpg`,
  );
  await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrls: paths.map(url),
  });
  check(
    "a cook snap carrying more URLs than the app writes deletes only the first 7",
    bucket.deleted.length === 7 &&
      paths.slice(0, 7).every((p) => bucket.deleted.includes(p)),
    JSON.stringify(bucket.deleted),
  );
}

function triggersListenOnTheRowPaths(): void {
  const comment = (onRecipeCommentDeleted as { __endpoint?: Record<string, unknown> })
    .__endpoint;
  const snap = (onCookSnapDeleted as { __endpoint?: Record<string, unknown> })
    .__endpoint;
  const filters = (e: Record<string, unknown> | undefined) =>
    JSON.stringify((e?.eventTrigger as Record<string, unknown>)?.eventFilterPathPatterns);
  check(
    "onRecipeCommentDeleted listens on recipe_comments/{commentId}",
    filters(comment).includes("recipe_comments/{commentId}"),
    filters(comment),
  );
  check(
    "onCookSnapDeleted listens on cook_snaps/{snapId}",
    filters(snap).includes("cook_snaps/{snapId}"),
    filters(snap),
  );
}

async function main(): Promise<void> {
  console.log("BUT-2337: images of a deleted comment or cook snap");
  await commentImagesAreDeleted();
  await commentGuardRefusesOtherPaths();
  await commentWithoutImagesOrAuthor();
  await commentDeleteFailuresDoNotStopTheRest();
  await cookSnapPhotosAndThumbnailsAreDeleted();
  await cookSnapGuardRefusesOtherPaths();
  await cookSnapUrlListIsCapped();
  triggersListenOnTheRowPaths();
  console.log(`\n${passed}/${passed + failed} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
