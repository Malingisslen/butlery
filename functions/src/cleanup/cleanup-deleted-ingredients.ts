/**
 * Deleted Ingredient Cleanup Cloud Function
 *
 * Scheduled to run weekly to:
 * 1. Hard-delete ingredients that have been soft-deleted for > 30 days
 * 2. Find recipes still referencing stale ingredients and ensure they're marked for retagging
 *
 * This function maintains data hygiene and prevents orphaned references.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Configuration
const SOFT_DELETE_GRACE_PERIOD_DAYS = 30;
const BATCH_SIZE = 500; // Firestore batch limit

/**
 * Weekly cleanup of soft-deleted ingredients
 *
 * Schedule: 0 4 * * 1 (Weekly on Monday at 4 AM UTC)
 * Region: europe-west1 (Stockholm)
 *
 * Actions:
 * 1. Find ingredients with status='deleted' older than grace period
 * 2. Hard-delete them permanently
 * 3. Check for recipes with stale tags and ensure they're queued for retagging
 */
export const cleanupDeletedIngredients = functions
  .region("europe-west1")
  .pubsub.schedule("0 4 * * 1") // Weekly on Monday at 4 AM UTC
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();

    functions.logger.info("Starting deleted ingredient cleanup...");

    try {
      // Calculate cutoff date for permanent deletion
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - SOFT_DELETE_GRACE_PERIOD_DAYS);
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

      functions.logger.info(
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

      functions.logger.info(
        `Ingredient cleanup complete: hard-deleted ${deletedIngredientsCount} ingredients, ` +
          `found ${staleRecipesCount} recipes with stale tags`
      );

      return null;
    } catch (e) {
      functions.logger.error("Ingredient cleanup failed", e);
      throw e; // Let Cloud Functions retry
    }
  });

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
    functions.logger.info("No old deleted ingredients to hard-delete");
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
      functions.logger.info(`Committed batch of ${BATCH_SIZE} deletions`);
    }
  }

  // Commit remaining deletions
  if (batchCount > 0) {
    await batch.commit();
    functions.logger.info(`Committed final batch of ${batchCount} deletions`);
  }

  return deletedCount;
}

/**
 * Count recipes that have stale ingredient tags.
 * These recipes have generatorVersion='stale-ingredient' or 'failed'.
 */
async function countStaleRecipes(
  db: admin.firestore.Firestore
): Promise<number> {
  // Count recipes with stale-ingredient marker
  const staleSnapshot = await db
    .collection("recipes")
    .where("core.tagResult.generatorVersion", "==", "stale-ingredient")
    .count()
    .get();

  const failedSnapshot = await db
    .collection("recipes")
    .where("core.tagResult.generatorVersion", "==", "failed")
    .count()
    .get();

  const staleCount = staleSnapshot.data().count;
  const failedCount = failedSnapshot.data().count;

  if (staleCount > 0 || failedCount > 0) {
    functions.logger.warn(
      `Found ${staleCount} stale and ${failedCount} failed recipes needing retagging`
    );
  }

  return staleCount + failedCount;
}

/**
 * Get deleted ingredient statistics (callable for admin dashboard)
 */
export const getDeletedIngredientStats = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    // Verify admin access
    if (!context.auth?.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required"
      );
    }

    const db = admin.firestore();

    try {
      // Count soft-deleted ingredients
      const deletedSnapshot = await db
        .collection("ingredients")
        .where("status", "==", "deleted")
        .count()
        .get();

      // Count recipes with stale tags
      const staleRecipesSnapshot = await db
        .collection("recipes")
        .where("core.tagResult.generatorVersion", "==", "stale-ingredient")
        .count()
        .get();

      const failedRecipesSnapshot = await db
        .collection("recipes")
        .where("core.tagResult.generatorVersion", "==", "failed")
        .count()
        .get();

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
        staleRecipesCount: staleRecipesSnapshot.data().count,
        failedRecipesCount: failedRecipesSnapshot.data().count,
        oldestDeletedAt,
        gracePeriodDays: SOFT_DELETE_GRACE_PERIOD_DAYS,
      };
    } catch (e) {
      functions.logger.error("Failed to get deleted ingredient stats", e);
      throw new functions.https.HttpsError("internal", "Failed to get stats");
    }
  });
