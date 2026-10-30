/**
 * BUT-788: Firestore cascade for server-side account deletion.
 *
 * Runs under Admin SDK from the `requestAccountDeletion` callable. Owns the
 * user's own-data deletion across ~25 collections; cross-user cleanup
 * (friendships, friend counts, group memberships, anonymizations) is owned
 * by the existing `onUserDeleted` v1 auth trigger which fires automatically
 * AFTER `admin.auth().deleteUser(uid)` — see request-account-deletion.ts.
 *
 * **Tier ordering** (mirrors the prior client cascade in
 * `lib/services/account/account_deletion/`):
 *
 *   Tier 1 (parallel): own-content + own-data-on-shared-surfaces.
 *     Recipes, menus, shopping lists, personal tags, cook-snaps, activity
 *     events, weekly menus, pantry, messages, shared content, comments &
 *     ratings, pings, reports, notifications & FCM tokens.
 *   Tier 2 (parallel after T1): subcollections under `users/{uid}` that
 *     Firestore won't cascade when the root doc is deleted.
 *   Tier 3 (final): the `users/{uid}` root document itself.
 *
 * Each step returns `true` on success, `false` on caught failure. A failed
 * step is recorded in `failedCollections` of the orchestrator result and
 * does NOT abort the cascade — partial cleanup beats total failure for
 * GDPR Article 17. The audit log records `gdprCompliant: false` whenever
 * `failedCollections` is non-empty.
 *
 * Idempotency: every step uses Firestore deletes / `arrayRemove` / `set`
 * with merge, or a per-document transaction that re-reads before it writes
 * — all safe to re-run if the caller retries after a partial failure. The post-cascade probe (`probeResidualData`) confirms the
 * highest-risk collections are empty after the run.
 *
 * The step bodies live in `account/cascade/`, one module per area; this file is the
 * one import surface for them.
 */

export { runStep } from "./cascade/core";
export type { RetainedRecord, DeletionResult, Step } from "./cascade/core";
export {
  deleteRecipes,
  deleteMenus,
  deletePersonalTags,
  deletePersonalTagGroups,
  deleteTagOverridesLog,
  deleteParsingCorrections,
  PARSING_CORRECTIONS_PAGE,
  deleteCookSnaps,
  deleteActivityEvents,
  TEMPLATE_SWEEP_PAGE,
  deleteShoppingListTemplates,
  deleteDeepLinks,
  MAX_SUGGESTION_SWEEP_ROWS,
  deleteIngredientSuggestions,
  RECIPE_SUGGESTION_SWEEP_PAGE,
  deleteRecipeSuggestions,
} from "./cascade/own-content";
export { deleteShoppingLists } from "./cascade/shopping-lists";
export {
  deleteMfaRecoveryData,
  deleteGuestQuota,
  MAX_HOUSEHOLD_SHARE_SWEEP_ROWS,
  deleteHouseholdAllergenShares,
  deleteFeatureRetentionFlags,
  RETENTION_ANALYTICS_PARENTS,
  deleteRetentionAnalytics,
  deleteNotificationEffectiveness,
  deleteFcmTokens,
  deleteNotificationPreferences,
  deleteNotifications,
  deleteNotificationAnalytics,
} from "./cascade/own-account-data";
export {
  deleteWeeklyMenuPlans,
  deletePantryItems,
} from "./cascade/weekly-menu-plans";
export { deleteFamilyData } from "./cascade/family";
export {
  deletePollVotes,
  anonymizeSystemMessagesAboutUser,
} from "./cascade/message-side-records";
export { deleteMessages } from "./cascade/messages";
export {
  MAX_MIRROR_SWEEP_ROWS,
  deleteBlockMirrors,
  MAX_BLOCK_SWEEP_ROWS,
  deleteBlocks,
  MAX_BLOCK_HELD_SWEEP_ROWS,
  scrubBlockHeldShares,
} from "./cascade/blocks";
export {
  removeFromSharedContent,
  ITEM_UID_FIELDS,
  isSharedContentParent,
} from "./cascade/shared-content";
export {
  deleteCommentsAndRatings,
  MAX_RATING_OWNER_SWEEP_ROWS,
  scrubRatingRecipeOwner,
  MAX_COMMENT_OWNER_SWEEP_ROWS,
  MAX_COMMENT_SHARE_SWEEP_ROWS,
  MAX_COMMENT_LIKE_SWEEP_ROWS,
  scrubCommentRecipeOwner,
  scrubCommentSharedWith,
  deleteCommentLikes,
} from "./cascade/comments-ratings";
export {
  MAX_RECIPE_MEMBER_SWEEP_ROWS,
  scrubRecipeMemberPermissions,
  COMMENT_REACTION_KEYS,
  MAX_COMMENT_REACTION_SWEEP_ROWS,
  scrubCommentReactions,
  MAX_MESSAGE_REACTION_SWEEP_ROWS,
  scrubMessageReactions,
} from "./cascade/recipe-members-reactions";
export {
  deletePingsByUser,
  deleteUserReports,
  USER_MODERATION,
} from "./cascade/moderation";
export type { ReporterErasureOutcome } from "./cascade/moderation";
export {
  deleteModerationSystemEvents,
  deleteModerationRecord,
  deleteReportHistoryByReporter,
} from "./cascade/moderation-history";
export {
  deleteRealtimeMenus,
  deleteRealtimeResources,
  MAX_LIVE_MENU_VOTE_SWEEP_ROWS,
  deleteLiveMenuVotes,
} from "./cascade/realtime";
export {
  TRIGGER_OWNED_SUBCOLLECTIONS,
  EXPORT_EXEMPT,
  deleteUserPreferences,
  deleteConsentRecords,
  USER_SUBCOLLECTIONS,
  deleteUserSubcollections,
  deleteUserProfile,
} from "./cascade/user-subcollections";
export {
  MAX_CHAT_GROUPS_PER_USER,
  deleteChatGroupMemberships,
} from "./cascade/chat-groups";
export { probeResidualData } from "./cascade/residual-probe";
export { userStoragePrefix } from "./cascade/storage";
