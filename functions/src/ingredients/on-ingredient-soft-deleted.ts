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

const db = admin.firestore();

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
    const ingredientNameLower = ingredientName?.toLowerCase();

    if (!ingredientName) {
      functions.logger.error(
        `Ingredient ${ingredientId} missing 'swedish' field`
      );
      return;
    }

    functions.logger.info(
      `Ingredient soft-deleted: "${ingredientName}" (${ingredientId})`
    );

    try {
      // Query recipes that might use this ingredient
      // Note: Firestore doesn't support case-insensitive array-contains,
      // so we check normalized ingredients if available
      const recipesSnapshot = await db
        .collection("recipes")
        .where("core.ingredientsNormalized", "array-contains", ingredientNameLower)
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
      const batchSize = 500; // Firestore batch limit
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
    } catch (error) {
      functions.logger.error(
        `Failed to cascade soft-delete for ingredient "${ingredientName}":`,
        error
      );
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  });
