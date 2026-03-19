/**
 * Sprint 5: Track unmatched ingredients for admin analytics.
 *
 * When a recipe is tagged, this function extracts any unknown/unmatched
 * ingredients and tracks their occurrence frequency. This helps admins
 * prioritize which ingredients to add to the global database.
 *
 * Firestore structure:
 * /ingredientAnalytics/unmatched/{normalizedName}
 *   - name: string (original name, for display)
 *   - count: number (occurrence count)
 *   - firstSeen: Timestamp
 *   - lastSeen: Timestamp
 *   - exampleRecipes: string[] (up to 5 recipe IDs)
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { stripDiacritics } from "../shared/swedish-normalize";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getDb = () => admin.firestore();

/**
 * Normalize ingredient name for consistent deduplication.
 *
 * Matches Dart-side normalization in ingredient_lookup_service.dart
 */
function normalizeIngredientName(name: string): string {
  return stripDiacritics(name.toLowerCase().trim())
    .replace(/[^a-z0-9]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/**
 * Trigger: When a recipe document is updated
 *
 * Path: recipes/{recipeId}
 * Event: onUpdate
 *
 * Only processes when core.tagResult.unknownIngredients changes
 */
export const trackUnmatchedIngredients = functions.firestore
  .document("recipes/{recipeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const recipeId = context.params.recipeId;

    // Extract unknownIngredients from tagResult
    const beforeUnknowns: string[] =
      before?.core?.tagResult?.unknownIngredients || [];
    const afterUnknowns: string[] =
      after?.core?.tagResult?.unknownIngredients || [];

    // Skip if unknownIngredients hasn't changed
    if (JSON.stringify(beforeUnknowns) === JSON.stringify(afterUnknowns)) {
      return;
    }

    // Find newly added unknown ingredients (not in before, but in after)
    const newUnknowns = afterUnknowns.filter(
      (ing) => !beforeUnknowns.includes(ing)
    );

    if (newUnknowns.length === 0) {
      functions.logger.debug(
        `Recipe ${recipeId}: No new unknown ingredients to track`
      );
      return;
    }

    functions.logger.info(
      `Recipe ${recipeId}: Tracking ${newUnknowns.length} new unknown ingredients`
    );

    const db = getDb();
    const batch = db.batch();
    const now = admin.firestore.FieldValue.serverTimestamp();

    for (const ingredientName of newUnknowns) {
      const normalizedName = normalizeIngredientName(ingredientName);

      if (!normalizedName) {
        functions.logger.warn(
          `Skipping empty ingredient name after normalization: "${ingredientName}"`
        );
        continue;
      }

      const docRef = db
        .collection("ingredientAnalytics")
        .doc("unmatched")
        .collection("items")
        .doc(normalizedName);

      // Use set with merge to handle both create and update
      batch.set(
        docRef,
        {
          name: ingredientName, // Keep original for display
          count: admin.firestore.FieldValue.increment(1),
          lastSeen: now,
          // ArrayUnion adds to array if not present, max handled separately
          exampleRecipes: admin.firestore.FieldValue.arrayUnion(recipeId),
        },
        { merge: true }
      );

      // Set firstSeen only on creation (won't overwrite if exists)
      // This requires a separate operation after the batch
    }

    try {
      await batch.commit();
      functions.logger.info(
        `Tracked ${newUnknowns.length} unknown ingredients from recipe ${recipeId}`
      );

      // Now set firstSeen for any new documents
      // (This is a secondary operation, not critical if it fails)
      for (const ingredientName of newUnknowns) {
        const normalizedName = normalizeIngredientName(ingredientName);
        if (!normalizedName) continue;

        const docRef = db
          .collection("ingredientAnalytics")
          .doc("unmatched")
          .collection("items")
          .doc(normalizedName);

        const doc = await docRef.get();
        if (doc.exists && !doc.data()?.firstSeen) {
          await docRef.update({
            firstSeen: now,
          });
        }

        // Trim exampleRecipes to max 5
        const data = doc.data();
        if (data?.exampleRecipes && data.exampleRecipes.length > 5) {
          await docRef.update({
            exampleRecipes: data.exampleRecipes.slice(0, 5),
          });
        }
      }
    } catch (error) {
      functions.logger.error(
        `Failed to track unknown ingredients for recipe ${recipeId}:`,
        error
      );
      // Don't throw - this is analytics, not critical
    }
  });

/**
 * Get statistics about unmatched ingredients.
 *
 * Callable function for admin use.
 */
export const getUnmatchedIngredientStats = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const isAdmin = context.auth.token.admin === true ||
                    context.auth.token.role === "admin";
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin access required"
      );
    }

    const db = getDb();
    const limit = data?.limit || 50;

    const snapshot = await db
      .collection("ingredientAnalytics")
      .doc("unmatched")
      .collection("items")
      .orderBy("count", "desc")
      .limit(limit)
      .get();

    const items = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      total: snapshot.size,
      items,
    };
  }
);
