/**
 * CRITICAL-3: Cloud Function to cascade ingredient property changes to recipes.
 *
 * When an ingredient's properties change (allergens, dietary properties, etc.),
 * this function marks all recipes using that ingredient for retagging.
 *
 * This ensures allergen and dietary data stays current when ingredient
 * properties are updated in the database.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { stripDiacritics } from "../shared/swedish-normalize";
import { batchUpdateDocs } from "../shared/batch-update";
import { Collections } from "../shared/collections";
import { withTimeout, CASCADE_TIMEOUT_MS } from "../shared/with-timeout";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

/**
 * Normalize Swedish text to match Dart-side normalization.
 */
function normalizeSwedish(text: string): string {
  return stripDiacritics(text.toLowerCase());
}

/**
 * Compare two property arrays for meaningful differences.
 * Returns true if the properties changed in a way that affects tagging.
 */
function propertiesChanged(
  before: string[] | undefined,
  after: string[] | undefined
): boolean {
  const beforeSet = new Set(before || []);
  const afterSet = new Set(after || []);

  // Check if any properties were added or removed
  if (beforeSet.size !== afterSet.size) {
    return true;
  }

  for (const prop of beforeSet) {
    if (!afterSet.has(prop)) {
      return true;
    }
  }

  return false;
}

/**
 * Trigger: When an ingredient document is updated
 *
 * Path: ingredients/{ingredientId}
 * Event: onUpdate
 *
 * Triggers cascade when properties change (excluding soft-delete which is
 * handled by onIngredientSoftDeleted).
 */
export const onIngredientPropertiesChanged = functions.firestore
  .document("ingredients/{ingredientId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const ingredientId = context.params.ingredientId;

    // Skip if status changed to 'deleted' (handled by onIngredientSoftDeleted)
    if (before.status !== "deleted" && after.status === "deleted") {
      functions.logger.debug(
        `Skipping ${ingredientId}: soft-delete handled by other function`
      );
      return;
    }

    // Check if properties actually changed
    const beforeProps = before.properties as string[] | undefined;
    const afterProps = after.properties as string[] | undefined;

    if (!propertiesChanged(beforeProps, afterProps)) {
      functions.logger.debug(
        `Skipping ${ingredientId}: properties unchanged`
      );
      return;
    }

    const ingredientName = after.swedish as string;
    const ingredientNameNormalized = ingredientName
      ? normalizeSwedish(ingredientName)
      : undefined;

    if (!ingredientName || !ingredientNameNormalized) {
      functions.logger.error(
        `Ingredient ${ingredientId} missing 'swedish' field`
      );
      return;
    }

    // Log the property change for debugging
    const addedProps = (afterProps || []).filter(
      (p) => !(beforeProps || []).includes(p)
    );
    const removedProps = (beforeProps || []).filter(
      (p) => !(afterProps || []).includes(p)
    );

    functions.logger.info(
      `Ingredient properties changed: "${ingredientName}" (${ingredientId})`,
      {
        added: addedProps,
        removed: removedProps,
      }
    );

    const cascadeOperation = async (): Promise<void> => {
      // Query recipes that use this ingredient
      const recipesSnapshot = await getDb()
        .collection(Collections.recipes)
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

      const db = getDb();
      const totalUpdated = await batchUpdateDocs(
        null,
        db,
        () => ({ "core.tagResult.generatorVersion": "stale-properties" }),
        recipesSnapshot.docs.map((doc) => doc.ref)
      );

      functions.logger.info(
        `Marked ${totalUpdated} recipes for retagging due to property change for "${ingredientName}"`
      );
    };

    try {
      await withTimeout(
        cascadeOperation(),
        CASCADE_TIMEOUT_MS,
        `Cascade property change for "${ingredientName}"`
      );
    } catch (error) {
      functions.logger.error(
        `Failed to cascade property change for ingredient "${ingredientName}":`,
        error
      );
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  });
