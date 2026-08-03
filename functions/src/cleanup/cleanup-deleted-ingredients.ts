/**
 * Deleted Ingredient Cleanup Cloud Function
 *
 * Scheduled to run weekly to:
 * 1. Hard-delete ingredients that have been soft-deleted for > 30 days
 * 2. Find recipes still referencing stale ingredients and ensure they're marked for retagging
 *
 * This function maintains data hygiene and prevents orphaned references.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { requireAdmin } from "../shared/require-admin";

// Configuration
const SOFT_DELETE_GRACE_PERIOD_DAYS = 30;
const BATCH_SIZE = 500; // Firestore batch limit

/**
 * Weekly cleanup of soft-deleted ingredients
 *
 * Schedule: 0 4 * * 1 (Weekly on Monday at 4 AM UTC)
 *
 * Actions:
 * 1. Find ingredients with status='deleted' older than grace period
 * 2. Hard-delete them permanently
 * 3. Check for recipes with stale tags and ensure they're queued for retagging
 */
export const cleanupDeletedIngredients = onSchedule(
  { schedule: "0 4 * * 1", timeZone: "UTC" },
  async () => {
    const db = admin.firestore();

    logger.info("Starting deleted ingredient cleanup...");

    try {
      // Calculate cutoff date for permanent deletion
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - SOFT_DELETE_GRACE_PERIOD_DAYS);
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

      logger.info(
        `Deleting ingredients soft-deleted before ${cutoffDate.toISOString()}`
      );

      // Step 1: Find and hard-delete old soft-deleted ingredients
      const deletedIngredientsCount = await hardDeleteOldIngredients(
        db,
        cutoffTimestamp
      );

      // Step 2: Find recipes with stale ingredient tags
      const staleRecipesCount = await countStaleRecipes(db);

      // Log cleanup event for monitoring
      const cleanupLog = {
        type: "ingredient_cleanup",
        ingredientsHardDeleted: deletedIngredientsCount,
        staleRecipesFound: staleRecipesCount,
        gracePeriodDays: SOFT_DELETE_GRACE_PERIOD_DAYS,
        cutoffDate: cutoffDate.toISOString(),
        executedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection("system_events").add(cleanupLog);

      logger.info(
        `Ingredient cleanup complete: hard-deleted ${deletedIngredientsCount} ingredients, ` +
          `found ${staleRecipesCount} recipes with stale tags`
      );

    } catch (e) {
      logger.error("Ingredient cleanup failed", e);
      throw e; // Let Cloud Functions retry
    }
  }
);

/**
 * Hard-delete ingredients that have been soft-deleted past the grace period.
 */
async function hardDeleteOldIngredients(
  db: admin.firestore.Firestore,
  cutoffTimestamp: admin.firestore.Timestamp
): Promise<number> {
  const ingredientsRef = db.collection("ingredients");

  // Query soft-deleted ingredients older than grace period
  const snapshot = await ingredientsRef
    .where("status", "==", "deleted")
    .where("deletedAt", "<", cutoffTimestamp)
    .limit(5000) // Process up to 5k per run
    .get();

  if (snapshot.empty) {
    logger.info("No old deleted ingredients to hard-delete");
    return 0;
  }

  let deletedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    batchCount++;
    deletedCount++;

    // Commit every 500 operations (Firestore batch limit)
    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
      logger.info(`Committed batch of ${BATCH_SIZE} deletions`);
    }
  }

  // Commit remaining deletions
  if (batchCount > 0) {
    await batch.commit();
    logger.info(`Committed final batch of ${batchCount} deletions`);
  }

  return deletedCount;
}

/**
 * Every `generatorVersion` value that means "this recipe still needs retagging".
 *
 * ONE list, because there are two producers and three consumers and they had
 * already drifted: `on-ingredient-soft-deleted.ts` writes `stale-ingredient`
 * and `on-ingredient-properties-changed.ts` writes `stale-properties`, but this
 * monitor counted only the first, so the second was invisible to the very
 * dashboard meant to catch it. Keep in sync with `_needsRetagging` in
 * `lib/services/offline/offline_user_storage.dart` — the Dart side is what
 * actually re-runs the tagger.
 */
const STALE_TAG_MARKERS = [
  "stale-ingredient",
  "stale-properties",
  // Written by the bulk-retag drain callable. Without it the monitor reads 0
  // the moment an operator drains, while N recipes still await a client
  // retag — it would certify success for an action that only moved the marker.
  "outdated",
] as const;

/** Count recipes carrying any stale marker, across every user's subcollection. */
async function countByMarkers(
  db: admin.firestore.Firestore,
  markers: readonly string[]
): Promise<number> {
  const counts = await Promise.all(
    markers.map((marker) =>
      db
        .collectionGroup("recipes")
        .where("core.tagResult.generatorVersion", "==", marker)
        .count()
        .get()
        .then((snap) => snap.data().count)
    )
  );
  return counts.reduce((total, n) => total + n, 0);
}

/**
 * Count recipes that have stale ingredient tags.
 *
 * BUT-1781: recipes live ONLY at users/{uid}/recipes/{recipeId}; the previous
 * collection-scoped read hit a top-level `recipes` collection that does not
 * exist, so this monitor always reported 0. The COLLECTION_GROUP index for
 * core.tagResult.generatorVersion is declared in firestore.indexes.json.
 */
async function countStaleRecipes(
  db: admin.firestore.Firestore
): Promise<number> {
  const staleCount = await countByMarkers(db, STALE_TAG_MARKERS);
  const failedCount = await countByMarkers(db, ["failed"]);

  if (staleCount > 0 || failedCount > 0) {
    logger.warn(
      `Found ${staleCount} stale and ${failedCount} failed recipes needing retagging`
    );
  }

  return staleCount + failedCount;
}

/**
 * Get deleted ingredient statistics (callable for admin dashboard)
 */
export const getDeletedIngredientStats = onCall(
  async (request: CallableRequest) => {
    requireAdmin(request);

    const db = admin.firestore();

    try {
      // Count soft-deleted ingredients
      const deletedSnapshot = await db
        .collection("ingredients")
        .where("status", "==", "deleted")
        .count()
        .get();

      // Count recipes with stale tags. Collection-group scoped: recipes live
      // under users/{uid}/recipes, never at the root (BUT-1781). Both stale
      // markers, not just the soft-delete one — see STALE_TAG_MARKERS.
      const staleRecipesCount = await countByMarkers(db, STALE_TAG_MARKERS);
      const failedRecipesCount = await countByMarkers(db, ["failed"]);

      // Get oldest soft-deleted ingredient
      const oldestSnapshot = await db
        .collection("ingredients")
        .where("status", "==", "deleted")
        .orderBy("deletedAt", "asc")
        .limit(1)
        .get();

      let oldestDeletedAt: string | null = null;
      if (!oldestSnapshot.empty) {
        const oldest = oldestSnapshot.docs[0].data();
        oldestDeletedAt = oldest.deletedAt?.toDate().toISOString() || null;
      }

      return {
        softDeletedCount: deletedSnapshot.data().count,
        staleRecipesCount,
        failedRecipesCount,
        oldestDeletedAt,
        gracePeriodDays: SOFT_DELETE_GRACE_PERIOD_DAYS,
      };
    } catch (e) {
      logger.error("Failed to get deleted ingredient stats", e);
      throw new HttpsError("internal", "Failed to get stats");
    }
  }
);
