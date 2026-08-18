/**
 * CRITICAL-3: Cloud Function to cascade ingredient property changes to recipes.
 *
 * When an ingredient's properties change (allergens, dietary properties, etc.),
 * this function marks all recipes using that ingredient for retagging.
 *
 * This ensures allergen and dietary data stays current when ingredient
 * properties are updated in the database.
 */

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { ingredientMatchVariants } from "../shared/swedish-normalize";
import { batchUpdateQueryPaginated } from "../shared/batch-update";
import { Collections } from "../shared/collections";
import {
  withTimeout,
  isCascadeEventExpired,
  CASCADE_TIMEOUT_MS,
  CASCADE_TIMEOUT_SECONDS,
} from "../shared/with-timeout";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

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
export const onIngredientPropertiesChanged = onDocumentUpdated(
  {
    document: "ingredients/{ingredientId}",
    // See the identical note on onIngredientSoftDeleted: without an explicit
    // timeout this ran at the v2 event default of 60s, i.e. shorter than its own
    // CASCADE_TIMEOUT_MS guard, and a platform kill mid-cascade is silent and
    // does not resume. BUT-1781.
    timeoutSeconds: CASCADE_TIMEOUT_SECONDS,
    // See the identical note on onIngredientSoftDeleted: `concurrency` defaults
    // to 80, one admin sync fires hundreds of these at once, and each holds a
    // 500-document page for up to 540s — sharing a 512MiB container OOMs, and
    // `retry: true` then re-delivers into the same packing until the event-age
    // guard abandons the cascade permanently.
    concurrency: 1,
    // See the identical note on onIngredientSoftDeleted: v2 event triggers do
    // not retry by default, so without this the `throw` below is dropped and a
    // half-finished fan-out leaves recipes tagged from the ingredient's OLD
    // allergen properties with nothing to recover them. The update is
    // idempotent, and the event-age guard below bounds the retry window.
    retry: true,
    memory: "512MiB",
  },
  async (event) => {
    // `retry: true` is on, so a TypeError from an absent payload would become an
    // hour-long retry loop instead of a single dropped event.
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const ingredientId = event.params.ingredientId;

    // `retry: true` re-delivers for up to 7 days; abandon a cascade that is
    // failing deterministically rather than re-writing pages all week.
    if (isCascadeEventExpired(event.time)) {
      logger.error("cascade.abandoned", {
        cascade: "onIngredientPropertiesChanged",
        ingredientId,
        eventTime: event.time,
      });
      return;
    }

    // Skip if status changed to 'deleted' (handled by onIngredientSoftDeleted)
    if (before.status !== "deleted" && after.status === "deleted") {
      logger.debug(
        `Skipping ${ingredientId}: soft-delete handled by other function`
      );
      return;
    }

    // Check if properties actually changed
    const beforeProps = before.properties as string[] | undefined;
    const afterProps = after.properties as string[] | undefined;

    if (!propertiesChanged(beforeProps, afterProps)) {
      logger.debug(
        `Skipping ${ingredientId}: properties unchanged`
      );
      return;
    }

    const ingredientName = after.swedish as string;

    if (!ingredientName) {
      logger.error(
        `Ingredient ${ingredientId} missing 'swedish' field`
      );
      return;
    }

    const ingredientNameVariants = ingredientMatchVariants(ingredientName);

    const addedProps = (afterProps || []).filter(
      (p) => !(beforeProps || []).includes(p)
    );
    const removedProps = (beforeProps || []).filter(
      (p) => !(afterProps || []).includes(p)
    );

    logger.info(
      `Ingredient properties changed: "${ingredientName}" (${ingredientId})`,
      {
        added: addedProps,
        removed: removedProps,
      }
    );

    const cascadeOperation = async (): Promise<void> => {
      const db = getDb();
      // Recipes live ONLY at users/{uid}/recipes/{recipeId} — there is no
      // top-level `recipes` collection, so a collection-scoped read matched
      // zero docs and this cascade never fired (BUT-1781). The matching
      // COLLECTION_GROUP index for core.ingredientsNormalized is declared in
      // firestore.indexes.json → fieldOverrides.
      // Paginate the read: a common ingredient can match thousands of recipes,
      // and loading them all at once risks an out-of-memory crash.
      const recipesQuery = db
        .collectionGroup(Collections.recipes)
        .where(
          "core.ingredientsNormalized",
          "array-contains-any",
          ingredientNameVariants
        );

      const totalUpdated = await batchUpdateQueryPaginated(
        recipesQuery,
        { "core.tagResult.generatorVersion": "stale-properties" },
        db
      );

      if (totalUpdated === 0) {
        logger.info(
          `No recipes found using ingredient "${ingredientName}"`
        );
        return;
      }

      logger.info(
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
      logger.error(
        `Failed to cascade property change for ingredient "${ingredientName}":`,
        error
      );
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  }
);
