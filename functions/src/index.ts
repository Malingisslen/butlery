/**
 * Cloud Functions for Butlery Application
 *
 * Rating Aggregation System:
 * - Automatically maintains denormalized rating statistics in recipe documents
 * - Triggers on rating create/update/delete operations
 * - Calculates: ratingCount, averageRating, ratingDistribution, lastRatedAt
 * - Prevents N+1 query problems and ensures O(1) rating stat access
 *
 * LLM Services (Vertex AI / Gemini):
 * - structureRecipe: Extract structured recipe from text
 * - ocrRecipeImage: Extract recipe from images using vision AI
 */

import { setGlobalOptions } from "firebase-functions/v2/options";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  scheduleRatingAggregation,
  drainRatingAggregationQueue,
} from "./ratings/rating-aggregation";

setGlobalOptions({ region: "europe-west1" });

admin.initializeApp();

// LLM Functions - Vertex AI / Gemini integration
export { structureRecipe } from "./llm/structure-recipe";
export { ocrRecipeImage } from "./llm/ocr-recipe-image";

// GDPR Article 15 Right of Access — server-side export of admin-only data
// (BUT-770). The audit_logs collection is unreadable by users at the rules
// layer (BUT-424 tampering-detection invariant); this callable runs under
// Admin SDK to satisfy the user's right to access their own actor history.
export { exportAuditLogs } from "./exports/audit-logs";

// Storage upload moderation (BUT-780): magic-byte verification of every
// `onObjectFinalized` event so a spoofed Content-Type can't slip an SVG
// or executable past the Storage rule's contentType allow-list.
export { moderateUpload } from "./storage/moderate-upload";

// BUT-778: server-side conversation.lastMessage sync. Replaces the deprecated
// client-side ConversationAutoHealerModule, which spawned ~50 per-conversation
// `messages` listeners per active user. CF triggers once per message
// create/update/delete and updates the parent conversation atomically.
export { syncConversationLastMessage } from "./messaging/sync-conversation-last-message";

// Cleanup Functions - Event-triggered
export { onRecipeDeleted } from "./cleanup/cleanup-recipe-storage";

// Cleanup Functions - Scheduled
export { cleanupExpiredCache } from "./cleanup/cleanup-cache";
export { cleanupOldAuditLogs, getAuditLogStats } from "./cleanup/cleanup-audit-logs";
export { purgeExpiredAuditLogs } from "./audit_logs/purge-expired";
export { cleanupDeletedIngredients, getDeletedIngredientStats } from "./cleanup/cleanup-deleted-ingredients";
export { cleanupOldNotifications } from "./cleanup/cleanup-old-notifications";
export { cleanupOldRateLimits } from "./cleanup/cleanup-rate-limits";
export { cleanupExpiredSocialRequests } from "./cleanup/cleanup-expired-social-requests";
export { cleanupSharedContentMetadata } from "./cleanup/cleanup-shared-content-metadata";

// Social Cleanup - User deletion and moderation
export { onUserDeleted } from "./cleanup/on-user-deleted";

// BUT-788: server-side account-deletion callable. Replaces the prior
// client-side `firebaseAuth.user.delete()` + 30-collection Flutter cascade.
// Runs own-data cleanup under Admin SDK, then calls `admin.auth().deleteUser`
// which triggers `onUserDeleted` for cross-user cleanup.
export { requestAccountDeletion } from "./account/request-account-deletion";

// Social - Profile propagation
export { onProfileUpdated } from "./social/on-profile-updated";

// Parse Event Logging - Server-side analytics (P1-4 security)
export { logParseEvent } from "./events/log-parse-event";

// Parse Correction Logging - per-field correction telemetry (BUT-595)
export { logParseCorrection } from "./events/log-parse-correction";

// Web Error Logging - Crashlytics-equivalent for Flutter Web (BUT-449)
export { logWebError } from "./events/log-web-error";

// Admin Functions - Site config management
export { seedSiteConfigs, getSiteConfigStats } from "./admin/seed-site-configs";
export { bulkMarkForRetagging, getRetagStatus } from "./admin/bulk-retag";

// BUT-458: One-time backfill of recipe_comments denorm fields.
// REMOVE this export (and the source file) once a `hasMore: false` invocation
// has held for 30 days without rule-error reports. See file header for full
// lifecycle conditions.
export { backfillRecipeCommentsDenorm } from "./migrations/backfill-recipe-comments-denorm";

// Notification Functions - FCM push notifications
export { sendNotification, sendNotificationBatch } from "./notifications/send-notification";
export { deliverScheduledNotifications } from "./notifications/deliver-scheduled-notifications";
export { recordNotificationOpened } from "./notifications/record-notification-opened";

// Ingredient Functions - Cascade updates
export { onIngredientSoftDeleted } from "./ingredients/on-ingredient-soft-deleted";
export { onIngredientPropertiesChanged } from "./ingredients/on-ingredient-properties-changed";

// Ingredient Suggestion Functions - User-submitted suggestions
export { onSuggestionCreated, onSuggestionStatusChanged } from "./ingredients/on-suggestion-created";

// Analytics Functions - Ingredient tracking
export { trackUnmatchedIngredients, getUnmatchedIngredientStats } from "./analytics/track-unmatched-ingredients";

// Analytics Functions - Scheduled engagement
export { detectLapsedUsers } from "./analytics/detect-lapsed-users";
export { sendWeeklyActivityDigest } from "./analytics/send-activity-digest";
export { trackDayNRetention } from "./analytics/track-retention";
export { computeFeatureRetention } from "./analytics/compute-feature-retention";
export { correlateNotificationEffectiveness } from "./analytics/correlate-notifications";
export { suppressLowPerformers } from "./analytics/suppress-low-performers";

// Scheduled Aggregations - North Star metrics
export { northStarWeekly } from "./scheduled/north-star-weekly";

// BUT-627: Ping moderation
export { pingSweeper } from "./scheduled/ping_sweeper";
export { onPingCreated } from "./triggers/ping_onCreate";

// Correction Analytics - Alias learning and domain stats
export { analyzeCorrections, getCorrectionStats } from "./analytics/analyze-corrections";


// Feedback Functions - Beta user feedback
export { onFeedbackCreated } from "./feedback/on-feedback-created";

// Admin identity: keep the `admin` custom claim in sync with admins/{uid}
export { onAdminGranted, onAdminRevoked } from "./admin/sync-admin-claim";

// Content Moderation - Report processing
export { onReportCreated } from "./feedback/on-report-created";

// BUT-654: Duplicate-content rejection on comments + chat
export {
  guardDuplicateComment,
  guardDuplicateMessage,
} from "./social/duplicate-content-guard";

const db = admin.firestore();

/**
 * Rating statistics interface matching Dart model
 */
interface RatingStats {
  ratingCount: number;
  averageRating: number;
  ratingDistribution: { [key: number]: number };
  lastRatedAt: admin.firestore.Timestamp;
}

/**
 * Aggregates all ratings for a recipe and updates denormalized stats
 *
 * **Performance Characteristics:**
 * - Single transaction ensures consistency
 * - Processes ALL ratings for the recipe (typically 10-100 ratings)
 * - Runs server-side: no client bandwidth or memory impact
 * - Average execution time: 50-200ms depending on rating count
 *
 * **Trigger Events:**
 * - onCreate: New rating added
 * - onUpdate: Rating value changed
 * - onDelete: Rating removed
 *
 * @param recipeId The ID of the recipe to update
 */
async function updateRecipeRatingStats(recipeId: string): Promise<void> {
  logger.info(`Updating rating stats for recipe ${recipeId}`);

  try {
    // Query all ratings for this recipe
    const ratingsSnapshot = await db
      .collection("recipe_ratings")
      .where("recipeId", "==", recipeId)
      .get();

    logger.info(
      `Found ${ratingsSnapshot.size} ratings for recipe ${recipeId}`
    );

    // Calculate aggregates
    if (ratingsSnapshot.empty) {
      // No ratings - clear all rating stats
      await db.collection("recipe_social_stats").doc(recipeId).set({
        ratingCount: 0,
        averageRating: null,
        ratingDistribution: null,
        lastRatedAt: null,
      }, { merge: true });

      logger.info(
        `Cleared rating stats for recipe ${recipeId} (no ratings)`
      );
      return;
    }

    // Initialize counters
    let totalRating = 0;
    let ratingCount = 0;
    const distribution: { [key: number]: number } = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };
    let lastRatedAt: admin.firestore.Timestamp | null = null;

    // Process all ratings
    ratingsSnapshot.forEach((doc) => {
      const data = doc.data();
      const ratingValue = data.rating as number;
      const ratedAt = data.createdAt as admin.firestore.Timestamp;

      // Validate rating value (1-5)
      if (ratingValue >= 1 && ratingValue <= 5) {
        totalRating += ratingValue;
        ratingCount++;
        distribution[ratingValue] = (distribution[ratingValue] || 0) + 1;

        // Track most recent rating
        if (!lastRatedAt || ratedAt.toMillis() > lastRatedAt.toMillis()) {
          lastRatedAt = ratedAt;
        }
      } else {
        logger.warn(
          `Invalid rating value ${ratingValue} for recipe ${recipeId}, doc ${doc.id}`
        );
      }
    });

    // Calculate average
    const averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

    // Update recipe document with aggregated stats
    const stats: Partial<RatingStats> = {
      ratingCount: ratingCount,
      averageRating: Math.round(averageRating * 10) / 10, // Round to 1 decimal
      ratingDistribution: distribution,
      lastRatedAt: lastRatedAt || admin.firestore.Timestamp.now(),
    };

    await db.collection("recipe_social_stats").doc(recipeId).set(stats, { merge: true });

    logger.info(
      `Updated recipe ${recipeId}: ${ratingCount} ratings, avg ${stats.averageRating}`
    );
  } catch (error) {
    logger.error(
      `Failed to update rating stats for recipe ${recipeId}:`,
      error
    );
    throw error; // Re-throw to trigger Cloud Functions retry
  }
}

/**
 * Trigger: When a new rating is created
 *
 * Path: ratings/{ratingId}
 * Event: onCreate
 */
export const onRatingCreated = onDocumentCreated(
  "recipe_ratings/{ratingId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const recipeId = data.recipeId as string;

    if (!recipeId) {
      logger.error(
        `Rating ${event.data!.id} missing recipeId field`
      );
      return;
    }

    logger.info(
      `New rating created for recipe ${recipeId} (rating: ${data.rating})`
    );

    await scheduleRatingAggregation(recipeId);
  }
);

/**
 * Trigger: When a rating is updated
 *
 * Path: ratings/{ratingId}
 * Event: onUpdate
 */
export const onRatingUpdated = onDocumentUpdated(
  "recipe_ratings/{ratingId}",
  async (event) => {
    const before = event.data!.before.data();
    const after = event.data!.after.data();
    const recipeId = after.recipeId as string;

    if (!recipeId) {
      logger.error(
        `Rating ${event.data!.after.id} missing recipeId field`
      );
      return;
    }

    // Only update if rating value changed
    if (before.rating !== after.rating) {
      logger.info(
        `Rating updated for recipe ${recipeId} (${before.rating} -> ${after.rating})`
      );

      // BUT-482: debounce — coalesce bursts on popular recipes within 5s.
      await scheduleRatingAggregation(recipeId);
    } else {
      logger.info(
        `Rating ${event.data!.after.id} updated but value unchanged, skipping aggregation`
      );
    }
  }
);

/**
 * Trigger: When a rating is deleted
 *
 * Path: ratings/{ratingId}
 * Event: onDelete
 */
export const onRatingDeleted = onDocumentDeleted(
  "recipe_ratings/{ratingId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const recipeId = data.recipeId as string;

    if (!recipeId) {
      logger.error(
        `Deleted rating ${event.data!.id} missing recipeId field`
      );
      return;
    }

    logger.info(
      `Rating deleted for recipe ${recipeId} (was: ${data.rating})`
    );

    await scheduleRatingAggregation(recipeId);
  }
);

/**
 * BUT-482: Drain pending rating-aggregation markers every minute.
 *
 * The trigger handlers above only WRITE markers; this scheduler is the
 * single producer of `recipe_social_stats` writes. Per-recipe latency is
 * 0..60s after the rate-burst settles, which is acceptable for rating
 * stats display (was: synchronous, throttled at ~1/sec on hot recipes).
 *
 * Region pinned via `setGlobalOptions` above.
 */
export const drainRatingAggregations = onSchedule(
  { schedule: "every 1 minutes", timeoutSeconds: 120 },
  async () => {
    const result = await drainRatingAggregationQueue({
      aggregate: updateRecipeRatingStats,
    });
    logger.info("rating_aggregation.drain_complete", {
      event: "rating_aggregation.drain_complete",
      processed: result.processed,
      failed: result.failed,
      durationMs: result.durationMs,
    });
  }
);
