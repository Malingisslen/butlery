/**
 * H10: Cloud Function to cascade soft-deleted ingredient changes to recipes.
 *
 * When an ingredient is marked as deleted (status: "deleted"), this function:
 * 1. Queries all recipes that use this ingredient
 * 2. Marks those recipes for retagging by setting generatorVersion to 'stale-ingredient'
 *
 * This ensures allergen data stays current when ingredients are removed from the database.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { stripDiacritics } from "../shared/swedish-normalize";

import { withTimeout, CASCADE_TIMEOUT_MS } from "../shared/with-timeout";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

/** Normalize Swedish text for ingredient matching (superset of Dart-side å/ä/ö). */
function normalizeSwedish(text: string): string {
  return stripDiacritics(text.toLowerCase());
}

/**
 * Trigger: When an ingredient document is updated
 *
 * Path: ingredients/{ingredientId}
 * Event: onUpdate
 *
 * Only triggers cascade when status changes to 'deleted'
 */
export const onIngredientSoftDeleted = functions.firestore
  .document("ingredients/{ingredientId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const ingredientId = context.params.ingredientId;

    // Only trigger when status changes to 'deleted'
    if (before.status === "deleted" || after.status !== "deleted") {
      return;
    }

    const ingredientName = after.swedish as string;
    // CRIT-5: Use Swedish normalization to match Dart-side ingredient lookup
    const ingredientNameNormalized = ingredientName
      ? normalizeSwedish(ingredientName)
      : undefined;

    if (!ingredientName) {
      functions.logger.error(
        `Ingredient ${ingredientId} missing 'swedish' field`
      );
      return;
    }

    functions.logger.info(
      `Ingredient soft-deleted: "${ingredientName}" (${ingredientId})`
    );

    // MED-10: Wrap cascade operation with timeout to prevent hanging on large datasets
    const cascadeOperation = async (): Promise<void> => {
      // Query recipes that might use this ingredient
      // CRIT-5: Use Swedish-normalized name to match Dart-side storage
      // (ingredientsNormalized stores å→a, ä→a, ö→o transformed names)
      const recipesSnapshot = await getDb()
        .collection("recipes")
        .where(
          "core.ingredientsNormalized",
          "array-contains",
          ingredientNameNormalized
        )
        .get();

      if (recipesSnapshot.empty) {
        functions.logger.info(
          `No recipes found using ingredient "${ingredientName}"`
        );
        return;
      }

      functions.logger.info(
        `Found ${recipesSnapshot.size} recipes using "${ingredientName}"`
      );

      // Mark all affected recipes for retagging using batched writes
      // LOW-6: 500 is the Firestore maximum operations per batch commit.
      // This is a hard limit from Firebase, not an arbitrary choice.
      // See: https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
      const batchSize = 500;
      const db = getDb();
      let batch = db.batch();
      let operationCount = 0;
      let totalUpdated = 0;

      for (const doc of recipesSnapshot.docs) {
        batch.update(doc.ref, {
          "core.tagResult.generatorVersion": "stale-ingredient",
        });
        operationCount++;
        totalUpdated++;

        // Commit batch if we hit the limit
        if (operationCount >= batchSize) {
          await batch.commit();
          functions.logger.info(`Committed batch of ${operationCount} updates`);
          batch = db.batch();
          operationCount = 0;
        }
      }

      // Commit remaining operations
      if (operationCount > 0) {
        await batch.commit();
        functions.logger.info(`Committed final batch of ${operationCount} updates`);
      }

      functions.logger.info(
        `Marked ${totalUpdated} recipes for retagging due to deleted ingredient "${ingredientName}"`
      );
    };

    try {
      await withTimeout(
        cascadeOperation(),
        CASCADE_TIMEOUT_MS,
        `Cascade soft-delete for "${ingredientName}"`
      );
    } catch (error) {
      functions.logger.error(
        `Failed to cascade soft-delete for ingredient "${ingredientName}":`,
        error
      );
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  });
