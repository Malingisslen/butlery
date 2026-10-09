/**
 * `onRecipeDeleted` (BUT-907) and the shared path guard — unit tests with a
 * fake db and bucket, no emulator.
 *
 * The recipe's photos stay only while a FRESH trash copy holds them; an open
 * report sends recipe, copy and photos away together; everything else deletes
 * as before. The guard cases pin that a URL the user wrote can only reach
 * their own `users/{uid}/recipes/` files.
 *
 * Run: npx ts-node src/__tests__/cleanup-recipe-storage.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cleanup-recipe-storage" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  handleRecipeDeleted,
  FRESH_COPY_WINDOW_MS,
} = require("../cleanup/cleanup-recipe-storage");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  recipePhotoPath,
  recipeThumbnailPaths,
  deleteRecipePhotos,
} = require("../cleanup/storage-path-guard");

const UID = "owner-uid";
const OTHER = "other-uid";
const RECIPE = "recipe-1";
const NOW = Date.UTC(2026, 9, 9, 12, 0, 0);

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

interface Report {
  contentType: string;
  contentId: string;
  status: string;
}

class FakeDb {
  docs = new Map<string, Record<string, unknown>>();
  reports: Report[] = [];
  doc(path: string) {
    return {
      get: async () => {
        const data = this.docs.get(path);
        return {
          exists: data !== undefined,
          get: (field: string) => data?.[field],
        };
      },
      delete: async () => {
        this.docs.delete(path);
      },
    };
  }
  collection(name: string) {
    const filters: [string, string, unknown][] = [];
    const reports = this.reports;
    const query = {
      where(field: string, op: string, value: unknown) {
        filters.push([field, op, value]);
        return query;
      },
      limit() {
        return query;
      },
      async get() {
        if (name !== "reports") return { empty: true };
        const hit = reports.filter((r) =>
          filters.every(([f, op, v]) => {
            const actual = (r as unknown as Record<string, unknown>)[f];
            return op === "in" ? (v as unknown[]).includes(actual) : actual === v;
          }),
        );
        return { empty: hit.length === 0 };
      },
    };
    return { where: query.where };
  }
}

// The owner restores while the report query is in flight: the recipe comes
// back and its copy goes, as restoreRecipe's transaction does.
class RestoreDuringReportQuery extends FakeDb {
  constructor(private readonly uid: string, private readonly id: string,
    private readonly recipe: Record<string, unknown>) {
    super();
  }
  collection(name: string) {
    const inner = super.collection(name);
    const restore = () => {
      this.docs.set(`users/${this.uid}/recipes/${this.id}`, this.recipe);
      this.docs.delete(`users/${this.uid}/trash/${this.id}`);
    };
    const wrap = (q: ReturnType<FakeDb["collection"]>["where"]) =>
      (field: string, op: string, value: unknown) => {
        const next = q(field, op, value);
        const get = async () => {
          restore();
          return next.get();
        };
        return { ...next, where: wrap(next.where), limit: () => ({ ...next, get }), get };
      };
    return { where: wrap(inner.where) };
  }
}

// The owner restores inside the handler's own get or delete of the copy, the
// last read before its re-read of the recipe.
class RestoreInsideCopyCall extends FakeDb {
  constructor(private readonly uid: string, private readonly id: string,
    private readonly recipe: Record<string, unknown>,
    private readonly verb: "get" | "delete") {
    super();
  }
  doc(path: string) {
    const inner = super.doc(path);
    if (path !== `users/${this.uid}/trash/${this.id}`) return inner;
    const call = inner[this.verb];
    return {
      ...inner,
      [this.verb]: async () => {
        this.docs.set(`users/${this.uid}/recipes/${this.id}`, this.recipe);
        this.docs.delete(path);
        return call();
      },
    };
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

const PHOTO = `users/${UID}/recipes/recipe_1_abc.jpg`;
const THUMB = `users/${UID}/recipes/thumbnails/recipe_1_abc_thumb.jpg`;
const recipeData = {
  core: { title: "Gryta", imageUrls: [url(PHOTO)], createdBy: UID },
  type: 0,
};
const ts = (ms: number) => ({ toMillis: () => ms });

function world(copyDeletedAtMs?: number) {
  const db = new FakeDb();
  if (copyDeletedAtMs !== undefined) {
    db.docs.set(`users/${UID}/trash/${RECIPE}`, {
      kind: "recipe",
      sourceId: RECIPE,
      deletedAt: ts(copyDeletedAtMs),
    });
  }
  const bucket = new FakeBucket([PHOTO, THUMB]);
  return { db, bucket };
}

async function main(): Promise<void> {
  console.log("onRecipeDeleted + storage-path-guard (BUT-907)\n");

  {
    const { db, bucket } = world(NOW - 2000);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a fresh trash copy keeps the photos", out === "kept-for-trash" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world(NOW - FRESH_COPY_WINDOW_MS - 1000);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a stale trash copy does not save the photos", out === "deleted" &&
      bucket.deleted.includes(PHOTO) && bucket.deleted.includes(THUMB),
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world(NOW + FRESH_COPY_WINDOW_MS + 1000);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a copy dated far in the future does not save the photos", out === "deleted",
      `outcome=${out}`);
  }
  {
    const { db, bucket } = world();
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("no copy deletes photo and thumbnail", out === "deleted" &&
      bucket.deleted.includes(PHOTO) && bucket.deleted.includes(THUMB),
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world(NOW - 1000);
    db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "in_review" });
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("an open report deletes the fresh copy and the photos", out === "reported" &&
      !db.docs.has(`users/${UID}/trash/${RECIPE}`) && bucket.deleted.includes(PHOTO),
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world(NOW - 1000);
    db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "actioned" });
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("an actioned report is still open", out === "reported", `outcome=${out}`);
  }
  {
    const { db, bucket } = world(NOW - 1000);
    db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "closed" });
    db.reports.push({ contentType: "comment", contentId: RECIPE, status: "new" });
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a closed report, or one on another content type, keeps the trash path",
      out === "kept-for-trash" && db.docs.has(`users/${UID}/trash/${RECIPE}`),
      `outcome=${out}`);
  }
  for (const offset of [-59 * 60_000, 59 * 60_000]) {
    // The trash rule lets the phone's clock sit up to an hour off the server's.
    const { db, bucket } = world(NOW + offset);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check(`a copy ${offset / 60_000} min off the deletion keeps the photos`,
      out === "kept-for-trash" && bucket.deleted.length === 0, `outcome=${out}`);
  }
  {
    const { db, bucket } = world(NOW - 1000);
    db.reports.push({ contentType: "recipe", contentId: "recipe-2", status: "new" });
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("an open report on another recipe keeps the trash path",
      out === "kept-for-trash" && db.docs.has(`users/${UID}/trash/${RECIPE}`),
      `outcome=${out}`);
  }
  {
    // A restore (or a redelivery after one) put the recipe back before this ran.
    const { db, bucket } = world();
    db.docs.set(`users/${UID}/recipes/${RECIPE}`, recipeData);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a recipe that is live again keeps its photos",
      out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world();
    db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "new" });
    db.docs.set(`users/${UID}/recipes/${RECIPE}`, recipeData);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a reported recipe that is live again keeps its photos",
      out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const db = new RestoreDuringReportQuery(UID, RECIPE, recipeData);
    db.docs.set(`users/${UID}/trash/${RECIPE}`, {
      kind: "recipe", sourceId: RECIPE, deletedAt: ts(NOW - 1000),
    });
    db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "new" });
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a restore during the report check keeps the photos",
      out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    // The same race with no report: the restore takes the copy with it.
    const db = new RestoreDuringReportQuery(UID, RECIPE, recipeData);
    db.docs.set(`users/${UID}/trash/${RECIPE}`, {
      kind: "recipe", sourceId: RECIPE, deletedAt: ts(NOW - 1000),
    });
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a restore during the checks, with no report, keeps the photos",
      out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  for (const reported of [true, false]) {
    const db = new RestoreInsideCopyCall(UID, RECIPE, recipeData, reported ? "delete" : "get");
    db.docs.set(`users/${UID}/trash/${RECIPE}`, {
      kind: "recipe", sourceId: RECIPE, deletedAt: ts(NOW - 1000),
    });
    if (reported) db.reports.push({ contentType: "recipe", contentId: RECIPE, status: "new" });
    const bucket = new FakeBucket([PHOTO, THUMB]);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check(`a restore inside the copy's ${reported ? "delete" : "get"} keeps the photos`,
      out === "restored" && bucket.deleted.length === 0,
      `outcome=${out} deleted=${bucket.deleted}`);
  }
  {
    const { db, bucket } = world(NOW - FRESH_COPY_WINDOW_MS);
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, recipeData, NOW);
    check("a copy exactly at the window's edge keeps the photos",
      out === "kept-for-trash", `outcome=${out}`);
  }
  {
    const { db, bucket } = world();
    const out = await handleRecipeDeleted({ db, bucket }, UID, RECIPE, undefined, NOW);
    check("a delete event without data does nothing", out === "no-data" &&
      bucket.deleted.length === 0, `outcome=${out}`);
  }
  {
    const { db } = world();
    const bucket = new FakeBucket([`users/${UID}/recipes/a.jpg`]);
    const flat = { imageUrls: [url(`users/${UID}/recipes/a.jpg`)] };
    await handleRecipeDeleted({ db, bucket }, UID, RECIPE, flat, NOW);
    check("a legacy flat recipe's imageUrls are read too",
      bucket.deleted.includes(`users/${UID}/recipes/a.jpg`), `deleted=${bucket.deleted}`);
  }

  // ── guard ──
  check("own recipe photo passes", recipePhotoPath(url(PHOTO), UID) === PHOTO);
  check("own photo by gs:// passes",
    recipePhotoPath(`gs://bucket/${PHOTO}`, UID) === PHOTO);
  const refused: [string, string][] = [
    ["encoded ../ traversal", url(`users/${UID}/recipes/../avatars/me.jpg`)],
    ["traversal via %2e%2e", `https://x/v0/b/b/o/users%2F${UID}%2Frecipes%2F%2e%2e%2F%2e%2e%2F${OTHER}%2Frecipes%2Fa.jpg?alt=media`],
    ["double slash", url(`users/${UID}/recipes//a.jpg`)],
    ["double-encoded", `https://x/v0/b/b/o/users%2F${UID}%2Frecipes%2F%252e%252e%252Fa.jpg?alt=media`],
    ["another user's recipe photo", url(`users/${OTHER}/recipes/a.jpg`)],
    ["own avatar", url(`users/${UID}/avatars/a.jpg`)],
    ["own export", url(`users/${UID}/exports/bundle.zip`)],
    ["own comment image", url(`users/${UID}/comment_images/a.jpg`)],
    ["uid prefix of another uid", url(`users/${UID}x/recipes/a.jpg`)],
    ["the recipes folder itself", url(`users/${UID}/recipes/`)],
    ["not a storage URL", "https://example.com/a.jpg"],
  ];
  for (const [name, u] of refused) {
    check(`refused: ${name}`, recipePhotoPath(u, UID) === null, `got ${recipePhotoPath(u, UID)}`);
  }
  {
    const bucket = new FakeBucket([`users/${OTHER}/recipes/a.jpg`, `users/${UID}/avatars/a.jpg`]);
    const r = await deleteRecipePhotos(bucket, UID, [
      url(`users/${OTHER}/recipes/a.jpg`),
      url(`users/${UID}/avatars/a.jpg`),
      url(`users/${UID}/recipes/../avatars/a.jpg`),
    ], "test");
    check("refused paths are never deleted", bucket.deleted.length === 0 && r.failed === 3,
      `deleted=${bucket.deleted} failed=${r.failed}`);
  }

  // ── thumbnails ──
  const thumbs = (p: string) => recipeThumbnailPaths(p) as string[];
  check(".jpg thumbnail is <name>_thumb.jpg",
    thumbs(`users/${UID}/recipes/r.jpg`).includes(`users/${UID}/recipes/thumbnails/r_thumb.jpg`));
  for (const ext of [".png", ".jpeg", ".webp", ".gif"]) {
    const t = thumbs(`users/${UID}/recipes/r${ext}`);
    check(`${ext} thumbnail covers the writer's name and <name>_thumb${ext}`,
      t.includes(`users/${UID}/recipes/thumbnails/r${ext}`) &&
      t.includes(`users/${UID}/recipes/thumbnails/r_thumb${ext}`), `got ${t}`);
  }
  check("a thumbnail has no thumbnail",
    thumbs(`users/${UID}/recipes/thumbnails/r_thumb.jpg`).length === 0);

  console.log(`\n${passed}/${passed + failed} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
