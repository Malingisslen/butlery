/**
 * BUT-2409: the orphan decision must never call a referenced or fresh file an
 * orphan, because the later delete cannot be undone.
 *
 * Run with: npx ts-node src/__tests__/sweep-orphan-storage.test.ts
 */

import * as assert from "assert";
import {
  assertScanPlausible,
  assertWithinCap,
  deleteOrphans,
  classifyObject,
  GRACE_MS,
  harvestStoragePaths,
  orphansOf,
  parseMaxDelete,
  tallyObjects,
} from "../admin/sweep-orphan-storage-core";

const NOW = Date.UTC(2026, 10, 7);
const OLD = NOW - GRACE_MS - 1000;
const url = (path: string) =>
  `https://firebasestorage.googleapis.com/v0/b/b.firebasestorage.app/o/${encodeURIComponent(path)}?alt=media&token=t`;

let failed = 0;
const pending: Array<Promise<void>> = [];
function test(name: string, fn: () => void | Promise<void>): void {
  pending.push(
    (async () => {
      try {
        await fn();
        console.log(`  PASS  ${name}`);
      } catch (err) {
        failed++;
        console.log(`  FAIL  ${name}\n        ${String(err)}`);
      }
    })(),
  );
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

test("orphansOf returns only old unreferenced swept files", () => {
  const keepName = "users/u1/recipes/a.jpg";
  const list = orphansOf(
    [
      { name: keepName, sizeBytes: 1, createdMs: OLD },
      { name: "users/u1/recipes/b.jpg", sizeBytes: 1, createdMs: OLD },
      { name: "users/u1/recipes/new.jpg", sizeBytes: 1, createdMs: NOW },
      { name: "users/u1/trash/c.jpg", sizeBytes: 1, createdMs: OLD },
    ],
    new Set([keepName]),
    NOW,
  );
  assert.deepStrictEqual(list.map((o) => o.name), ["users/u1/recipes/b.jpg"]);
});

test("--max-delete must be a positive integer", () => {
  assert.strictEqual(parseMaxDelete(["--apply"]), null);
  assert.strictEqual(parseMaxDelete(["--max-delete"]), null);
  assert.strictEqual(parseMaxDelete(["--max-delete", "0"]), null);
  assert.strictEqual(parseMaxDelete(["--max-delete", "4x"]), null);
  assert.strictEqual(parseMaxDelete(["--max-delete", "4"]), 4);
});

test("more orphans than the approved cap deletes nothing", () => {
  assert.throws(() => assertWithinCap(5, 4), /REFUSED/);
  assertWithinCap(4, 4);
  assertWithinCap(0, 4);
});

function fakeBucket(failWith: Record<string, number>) {
  const calls: Array<[string, string]> = [];
  return {
    calls,
    bucket: {
      file: (name: string) => ({
        delete: async (o: { ifGenerationMatch: string }) => {
          calls.push([name, o.ifGenerationMatch]);
          if (failWith[name]) throw Object.assign(new Error("x"), { code: failWith[name] });
        },
      }),
    },
  };
}
const orph = (name: string, generation?: string) => ({ name, sizeBytes: 1, createdMs: OLD, generation });

test("deletes are pinned to the judged generation; 404 and 412 count as skipped", async () => {
  const f = fakeBucket({ "users/u/recipes/b": 404, "users/u/recipes/c": 412 });
  const seen: Array<[number, number]> = [];
  const r = await deleteOrphans(
    f.bucket,
    [orph("users/u/recipes/a", "7"), orph("users/u/recipes/b", "8"), orph("users/u/recipes/c", "9")],
    (x) => seen.push([x.deleted, x.skipped]),
  );
  assert.deepStrictEqual(f.calls[0], ["users/u/recipes/a", "7"]);
  assert.deepStrictEqual(r, { deleted: 1, skipped: 2 });
  assert.deepStrictEqual(seen, [[1, 2]]);
});

test("an object without a generation is skipped, never deleted", async () => {
  const f = fakeBucket({});
  const r = await deleteOrphans(f.bucket, [orph("users/u/recipes/a")], () => undefined);
  assert.strictEqual(f.calls.length, 0);
  assert.deepStrictEqual(r, { deleted: 0, skipped: 1 });
});

test("another error stops the run and still reports progress", async () => {
  const f = fakeBucket({ "users/u/recipes/b": 500 });
  const seen: Array<[number, number]> = [];
  await assert.rejects(
    deleteOrphans(f.bucket, [orph("users/u/recipes/a", "1"), orph("users/u/recipes/b", "2"), orph("users/u/recipes/c", "3")], (x) =>
      seen.push([x.deleted, x.skipped]),
    ),
  );
  assert.strictEqual(f.calls.length, 2);
  assert.deepStrictEqual(seen, [[1, 0]]);
});

void Promise.all(pending).then(() => {
  if (failed > 0) {
    console.log(`\n${failed} failed`);
    process.exit(1);
  }
  console.log("\nall passed");
});
