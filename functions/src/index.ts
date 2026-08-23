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
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { scheduleRatingAggregation } from "./ratings/rating-aggregation";
import {
  mirrorRatingToPool,
  POOL_MIRROR_TRIGGER_PATH,
  RatingDoc,
} from "./ratings/canonical-rating-aggregation";
import {
  schedulePoolAggregation,
  POOL_EVENT_TRIGGER_PATH,
} from "./ratings/pool-aggregation";
import {
  isProfileRating,
  shouldRecomputeOnFamilyRatingUpdate,
} from "./ratings/family-rating-recompute";

// `maxInstances` here is not performance tuning — it is what makes the project
// deployable at all. Cloud Run admits a new revision only if the sum of
// `cpu x maxInstances` across every service in the region fits the project's CPU
// quota, and leaving the ceiling unset does not mean "no reservation": it means
// the platform default of 100 per function. Multiplied across this project's
// gen2 services that is thousands of vCPU, and the 2026-08-17 deploy failed on
// 53 of them with "Quota exceeded for total allowable CPU per project per
// region" — each one surfacing the symptom as `Container Healthcheck failed`,
// which reads like broken code and is not. (The service COUNT is deliberately
// not written here: nothing asserts it, so it goes stale by ADDITION every time
// an export lands, with its own bytes untouched.)
//
// This is a cap on INSTANCES, not on in-flight requests: `concurrency` is a
// separate option that defaults to 80 at cpu >= 1, so the real ceiling per
// function is ~800 simultaneous requests, not 10. A function that genuinely
// needs more raises `maxInstances` in its OWN options object, which wins over
// this one key-by-key. Raising it globally re-arms the same wall, and the wall
// is invisible until a deploy is already half-applied.
//
// Does NOT reach `onUserDeleted`: that is a gen1 auth trigger, which v2
// `setGlobalOptions` cannot configure — verified in the compiled manifest,
// where it is the one export reporting `platform: "gcfv1"`. Gen1 is understood
// not to draw on the Cloud Run CPU pool this cap protects, so it is left out of
// the arithmetic above; that part is a platform property, not something the SDK
// or this repo can prove.
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

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

// BUT-1838: chat groups. Membership lives on a shared `chat_groups` document
// that no client may write, so every add/remove goes through one of the
// callables below — which is what lets the minor-membership gate run at INVITE time
// instead of once, at chat creation, as an after-the-fact trigger. Replaces
// `leaveGroupConversation` (BUT-1788), deleted in the same change rather than
// left beside them: two homes for one membership operation is the failure
// BUT-1795 records.
export { createChatGroup } from "./groups/create-chat-group";
export { addChatGroupMembers } from "./groups/add-chat-group-members";
export { removeChatGroupMember } from "./groups/remove-chat-group-member";
// BUT-1856: the meal-vote poll's entry point. Resolve-or-create, so a social
// group gets ONE chat instead of one per poll. It creates through
// `createChatGroupWithDeps`, so the gate above binds it too.
export { ensureCategoryChat } from "./groups/ensure-category-chat";

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

// Analytics Functions - the ten daily analytics jobs and the two weekly
// reports no longer own a Cloud Scheduler job each. They run as tasks inside
// `dailyAnalytics` (06:00 UTC) and `weeklyReports` (Mon 08:00 UTC) — see
// `./scheduled/maintenance-dispatchers`. Their `runX(deps)` seams are
// unchanged and remain the contract for tests.
export { suppressLowPerformers } from "./analytics/suppress-low-performers";

// Maintenance dispatchers — one Cloud Scheduler job per chain. Cloud Scheduler
// bills per JOB per month (3 free per billing account), not per run, so the
// analytics jobs above are merged into these three.
//
// DO NOT hoist this into a top-of-file `import`. `onSchedule` reads
// `getGlobalOptions()` EAGERLY at module-eval time (firebase-functions 7.2.5),
// and `export … from` compiles to a `require` at this source position — i.e.
// AFTER the `setGlobalOptions(...)` call above. Moving it above that line
// silently deploys all three dispatchers to us-central1.
// Verify against `functions/lib/index.js`, not the TypeScript source.
export {
  dailyAnalytics,
  weeklyReports,
  drainAggregations,
} from "./scheduled/maintenance-dispatchers";

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
 * BUT-482: pending rating-aggregation markers are drained every minute by
 * `drainAggregations` in `./scheduled/maintenance-dispatchers`, which runs this
 * queue and the pooled-rating queue CONCURRENTLY under one Cloud Scheduler job.
 *
 * The trigger handlers above only WRITE markers; that drainer is the single
 * producer of `recipe_social_stats` writes. Per-recipe latency is unchanged at
 * 0..60s after the rate-burst settles.
 */

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
 * Pending pool-aggregation markers are drained every minute by
 * `drainAggregations` in `./scheduled/maintenance-dispatchers` — the single
 * producer of canonical_recipe_stats writes. Per-pool latency is unchanged at
 * 0..60s after the write burst settles. The aggregator is wired there
 * explicitly; the shared drainer has no default and throws if it is omitted, so
 * a wiring mistake fails loudly rather than silently no-opping.
 */
