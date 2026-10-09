/**
 * `onTrashItemDeleted` (BUT-907) — unit tests with a fake db and bucket, no
 * emulator.
 *
 * A deleted trash copy takes its photos with it only when the recipe was not
 * restored and no copy with the same id stands now. The ordering
 * case (delete, restore, delete, then the first trigger arrives late) is the
 * one a recipe-exists check alone gets wrong.
 *
 * Run: npx ts-node src/__tests__/cleanup-trash-storage.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cleanup-trash-storage" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { handleTrashItemDeleted } = require("../cleanup/cleanup-trash-storage");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { deleteRecipePhotos } = require("../cleanup/storage-path-guard");

const UID = "owner-uid";
const OTHER = "other-uid";
const ID = "recipe-1";
const T1 = Date.UTC(2026, 9, 9, 12, 0, 0);
const T2 = T1 + 60_000;

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
const ts = (ms: number) => ({ toMillis: () => ms });

class FakeDb {
  docs = new Map<string, Record<string, unknown>>();
  doc(path: string) {
    return {
      get: async () => {
        const data = this.docs.get(path);
        return { exists: data !== undefined, get: (f: string) => data?.[f] };
      },
      delete: async () => {
        this.docs.delete(path);
      },
    };
  }
  collection() {
    const q = {
      where: () => q,
      limit: () => q,
      get: async () => ({ empty: true }),
    };
    return { where: q.where };
  }
}

class FakeBucket {
  files: Set<string>;
  deleted: string[] = [];
  constructor(files: string[]) {
    this.files = new Set(files);
  }
  file(path: string) {
    return {
      delete: async () => {
        if (!this.files.has(path)) {
          const e = new Error("not found") as Error & { code: number };
          e.code = 404;
          throw e;
        }
        this.files.delete(path);
        this.deleted.push(path);
      },
    };
  }
}

const PHOTO = `users/${UID}/recipes/recipe_1.png`;
const THUMB = `users/${UID}/recipes/thumbnails/recipe_1.png`;
const copy = (deletedAtMs: number, imageUrls: string[] = [url(PHOTO)]) => ({
  kind: "recipe",
  ownerId: UID,
  sourceId: ID,
  title: "Gryta",
  thumbnailUrl: url(THUMB),
  payload: { core: { title: "Gryta", imageUrls, createdBy: UID }, type: 0 },
  deletedAt: ts(deletedAtMs),
  expireAt: ts(deletedAtMs + 30 * 86_400_000),
});

async function main(): Promise<void> {
  console.log("onTrashItemDeleted (BUT-907)\n");

  {
    const db = new FakeDb();
    db.docs.set(`users/${UID}/recipes/${ID}`, { core: {} });
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleTrashItemDeleted({ db, bucket }, UID, ID, copy(T1));
    check("a restored recipe keeps its photos", out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const db = new FakeDb();
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleTrashItemDeleted({ db, bucket }, UID, ID, copy(T1));
    check("no recipe and no copy: photo and thumbnail deleted", out === "deleted" &&
      bucket.deleted.includes(PHOTO) && bucket.deleted.includes(THUMB),
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    // delete (T1) -> restore -> delete (T2); the T1 copy's trigger arrives now.
    const db = new FakeDb();
    db.docs.set(`users/${UID}/trash/${ID}`, copy(T2));
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleTrashItemDeleted({ db, bucket }, UID, ID, copy(T1));
    check("delete, restore, delete, then a late first trigger deletes nothing",
      out === "superseded" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    // A thumbnail URL that cannot be derived from any photo in the payload.
    const ownThumb = `users/${UID}/recipes/thumbnails/other_thumb.jpg`;
    const db = new FakeDb();
    const bucket = new FakeBucket([ownThumb]);
    const data = copy(T1, []);
    data.thumbnailUrl = url(ownThumb);
    await handleTrashItemDeleted({ db, bucket }, UID, ID, data);
    check("the copy's own thumbnailUrl is deleted", bucket.deleted.includes(ownThumb),
      `deleted=${bucket.deleted}`);
  }
  {
    const gone = await deleteRecipePhotos(new FakeBucket([]), UID, [url(PHOTO)], "t");
    check("a file already gone (404) is done, not failed",
      gone.failed === 0 && gone.deleted === 0, JSON.stringify(gone));
    const broken = {
      file: () => ({
        delete: async () => {
          const e = new Error("boom") as Error & { code: number };
          e.code = 500;
          throw e;
        },
      }),
    };
    const failedRun = await deleteRecipePhotos(broken, UID, [url(PHOTO)], "t");
    check("a file that fails to delete counts as failed", failedRun.failed === 1,
      JSON.stringify(failedRun));
  }
  {
    const db = new FakeDb();
    const foreign = [
      `users/${OTHER}/recipes/a.jpg`,
      `users/${UID}/avatars/me.jpg`,
      `users/${UID}/exports/bundle.zip`,
    ];
    const bucket = new FakeBucket(foreign);
    const data = copy(T1, [
      url(`users/${OTHER}/recipes/a.jpg`),
      url(`users/${UID}/avatars/me.jpg`),
      url(`users/${UID}/exports/bundle.zip`),
      url(`users/${UID}/recipes/../../${OTHER}/recipes/a.jpg`),
    ]);
    data.thumbnailUrl = url(`users/${UID}/avatars/me.jpg`);
    await handleTrashItemDeleted({ db, bucket }, UID, ID, data);
    check("traversal, other-uid, avatar and export paths are refused",
      bucket.deleted.length === 0, `deleted=${bucket.deleted}`);
  }

  console.log(`\n${passed}/${passed + failed} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
