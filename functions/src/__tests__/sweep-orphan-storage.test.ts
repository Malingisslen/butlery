/**
 * BUT-2409: the orphan decision must never call a referenced or fresh file an
 * orphan, because the later delete cannot be undone.
 *
 * Run with: npx ts-node src/__tests__/sweep-orphan-storage.test.ts
 */

import * as assert from "assert";
import {
  assertScanPlausible,
  classifyObject,
  GRACE_MS,
  harvestStoragePaths,
  tallyObjects,
} from "../admin/sweep-orphan-storage-core";

const NOW = Date.UTC(2026, 10, 7);
const OLD = NOW - GRACE_MS - 1000;
const url = (path: string) =>
  `https://firebasestorage.googleapis.com/v0/b/b.firebasestorage.app/o/${encodeURIComponent(path)}?alt=media&token=t`;

let failed = 0;
function test(name: string, fn: () => void): void {
  try {
    fn();
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed++;
    console.log(`  FAIL  ${name}\n        ${String(err)}`);
  }
}

test("a URL in any field of any nesting counts as a reference", () => {
  const keep = new Set<string>();
  harvestStoragePaths(
    { cover: { imageUrl: url("users/u1/recipes/cb.jpg") }, list: [url("users/u1/avatars/a.png")] },
    keep,
  );
  assert.ok(keep.has("users/u1/recipes/cb.jpg"));
  assert.ok(keep.has("users/u1/avatars/a.png"));
});

test("a referenced recipe photo also protects its thumbnail", () => {
  const keep = new Set<string>();
  harvestStoragePaths(url("users/u1/recipes/p.jpg"), keep);
  assert.ok(keep.has("users/u1/recipes/thumbnails/p_thumb.jpg"));
});

test("gs:// references are understood", () => {
  const keep = new Set<string>();
  harvestStoragePaths("gs://b/users/u1/comment_images/c1", keep);
  assert.ok(keep.has("users/u1/comment_images/c1"));
});

test("unrelated strings and non-user paths are ignored", () => {
  const keep = new Set<string>();
  harvestStoragePaths({ a: "hello users", b: url("feedback/u1/1.png"), c: 5, d: null }, keep);
  assert.strictEqual(keep.size, 0);
});

test("an old unreferenced file in a swept folder is an orphan", () => {
  const o = { name: "users/u1/avatars/old.jpg", sizeBytes: 10, createdMs: OLD };
  assert.strictEqual(classifyObject(o, new Set(), NOW), "orphan");
});

test("a referenced file is in use however old", () => {
  const o = { name: "users/u1/avatars/a.jpg", sizeBytes: 10, createdMs: OLD };
  assert.strictEqual(classifyObject(o, new Set([o.name]), NOW), "in-use");
});

test("a file inside the grace window is never an orphan", () => {
  const o = { name: "users/u1/recipes/x.jpg", sizeBytes: 10, createdMs: NOW - 1000 };
  assert.strictEqual(classifyObject(o, new Set(), NOW), "too-new");
});

test("folders outside the swept set are left alone", () => {
  for (const name of [
    "users/u1/public_recipes/r1/a.jpg",
    "users/u1/trash/x.jpg",
    "feedback/u1/1.png",
    "users/u1/file.jpg",
  ]) {
    assert.strictEqual(classifyObject({ name, sizeBytes: 1, createdMs: OLD }, new Set(), NOW), "not-swept");
  }
});

test("tally counts orphans and bytes per folder", () => {
  const t = tallyObjects(
    [
      { name: "users/u1/avatars/a", sizeBytes: 100, createdMs: OLD },
      { name: "users/u1/avatars/b", sizeBytes: 50, createdMs: OLD },
    ],
    new Set(["users/u1/avatars/a"]),
    NOW,
  );
  assert.deepStrictEqual(t.get("avatars"), { objects: 2, inUse: 1, tooNew: 0, orphans: 1, orphanBytes: 50 });
});

test("an empty reference scan over existing files is refused", () => {
  assert.throws(() => assertScanPlausible(0, 5), /REFUSED/);
  assertScanPlausible(0, 0);
  assertScanPlausible(3, 5);
});

if (failed > 0) {
  console.log(`\n${failed} failed`);
  process.exit(1);
}
console.log("\nall passed");
