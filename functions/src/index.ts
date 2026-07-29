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
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  scheduleRatingAggregation,
  drainRatingAggregationQueue,
} from "./ratings/rating-aggregation";
import { updateRecipeRatingStats } from "./ratings/update-recipe-rating-stats";
import {
  mirrorRatingToPool,
  POOL_MIRROR_TRIGGER_PATH,
  RatingDoc,
} from "./ratings/canonical-rating-aggregation";
import {
  schedulePoolAggregation,
  drainPoolAggregationQueue,
  POOL_EVENT_TRIGGER_PATH,
} from "./ratings/pool-aggregation";
import { updatePooledRatingStats } from "./ratings/update-pooled-rating-stats";
import {
  isProfileRating,
  shouldRecomputeOnFamilyRatingUpdate,
} from "./ratings/family-rating-recompute";

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

// BUT-1626 (BUT-674): group-conversation minor-safety gate. Removes a minor who
// was added to a group by a non-friend — the group backstop for the 1:1 DM gate
// that firestore.rules enforces (rules can't iterate a group participant list).
export { enforceGroupMinorMembership } from "./messaging/enforce-group-minor-membership";

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

// BUT-1386 (ADR-0002): authoritative server-side age enforcement. Only writer
// of `birthYear` + the `ageCompliant` custom claim that gates the UGC paths.
export { verifySignupAge } from "./account/verify-signup-age";

// Social - Profile propagation
export { onProfileUpdated } from "./social/on-profile-updated";

// Pre-release audit B1: server-side friend-request acceptance. Moves the
// mutual friend-doc write off the client so the friends-write rule can be
// tightened to owner-only — closing a hole where a stranger could insert
// themselves into a victim's friends list and read private cook_snaps.
export { acceptFriendRequest } from "./social/accept-friend-request";

// BUT-1629: the only path by which a minor can become searchable. The rules
// hard-deny (BUT-1626) blocks every CLIENT write of isSearchable:true for a
// minor; this Admin-SDK callable is the audited server-side exception.
export { setProfileSearchability } from "./social/set-profile-searchability";

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
// Pooled ratings ("Butlery-betyget") one-shot backfill (decision 14). HARD-GATED:
// a real run refuses unless enable_pooled_ratings is ON; see the file header for the
// full run gate + lifecycle-delete conditions. Built now, not run.
export { backfillCanonicalRatings } from "./migrations/backfill-canonical-ratings";
// BUT-1725: one-shot backfill of contributorUserIds on shared shopping lists,
// the handle account erasure uses to find lists a user has LEFT. REMOVE this
// export (and the source file) after a `hasMore: false` run plus a 30-day soak
// with no residual_data_detected on a shared list; see the file header.
export { backfillSharedListContributors } from "./migrations/backfill-shared-list-contributors";

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

// Analytics Functions - Daily snapshot aggregates for dashboard delta/anomaly
// series on the non-time-series tabs (staggered 05:00–05:40 UTC).
export {
  snapshotImportHealthDaily,
  snapshotRecipesDaily,
  snapshotParsingCorrectionsDaily,
  snapshotOpsDaily,
  snapshotFeedbackDaily,
} from "./analytics/daily-snapshots";

// Analytics Functions - Nightly anomaly detector over the daily snapshot series
// (06:00 UTC, after the 05:00–05:40 snapshot jobs).
export { detectAnomalies } from "./analytics/detect-anomalies";
export { correlateNotificationEffectiveness } from "./analytics/correlate-notifications";
export { suppressLowPerformers } from "./analytics/suppress-low-performers";

// Scheduled Aggregations - North Star metrics
export { northStarWeekly } from "./scheduled/north-star-weekly";

// BUT-627: Ping moderation
export { pingSweeper } from "./scheduled/ping_sweeper";
export { onPingCreated } from "./triggers/ping_onCreate";

// Family-rating storage limitation (GDPR Art. 5(1)(e), DPO-confirmed 24mo)
export { purgeDormantFamilyData } from "./family/purge-dormant-family-data";

// Correction Analytics - Alias learning and domain stats
export { analyzeCorrections, getCorrectionStats } from "./analytics/analyze-corrections";
// BUT-1468: human review + revoke for held allergen-relevant aliases
export { reviewLearnedAlias, revokeLearnedAlias } from "./analytics/review-learned-alias";


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

// ─── Family-diner ratings feed the same public counter ───────────────────
//
// A non-account family diner (memberType `profile`) rating a recipe must count
// toward the recipe's public average exactly like an account user. These
// triggers schedule the SAME aggregation; the aggregator folds in profile rows.
// Gated to `profile` rows so adult/proxy family writes (which don't affect the
// public counter — adults go via recipe_ratings) don't spend a recompute.
// `isProfileRating` / `shouldRecomputeOnFamilyRatingUpdate` live in
// ./ratings/family-rating-recompute so the update-gate is unit-testable.

export const onFamilyRatingCreated = onDocumentCreated(
  "family_ratings/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data || !isProfileRating(data)) return;
    const recipeId = data.recipeId as string;
    if (!recipeId) return;
    logger.info(`Family-diner rating created for recipe ${recipeId}`);
    await scheduleRatingAggregation(recipeId);
  }
);

export const onFamilyRatingUpdated = onDocumentUpdated(
  "family_ratings/{id}",
  async (event) => {
    const before = event.data!.before.data();
    const after = event.data!.after.data();
    // Recompute when the star value changed OR the memberType flips in EITHER
    // direction — promotion INTO `profile` (BUT-1511) or demotion OUT OF
    // `profile` (BUT-1592) — because either flip changes whether the row counts
    // toward the public average, even with unchanged stars. The direction-aware
    // gate lives inside the helper.
    if (!shouldRecomputeOnFamilyRatingUpdate(before, after)) return;
    const recipeId = after.recipeId as string;
    if (!recipeId) return;
    logger.info(`Family-diner rating updated for recipe ${recipeId}`);
    await scheduleRatingAggregation(recipeId);
  }
);

export const onFamilyRatingDeleted = onDocumentDeleted(
  "family_ratings/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data || !isProfileRating(data)) return;
    const recipeId = data.recipeId as string;
    if (!recipeId) return;
    logger.info(`Family-diner rating deleted for recipe ${recipeId}`);
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

// ─── Pooled ratings (Butlery-betyget) — Stage A: server-authoritative mirror ──
//
// SEPARATE from the recipe_social_stats aggregation above: this recomputes the
// content-derived poolKey server-side and files one frozen "pool event" per
// eligible rater. Bound to recipe_ratings ONLY (structural family exclusion,
// decision 7). Feature-flag gated (decision 11) — a no-op while the flag is off.
// The core logic + guarantees live in ratings/canonical-rating-aggregation.ts.
export const onRecipeRatingWrittenForPool = onDocumentWritten(
  // retry:true — v2 event triggers do NOT retry by default; without this the
  // `throw` below is logged and dropped. The mirror's writes are idempotent
  // (upsert at doc-ID=poolKey; delete keyed on recipeId) so a re-run is safe.
  { document: POOL_MIRROR_TRIGGER_PATH, retry: true },
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    const before = beforeSnap?.exists ? (beforeSnap.data() as RatingDoc) : null;
    const after = afterSnap?.exists ? (afterSnap.data() as RatingDoc) : null;
    if (!before && !after) return;

    try {
      const result = await mirrorRatingToPool({
        ratingId: event.params.ratingId,
        before,
        after,
      });
      logger.info("pool_mirror.result", {
        event: "pool_mirror.result",
        ratingId: event.params.ratingId,
        action: result.action,
        poolKey: result.poolKey,
      });
    } catch (err) {
      // Let Cloud Functions retry — the upsert/delete are idempotent (doc-ID =
      // poolKey; delete keyed on recipeId), so a re-run is safe.
      logger.error("pool_mirror.failed", {
        event: "pool_mirror.failed",
        ratingId: event.params.ratingId,
        err,
      });
      throw err;
    }
  }
);

// ─── Pooled ratings (Butlery-betyget) — Stage B: pool aggregator ──────────────
//
// Maintains canonical_recipe_stats/{poolKey} = {count, average, updatedAt} from
// the frozen events Stage A files. SEPARATE from Stage A: a change to ANY user's
// event for a pool must recompute THAT pool. The doc-ID wildcard {poolKey} is the
// pool identity, so we recover it from event.params even on delete (retraction /
// GDPR erasure), which fires this trigger to shrink the pool back down.
//
// NOT feature-flag gated: Stage A only creates events while the flag is on, but a
// retraction/erasure must always keep the stats consistent — like the always-on
// delete branch of the Stage A mirror. So this simply reflects whatever events
// exist; flag-off (pre-launch) means ~no events, so it rarely fires.
export const onPooledRatingEventWritten = onDocumentWritten(
  // retry:true — writes are idempotent (recompute-from-source aggregate + upsert
  // at doc-ID=poolKey), so a re-run on transient failure is safe.
  { document: POOL_EVENT_TRIGGER_PATH, retry: true },
  async (event) => {
    const poolKey = event.params.poolKey as string;
    if (!poolKey) return;
    // Only schedule a debounced recompute here (decision 5). The scheduler below
    // is the single producer of canonical_recipe_stats writes.
    await schedulePoolAggregation(poolKey);
  }
);

/**
 * Drain pending pool-aggregation markers every minute — the single producer of
 * canonical_recipe_stats writes. Per-pool latency is 0..60s after the write
 * burst settles (same trade-off as the rating drainer above). The aggregator is
 * wired here explicitly; the shared drainer has no default and would throw if it
 * were omitted (so a wiring mistake fails loudly, never silently no-ops).
 */
export const drainPooledRatingAggregations = onSchedule(
  { schedule: "every 1 minutes", timeoutSeconds: 120 },
  async () => {
    const result = await drainPoolAggregationQueue({
      aggregate: updatePooledRatingStats,
    });
    logger.info("pool_aggregation.drain_complete", {
      event: "pool_aggregation.drain_complete",
      processed: result.processed,
      failed: result.failed,
      durationMs: result.durationMs,
    });
  }
);
