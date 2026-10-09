/**
 * `cleanupRecipeReferences` (BUT-2327): what `onRecipeDeleted` removes beside
 * the photos. Unit tests with a fake db, no emulator.
 *
 * Run: npx ts-node src/__tests__/recipe-reference-cleanup.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-recipe-reference-cleanup" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  cleanupRecipeReferences,
  REFERENCE_PAGE_SIZE,
  MAX_REFERENCE_PAGES,
} = require("../cleanup/recipe-reference-cleanup");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { onRecipeDeletedEvent } = require("../cleanup/cleanup-recipe-storage");

const OWNER = "owner-uid";
const RECIPE = "recipe-1";
const OTHER_RECIPE = "recipe-2";
const NOW = Date.UTC(2026, 9, 9, 18, 0, 0);

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

interface Row {
  collection: string;
  id: string;
  data: Record<string, unknown>;
}

class FakeDb {
  rows: Row[] = [];
  docs = new Map<string, Record<string, unknown>>();
  deletedDocs: string[] = [];
  recursiveDeletes: string[] = [];
  queries: string[] = [];
  throwOn = new Set<string>();
  /** `field=value` pairs a live recipe document still holds, anywhere. */
  liveRecipeIds = new Set<string>();
  reports: { contentId: string; status: string }[] = [];
  probeThrows = false;
  statsDeleteThrows = false;
  /** A collection whose deletes silently leave the row, to exercise the page cap. */
  stuck = new Set<string>();

  add(collection: string, id: string, data: Record<string, unknown>): void {
    this.rows.push({ collection, id, data });
  }

  left(collection: string, recipeId: string, field = "recipeId"): number {
    return this.rows.filter(
      (r) => r.collection === collection && r.data[field] === recipeId,
    ).length;
  }

  collection(name: string) {
    if (name === "reports") {
      return {
        where: (_field: string, _op: string, value: unknown) => ({
          get: async () => {
            this.queries.push("reports");
            const ids = value as string[];
            return {
              docs: this.reports
                .filter((r) => ids.includes(r.contentId))
                .map((r) => ({
                  id: r.contentId,
                  ref: r,
                  get: (f: string) => (r as Record<string, unknown>)[f],
                })),
            };
          },
          limit: () => {
            throw new Error("reports are read whole");
          },
        }),
      };
    }
    return {
      where: (field: string, _op: string, value: unknown) => ({
        limit: (n: number) => ({
          get: async () => {
            this.queries.push(name);
            if (this.throwOn.has(name)) {
              throw Object.assign(new Error("boom"), { code: 13 });
            }
            const docs = this.rows
              .filter((r) => r.collection === name && r.data[field] === value)
              .slice(0, n)
              .map((r) => ({
                id: r.id,
                ref: r,
                get: (f: string) => r.data[f],
              }));
            return { docs };
          },
        }),
      }),
    };
  }

  collectionGroup(id: string) {
    return {
      where: (field: string, _op: string, value: unknown) => ({
        limit: () => ({
          get: async () => {
            this.queries.push(`group:${id}.${field}`);
            if (this.probeThrows) {
              throw Object.assign(new Error("index"), { code: 9 });
            }
            return { empty: !this.liveRecipeIds.has(`${field}=${value}`) };
          },
        }),
      }),
    };
  }

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
        if (this.statsDeleteThrows && path.startsWith("recipe_social_stats/")) {
          throw new Error("stats");
        }
        this.deletedDocs.push(path);
        this.docs.delete(path);
      },
    };
  }

  async recursiveDelete(ref: unknown): Promise<void> {
    const row = ref as Row;
    this.recursiveDeletes.push(`${row.collection}/${row.id}`);
    if (this.stuck.has(row.collection)) return;
    this.rows = this.rows.filter((r) => r !== row);
  }
}

function seeded(): FakeDb {
  const db = new FakeDb();
  db.add("recipe_comments", "c1", {
    recipeId: RECIPE,
    authorId: "a",
    recipeOwnerId: OWNER,
  });
  db.add("recipe_comments", "c2", { recipeId: RECIPE, authorId: "b" });
  db.add("recipe_comments", "c3", { recipeId: OTHER_RECIPE, authorId: "a" });
  db.add("recipe_ratings", "r1", { recipeId: RECIPE, userId: "a" });
  db.add("recipe_ratings", "r2", { recipeId: OTHER_RECIPE, userId: "a" });
  db.add("cook_snaps", "s1", { recipeId: RECIPE, userId: "b" });
  db.add("shared_content", "sh1", {
    originalRecipeId: RECIPE,
    sharedByUserId: OWNER,
  });
  db.add("shared_content", "sh2", { originalRecipeId: OTHER_RECIPE });
  db.docs.set(`recipe_social_stats/${RECIPE}`, { ratingCount: 1 });
  db.docs.set(`recipe_social_stats/${OTHER_RECIPE}`, { ratingCount: 1 });
  return db;
}

async function main(): Promise<void> {
  console.log("recipe-reference-cleanup");

  {
    const db = seeded();
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "every row naming the recipe is deleted, in all four collections",
      db.left("recipe_comments", RECIPE) === 0 &&
        db.left("recipe_ratings", RECIPE) === 0 &&
        db.left("cook_snaps", RECIPE) === 0 &&
        db.left("shared_content", RECIPE, "originalRecipeId") === 0,
      JSON.stringify(db.rows),
    );
    check(
      "rows naming another recipe stay",
      db.left("recipe_comments", OTHER_RECIPE) === 1 &&
        db.left("recipe_ratings", OTHER_RECIPE) === 1 &&
        db.left("shared_content", OTHER_RECIPE, "originalRecipeId") === 1,
    );
    check(
      "each row goes through recursiveDelete, so its subcollections go too",
      db.recursiveDeletes.length === 5,
      JSON.stringify(db.recursiveDeletes),
    );
    check(
      "the recipe's stats document is deleted, and only that one",
      !db.docs.has(`recipe_social_stats/${RECIPE}`) &&
        db.docs.has(`recipe_social_stats/${OTHER_RECIPE}`),
    );
    check(
      "the result counts the rows and reports nothing incomplete",
      result.deleted.recipe_comments === 2 &&
        result.deleted.recipe_ratings === 1 &&
        result.deleted.cook_snaps === 1 &&
        result.deleted.shared_content === 1 &&
        result.incomplete.length === 0 &&
        result.skippedForErasure === false,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.docs.set(`erasures_in_progress/${OWNER}`, { startedAtMs: NOW - 1000 });
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "an owner erasure underway stops every delete",
      result.skippedForErasure === true &&
        db.recursiveDeletes.length === 0 &&
        db.deletedDocs.length === 0 &&
        db.queries.length === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.docs.set(`erasures_in_progress/${OWNER}`, {
      startedAtMs: NOW - 2 * 60 * 60 * 1000,
    });
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "an expired erasure marker does not stop the cleanup",
      result.skippedForErasure === false &&
        db.left("recipe_comments", RECIPE) === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.docs.set(`erasures_in_progress/other-uid`, { startedAtMs: NOW });
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "another account's erasure does not stop the cleanup",
      result.skippedForErasure === false &&
        db.left("recipe_ratings", RECIPE) === 0,
    );
  }

  {
    const db = seeded();
    db.throwOn.add("recipe_ratings");
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "a collection that throws is reported, and the others still run",
      result.incomplete.includes("recipe_ratings") &&
        db.left("recipe_comments", RECIPE) === 0 &&
        db.left("cook_snaps", RECIPE) === 0 &&
        db.left("shared_content", RECIPE, "originalRecipeId") === 0 &&
        !db.docs.has(`recipe_social_stats/${RECIPE}`),
      JSON.stringify(result),
    );
  }

  {
    const db = new FakeDb();
    const total = REFERENCE_PAGE_SIZE + 3;
    for (let i = 0; i < total; i++) {
      db.add("recipe_comments", `c${i}`, { recipeId: RECIPE });
    }
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "more rows than one page are all deleted",
      db.left("recipe_comments", RECIPE) === 0 &&
        result.deleted.recipe_comments === total &&
        db.queries.filter((q) => q === "recipe_comments").length === 2,
      JSON.stringify({ left: db.left("recipe_comments", RECIPE), result }),
    );
  }

  {
    const db = new FakeDb();
    for (let i = 0; i < REFERENCE_PAGE_SIZE; i++) {
      db.add("cook_snaps", `s${i}`, { recipeId: RECIPE });
    }
    db.stuck.add("cook_snaps");
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "the page cap stops a collection whose rows keep coming back",
      result.incomplete.includes("cook_snaps") &&
        db.queries.filter((q) => q === "cook_snaps").length ===
          MAX_REFERENCE_PAGES &&
        db.queries.filter((q) => q === "shared_content").length === 1,
      JSON.stringify({ result, queries: db.queries.length }),
    );
  }

  {
    const db = seeded();
    db.liveRecipeIds.add(`core.id=${RECIPE}`);
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "a recipe id another live recipe holds in core.id deletes nothing",
      result.skippedForLiveRecipe === true &&
        db.recursiveDeletes.length === 0 &&
        db.deletedDocs.length === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.probeThrows = true;
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "a live-recipe probe that fails deletes nothing",
      result.skippedForLiveRecipe === true &&
        result.incomplete.includes("recipes") &&
        db.recursiveDeletes.length === 0 &&
        db.deletedDocs.length === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.add("recipe_comments", "victim-c", {
      recipeId: RECIPE,
      recipeOwnerId: "victim-uid",
    });
    db.add("recipe_ratings", "victim-r", {
      recipeId: RECIPE,
      recipeOwnerId: "victim-uid",
    });
    db.add("shared_content", "victim-sh", {
      originalRecipeId: RECIPE,
      sharedByUserId: "victim-uid",
    });
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    const left = db.rows.map((r) => r.id);
    check(
      "rows naming another account as owner or sharer stay",
      left.includes("victim-c") &&
        left.includes("victim-r") &&
        left.includes("victim-sh") &&
        result.kept === 3,
      JSON.stringify({ left, result }),
    );
    check(
      "rows naming the deleting owner, or no owner, still go",
      !left.includes("c1") && !left.includes("c2") && !left.includes("sh1"),
      JSON.stringify(left),
    );
  }

  {
    const db = seeded();
    db.statsDeleteThrows = true;
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "a stats delete that throws is reported after the rows are gone",
      result.incomplete.includes("recipe_social_stats") &&
        db.left("recipe_comments", RECIPE) === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    const bucket = {
      file: () => ({ delete: async () => undefined }),
    };
    await onRecipeDeletedEvent(
      { db, bucket, refs: db },
      OWNER,
      RECIPE,
      undefined,
      NOW,
      NOW,
    );
    check(
      "onRecipeDeleted runs the reference cleanup for the deleted recipe",
      db.left("recipe_comments", RECIPE) === 0 &&
        db.left("cook_snaps", RECIPE) === 0 &&
        db.left("recipe_comments", OTHER_RECIPE) === 1,
      JSON.stringify(db.rows),
    );
  }

  {
    const db = seeded();
    db.docs.set(`erasures_in_progress/${OWNER}`, { startedAtMs: NOW });
    const bucket = {
      file: () => ({ delete: async () => undefined }),
    };
    await onRecipeDeletedEvent(
      { db, bucket, refs: db },
      OWNER,
      RECIPE,
      undefined,
      NOW,
      NOW,
    );
    check(
      "onRecipeDeleted passes the owner, so the owner's erasure marker stops it",
      db.left("recipe_comments", RECIPE) === 2,
      JSON.stringify(db.rows),
    );
  }

  {
    const db = seeded();
    db.liveRecipeIds.add(`id=${RECIPE}`);
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    check(
      "a recipe id a legacy flat recipe holds in id deletes nothing",
      result.skippedForLiveRecipe === true && db.recursiveDeletes.length === 0,
      JSON.stringify(result),
    );
  }

  {
    const db = seeded();
    db.reports.push({ contentId: "c2", status: "in_review" });
    db.reports.push({ contentId: "s1", status: "closed" });
    const result = await cleanupRecipeReferences(db, OWNER, RECIPE, NOW);
    const left = db.rows.map((r) => r.id);
    check(
      "a row with an open report stays; a closed report does not keep one",
      left.includes("c2") &&
        !left.includes("c1") &&
        !left.includes("s1") &&
        result.kept === 1,
      JSON.stringify({ left, result }),
    );
  }

  {
    const db = seeded();
    const bucket = {
      file: () => ({ delete: async () => undefined }),
    };
    const throwingPhotos = {
      ...db,
      doc: () => {
        throw new Error("photo step");
      },
    };
    await onRecipeDeletedEvent(
      { db: throwingPhotos, bucket, refs: db },
      OWNER,
      RECIPE,
      { imageUrls: [] },
      NOW,
      NOW,
    );
    check(
      "a photo step that throws does not stop the reference cleanup",
      db.left("recipe_comments", RECIPE) === 0,
      JSON.stringify(db.rows),
    );
  }

  {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { onRecipeDeleted } = require("../cleanup/cleanup-recipe-storage");
    const timeout = onRecipeDeleted.__endpoint?.timeoutSeconds;
    check(
      "onRecipeDeleted declares a timeout longer than the 60 s default",
      typeof timeout === "number" && timeout >= 300,
      `timeoutSeconds: ${JSON.stringify(timeout)}`,
    );
  }

  console.log(`\n${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
