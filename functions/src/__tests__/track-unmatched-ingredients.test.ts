/**
 * The unknown-ingredient tally (`analytics/track-unmatched-ingredients.ts`):
 * names only, no link to a recipe or a user.
 *
 * Run: npx ts-node src/__tests__/track-unmatched-ingredients.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import {
  handleRecipeWrite,
  looksPersonal,
  newlyUnknown,
  pruneUnmatchedIngredients,
  UNMATCHED_SHOWN_MIN_COUNT,
} from "../analytics/track-unmatched-ingredients";

const NOW = new Date("2026-10-31T12:00:00Z");
const COL = "analytics/ingredients/unmatched";

function recipe(unknowns: string[]): Record<string, unknown> {
  return { core: { title: "Kanelbullar", tagResult: { unknownIngredients: unknowns } } };
}

const cases: UnitCase[] = [
  {
    name: "a new recipe counts each of its unknown names once",
    fn: async () => {
      const f = new FakeFirestore();
      await handleRecipeWrite(f.db, undefined, recipe(["kardemummakärnor", "pärlsocker"]), NOW);
      assertEqual(f.read(`${COL}/kardemummakarnor`)?.count, 1, "kardemumma");
      assertEqual(f.read(`${COL}/parlsocker`)?.count, 1, "pärlsocker");
    },
  },
  {
    name: "only the four fields are stored, with no recipe or user id",
    fn: async () => {
      const f = new FakeFirestore();
      await handleRecipeWrite(f.db, undefined, recipe(["pärlsocker"]), NOW);
      const doc = f.read(`${COL}/parlsocker`)!;
      assertEqual(
        JSON.stringify(Object.keys(doc).sort()),
        JSON.stringify(["count", "firstSeenDay", "lastSeenDay", "name"]),
        "keys",
      );
      assertEqual(doc.firstSeenDay, "2026-10-31", "day precision");
    },
  },
  {
    name: "an unchanged unknown list counts nothing",
    fn: async () => {
      const f = new FakeFirestore();
      await handleRecipeWrite(f.db, recipe(["pärlsocker"]), recipe(["pärlsocker"]), NOW);
      assertEqual(f.writes.length, 0, "writes");
    },
  },
  {
    name: "a retag counts only the names that are new to this recipe",
    fn: async () => {
      const f = new FakeFirestore();
      f.seed(`${COL}/parlsocker`, { name: "pärlsocker", count: 4, firstSeenDay: "2026-01-01", lastSeenDay: "2026-01-01" });
      await handleRecipeWrite(f.db, recipe(["pärlsocker"]), recipe(["pärlsocker", "mandelmassa"]), NOW);
      assertEqual(f.read(`${COL}/parlsocker`)?.count, 4, "kept");
      assertEqual(f.read(`${COL}/mandelmassa`)?.count, 1, "new");
    },
  },
  {
    name: "a name that leaves and comes back is counted again (accepted: count is a ranking signal)",
    fn: () => {
      assertEqual(newlyUnknown(recipe([]), recipe(["pärlsocker"])).join(), "pärlsocker", "re-entry");
    },
  },
  {
    name: "a deleted recipe writes nothing",
    fn: async () => {
      const f = new FakeFirestore();
      await handleRecipeWrite(f.db, recipe(["pärlsocker"]), undefined, NOW);
      assertEqual(f.writes.length, 0, "writes");
    },
  },
  {
    name: "an existing name keeps its first day and display name, and loses any recipe ids",
    fn: async () => {
      const f = new FakeFirestore();
      f.seed(`${COL}/parlsocker`, {
        name: "Pärlsocker",
        count: 2,
        firstSeenDay: "2026-01-01",
        lastSeenDay: "2026-01-01",
        exampleRecipes: ["r1", "r2"],
      });
      await handleRecipeWrite(f.db, undefined, recipe(["pärlsocker"]), NOW);
      const doc = f.read(`${COL}/parlsocker`)!;
      assertEqual(doc.count, 3, "count");
      assertEqual(doc.firstSeenDay, "2026-01-01", "first day");
      assertEqual(doc.lastSeenDay, "2026-10-31", "last day");
      assertEqual(doc.name, "Pärlsocker", "display name");
      assertEqual("exampleRecipes" in doc, false, "recipe ids removed");
    },
  },
  {
    name: "names that look personal are skipped and only counted in aggregate",
    fn: async () => {
      const f = new FakeFirestore();
      await handleRecipeWrite(
        f.db,
        undefined,
        recipe(["anna@example.com", "ring 0701234567", "https://example.com/x", "pärlsocker"]),
        NOW,
      );
      assertEqual(f.childPaths(COL).join(), `${COL}/parlsocker`, "only the ingredient");
      assertEqual(f.read("analytics/ingredients")?.skippedPiiCount, 3, "skipped tally");
    },
  },
  {
    name: "looksPersonal: email, phone, personnummer, url, long digits and long text",
    fn: () => {
      for (const s of ["a@b.se", "070-123 45 67", "19900101-1234", "www.x.se", "123456", "x".repeat(61)]) {
        assertEqual(looksPersonal(s), true, s);
      }
      for (const s of ["pärlsocker", "2 dl mjölk", "vetemjöl special"]) {
        assertEqual(looksPersonal(s), false, s);
      }
    },
  },
  {
    name: "the weekly prune removes only rare names unseen for a year",
    fn: async () => {
      const f = new FakeFirestore();
      f.seed(`${COL}/old-rare`, { name: "x", count: 1, firstSeenDay: "2025-01-01", lastSeenDay: "2025-06-01" });
      f.seed(`${COL}/old-common`, { name: "y", count: UNMATCHED_SHOWN_MIN_COUNT, firstSeenDay: "2025-01-01", lastSeenDay: "2025-06-01" });
      f.seed(`${COL}/new-rare`, { name: "z", count: 1, firstSeenDay: "2026-10-01", lastSeenDay: "2026-10-01" });
      const pruned = await pruneUnmatchedIngredients(f.db, NOW);
      assertEqual(pruned, 1, "pruned");
      assertEqual(f.childPaths(COL).join(), `${COL}/new-rare,${COL}/old-common`, "kept");
    },
  },
  {
    // The onDocumentWritten path cannot be reached without the emulator; the
    // old trigger listened on a path no recipe lives at.
    name: "the trigger listens on users/{uid}/recipes/{recipeId} for every write",
    fn: () => {
      const src = fs.readFileSync(path.resolve(__dirname, "../analytics/track-unmatched-ingredients.ts"), "utf8");
      assertEqual(/onDocumentWritten\(\s*"users\/\{uid\}\/recipes\/\{recipeId\}"/.test(src), true, "path");
    },
  },
  {
    name: "the admin list shows only names seen at least the threshold",
    fn: () => {
      const src = fs.readFileSync(path.resolve(__dirname, "../analytics/track-unmatched-ingredients.ts"), "utf8");
      assertEqual(/\.where\("count", ">=", UNMATCHED_SHOWN_MIN_COUNT\)/.test(src), true, "threshold");
    },
  },
];

runTests("track-unmatched-ingredients", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
