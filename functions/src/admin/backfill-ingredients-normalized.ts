/**
 * One-time migration: backfill ingredientsNormalized on recipes.
 *
 * For each recipe where core.ingredientsNormalized is null/empty,
 * parses raw core.ingredients to extract ingredient names (strips
 * quantities, units, and preparation words), then normalizes Swedish chars.
 *
 * Note: this produces simplified normalized names, not taxonomy IDs.
 * The Dart client will upgrade these to full taxonomy matches on next
 * recipe save/update via IngredientProcessor.
 *
 * Usage: npx ts-node src/admin/backfill-ingredients-normalized.ts [--dry-run]
 */

import { initializeAdminApp } from "./admin-init";
import { stripDiacritics } from "../shared/swedish-normalize";

const BATCH_SIZE = 500;

/** Common Swedish quantity units to strip from ingredient strings. */
const UNITS = new Set([
  "g", "kg", "ml", "dl", "cl", "l", "msk", "tsk", "krm",
  "st", "port", "nypa", "knippe", "burk", "förp", "paket",
]);

/** Preparation words to strip (Swedish). */
const PREP_WORDS = new Set([
  "hackad", "hackade", "hackat", "skivad", "skivade", "skivat",
  "riven", "rivna", "rivet", "strimlad", "strimlade", "strimlat",
  "tärnad", "tärnade", "tärnat", "krossad", "krossade", "krossat",
  "finriven", "finrivna", "grovhackad", "grovhackade",
  "pressad", "pressade", "pressat", "skalad", "skalade", "skalat",
  "delad", "delade", "delat", "kokt", "kokta", "stekt", "stekta",
  "smält", "smälta", "tinad", "tinade", "fryst", "frysta",
]);

/**
 * Parse a raw ingredient string to extract the ingredient name.
 * Strips leading quantities (numbers, fractions) and units.
 */
function parseIngredientName(raw: string): string {
  let s = raw.trim().toLowerCase();

  // Strip leading quantity: "500g" → "g ...", "2 dl" → "dl ...", "1/2" → ""
  s = s.replace(/^[\d.,/\s-]+/, "");

  // Strip leading unit if present
  const words = s.split(/\s+/).filter((w) => w.length > 0);
  if (words.length > 1 && UNITS.has(words[0])) {
    words.shift();
  }

  // Strip preparation words
  const filtered = words.filter((w) => !PREP_WORDS.has(w));

  // Join remaining as the ingredient name
  return filtered.join(" ").trim();
}

/** Normalize Swedish/European characters using shared diacritics stripping. */
function normalizeSwedish(text: string): string {
  return stripDiacritics(text.toLowerCase());
}

/** Full normalization pipeline for one raw ingredient string. */
function normalizeIngredient(raw: string): string {
  const name = parseIngredientName(raw);
  return normalizeSwedish(name);
}

async function backfillIngredientsNormalized(dryRun: boolean): Promise<void> {
  const app = initializeAdminApp();
  const db = app.firestore();

  console.log(
    `Starting ingredientsNormalized backfill${dryRun ? " (DRY RUN)" : ""}...`
  );

  const usersSnapshot = await db.collection("users").get();
  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const recipesRef = db
      .collection("users")
      .doc(userId)
      .collection("recipes");

    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    let userUpdated = 0;

    while (true) {
      let query = recipesRef.orderBy("__name__").limit(BATCH_SIZE);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        totalProcessed++;
        const data = doc.data();
        const core = data.core ?? data;

        // Skip if already has ingredientsNormalized
        const existing: string[] | undefined = core.ingredientsNormalized;
        if (existing && existing.length > 0) {
          totalSkipped++;
          continue;
        }

        // Skip if no raw ingredients
        const rawIngredients: string[] = core.ingredients ?? [];
        if (rawIngredients.length === 0) {
          totalSkipped++;
          continue;
        }

        // Normalize each ingredient
        const normalized = rawIngredients
          .map(normalizeIngredient)
          .filter((n) => n.length > 0);

        if (normalized.length === 0) {
          totalSkipped++;
          continue;
        }

        if (!dryRun) {
          const field = data.core
            ? "core.ingredientsNormalized"
            : "ingredientsNormalized";
          batch.update(doc.ref, { [field]: normalized });
          batchCount++;
        }

        totalUpdated++;
        userUpdated++;

        if (batchCount >= BATCH_SIZE) {
          if (!dryRun) await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0 && !dryRun) {
        await batch.commit();
      }

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.docs.length < BATCH_SIZE) break;
    }

    if (userUpdated > 0) {
      console.log(`  [${userId}] ${userUpdated} recipes normalized`);
    }
  }

  console.log("\n=== Backfill Summary ===");
  console.log(`Total recipes processed: ${totalProcessed}`);
  console.log(`Recipes normalized: ${totalUpdated}`);
  console.log(`Already normalized / no ingredients: ${totalSkipped}`);
  if (dryRun) console.log("(DRY RUN — no writes performed)");
}

// Run
const dryRun = process.argv.includes("--dry-run");
backfillIngredientsNormalized(dryRun)
  .then(() => {
    console.log("Done.");
    process.exit(0);
  })
  .catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
  });
