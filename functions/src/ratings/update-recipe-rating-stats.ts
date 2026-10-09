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
 * BUT-2084 — what one recompute READS is bounded. Each collection is read with
 * `limit(FOLD_LIMIT + 1)`; a collection that fits is folded in memory as
 * before. A collection past the limit has its count and distribution from
 * `count()` aggregations instead — five equality-filtered counts for that collection, which
 * single-field indexes serve without a composite index and which Firestore
 * bills per 1,000 index entries. The average is computed from the distribution,
 * never from `sum()`/`average()`, which would need a composite index. Only
 * whole-number values 1–5 are counted on either path, so the two paths agree
 * at the limit.
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

/** Rows per collection folded in memory before the recompute counts instead. */
export const FOLD_LIMIT = 100;

const STAR_VALUES = [1, 2, 3, 4, 5] as const;

/** Index entries one billed read covers in an aggregation query. */
const AGGREGATION_ENTRIES_PER_READ = 1000;

export interface RecomputeResult {
  /**
   * Billed document reads this recompute cost: the rows fetched, plus each
   * aggregation's own charge. Summed per drain into the `docsRead` counter.
   */
  docsRead: number;
  /** True when the count() path ran because a collection passed the limit. */
  counted: boolean;
}

function isStarValue(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 1 && (value as number) <= 5;
}

export async function updateRecipeRatingStats(
  recipeId: string,
  dbArg?: admin.firestore.Firestore,
  foldLimit: number = FOLD_LIMIT
): Promise<RecomputeResult> {
  const db = dbArg ?? admin.firestore();
  logger.info(`Updating rating stats for recipe ${recipeId}`);

  const userRatings = db
    .collection("recipe_ratings")
    .where("recipeId", "==", recipeId);
  const dinerRatings = db
    .collection("family_ratings")
    .where("recipeId", "==", recipeId)
    .where("memberType", "==", "profile");

  try {
    const [ratingsSnapshot, familySnapshot] = await Promise.all([
      userRatings.limit(foldLimit + 1).get(),
      dinerRatings.limit(foldLimit + 1).get(),
    ]);
    // An empty query is still billed one read.
    let docsRead =
      Math.max(ratingsSnapshot.size, 1) + Math.max(familySnapshot.size, 1);

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
      return { docsRead, counted: false };
    }

    const distribution: { [key: number]: number } = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let lastRatedAt: admin.firestore.Timestamp | null = null;

    const countInto = async (
      query: admin.firestore.Query,
      field: string
    ): Promise<void> => {
      const counts = await Promise.all(
        STAR_VALUES.map((star) => query.where(field, "==", star).count().get())
      );
      counts.forEach((snapshot, index) => {
        const count = snapshot.data().count;
        distribution[STAR_VALUES[index]] += count;
        docsRead += Math.max(1, Math.ceil(count / AGGREGATION_ENTRIES_PER_READ));
      });
    };

    const fold = (
      ratingValue: unknown,
      ratedAt: admin.firestore.Timestamp | undefined,
      docId: string
    ): void => {
      if (!isStarValue(ratingValue)) {
        logger.warn(
          `Invalid rating value ${ratingValue} for recipe ${recipeId}, doc ${docId}`
        );
        return;
      }
      distribution[ratingValue]++;
      if (
        ratedAt &&
        (!lastRatedAt || ratedAt.toMillis() > lastRatedAt.toMillis())
      ) {
        lastRatedAt = ratedAt;
      }
    };

    const usersCounted = ratingsSnapshot.size > foldLimit;
    const dinersCounted = familySnapshot.size > foldLimit;
    const counted = usersCounted || dinersCounted;

    if (usersCounted) {
      await countInto(userRatings, "rating");
    } else {
      ratingsSnapshot.forEach((doc) => {
        const data = doc.data();
        fold(
          data.rating,
          data.createdAt as admin.firestore.Timestamp | undefined,
          doc.id
        );
      });
    }

    if (dinersCounted) {
      await countInto(dinerRatings, "stars");
    } else {
      familySnapshot.forEach((doc) => {
        const data = doc.data();
        fold(
          data.stars,
          (data.lastUpdatedAt ?? data.createdAt) as
            | admin.firestore.Timestamp
            | undefined,
          doc.id
        );
      });
    }

    let ratingCount = 0;
    let totalRating = 0;
    for (const star of STAR_VALUES) {
      ratingCount += distribution[star];
      totalRating += star * distribution[star];
    }
    const averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

    const stats: Partial<RatingStats> = {
      ratingCount: ratingCount,
      averageRating: Math.round(averageRating * 10) / 10,
      ratingDistribution: distribution,
    };
    if (!counted) {
      stats.lastRatedAt = lastRatedAt || admin.firestore.Timestamp.now();
    }

    await db
      .collection("recipe_social_stats")
      .doc(recipeId)
      .set(stats, { merge: true });

    logger.info("rating_stats.recomputed", {
      event: "rating_stats.recomputed",
      recipeId,
      ratingCount,
      docsRead,
      counted,
    });
    return { docsRead, counted };
  } catch (error) {
    logger.error(`Failed to update rating stats for recipe ${recipeId}:`, error);
    throw error; // Re-throw to trigger Cloud Functions retry
  }
}
