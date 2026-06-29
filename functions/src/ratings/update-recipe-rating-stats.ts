/**
 * Aggregates a recipe's public rating counter from EVERY rater, each once:
 *   - account users via `recipe_ratings` (one doc per user, editable), and
 *   - non-account family diners (children/guests) via `family_ratings` rows
 *     whose `memberType` is `profile`.
 *
 * Account users' family self-rates already mirror into `recipe_ratings`, so
 * only the PROFILE family rows are added here — no adult is double-counted.
 * Proxy-entered adult family rows (memberType `user`) are not that adult's own
 * verifiable public rating and are intentionally excluded.
 *
 * The cross-household read runs under the Admin SDK (server-side only); the
 * result is an ANONYMOUS aggregate, so no client ever sees another household's
 * individual verdict — only the combined average. Writes
 * `recipe_social_stats/{recipeId}`.
 *
 * Accepted scope (CF review, Low): a family rating on a PRIVATE/never-shared
 * recipe now creates a `recipe_social_stats` doc too. That collection is
 * world-readable to signed-in users, but it carries only an anonymous
 * count/average/distribution — no recipe content, no rater identity — keyed by
 * an opaque recipe id. Deliberately not gated on shared-status: the gate would
 * cost a recipe lookup per rating (against the cost-minimisation rule) for a
 * near-zero-risk surface. If private-recipe aggregate visibility ever matters,
 * gate the write on the recipe being shared/public.
 *
 * Extracted from index.ts so it can be invoked directly under the emulator.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

export interface RatingStats {
  ratingCount: number;
  averageRating: number;
  ratingDistribution: { [key: number]: number };
  lastRatedAt: admin.firestore.Timestamp;
}

export async function updateRecipeRatingStats(
  recipeId: string,
  dbArg?: admin.firestore.Firestore
): Promise<void> {
  const db = dbArg ?? admin.firestore();
  logger.info(`Updating rating stats for recipe ${recipeId}`);

  try {
    const [ratingsSnapshot, familySnapshot] = await Promise.all([
      db.collection("recipe_ratings").where("recipeId", "==", recipeId).get(),
      db
        .collection("family_ratings")
        .where("recipeId", "==", recipeId)
        .where("memberType", "==", "profile")
        .get(),
    ]);

    logger.info(
      `Found ${ratingsSnapshot.size} user + ${familySnapshot.size} ` +
        `family-diner ratings for recipe ${recipeId}`
    );

    if (ratingsSnapshot.empty && familySnapshot.empty) {
      await db.collection("recipe_social_stats").doc(recipeId).set(
        {
          ratingCount: 0,
          averageRating: null,
          ratingDistribution: null,
          lastRatedAt: null,
        },
        { merge: true }
      );
      logger.info(`Cleared rating stats for recipe ${recipeId} (no ratings)`);
      return;
    }

    let totalRating = 0;
    let ratingCount = 0;
    const distribution: { [key: number]: number } = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let lastRatedAt: admin.firestore.Timestamp | null = null;

    const fold = (
      ratingValue: number,
      ratedAt: admin.firestore.Timestamp | undefined,
      docId: string
    ): void => {
      if (ratingValue >= 1 && ratingValue <= 5) {
        totalRating += ratingValue;
        ratingCount++;
        distribution[ratingValue] = (distribution[ratingValue] || 0) + 1;
        if (
          ratedAt &&
          (!lastRatedAt || ratedAt.toMillis() > lastRatedAt.toMillis())
        ) {
          lastRatedAt = ratedAt;
        }
      } else {
        logger.warn(
          `Invalid rating value ${ratingValue} for recipe ${recipeId}, doc ${docId}`
        );
      }
    };

    ratingsSnapshot.forEach((doc) => {
      const data = doc.data();
      fold(
        data.rating as number,
        data.createdAt as admin.firestore.Timestamp | undefined,
        doc.id
      );
    });

    familySnapshot.forEach((doc) => {
      const data = doc.data();
      fold(
        data.stars as number,
        (data.lastUpdatedAt ?? data.createdAt) as
          | admin.firestore.Timestamp
          | undefined,
        doc.id
      );
    });

    const averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

    const stats: Partial<RatingStats> = {
      ratingCount: ratingCount,
      averageRating: Math.round(averageRating * 10) / 10,
      ratingDistribution: distribution,
      lastRatedAt: lastRatedAt || admin.firestore.Timestamp.now(),
    };

    await db
      .collection("recipe_social_stats")
      .doc(recipeId)
      .set(stats, { merge: true });

    logger.info(
      `Updated recipe ${recipeId}: ${ratingCount} ratings, avg ${stats.averageRating}`
    );
  } catch (error) {
    logger.error(`Failed to update rating stats for recipe ${recipeId}:`, error);
    throw error; // Re-throw to trigger Cloud Functions retry
  }
}
