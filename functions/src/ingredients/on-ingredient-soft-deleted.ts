/**
 * H10: Cloud Function to cascade soft-deleted ingredient changes to recipes.
 *
 * When an ingredient is marked as deleted (status: "deleted"), this function:
 * 1. Queries all recipes that use this ingredient
 * 2. Marks those recipes for retagging by setting generatorVersion to 'stale-ingredient'
 *
 * This ensures allergen data stays current when ingredients are removed from the database.
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
 * Trigger: When an ingredient document is updated
 *
 * Path: ingredients/{ingredientId}
 * Event: onUpdate
 *
 * Only triggers cascade when status changes to 'deleted'
 */
export const onIngredientSoftDeleted = onDocumentUpdated(
  {
    document: "ingredients/{ingredientId}",
    // The `setGlobalOptions` call in index.ts declares no `timeoutSeconds`, so
    // this ran at the v2 event DEFAULT of 60s — shorter than its own
    // `CASCADE_TIMEOUT_MS` guard, which therefore could never fire. Now that the
    // query is a collectionGroup that actually matches documents, a common
    // ingredient (salt, socker, mjöl) fans out across every user's recipes at
    // 500 writes per page, and a platform kill mid-cascade is silent and does
    // not resume. BUT-1781.
    timeoutSeconds: CASCADE_TIMEOUT_SECONDS,
    // One cascade per container. `concurrency` defaults to 80 at cpu >= 1, and
    // an admin ingredient sync soft-deletes up to 500 rows in ONE batch, firing
    // that many events at once — each holding a 500-document page of recipe
    // snapshots for up to 540s. Sharing a 512MiB container between them OOMs,
    // and the failure is not self-correcting: `retry: true` re-delivers into the
    // same packing until the event-age guard below abandons the cascade for
    // good, leaving every matching recipe tagged from the deleted ingredient
    // with nothing that re-runs it. Instance count is NOT the control here —
    // packing happens before Cloud Run scales out, so this must be declared even
    // when `maxInstances` is generous.
    concurrency: 1,
    // OVERRIDES the global ceiling, which dropped to 3 on 2026-08-27 to make
    // deploys fit `CpuAllocPerProjectRegion`. With `concurrency: 1` above, one
    // instance drains one event at a time, so capacity inside the 1h
    // `CASCADE_MAX_EVENT_AGE_MS` window is on the order of
    // `maxInstances x 3600/540` — roughly 20 at 3, roughly 66 at 10 — against
    // the up-to-500-event batch described above. That is a floor rather than an
    // estimate (see the full reasoning in `index.ts`), so at the global value
    // the event-age guard COULD abandon the cascade silently — the exact
    // permanent-mistagging failure this comment block already describes. 66
    // does not clear 500 either; the override buys a factor, not safety.
    //
    // Registered in `ALLOWED_OVERRIDES` in `deploy-manifest.test.ts`; the pair
    // must move together.
    maxInstances: 10,
    // v2 event triggers do NOT retry by default — without this the `throw` at
    // the bottom is logged and dropped, so a timeout or a transient Firestore
    // error at page N leaves every remaining recipe carrying allergen tags
    // computed from the ingredient's PREVIOUS properties, permanently: nothing
    // re-runs the cascade (the weekly cleanup only counts, and bulk retagging
    // is a manual admin callable capped at 5/day). Safe because the write is
    // idempotent — a constant marker value, and the cursor restarts at page 1.
    // Bounded by the event-age guard below. BUT-1781.
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

    // `retry: true` re-delivers for up to 7 days. Stop a deterministically
    // failing cascade from re-writing pages for a week.
    if (isCascadeEventExpired(event.time)) {
      logger.error("cascade.abandoned", {
        cascade: "onIngredientSoftDeleted",
        ingredientId,
        eventTime: event.time,
      });
      return;
    }

    // Only trigger when status changes to 'deleted'
    if (before.status === "deleted" || after.status !== "deleted") {
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

    logger.info(
      `Ingredient soft-deleted: "${ingredientName}" (${ingredientId})`
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
        { "core.tagResult.generatorVersion": "stale-ingredient" },
        db
      );

      if (totalUpdated === 0) {
        logger.info(
          `No recipes found using ingredient "${ingredientName}"`
        );
        return;
      }

      logger.info(
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
      logger.error(
        `Failed to cascade soft-delete for ingredient "${ingredientName}":`,
        error
      );
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  }
);
