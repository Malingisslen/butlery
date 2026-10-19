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
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { batchUpdateRefs, commitInChunks } from "../shared/batch-update";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";
// Deliberate cross-domain import (BUT-1822). `tryClearRoster` lives in a
// minor-safety TRIGGER module, but it is the one roster clearer: bounded,
// never-throwing, and it answers the exact question this cascade must ask before
// it deletes a conversation. A second implementation here would be a second
// contract to keep in sync on a GDPR path. Extraction into a neutral module is
// tracked separately; until then, that function's docstring names this caller.
import { tryClearRoster } from "../messaging/enforce-group-minor-membership";
import { logSafeConversationId } from "../shared/log-safe-conversation-id";
// BUT-1838: the single writer of chat-group membership. Imported rather than
// re-implemented for the same reason as `tryClearRoster` above — a second
// spelling of "remove this member" on a GDPR path is a contract to keep in sync,
// and this one touches three documents.
import { stageMemberRemoval } from "../groups/chat-group-writes";
// BUT-2032 / ADR-0014: the first audit staging in this file. The cascade had
// none and `on-user-deleted.ts` stages one per mutated row; the panel measured
// that BUT-781's analogy carries the ACTION and not the record, so the two new
// steps below keep the trigger's posture rather than inherit the cascade's.
import { stageCascadeAuditEntry } from "../cleanup/cascade-audit-log";
import { APPELLANT_ID, MODERATION_APPEALS } from "../moderation/appeals";
import {
  isClosedReportStatus,
  REPORTER_RETENTION_DAYS,
  REPORTS,
} from "../moderation/report-status";
// P6-U09: the two-step-verification collections. Imported rather than
// retyped so the cascade and the writer cannot disagree about a name or about
// the shape of the per-account counter key.
import {
  BACKUP_CODES_COLLECTION,
  RECOVERY_ATTEMPTS_COLLECTION,
  uidAttemptKey,
} from "./mfa-backup-codes";
import {
  DeletionResult,
  batchDeleteAll,
  scrubWithOneReread,
  cappedReread,
  updateWith,
} from "./cascade/core";
import { scrubDishCreator } from "./cascade/dish-creator";
import { RETENTION_ANALYTICS_PARENTS } from "./cascade/own-account-data";

export { runStep } from "./cascade/core";
export type { RetainedRecord, DeletionResult, Step } from "./cascade/core";
export {
  deleteRecipes,
  deleteMenus,
  deletePersonalTags,
  deletePersonalTagGroups,
  deleteTagOverridesLog,
  deleteCookSnaps,
  deleteActivityEvents,
  TEMPLATE_SWEEP_PAGE,
  deleteShoppingListTemplates,
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

/**
 * The `users/{uid}` subcollections `onUserDeleted` (cleanupContentGuardSubcollections)
 * owns, which run AFTER `admin.auth().deleteUser(uid)`.
 *
 * `probeResidualData` runs BEFORE that, so without the exclusion every single
 * deletion would report them as residual and `gdprCompliant` would be false
 * forever, for every user.
 *
 * Exported (BUT-2043) so guards and the reset script's unknown-collection
 * report read the real value instead of parsing this file as source text. The
 * text parsers matched `[A-Za-z_]+` and stripped only `//` comments, so a name
 * carrying a digit was invisible to them and a quoted name inside a block
 * comment was read as a list entry. The `EXPORT_EXEMPT` const below is the
 * precedent, in this same file: no separate module is needed, because nothing
 * here runs at import.
 */
export const TRIGGER_OWNED_SUBCOLLECTIONS: ReadonlySet<string> = new Set([
  "notificationCounters",
  "recentContentHashes",
]);

/**
 * GDPR canary — query the highest-risk collections AFTER the cascade.
 * Any non-zero count means a delete path silently dropped data. The probe
 * is the safety net, never the cascade itself: errors are logged but never
 * abort the wider deletion.
 *
 * Mirrors `_probeResidualData` in the prior client implementation.
 */
export async function probeResidualData(
  db: admin.firestore.Firestore,
  uid: string,
  result: DeletionResult,
): Promise<void> {
  /**
   * BUT-2046 follow-up. A lawful hold makes the probe's own house rule — the
   * deleter is a true superset of the probe — false for the legs the hold
   * keeps, and that exception is written here rather than left to be inferred:
   * without it every held erasure reports `gdprCompliant: false` about itself,
   * permanently, with no code path able to clear it.
   *
   * The set must stay in step with `deleteModerationSystemEvents`'s own `legs`
   * array. They are two spellings of one decision about which rows survive a
   * hold, and the day they disagree the erasure lies about itself.
   *
   * Scoped to the RESOURCE, not to `retained` being non-empty: `RetainedRecord`
   * is a general shape, so the day a second Art. 17(3) hold ships over some
   * other collection, a length test would silently disarm the legs below for a
   * hold that has nothing to do with moderation.
   *
   * The skipped legs are named by their LOG LABELS below, not by collection,
   * because `report_history` has two legs and only one of them is held. The other —
   * "residual report rows as reporter" — must keep firing: it is the reporter
   * side, which the hold is deliberately one-directional about, and silencing
   * it would hide a real failure of `deleteReportHistoryByReporter`.
   */
  const held = result.retained.some(
    (r) => r.resourceType === USER_MODERATION,
  );

  // `recipes` is NOT in this list, and must never be added back. These probes are
  // top-level collections filtered by a `userId` FIELD; recipes live in the
  // subcollection `users/{uid}/recipes` and are probed separately below. Reading
  // them here counted a collection with no documents, so the probe returned zero
  // on every deletion — an all-clear that was true by accident and would have
  // stayed true if `deleteRecipes` ever stopped working. Exactly the failure the
  // comment further down calls "the realtime_recipes wrong-field trap" (BUT-1801).
  const probes = [
    "user_notifications",
    "user_fcm_tokens",
    // BUT-1450: notification analytics the cascade erases (all userId-scoped).
    "notification_history",
    "notification_batches",
    "notification_engagement",
    // BUT-1473: allergen tag-override corrections (top-level, userId-scoped).
    "tag_overrides_log",
    // BUT-2028: the collection `deleteIngredientSuggestions` erases. Same
    // shape as the rest of this list — top-level, filtered on a `userId`
    // field — so it belongs here rather than needing a leg of its own.
    "ingredient_suggestions",
    // BUT-1693: the collection `deleteHouseholdAllergenShares` erases.
    "household_allergen_shares",
  ] as const;
  let residual = 0;
  for (const col of probes) {
    try {
      const snap = await db
        .collection(col)
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual in ${col}: ${count} docs`);
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, { err });
    }
  }
  // BUT-2350: `activity_events` is keyed on `actorId`, so it cannot join the
  // `userId` list above.
  try {
    const snap = await db
      .collection("activity_events")
      .where("actorId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in activity_events: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: activity_events", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2354: templates are keyed on `ownerId`, not `userId`.
  try {
    const snap = await db
      .collection(Collections.shoppingListTemplates)
      .where("ownerId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.shoppingListTemplates}: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.shoppingListTemplates}`,
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  // BUT-1801: recipes are a SUBCOLLECTION, so they need a path-scoped probe
  // rather than a userId-field filter. Counted directly under the user document:
  // no index is required for a bare `count()`, and it makes no assumption about
  // recipe documents carrying a top-level `userId` field (they are not known to).
  // A `collectionGroup("recipes").where("userId","==",uid)` probe would need both
  // — a COLLECTION_GROUP index this repo does not declare for that field, and the
  // field itself — and would fail the same silent way the top-level read did.
  try {
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("recipes")
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(`[deletion-cascade] residual in recipes: ${count} docs`);
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: recipes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-1801: poll VOTES. `deletePollVotes` deletes through `batchDeleteAll` →
  // `commitInChunks(strict:false)`, which catches a whole failed chunk and still
  // lets the step report success; only the CAP can falsify it. So a single
  // failed commit can leave up to 500 rows whose DOCUMENT ID is the erased uid,
  // with the step reporting a clean erasure. This leg is the only thing that
  // contradicts it. Uncapped and separate for the same reason as the roster leg
  // below: `count()` is cheap, and it must stay loud exactly when the deleter
  // DECLINED. It also fails CLOSED while the collection-group index builds —
  // FAILED_PRECONDITION lands in the catch as a false alarm, never a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(Collections.pollVotes)
      .where("voterId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual poll votes", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: poll_votes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2118: live-menu ballots. `deleteLiveMenuVotes` declines above its cap
  // and reports the step incomplete; this leg stays loud in that case and
  // while the collection-group index builds (FAILED_PRECONDITION lands in the
  // catch). It reads the deleter's own rows, so a `votes` document under
  // another parent is never counted.
  try {
    const rows = await liveMenuBallotRows(db, uid);
    const count = rows === null ? 1 : rows.length;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual live-menu ballots", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: votes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2046: the erased uid as a REPORTER, on rows under OTHER people's
  // moderation records, and their OWN moderation record's rows. Two legs
  // because two deleters, per this file's rule that the deleter stays a strict
  // superset of the probe. Both are collection-group / subcollection reads,
  // so neither the `probes` list nor the owner-keyed loop below can serve them.
  //
  // Uncapped on purpose: when a sweep DECLINES above
  // `MAX_REPORT_HISTORY_SWEEP_ROWS` it removes nothing, and this is what says
  // so. The reporter leg uses the same collection-group index the sweep needs,
  // so a missing index lands in the catch as a false alarm, never as a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(REPORT_HISTORY)
      .where("reporterId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual report rows as reporter", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: report_history", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // Skipped under a hold: the held person's OWN rows. The reporter leg above
  // is NOT skipped — see the note on `held`.
  if (!held) try {
    const snap = await db
      .collection(USER_MODERATION)
      .doc(uid)
      .collection(REPORT_HISTORY)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual own moderation rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: user_moderation", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // The PARENT document, whose id is the erased uid and which holds
  // `totalReports`/`lastReportedAt`. The leg above counts its rows; without
  // this one a parent standing with no rows beneath it reads as clean.
  //
  // Skipped under a hold.
  if (!held) try {
    const snap = await db.collection(USER_MODERATION).doc(uid).get();
    if (snap.exists) {
      residual += 1;
      logger.warn("[deletion-cascade] residual moderation record", {
        uid_prefix: uid.slice(0, 6),
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: user_moderation parent",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  // P6-U09: the two documents `deleteMfaRecoveryData` removes. Both are keyed
  // by the uid itself and carry no uid field, so neither the `probes` list
  // nor the field-filter loop can see them; an existence read is the leg.
  // BUT-920: `guest_quotas/{uid}` (`deleteGuestQuota`) is keyed the same way.
  for (const [col, id] of [
    [BACKUP_CODES_COLLECTION, uid],
    [RECOVERY_ATTEMPTS_COLLECTION, uidAttemptKey(uid)],
    [Collections.guestQuotas, uid],
  ] as const) {
    try {
      const snap = await db.collection(col).doc(id).get();
      if (snap.exists) {
        residual += 1;
        logger.warn(`[deletion-cascade] residual in ${col}`, {
          uid_prefix: uid.slice(0, 6),
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  // BUT-2072: the erased uid as the recipe OWNER on other people's ratings. Its
  // own leg because the `probes` list above filters on `userId`, which is the
  // rater. Uncapped, so it stays loud when the capped scrub declined.
  try {
    const snap = await db
      .collection("recipe_ratings")
      .where("recipeOwnerId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual rating owner stamps", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: rating owner", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2112: the erased uid in other people's comments — as recipe owner, as
  // a share recipient — and their own comment likes. Own legs for the same
  // reason as the rating-owner leg above.
  for (const [label, field, op] of [
    ["comment owner", "recipeOwnerId", "=="],
    ["comment shared-with", "sharedWithUserIds", "array-contains"],
  ] as const) {
    try {
      const snap = await db
        .collection("recipe_comments")
        .where(field, op, uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual ${label} stamps`, {
          uid_prefix: uid.slice(0, 6),
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${label}`, {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  // BUT-2272: the erased uid as a member of other people's shared recipes.
  // A plain count, with no skip for the user's own recipes: the probe runs
  // after tier 1, where `deleteRecipes` removes those, so one still standing
  // is residue too. Uncapped, so it stays loud when the capped scrub declined.
  try {
    const snap = await db
      .collectionGroup("recipes")
      .where(
        new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
        "!=",
        null,
      )
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual recipe member keys", {
        uidHash: hashUid(uid),
        field: "socialData.memberPermissions.<uid>",
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: recipe members", {
      uidHash: hashUid(uid),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-2115 (comments) and BUT-2398 (messages): one leg per reaction key,
  // the deleter's own query shape.
  for (const [collection, noun] of [
    ["recipe_comments", "comment"],
    ["messages", "message"],
  ] as const) {
    for (const key of COMMENT_REACTION_KEYS) {
      const label = `${noun} reaction ${key}`;
      try {
        const snap = await db
          .collection(collection)
          .where(`reactions.${key}`, "array-contains", uid)
          .count()
          .get();
        const count = snap.data().count ?? 0;
        if (count > 0) {
          residual += count;
          logger.warn(`[deletion-cascade] residual ${label} stamps`, {
            uid_prefix: uid.slice(0, 6),
            count,
          });
        }
      } catch (err) {
        residual += 1;
        logger.error(`[deletion-cascade] residual probe failed: ${label}`, {
          uid_prefix: uid.slice(0, 6),
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        });
      }
    }
  }
  // A read rather than `count()`, because only rows under `recipe_comments`
  // are the deleter's to remove. Over the cap reads as residual.
  try {
    const rows = await commentLikeRows(db, uid);
    const count = rows === null ? 1 : rows.length;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual comment likes", {
        uid_prefix: uid.slice(0, 6),
        count,
        overCap: rows === null,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: comment likes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-1917: the erased uid inside OTHER people's block mirrors. Same shape as
  // the poll-vote leg above, and for the same reason — `deleteBlockMirrors` is
  // a cross-user sweep, so nothing under `users/{uid}` can see whether it
  // finished. It uses the collection-group index the sweep itself needs, so a
  // missing index shows up here as a false alarm rather than as a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(Collections.blockMirror)
      .where("blockedByUserIds", "array-contains", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual block mirrors", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: block_mirror", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // Two-field probes: these collections are scoped by a PAIR of uid fields, not
  // by `userId`, so a `userId == uid` probe would silently match zero — the
  // realtime_recipes wrong-field trap.
  //
  // BUT-1450: notification_delivery (senderId / targetUserId).
  //
  // `friend_requests` is NOT here, and neither is `social_requests`, for the
  // same reason `TRIGGER_OWNED_SUBCOLLECTIONS` exists: both are swept by
  // `onUserDeleted`, which `requestAccountDeletion` fires AFTER this probe. A
  // leg here would count rows the trigger erases seconds later and turn every
  // affected erasure into `gdprCompliant: false` and `success: false` — a false
  // failure on an Art. 17 path. What DOES surface an
  // orphaned spelling is the dry run's unknown-collection report (BUT-2043) —
  // it reads the database, not the erasure path.
  const pairProbes: ReadonlyArray<readonly [string, readonly string[]]> = [
    ["notification_delivery", ["senderId", "targetUserId"]],
  ];
  for (const [collection, fields] of pairProbes) {
    for (const field of fields) {
      try {
        const snap = await db
          .collection(collection)
          .where(field, "==", uid)
          .count()
          .get();
        const count = snap.data().count ?? 0;
        if (count > 0) {
          residual += count;
          logger.warn(
            `[deletion-cascade] residual in ${collection}.${field}: ${count} docs`,
          );
        }
      } catch (err) {
        residual += 1;
        logger.error(
          `[deletion-cascade] residual probe failed: ${collection}.${field}`,
          { err },
        );
      }
    }
  }
  // BUT-1766/BUT-1768: more collections whose owner handle is NOT `userId`, so
  // the loop above is structurally blind to them. Each pair is exactly what the
  // matching deleter now clears, keeping the deleter a strict superset of the
  // probe:
  //   messages.senderId          — anonymized (or deleted with a 1:1 thread)
  //   realtime_menus.ownerId       — deleted, subcollections included
  //   realtime_menus.lastEditedBy  — anonymized
  //   realtime_menus.participantIds — membership dropped on docs the
  //                                           user does not own
  //   conversations.participantIds — 1:1 deleted, group departed
  // The conversation ROSTER rows (`conversations/{id}/participants/{uid}`) are on
  // the same inventory but cannot be probed from this loop at all — they need a
  // collection-group query, so their leg is appended at the end of this function.
  // `messages` is the highest-value leg here: the collection this probe could
  // not see is the one the cascade never touched for two years. The
  // `participantIds` legs are the only map-shaped residual Firestore can
  // actually query — a uid used as a MAP KEY (`participants.<uid>`,
  // `perUserSettings.<uid>`, a `votes` map entry) is unqueryable, so those are
  // covered by the deleter and by the emulator lane, never by a count here.
  for (const [col, field, op] of [
    [Collections.messages, "senderId", "=="],
    // BUT-1788: system rows ABOUT the user, authored by "system", so the
    // senderId leg above is structurally blind to them.
    [Collections.messages, "metadata.subjectUserId", "=="],
    [Collections.realtimeMenus, "ownerId", "=="],
    [Collections.realtimeMenus, "lastEditedBy", "=="],
    [Collections.realtimeMenus, "participantIds", "array-contains"],
    [Collections.realtimeResources, "ownerId", "=="],
    [Collections.realtimeResources, "lastEditedBy", "=="],
    [Collections.realtimeResources, "participantIds", "array-contains"],
    [Collections.conversations, "participantIds", "array-contains"],
    // BUT-1838: chat-group membership. A deleter without a probe is exactly how
    // an erasure becomes silently incomplete, so this line ships in the same
    // edit as its deleter.
    [Collections.chatGroups, "memberIds", "array-contains"],
    // BUT-1856: two more owner handles on the same document that the membership
    // leg above is structurally blind to. `departedUserIds` holds people who are
    // no longer in `memberIds` by definition; `sourceCategoryOwnerId` names the
    // owner of the social group a meal-vote chat was built from, and survives
    // them leaving it. Each ships with its deleter, per the rule this list
    // states above.
    [Collections.chatGroups, "departedUserIds", "array-contains"],
    [Collections.chatGroups, "sourceCategoryOwnerId", "=="],
    // BUT-1798: shared_content membership. The scrub above is the only thing
    // that clears this, and it was blind to ad-hoc shares for the collection's
    // entire life — so this probe is what stops that ever being invisible
    // again. Single-field array-contains is served by the automatic index; no
    // composite entry needed.
    ["shared_content", "sharedToUserIds", "array-contains"],
    // BUT-2169: the same person, held off a share by a block. Ships with
    // `scrubBlockHeldShares`.
    ["shared_content", "blockHeldUserIds", "array-contains"],
    // BUT-1801: poll AUTHORSHIP. `deletePollVotes` rewrites this field to
    // "deleted" and REPORTS ON ITSELF — it decides its own `complete` flag. This
    // row is the independent check on that self-report, which is the whole point
    // of a probe: it also sees a document written or re-written after the scrub
    // passed over it, which the scrub by construction cannot. The
    // `metadata.subjectUserId` entry earlier in this same list proves a nested
    // equality filter needs no declared index.
    [Collections.messages, "metadata.poll.creatorId", "=="],
    // BUT-1917: `blocks`, BOTH directions. `deleteBlocks` sweeps through
    // `batchDeleteAll` -> `commitInChunks(strict:false)`, which swallows a
    // failed chunk and lets the step return success — so without these two the
    // sweep self-reports clean over rows whose DOCUMENT ID is the erased uid.
    // These legs are also uncapped, so they still fire when the sweep DECLINED
    // above `MAX_BLOCK_SWEEP_ROWS` and deleted nothing at all.
    [Collections.blocks, "blockerId", "=="],
    [Collections.blocks, "blockedId", "=="],
    // P5-U27b: recipe suggestions name two people and go with either account,
    // so both legs of `deleteRecipeSuggestions` are probed. Uncapped, so they
    // still fire when the sweep DECLINED above its cap and deleted nothing.
    ["recipe_suggestions", "suggesterId", "=="],
    ["recipe_suggestions", "ownerId", "=="],
    // BUT-1971: the group weekly menu scrubs membership, per-dish provenance
    // and the edit trail in ONE `batch.update` under `strict: false`, which
    // returns `true` on a failed chunk. The provenance fields are arrays of
    // maps and cannot be queried. It does not see an entries-only failure, but
    // it does see the chunk failure that would produce one.
    [Collections.groupWeeklyMenuPlans, "participantUserIds", "array-contains"],
    // And the doc-level attribution, which unlike the two arrays IS queryable:
    // a flat equality, served by the automatic single-field index.
    [Collections.groupWeeklyMenuPlans, "lastModifiedBy", "=="],
    // The ACL key. Without it a failed chunk on a document reached only by the
    // permission handle reports clean under `strict: false`, with the raw uid
    // still granting read access.
    //
    // The loop below runs `.where(field, op, uid)`, so this leg reads
    // `memberPermissions.<uid> != <uid>`. That is an EXISTENCE test rather than
    // a comparison: Firestore's `!=` excludes a missing field, and the stored
    // value is always `view`/`edit`/`admin`, never a uid. The deleter's twin is
    // spelled `!= null` because it builds its own query and can say so
    // directly. Do not "align" the two spellings without changing the loop.
    [
      Collections.groupWeeklyMenuPlans,
      new admin.firestore.FieldPath("memberPermissions", uid),
      "!=",
    ],
    // The contributor trail, which the deleter also reads. A DEPARTURE clears
    // the roster and its mirror, so on a plan the user has left this leg is
    // what still reaches the document.
    [Collections.groupWeeklyMenuPlans, "contributorUserIds", "array-contains"],
    // BUT-2032: the moderation rows in the admin ops log. These belong in THIS
    // loop and not in the `probes` list at the top of the function, which
    // filters a TOP-LEVEL `userId` field: `system_events` carries the uid under
    // `details`, so a leg there would match zero on every erasure forever — an
    // all-clear that is true by accident, the realtime_recipes trap this file
    // keeps paying for. One leg per field the deleter sweeps, and they are
    // uncapped so they still fire when a leg DECLINED above
    // `MAX_SYSTEM_EVENT_SWEEP_ROWS` and swept nothing.
    //
    // `details.contentOwnerId` is not redundant with the legs beside it: it is
    // the only thing that measures whether the ANONYMIZE half ran, since a
    // deleted row and an un-anonymized one are indistinguishable to the legs
    // beside it.
    // Both of these are skipped under a hold, and they must move TOGETHER with
    // the deleter's `legs` array — two spellings of one decision about which
    // rows survive a hold, and the day they disagree the erasure lies about
    // itself: `details.userId` carries the REPORTED
    // person's uid on the threshold alert, which a hold keeps, and
    // `details.contentOwnerId` is the leg whose own comment calls it the only
    // thing measuring whether the anonymize half ran — which, under a hold,
    // deliberately did not. Counting either would report residue for a decision
    // that went right, on every held erasure, forever, with no code path able
    // to clear it.
    ...(held ? [] : ([[SYSTEM_EVENTS, "details.userId", "=="]] as const)),
    // NOT skipped: this is the genuinely reporter-side leg, and the hold is
    // one-directional by design.
    [SYSTEM_EVENTS, "details.reporterId", "=="],
    // `deleteUserReports` deletes a closed report and nulls `reporterId` on an
    // open one, so either way this counts zero after a clean run. Never gated
    // on `held`: that is the REPORTED person's hold, a different axis.
    [REPORTS, "reporterId", "=="],
    // BUT-2353: `deleteAppealsByAppellant`, both roles. Never gated on `held`:
    // a hold keeps the evidence of an open case, and an appeal is only ever on
    // a closed one.
    [MODERATION_APPEALS, APPELLANT_ID, "=="],
    ...(held
      ? []
      : ([[SYSTEM_EVENTS, "details.contentOwnerId", "=="]] as const)),
  ] as const) {
    // A `FieldPath` leg carries the uid IN ITS SEGMENTS, and the logger
    // JSON-stringifies whatever it is handed — so logging `field` directly
    // would write the full uid on the very line that truncates it to a prefix,
    // into a log that outlives the account. Label it instead.
    const fieldLabel =
      field instanceof admin.firestore.FieldPath
        ? "memberPermissions.<uid>"
        : field;
    try {
      const snap = await db.collection(col).where(field, op, uid).count().get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual owner-keyed docs", {
          uid_prefix: uid.slice(0, 6),
          collection: col,
          field: fieldLabel,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error("[deletion-cascade] residual probe failed", {
        uid_prefix: uid.slice(0, 6),
        collection: col,
        field: fieldLabel,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  // Subcollections under users/{uid}. These are NOT top-level userId-scoped
  // collections, so a where("userId","==",uid) probe would silently match zero
  // (the realtime_recipes wrong-field trap). Probe each one directly.
  //
  // ENUMERATED, not listed (BUT-1957). This was a hand-written include-list
  // naming one collection, so a subcollection nobody remembered to add was not
  // reported as residual — it was invisible, and an all-clear was returned with
  // the rows still on disk. `users/{uid}/notifications` was the second miss
  // found that way, and a list cannot stop the third. `listCollections()` asks
  // the database what is actually still there, so a subcollection introduced by
  // a future feature shows up here on its first deletion instead of never.
  //
  // The two exclusions are TRIGGER_OWNED_SUBCOLLECTIONS, hoisted to module
  // scope so guards can import it (BUT-2043).
  try {
    const remaining = await db.collection("users").doc(uid).listCollections();
    for (const ref of remaining) {
      if (TRIGGER_OWNED_SUBCOLLECTIONS.has(ref.id)) continue;
      try {
        // `count()`, not `listDocuments()`. The two answer different
        // questions: `listDocuments()` is required where a MISSING parent can
        // still own live children, which is why `unified_shopping_lists` has
        // its own leg using it. That case is covered there, so this leg
        // only needs to know whether anything is left.
        const snap = await ref.count().get();
        const count = snap.data().count ?? 0;
        if (count > 0) {
          residual += count;
          // Collection id and count only — the rows under `notifications`
          // carry the push text actually shown to the user, and this log
          // outlives the account.
          logger.warn("[deletion-cascade] residual user subcollection", {
            uid_prefix: uid.slice(0, 6),
            collection: ref.id,
            count,
          });
        }
      } catch (err) {
        residual += 1;
        logger.error("[deletion-cascade] residual probe failed: subcollection", {
          uid_prefix: uid.slice(0, 6),
          collection: ref.id,
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        });
      }
    }
  } catch (err) {
    // Fails CLOSED: if we cannot even ask what is left, we do not get to say
    // the erasure was complete.
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: listCollections", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }

  // BUT-1956: `analytics/notifications/effectiveness`, a subcollection under a
  // FIXED `analytics/` document — neither the top-level loop nor the
  // `users/{uid}` enumeration above can reach it, so it needs its own leg.
  //
  // This leg is not a mirror of `deleteNotificationEffectiveness`. The writer,
  // `correlateNotificationEffectiveness`, runs daily inside `dailyAnalytics`
  // and writes these rows from pages it is already holding in memory, so a
  // cascade that lands mid-run can have a row written back AFTER the deleter
  // swept. That resurrection is exactly what this leg exists to report.
  try {
    const snap = await db
      .collection("analytics")
      .doc("notifications")
      .collection("effectiveness")
      .where("userId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual notification effectiveness", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: notification effectiveness",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }

  // unified_shopping_lists (BUT-1697): the LIVE personal shopping-list path,
  // erased in deleteShoppingLists. The canary was blind to it while the cascade
  // swept only the legacy `shopping_lists` name.
  //
  // `listDocuments()`, not `count()`. The client deletes a list doc without
  // recursing into its `items` subcollection, so a residual here can be a
  // MISSING parent that still owns live item docs — a state `count()` reports as
  // zero. A probe that cannot see what the deleter must remove is a probe that
  // certifies an incomplete erasure.
  try {
    const listRefs = await db
      .collection("users")
      .doc(uid)
      .collection(Collections.unifiedShoppingLists)
      .listDocuments();
    if (listRefs.length > 0) {
      residual += listRefs.length;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.unifiedShoppingLists}: ${listRefs.length} list refs (incl. missing parents that still own items)`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.unifiedShoppingLists}`,
      { err },
    );
  }

  // unified_shared_shopping_lists (BUT-1697 follow-up). Two distinct residual
  // classes, neither of which a plain `ownerId == uid` count could express:
  //
  //  1. the deleted uid still present as a `memberPermissions` MAP KEY — after
  //     the cascade that key is gone on every matched doc, whether the doc was
  //     scrubbed or deleted, so ANY hit here is a residual.
  //  2. a list still owned by the uid with NO other member left — an orphan no
  //     account can read. A list owned by the uid that OTHER members still
  //     share is the one justified residual (nulling `ownerId` would orphan it
  //     for them), so it must NOT count. That distinction is why this leg reads
  //     the docs instead of using `count()`.
  try {
    const keyed = await db
      .collection(Collections.unifiedSharedShoppingLists)
      .where(`memberPermissions.${uid}`, "!=", null)
      .count()
      .get();
    const keyedCount = keyed.data().count ?? 0;
    if (keyedCount > 0) {
      residual += keyedCount;
      // uid_prefix, never the raw uid: Cloud Logging outlives the account, and
      // a per-user message string would destroy grouping on the one canary you
      // actually query. Same convention as request-account-deletion.ts.
      logger.warn("[deletion-cascade] residual shared-list member keys", {
        uid_prefix: uid.slice(0, 6),
        count: keyedCount,
      });
    }

    const owned = await db
      .collection(Collections.unifiedSharedShoppingLists)
      .where("ownerId", "==", uid)
      .get();
    const orphaned = owned.docs.filter((doc) => {
      const perms = (doc.data().memberPermissions ?? {}) as Record<
        string,
        unknown
      >;
      return !Object.keys(perms).some((k) => k !== uid);
    });
    if (orphaned.length > 0) {
      residual += orphaned.length;
      logger.warn(
        `[deletion-cascade] residual sole-member shared shopping lists: ${orphaned.length} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: unified_shared_shopping_lists",
      { err },
    );
  }

  // BUT-1705/BUT-1725: a removed member has no member key and owns nothing, so
  // the legs above are blind to exactly the case that leaves a name on the items
  // forever. These two count the handles the deleter now uses, and the deleter
  // clears both — keeping it a strict superset of the probe.
  //
  // Each leg carries its OWN try/catch, and they are APPENDED rather than
  // inserted: a leg dropped inside an existing `try` shortens every leg after
  // it, so one transient error on this query would silently skip the
  // sole-member-orphan scan above while the `residual += 1` masked the gap.
  for (const [field, query] of [
    [
      "contributorUserIds",
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("contributorUserIds", "array-contains", uid),
    ],
    [
      "lastActivityByUserId",
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("lastActivityByUserId", "==", uid),
    ],
  ] as const) {
    try {
      const snap = await query.count().get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual shared-list attribution", {
          uid_prefix: uid.slice(0, 6),
          field,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(
        "[deletion-cascade] residual probe failed: shared-list attribution",
        {
          uid_prefix: uid.slice(0, 6),
          field,
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        },
      );
    }
  }

  // BUT-1789: the feature-retention rows. A SUBCOLLECTION under an analytics
  // document, so neither the top-level `userId` loop at the head of this
  // function nor the `users/{uid}/...` loop above can reach it — both are
  // structurally blind to `analytics/feature_retention/users`. Same handle the
  // deleter uses, keeping the deleter a strict superset of the probe. Appended
  // rather than folded into an existing `try`, for the reason the block above
  // states: a leg sharing another leg's catch shortens every leg after it.
  try {
    const snap = await db
      .collection("analytics")
      .doc("feature_retention")
      .collection("users")
      .where("userId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual feature-retention rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: feature_retention",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }

  // BUT-1800: probed on the same handle the deleter uses, and over the SAME
  // list, so the deleter stays a strict superset of the probe. Each
  // parent gets its OWN `try` for the reason the blocks above state — a leg
  // sharing another leg's catch shortens every leg after it, and here that
  // would let a failure on `retention` hide whatever `lapsed_users` holds.
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    try {
      const snap = await db
        .collection("analytics")
        .doc(parent)
        .collection("events")
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual analytics rows", {
          uid_prefix: uid.slice(0, 6),
          parent,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error("[deletion-cascade] residual probe failed: analytics", {
        uid_prefix: uid.slice(0, 6),
        parent,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  // BUT-1822: the conversation roster rows. A SUBCOLLECTION, so neither the
  // top-level loops at the head of this function nor the `users/{uid}/...` loop
  // can express it — only a collection-group query can, and the loops above are
  // all `db.collection(...)`. Same handle `deleteOwnRosterRows` uses, keeping the
  // deleter a strict superset of the probe. Appended rather than folded into an
  // existing `try`, for the reason the blocks above state.
  //
  // Uncapped on purpose, unlike the deleter: `count()` is cheap, and this is the
  // leg that must stay loud when the deleter DECLINES an implausible row count.
  // It also fails CLOSED while the collection-group index is still building —
  // FAILED_PRECONDITION lands in the catch as `residual += 1`, a false alarm
  // rather than a false all-clear. Do not "simplify" that into a silent swallow.
  try {
    const snap = await db
      .collectionGroup(Collections.participants)
      .where("participantId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual conversation roster rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: conversation participants",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }

  if (
    residual > 0 &&
    !result.failedCollections.includes("residual_data_detected")
  ) {
    result.failedCollections.push("residual_data_detected");
  }
}

/**
 * Cap on one erasure's sweep of OTHER people's block mirrors.
 *
 * Same contract as the sibling caps and the same DECLINE-rather-than-truncate
 * choice, for the roster cap's reason rather than the poll-vote one: the row
 * count here is chosen by how many people this user blocked, which is their own
 * doing — but each mirror belongs to somebody else, and a half-finished sweep
 * would leave the erased uid inside a live safety control on an unknown subset
 * of them. Declining reports itself; truncating would not.
 */
export const MAX_MIRROR_SWEEP_ROWS = 2000;

/**
 * BUT-1917: take the erased uid out of everybody else's block mirror.
 *
 * The mirror is a PROJECTION of `blocks`, and `deleteBlocks` has already
 * removed the rows it is derived from. In principle `syncBlockMirror` would
 * rebuild each affected mirror on its own, because an Admin-SDK delete fires
 * the same trigger a client delete does. This step exists because that is not
 * good enough for an erasure: the trigger is asynchronous and may land after
 * the callable has returned and after `probeResidualData` has already decided
 * the account is clean, so an Art. 17 guarantee that depends on it is a
 * guarantee about scheduling. Doing it here makes the erasure synchronous, and
 * the trigger then rebuilds an already-correct document.
 *
 * Probe-covered on both halves. The deleted user's OWN mirror is reached by the
 * enumeration of what is left under `users/{uid}`; this cross-user half has its
 * own uncapped `count()` leg on the same collection-group index this sweep
 * uses, beside the poll-vote leg it is modelled on.
 */
export async function deleteBlockMirrors(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(Collections.blockMirror)
    .where("blockedByUserIds", "array-contains", uid)
    .limit(MAX_MIRROR_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_MIRROR_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible block-mirror count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }

  // Per document with `arrayRemove`, not a recompute: the mirror belongs to
  // another living user, and rebuilding it from `blocks` here would rewrite
  // THEIR document from this cascade's view of the world. Removing one entry
  // is the smallest change that erases the uid, and it leaves every other
  // blocker of that user untouched.
  await batchUpdateRefs(
    snap.docs.map((d) => d.ref),
    () => ({
      blockedByUserIds: admin.firestore.FieldValue.arrayRemove(uid),
      // Stamped so a `syncBlockMirror` rebuild that read `blocks` BEFORE
      // `deleteBlocks` committed cannot land afterwards and put the uid back:
      // its own `sourceRev` guard then sees a newer revision and skips. Without
      // this the sweep is invisible to that guard, because `arrayRemove` alone
      // leaves the revision untouched.
      sourceRev: Date.now(),
    }),
    db,
  );
  return true;
}

/**
 * Cap on one erasure's `blocks` sweep, per direction.
 *
 * The two directions do NOT have the same cap argument, and saying so is the
 * point of writing it down — this file already records one docstring that
 * borrowed a sibling's reasoning and was wrong.
 *
 * `blockerId == uid` is self-chosen: only this user can create a row naming
 * themselves as blocker (`firestore.rules` pins
 * `request.resource.data.blockerId == request.auth.uid` on create), so the
 * count is theirs, and the cap is the self-inflation guard.
 *
 * `blockedId == uid` is chosen by OTHER PEOPLE. Any authenticated account may
 * block this user, and nothing rate-limits it, so this leg has the roster
 * cap's argument rather than the poll-vote one: a peer can seat rows keyed on
 * this user. That is the leg the cap is really for.
 *
 * Above the cap the leg DECLINES rather than truncating, and the step reports
 * itself incomplete — `gdprCompliant: false`. Declining is strictly less
 * erasure for the same alarm, which is the choice `deleteOwnRosterRows` already
 * made.
 *
 * Recovery is a human running `admin/reset-user-data.ts`, which names this
 * collection. That script was inert from 2026-03-19 to 2026-09-05 —
 * `tag_configs` was in both the delete and keep lists, and the overlap guard
 * exited before Phase 1 (BUT-2010, fixed 2026-09-05). Read that file's header
 * before running it: it is a whole-project clean slate rather than a per-user
 * remedy. For one declined sweep the recovery is a human with the Admin SDK.
 */
export const MAX_BLOCK_SWEEP_ROWS = 2000;

/**
 * BUT-1917: the `blocks` collection, BOTH directions.
 *
 * Nothing in this cascade has ever touched it. `blocks/{blockerId}_{blockedId}`
 * is written by the client (`FirebaseBlockRepository.blockUser`) and no server
 * code read the collection before this, so an erased account's uid survived
 * erasure inside every block row it was party to — in the DOCUMENT ID as well
 * as in the fields, which is why a projection would not have been enough.
 *
 * `probeResidualData` did not see it either, and the reason is simply that no
 * leg of that probe named the collection — it queries top-level collections by
 * field as well as enumerating subcollections, so being top-level was never the
 * obstacle. Two legs ship in this same change, because a sweep that reports on
 * itself through `commitInChunks(strict:false)` needs an independent check.
 *
 * BOTH directions are erased, and the second one deserves its own sentence
 * because it deletes a row another living user created. A block naming a
 * deleted account is a decision about an account that no longer exists: it can
 * never be acted on again, and it carries the erased uid. Art. 17 reaches it;
 * the blocker loses nothing they can use.
 *
 * The client method that used to claim this job, `deleteAllBlocksForUser`, is
 * removed in the same change. It had no caller, and it could not have worked:
 * `firestore.rules` lets only the BLOCKER delete a row, so its second query's
 * deletes would have been refused and taken the whole batch with them.
 */
export async function deleteBlocks(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let complete = true;

  for (const field of ["blockerId", "blockedId"] as const) {
    const snap = await db
      .collection(Collections.blocks)
      .where(field, "==", uid)
      .limit(MAX_BLOCK_SWEEP_ROWS + 1)
      .get();

    if (snap.size > MAX_BLOCK_SWEEP_ROWS) {
      logger.error(
        "[deletion-cascade] implausible block count; not sweeping",
        { uid_prefix: uid.slice(0, 6), field, rows: snap.size },
      );
      // `continue`, not `return`: the two directions are independent, and half
      // an erasure beats none as long as the step still reports itself
      // incomplete. Same shape as `deletePollVotes`.
      complete = false;
      continue;
    }

    await batchDeleteAll(db, snap.docs);
  }

  return complete;
}

/** Cap on one erasure's sweep of held shares (BUT-2169). Declines above it. */
export const MAX_BLOCK_HELD_SWEEP_ROWS = 2000;

/**
 * BUT-2169: the held state a block left on `shared_content` that involves the
 * erased uid, both ways round: the uid HELD on someone else's share
 * (`blockHeldUserIds` plus the `blockHeld.<uid>` entry, which keeps their
 * member row and recipe permission), and other people held on a share the
 * erased user made.
 *
 * Runs BEFORE tier 1. Tier 1 deletes the user's `blocks` rows, and each delete
 * fires `holdSharesOnBlock`'s release, which puts held people back on the
 * shares; with nothing held left, that release has nothing to write. It runs
 * again after tier 1 for a hold that committed while the cascade was running.
 */
export async function scrubBlockHeldShares(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  if (uid.includes(".")) {
    // A dotted key would address a different path; Auth never issues one.
    logger.error("[deletion-cascade] uid unusable as a map key; not sweeping held shares");
    return false;
  }
  const readHeld = () =>
    db
      .collection("shared_content")
      .where("blockHeldUserIds", "array-contains", uid)
      .limit(MAX_BLOCK_HELD_SWEEP_ROWS + 1)
      .get();
  const snap = await readHeld();
  if (snap.size > MAX_BLOCK_HELD_SWEEP_ROWS) {
    logger.error("[deletion-cascade] implausible held-share count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
    });
    return false;
  }
  try {
    // First, so a decline on the owned half below cannot leave this user held
    // for tier 1's release to put back.
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(readHeld, MAX_BLOCK_HELD_SWEEP_ROWS, "scrubBlockHeldShares"),
      updateWith({
        blockHeldUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        [`blockHeld.${uid}`]: admin.firestore.FieldValue.delete(),
      }),
      "scrubBlockHeldShares",
    );
  } catch (err) {
    logger.error("[deletion-cascade] scrubBlockHeldShares failed", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  const readOwned = () =>
    db
      .collection("shared_content")
      .where("sharedByUserId", "==", uid)
      .limit(MAX_BLOCK_HELD_SWEEP_ROWS + 1)
      .get();
  const owned = await readOwned();
  if (owned.size > MAX_BLOCK_HELD_SWEEP_ROWS) {
    logger.error("[deletion-cascade] implausible owned-share count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
      rows: owned.size,
    });
    return false;
  }
  const holdsSomeone = (doc: admin.firestore.QueryDocumentSnapshot) => {
    const held = doc.get("blockHeldUserIds");
    return Array.isArray(held) && held.length > 0;
  };
  const ownedHeld = owned.docs.filter(holdsSomeone);
  try {
    // Tier 1 deletes these rows; until then a release would rewrite member
    // rows that name the erased user as the one who added them.
    await scrubWithOneReread(
      db,
      ownedHeld,
      cappedReread(
        readOwned,
        MAX_BLOCK_HELD_SWEEP_ROWS,
        "scrubBlockHeldShares:owned",
        holdsSomeone,
      ),
      updateWith({
        blockHeldUserIds: admin.firestore.FieldValue.delete(),
        blockHeld: admin.firestore.FieldValue.delete(),
      }),
      "scrubBlockHeldShares:owned",
    );
  } catch (err) {
    logger.error("[deletion-cascade] scrubBlockHeldShares owned half failed", {
      uid_prefix: uid.slice(0, 6),
      rows: ownedHeld.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
  logger.info("[deletion-cascade] scrubBlockHeldShares", {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
    owned_rows: ownedHeld.length,
  });
  return true;
}

export async function removeFromSharedContent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-1798 — the members-subcollection scrub below reaches ONLY content shared
  // through BaseSharedContentRepository.addMember() (the group path). The three
  // direct-share managers — recipe_sharing_manager, social_menu_operations and
  // shopping_social_share_module — write the parent document only and have never
  // written a members/{uid} row, so every recipient of an ad-hoc shared recipe,
  // menu or list has been un-erasable since this collection existed. The Art. 15
  // export now returns exactly those rows, so the gap has to close with it.
  //
  // Single `array-contains` on the one membership field. This was a union of
  // two queries deduped by document id, because the collection carried the same
  // list under two spellings; retired 2026-08-03.
  //
  // The admin SDK bypasses rules, so this predicate is the only access control  claim-lint:ok moved unchanged from below the members leg (BUT-1798)
  // on the read — keep it scoped to shared_content and to this exact field.
  //
  // BUT-2214: read together with `members`, before either leg removes the uid
  // from `sharedToUserIds`: `addMember` writes both handles, so a query run
  // after the members leg no longer matches a document shared that way.
  const [members, engagements, membershipSnap] = await Promise.all([
    db.collectionGroup("members").where("userId", "==", uid).get(),
    db.collectionGroup("engagements").where("userId", "==", uid).get(),
    db
      .collection("shared_content")
      .where("sharedToUserIds", "array-contains", uid)
      .get(),
  ]);

  const membershipDocs = new Map<
    string,
    admin.firestore.QueryDocumentSnapshot
  >();
  for (const doc of membershipSnap.docs) {
    // Documents this user OWNS are hard-deleted a few lines below. Updating them
    // first is wasted writes, and a batch.update against an already-deleted doc
    // throws NOT_FOUND and poison-pills the whole chunk on any retry — the same
    // failure shape as BUT-1582/1583. The owner is always in their own
    // membership array, so without this skip the overlap would be total.
    if (doc.get("sharedByUserId") === uid) continue;
    membershipDocs.set(doc.id, doc);
  }

  // BUT-2214: a menu shared with the user can hold a dish of theirs. Scrubbed
  // while the user is still in `sharedToUserIds`.
  await scrubDishCreator(
    db,
    [...membershipDocs.values()],
    uid,
    "shared_content",
  );

  // Scrub membership on each parent shared_content doc. One field: this
  // collection briefly carried the same recipient list under two spellings so
  // rows predating the writer fix stayed readable. Retired 2026-08-03 — the
  // project holds only test data, so there was nothing for the second field to
  // protect and two copies of one fact could only drift.
  if (members.docs.length > 0) {
    await commitInChunks(
      db,
      members.docs,
      (batch, doc) => {
        const parentRef = doc.ref.parent.parent;
        // BUT-1716: scoped by PATH, like the item scrub below. `members` is a
        // collection GROUP read, so it returns rows under every collection that
        // has a `members` subcollection — and an unscoped update writes an empty
        // `sharedToUserIds` onto a stranger's parent, or NOT_FOUND-poisons the
        // chunk when that parent document does not exist. Raised by the
        // `cloud-functions-specialist` and `firebase-backend-security` gates
        // once the new scoping sat three lines below an unscoped copy of itself.
        if (parentRef && isSharedContentParent(parentRef)) {
          batch.update(parentRef, {
            sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      },
      { label: "scrubSharedToUserIds", strict: false },
    );
  }
  // The DELETE stays unscoped where the UPDATE above is scoped, on the same
  // snapshot, and the asymmetry is deliberate: the update writes a stranger's
  // parent document, while a `members` row naming this user should go wherever
  // it sits.
  await batchDeleteAll(db, members.docs);

  if (membershipDocs.size > 0) {
    await commitInChunks(
      db,
      [...membershipDocs.values()],
      (batch, doc) => {
        batch.update(doc.ref, {
          sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        });
      },
      { label: "scrubSharedContentMembership", strict: false },
    );
  }

  logger.info("[deletion-cascade] shared_content membership scrub", {
    scrubbed: membershipDocs.size,
  });
  await batchDeleteAll(db, engagements.docs);

  // Delete shared_content owned by uid (subcollections first). Queried BEFORE
  // the item scrub so the scrub can skip these parents: their rows are deleted
  // a few lines down, and scrubbing a row on its way out is a wasted write.
  const owned = await db
    .collection("shared_content")
    .where("sharedByUserId", "==", uid)
    .get();
  const ownedIds = new Set(owned.docs.map((doc) => doc.id));

  const itemScrub = await scrubSharedContentItemAttribution(db, uid, ownedIds);

  const orphanedParents = new Set<string>();
  for (const doc of owned.docs) {
    // BUT-1716: `items` joins `members` here. Firestore does not delete a
    // subcollection with its parent, so every item the sharer and their
    // recipients wrote — each stamped with a uid and a display name — outlived
    // the share document, unreachable by any client and unerasable by
    // anyone but this cascade.
    //
    // Children first and STRICT, parent only if they went: the same contract
    // `deleteRealtimeDocsWithChildren` states in this file. Ordering alone does
    // not prevent an orphan — a swallowed chunk plus an unconditional parent
    // delete does exactly what the ordering is there to stop.
    const [childMembers, childItems] = await Promise.all([
      doc.ref.collection("members").get(),
      doc.ref.collection("items").get(),
    ]);
    try {
      await commitInChunks(
        db,
        [...childMembers.docs, ...childItems.docs],
        (batch, child) => batch.delete(child.ref),
        { label: "deleteSharedContentChildren", strict: true },
      );
    } catch (err) {
      orphanedParents.add(doc.id);
      logger.error("[deletion-cascade] shared_content children not deleted", {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  await batchDeleteAll(
    db,
    owned.docs.filter((doc) => !orphanedParents.has(doc.id)),
  );

  // The step is INCOMPLETE if either half left the uid behind. `runStep` turns
  // false into `failedCollections` and `gdprCompliant: false` — the only thing
  // that can contradict a clean audit row, since no probe leg reaches these
  // item rows.
  return itemScrub.ok && orphanedParents.size === 0;
}

/** The four fields on an item row that name a person by uid. */
export const ITEM_UID_FIELDS = [
  "addedByUserId",
  "lastModifiedByUserId",
  "assignedToUserId",
  "purchasedByUserId",
] as const;

/**
 * A shared-list row cap in the shape every sibling sweep in this file uses:
 * DECLINE rather than truncate, because a truncated erasure reports success
 * over rows it never touched.
 */
const MAX_SHARED_ITEM_ROWS = 2000;

/** True for `shared_content/{id}`, and for nothing nested deeper. */
export function isSharedContentParent(ref: admin.firestore.DocumentReference): boolean {
  return ref.parent.id === "shared_content" && ref.parent.parent === null;
}

/**
 * BUT-1716: erase one user's identity from the items of shared lists OTHER
 * people keep.
 *
 * Discovery is a collection-group query PER UID FIELD, not a walk of the
 * parents this user is currently a member of. Membership is the wrong handle,
 * and for the reason the array-shaped twin already carries `contributorUserIds`:
 * `BaseSharedContentRepository.removeMember` deletes the `members/{uid}` row and
 * `arrayRemove`s the uid from `sharedToUserIds` in one call, so somebody who
 * LEFT a shared list is invisible to both handles while their uid and display
 * name stay on every row they wrote. That is the residual this leg exists to
 * close, so it must not be discovered through the thing that forgets them. The
 * four `COLLECTION_GROUP` field overrides are declared in
 * `firestore.indexes.json`.
 *
 * `users/{uid}/unified_shopping_lists/{id}/items` shares the collection-group id
 * and is erased by `deleteShoppingLists`, so rows are scoped by PATH to a
 * top-level `shared_content` parent — the two paths must not fight over the same
 * rows.
 *
 * No code in `lib/` writes this path, and `firestore.rules` carries no block for
 * it. This leg is kept anyway: rows can
 * exist on disk in a project this repo is not looking at, and a cascade that
 * stops looking is how a residual becomes permanent.
 *
 * The four pairs mirror the array-path scrub in `deleteShoppingLists` field for
 * field — the two shapes must not drift: `assignedTo*` and `purchasedBy*` are
 * cleared to null with their timestamp (a claim and a tick are facts about a
 * person, and the item is still the list's), while `addedBy*` and
 * `lastModifiedBy*` are ANONYMIZED to the sentinel `"deleted"` because the
 * client model reads `isCollaborative => addedByUserId != null` and nulling it
 * would flip a shared row back to a personal one for every remaining member.
 * Display names go in every case.
 */
async function scrubSharedContentItemAttribution(
  db: admin.firestore.Firestore,
  uid: string,
  ownedParentIds: Set<string>,
): Promise<{ ok: boolean }> {
  const rows = await sharedItemRowsNaming(db, uid, ownedParentIds);
  if (rows === null) return { ok: false };
  if (rows.length === 0) return { ok: true };

  try {
    await scrubWithOneReread(
      db,
      rows,
      async () => {
        const again = await sharedItemRowsNaming(db, uid, ownedParentIds);
        if (again === null) {
          throw new Error("scrubSharedContentItems: re-read over the cap");
        }
        return again;
      },
      (batch, doc) => {
        const data = doc.data();
        const update: Record<string, unknown> = {};
        if (data.assignedToUserId === uid) {
          update.assignedToUserId = null;
          update.assignedToDisplayName = null;
          update.assignedAt = null;
        }
        if (data.purchasedByUserId === uid) {
          update.purchasedByUserId = null;
          update.purchasedByDisplayName = null;
          update.purchasedAt = null;
        }
        if (data.addedByUserId === uid) {
          update.addedByUserId = "deleted";
          update.addedByDisplayName = null;
        }
        if (data.lastModifiedByUserId === uid) {
          update.lastModifiedByUserId = "deleted";
          update.lastModifiedByDisplayName = null;
        }
        batch.update(doc.ref, update);
      },
      "scrubSharedContentItems",
    );
  } catch (err) {
    logger.error("[deletion-cascade] shared_content item scrub failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return { ok: false };
  }

  logger.info("[deletion-cascade] shared_content item attribution scrub", {
    uid_prefix: uid.slice(0, 6),
    items: rows.length,
  });
  return { ok: true };
}

/**
 * The `shared_content` item rows naming `uid` in any attribution field, outside
 * the shares this user owns (the caller deletes those with their share). Null,
 * logged, when a field is over its cap.
 */
async function sharedItemRowsNaming(
  db: admin.firestore.Firestore,
  uid: string,
  ownedParentIds: Set<string>,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const rows = new Map<string, admin.firestore.QueryDocumentSnapshot>();
  for (const field of ITEM_UID_FIELDS) {
    const snap = await db
      .collectionGroup("items")
      .where(field, "==", uid)
      .limit(MAX_SHARED_ITEM_ROWS + 1)
      .get();
    if (snap.size > MAX_SHARED_ITEM_ROWS) {
      logger.error("[deletion-cascade] implausible shared item count", {
        uid_prefix: uid.slice(0, 6),
        field,
        rows: snap.size,
      });
      return null;
    }
    for (const doc of snap.docs) {
      const parentRef = doc.ref.parent.parent;
      if (!parentRef || !isSharedContentParent(parentRef)) continue;
      if (ownedParentIds.has(parentRef.id)) continue;
      rows.set(doc.ref.path, doc);
    }
  }
  return [...rows.values()];
}

export async function deleteCommentsAndRatings(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // recipe_comments: anonymize to preserve thread structure.
  const recipeComments = await db
    .collection("recipe_comments")
    .where("authorId", "==", uid)
    .get();
  if (recipeComments.docs.length > 0) {
    await commitInChunks(
      db,
      recipeComments.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          authorId: "deleted",
          authorDisplayName: "[Raderad användare]",
          authorAvatarUrl: null,
          isDeleted: true,
          text: "[Borttagen kommentar]",
        });
      },
      { label: "anonymizeRecipeComments", strict: false },
    );
  }

  // Hard-delete ratings + collectionGroup comments/ratings.
  const [recipeRatings, cgComments, cgRatings] = await Promise.all([
    db.collection("recipe_ratings").where("userId", "==", uid).get(),
    db.collectionGroup("comments").where("commentedBy", "==", uid).get(),
    db.collectionGroup("ratings").where("ratedBy", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [
    ...recipeRatings.docs,
    ...cgComments.docs,
    ...cgRatings.docs,
  ]);
  return true;
}

/**
 * Cap on one erasure's sweep of OTHER people's ratings that name this user as
 * the recipe owner. Declines rather than truncates, like the sibling caps: any
 * rater can write any uid into `recipeOwnerId` (BUT-2057), so the row count is
 * not this user's own doing.
 */
export const MAX_RATING_OWNER_SWEEP_ROWS = 2000;

/**
 * BUT-2072: take the erased uid out of `recipeOwnerId` on ratings OTHER people
 * wrote on this user's recipes. The field is removed, never nulled — the rules'
 * block gate reads its PRESENCE — and the rating itself stays, because it
 * belongs to the rater.
 *
 * Runs after tier 1, not inside it: `deleteCommentsAndRatings` hard-deletes the
 * ratings this user wrote on their OWN recipes, which match this query too, and
 * a `batch.update` on a row deleted underneath it rejects the whole chunk.
 */
export async function scrubRatingRecipeOwner(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const read = () =>
    db
      .collection("recipe_ratings")
      .where("recipeOwnerId", "==", uid)
      .limit(MAX_RATING_OWNER_SWEEP_ROWS + 1)
      .get();
  const snap = await read();

  if (snap.size > MAX_RATING_OWNER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible rating owner count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  if (snap.empty) return true;

  try {
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(read, MAX_RATING_OWNER_SWEEP_ROWS, "scrubRatingRecipeOwner"),
      updateWith({ recipeOwnerId: admin.firestore.FieldValue.delete() }),
      "scrubRatingRecipeOwner",
    );
  } catch (err) {
    logger.error("[deletion-cascade] rating owner scrub failed", {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info("[deletion-cascade] rating owner scrub", {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
  });
  return true;
}

/**
 * Caps on one erasure's sweeps of `recipe_comments` (BUT-2112). Decline rather
 * than truncate, like the sibling caps. `recipeOwnerId` and `sharedWithUserIds`
 * are written by the commenting client, so their row counts are not this
 * user's own doing.
 */
export const MAX_COMMENT_OWNER_SWEEP_ROWS = 2000;

export const MAX_COMMENT_SHARE_SWEEP_ROWS = 2000;

export const MAX_COMMENT_LIKE_SWEEP_ROWS = 2000;

/**
 * One capped scrub over rows of `collection` that carry the erased uid in a
 * field someone else's client wrote. The row stays; only the uid goes.
 */
async function scrubCommentField(
  db: admin.firestore.Firestore,
  uid: string,
  collection: "recipe_comments" | "messages",
  query: { field: string; op: "==" | "array-contains"; cap: number },
  update: Record<string, unknown>,
  label: string,
): Promise<boolean> {
  const read = () =>
    db
      .collection(collection)
      .where(query.field, query.op, uid)
      .limit(query.cap + 1)
      .get();
  const snap = await read();

  if (snap.size > query.cap) {
    logger.error(`[deletion-cascade] implausible ${label} count; not sweeping`, {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
    });
    return false;
  }
  if (snap.empty) return true;

  try {
    await scrubWithOneReread(
      db,
      snap.docs,
      cappedReread(read, query.cap, label),
      updateWith(update),
      label,
    );
  } catch (err) {
    logger.error(`[deletion-cascade] ${label} failed`, {
      uid_prefix: uid.slice(0, 6),
      rows: snap.size,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info(`[deletion-cascade] ${label}`, {
    uid_prefix: uid.slice(0, 6),
    rows: snap.size,
  });
  return true;
}

/**
 * BUT-2112: remove the erased uid from `recipeOwnerId` on comments on their
 * recipes. Removed, never nulled: the read rule and the block gate both test
 * the field's PRESENCE.
 */
export async function scrubCommentRecipeOwner(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  return scrubCommentField(
    db,
    uid,
    "recipe_comments",
    { field: "recipeOwnerId", op: "==", cap: MAX_COMMENT_OWNER_SWEEP_ROWS },
    { recipeOwnerId: admin.firestore.FieldValue.delete() },
    "scrubCommentRecipeOwner",
  );
}

/**
 * BUT-2112: remove the erased uid from `sharedWithUserIds`. `arrayRemove`
 * takes out that one element, so every other recipient keeps read access.
 */
export async function scrubCommentSharedWith(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  return scrubCommentField(
    db,
    uid,
    "recipe_comments",
    {
      field: "sharedWithUserIds",
      op: "array-contains",
      cap: MAX_COMMENT_SHARE_SWEEP_ROWS,
    },
    { sharedWithUserIds: admin.firestore.FieldValue.arrayRemove(uid) },
    "scrubCommentSharedWith",
  );
}

/** True for `recipe_comments/{id}`, and for nothing nested deeper. */
function isRecipeCommentParent(ref: admin.firestore.DocumentReference): boolean {
  return ref.parent.id === "recipe_comments" && ref.parent.parent === null;
}

/**
 * The erased user's like rows under comments, found by collection group and
 * kept only when they sit under a top-level `recipe_comments` document.
 * `null` when the read exceeds the cap.
 */
async function commentLikeRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const snap = await db
    .collectionGroup("likes")
    .where("userId", "==", uid)
    .limit(MAX_COMMENT_LIKE_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_COMMENT_LIKE_SWEEP_ROWS) return null;
  return snap.docs.filter((doc) => {
    const parent = doc.ref.parent.parent;
    return parent !== null && isRecipeCommentParent(parent);
  });
}

/**
 * BUT-2112: delete the erased user's comment likes, then take each one off
 * its comment's `likesCount`.
 *
 * Two passes, deletes first. A like can outlive its comment — the author, an
 * admin or the duplicate guard can delete the comment and nothing deletes
 * its subcollection — and an update on that missing parent would reject
 * every other write in its chunk. Deleting a missing document never throws.
 * Deletes first also means a re-run finds no rows.
 *
 * A failed decrement pass is logged, not reported: the personal data is gone
 * after the first pass, and what is left is a display counter one too high.
 */
export async function deleteCommentLikes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const rows = await commentLikeRows(db, uid);
  if (rows === null) {
    logger.error("[deletion-cascade] implausible comment like count; not sweeping", {
      uid_prefix: uid.slice(0, 6),
    });
    return false;
  }
  if (rows.length === 0) return true;

  try {
    await commitInChunks(
      db,
      rows,
      (batch, doc) => {
        batch.delete(doc.ref);
      },
      { label: "deleteCommentLikes", strict: true },
    );
  } catch (err) {
    logger.error("[deletion-cascade] comment like delete failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  let decremented = 0;
  try {
    const parents: admin.firestore.DocumentReference[] = [];
    const GROUP = 100;
    for (let i = 0; i < rows.length; i += GROUP) {
      const group = rows.slice(i, i + GROUP);
      const snaps = await Promise.all(
        group.map((doc) => (doc.ref.parent.parent as admin.firestore.DocumentReference).get()),
      );
      snaps.forEach((snap, j) => {
        const count = snap.data()?.likesCount;
        if (snap.exists && typeof count === "number" && count > 0) {
          parents.push(group[j].ref.parent.parent as admin.firestore.DocumentReference);
        }
      });
    }
    decremented = parents.length;
    await commitInChunks(
      db,
      parents,
      (batch, ref) => {
        batch.update(ref, {
          likesCount: admin.firestore.FieldValue.increment(-1),
        });
      },
      { label: "decrementCommentLikes", strict: true },
    );
  } catch (err) {
    logger.warn("[deletion-cascade] comment likesCount decrement failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }

  logger.info("[deletion-cascade] comment likes deleted", {
    uid_prefix: uid.slice(0, 6),
    rows: rows.length,
    decremented,
  });
  return true;
}

/**
 * Cap on one erasure's sweep of OTHER people's recipes that list this user in
 * `socialData.memberPermissions`. Declines rather than truncates, like the
 * sibling caps: the recipe create and update rules let an owner write any
 * uid into that map on their own recipes, so the row count is not this
 * user's own doing.
 */
export const MAX_RECIPE_MEMBER_SWEEP_ROWS = 2000;

/** True for a document in the erased user's own `users/{uid}/recipes`. */
function isOwnRecipe(
  ref: admin.firestore.DocumentReference,
  uid: string,
): boolean {
  const owner = ref.parent.parent;
  return (
    owner !== null &&
    owner.id === uid &&
    owner.parent.id === "users" &&
    owner.parent.parent === null
  );
}

/**
 * BUT-2272: take the erased uid out of other people's shared recipes — the
 * `socialData.memberPermissions` key that found the recipe, and the
 * `socialData.grants` key beside it. The recipe stays; it belongs to its owner.
 *
 * Both keys are addressed with `FieldPath`, never a dotted string built from
 * the uid. The user's own recipes are skipped: `deleteRecipes` removes them in
 * tier 1, and an update on a document deleted underneath it rejects the whole
 * chunk.
 */
export async function scrubRecipeMemberPermissions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const read = () =>
    db
      .collectionGroup("recipes")
      .where(
        new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
        "!=",
        null,
      )
      .limit(MAX_RECIPE_MEMBER_SWEEP_ROWS + 1)
      .get();
  const snap = await read();

  if (snap.size > MAX_RECIPE_MEMBER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible recipe member count; not sweeping",
      { uidHash: hashUid(uid), rows: snap.size },
    );
    return false;
  }
  const othersRecipe = (doc: admin.firestore.QueryDocumentSnapshot) =>
    !isOwnRecipe(doc.ref, uid);
  const rows = snap.docs.filter(othersRecipe);
  if (rows.length === 0) return true;

  try {
    await scrubWithOneReread(
      db,
      rows,
      cappedReread(
        read,
        MAX_RECIPE_MEMBER_SWEEP_ROWS,
        "scrubRecipeMemberPermissions",
        othersRecipe,
      ),
      (batch, doc) => {
        batch.update(
          doc.ref,
          new admin.firestore.FieldPath("socialData", "memberPermissions", uid),
          admin.firestore.FieldValue.delete(),
          new admin.firestore.FieldPath("socialData", "grants", uid),
          admin.firestore.FieldValue.delete(),
        );
      },
      "scrubRecipeMemberPermissions",
    );
  } catch (err) {
    logger.error("[deletion-cascade] recipe member scrub failed", {
      uidHash: hashUid(uid),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }

  logger.info("[deletion-cascade] recipe member scrub", {
    uidHash: hashUid(uid),
    rows: rows.length,
  });
  return true;
}

/**
 * BUT-2115: the reaction keys `recipe_comments.reactions` and
 * `messages.reactions` may hold. One list
 * with `reactionKeys()` in firestore.rules and `kReactionEmojis` in
 * emoji_reaction_picker.dart; a functions test parses all three.
 */
export const COMMENT_REACTION_KEYS = [
  "thumbs_up",
  "heart",
  "fire",
  "laughing",
  "yum",
  "thinking",
] as const;

/** Per-key cap for `scrubCommentReactions`, declining like the BUT-2112 caps. */
export const MAX_COMMENT_REACTION_SWEEP_ROWS = 2000;

/**
 * BUT-2115: take the erased uid out of every reaction list on other people's
 * comments. `arrayRemove` leaves the other reactors in place. A key that
 * declines or fails does not stop the others, and fails the step.
 */
export async function scrubCommentReactions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let ok = true;
  for (const key of COMMENT_REACTION_KEYS) {
    const swept = await scrubCommentField(
      db,
      uid,
      "recipe_comments",
      {
        field: `reactions.${key}`,
        op: "array-contains",
        cap: MAX_COMMENT_REACTION_SWEEP_ROWS,
      },
      { [`reactions.${key}`]: admin.firestore.FieldValue.arrayRemove(uid) },
      `scrubCommentReactions:${key}`,
    );
    if (!swept) ok = false;
  }
  return ok;
}

/** Per-key cap for `scrubMessageReactions`, declining like the comment cap. */
export const MAX_MESSAGE_REACTION_SWEEP_ROWS = 2000;

/**
 * BUT-2398: take the erased uid out of every reaction list on chat messages.
 * The rules admit the same keys as on comments. `arrayRemove` leaves the other
 * reactors in place. A key that declines or fails does not stop the others,
 * and fails the step.
 */
export async function scrubMessageReactions(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let ok = true;
  for (const key of COMMENT_REACTION_KEYS) {
    const swept = await scrubCommentField(
      db,
      uid,
      "messages",
      {
        field: `reactions.${key}`,
        op: "array-contains",
        cap: MAX_MESSAGE_REACTION_SWEEP_ROWS,
      },
      { [`reactions.${key}`]: admin.firestore.FieldValue.arrayRemove(uid) },
      `scrubMessageReactions:${key}`,
    );
    if (!swept) ok = false;
  }
  return ok;
}

export async function deletePingsByUser(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup("pings")
    .where("fromUserId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export interface ReporterErasureOutcome {
  ok: boolean;
  /** Reports kept because their case was still open. */
  keptOpen: number;
  /** When a kept report is deleted at the latest, whatever its case does. */
  retainUntil: admin.firestore.Timestamp;
}

function reporterRetainUntilFrom(now: Date): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + REPORTER_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  );
}

/**
 * The erased user as the person who FILED a report.
 *
 * A closed case's report is deleted. An open one is KEPT with the reporter's
 * uid removed, so the case can still be decided — Malin's call, 2026-09-18.
 * Its free text (`description`) stays: it is often all a moderator has beyond
 * the `reason` category. `reporter-retention.ts` deletes the row once the case
 * closes or `reporterRetainUntil` passes.
 *
 * ONE equality, and the status is read off the row rather than filtered in the
 * query: the orchestration suite's fixture keys on "two chained `where`s on
 * `reports`" to recognise `hasOpenModerationCase`, and a second chained filter
 * here would be answered by it.
 *
 * STRICT: a failed chunk throws, so the step is reported failed rather than
 * leaving the uid behind under a success.
 */
export async function deleteUserReports(
  db: admin.firestore.Firestore,
  uid: string,
  now: Date = new Date(),
): Promise<ReporterErasureOutcome> {
  const retainUntil = reporterRetainUntilFrom(now);
  const snap = await db
    .collection(REPORTS)
    .where("reporterId", "==", uid)
    .get();
  if (snap.empty) return { ok: true, keptOpen: 0, retainUntil };

  let keptOpen = 0;
  await commitInChunks(
    db,
    snap.docs,
    (batch, doc) => {
      if (isClosedReportStatus(doc.get("status"))) {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: REPORTS,
          resourceId: doc.id,
        });
        return;
      }
      keptOpen += 1;
      batch.update(doc.ref, {
        reporterId: null,
        reporterErasedAt: admin.firestore.FieldValue.serverTimestamp(),
        reporterRetainUntil: retainUntil,
      });
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: uid,
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: REPORTS,
        resourceId: doc.id,
        extra: { field: "reporterId" },
      });
    },
    {
      label: `reporter reports for ${uid.slice(0, 6)}`,
      opsPerItem: 2,
      strict: true,
    },
  );
  return { ok: true, keptOpen, retainUntil };
}

/**
 * Whether each linked report's case is still open, keyed by report id.
 *
 * Read one document at a time in bounded groups rather than with `getAll`: the
 * sweeps it serves are capped at 2000 rows, and neither cascade test fake
 * implements a top-level `getAll`.
 *
 * A report that does not exist reads as NOT open — its case can no longer be
 * decided. Throws when a read fails; callers treat that as "open".
 */
async function openReportIds(
  db: admin.firestore.Firestore,
  reportIds: string[],
): Promise<Set<string>> {
  const open = new Set<string>();
  const unique = [...new Set(reportIds)];
  const GROUP = 100;
  for (let i = 0; i < unique.length; i += GROUP) {
    const group = unique.slice(i, i + GROUP);
    const snaps = await Promise.all(
      group.map((id) => db.collection(REPORTS).doc(id).get()),
    );
    snaps.forEach((snap, i) => {
      if (snap.exists && !isClosedReportStatus(snap.data()?.status)) {
        open.add(group[i]);
      }
    });
  }
  return open;
}

/**
 * The admin ops log. Named through a local const because `Collections` does not
 * carry it; the coverage guard resolves file-local consts, so this stays
 * discoverable to it (BUT-2043).
 */
const SYSTEM_EVENTS = "system_events";

/**
 * The moderation strike record, keyed on the REPORTED user's uid (BUT-2046).
 *
 * Exported because `held` is keyed on it in TWO files, and the comments on both
 * say they must agree — a second string literal is how they stop agreeing.
 */
export const USER_MODERATION = "user_moderation";

/** One row per report, beneath a `user_moderation` document (BUT-2046). */
const REPORT_HISTORY = "report_history";

/**
 * Cap on one erasure's `system_events` sweep. Same contract as
 * `MAX_BLOCK_SWEEP_ROWS` — decline above it rather than truncate, because a
 * truncated sweep reports a clean erasure over rows it never looked at.
 *
 * The count is chosen by OTHER PEOPLE on the owner-keyed legs: anyone may file
 * a report naming this user as `contentOwnerId`, and `firestore.rules` has no
 * write limb on this collection at all — every row here is an Admin-SDK write
 * from `onReportCreated`, so nothing a client can be rate-limited on bounds it
 * directly. That is the roster cap's argument, not the poll-vote cap's, and the
 * two differ (BUT-1801).
 */
const MAX_SYSTEM_EVENT_SWEEP_ROWS = 2000;

/**
 * The report a `content_report_<reportId>` row is about. The trigger writes the
 * id both into `details.reportId` and into the document id.
 */
function reportIdOfEvent(doc: admin.firestore.QueryDocumentSnapshot): string {
  return (
    (doc.get("details.reportId") as string | undefined) ??
    doc.id.replace(/^content_report_/, "")
  );
}

/**
 * BUT-2032: the moderation rows in the admin ops log, which no erasure path
 * reached. `feedback/on-report-created.ts` writes TWO shapes about a report, and
 * a step written from the document id alone covers only one of them:
 *
 *   `moderation_threshold_<contentOwnerId>` — the uid is the document's own
 *       identity, and `details.userId` repeats it. Deleted: a document whose id
 *       IS the identifier cannot be anonymized.
 *   `content_report_<reportId>` — no uid in the id, and BOTH parties in the
 *       fields (`details.reporterId`, `details.contentOwnerId`).
 *
 * The policy is derived from the two already-decided outcomes on the SOURCE
 * collection rather than invented here, because a third policy for one event is
 * how two records of one decision drift apart:
 *
 *   reporter erases  -> the row follows its `reports` document: DELETED when
 *       that case is closed (ADR-0016, 2026-09-08), KEPT with
 *       `details.reporterId` nulled while it is open (Malin, 2026-09-18).
 *   reported erases  -> ANONYMIZE, exactly as `anonymizeReportsByContentOwnerWithDb`
 *       does on the source row (BUT-781): the row stays, the identifier goes.
 *
 * Each mutation stages its own `audit_logs` row (ADR-0014). The step runs in the
 * CASCADE and not in `onUserDeleted` because `probeResidualData` runs before
 * `auth.deleteUser` and the trigger runs after it — a trigger-owned step with a
 * probe leg turns every affected erasure into a false `gdprCompliant: false`,
 * which is the defect BUT-2044 records.
 *
 * NOT closed by this step, and named rather than left to be discovered:
 * `onReportCreated` is an `onDocumentCreated` trigger on `reports/{reportId}`
 * with NO ordering relationship to account deletion in either direction — it
 * re-throws for retry — so a report created, or a delivery retried, around the
 * erasure writes a fresh row naming the erased uid afterwards. Malin accepted
 * that as a named residual on 2026-09-08 rather than build the reconciliation
 * pass the block mirror has for the same race.
 */
export async function deleteModerationSystemEvents(
  db: admin.firestore.Firestore,
  uid: string,
  /**
   * BUT-2046 follow-up. Under a legal hold every row ABOUT this person is kept:
   * the `details.contentOwnerId` anonymize does not run, and the
   * `details.userId` threshold alert is not deleted — that field carries the
   * REPORTED person's uid (`feedback/on-report-created.ts` writes
   * `userId: contentOwnerId`), so deleting it would keep the report and destroy
   * the alert derived from it, which is a half-held case.
   *
   * Only `details.reporterId` is genuinely the other party, and that leg runs
   * unchanged: the hold is one-directional by design.
   *
   * `sweepErasureHolds` calls this again with the default once the hold lifts.
   */
  held = false,
): Promise<boolean> {
  let complete = true;

  /** Runs one capped leg. Returns null when the leg declined. */
  const sweep = async (
    field: string,
  ): Promise<admin.firestore.QueryDocumentSnapshot[] | null> => {
    const snap = await db
      .collection(SYSTEM_EVENTS)
      .where(field, "==", uid)
      .limit(MAX_SYSTEM_EVENT_SWEEP_ROWS + 1)
      .get();
    if (snap.size > MAX_SYSTEM_EVENT_SWEEP_ROWS) {
      logger.error(
        "[deletion-cascade] implausible system_events count; not sweeping",
        { uid_prefix: uid.slice(0, 6), field, rows: snap.size },
      );
      return null;
    }
    return snap.docs;
  };

  // The rows this erasure DELETES, sharing one commit. Which legs those are
  // depends on `held` — see the array below. `details.userId` is queried rather than the document id
  // rebuilt, so a threshold row whose id ever differs from the convention is
  // still reached, and no audit row is staged for a document that never existed.
  const deletions: admin.firestore.QueryDocumentSnapshot[] = [];
  const deletedIds = new Set<string>();
  // Reporter rows whose case is still open: kept, with the reporter removed.
  const reporterAnonymizations: admin.firestore.QueryDocumentSnapshot[] = [];
  const legs = held
    ? (["details.reporterId"] as const)
    : (["details.userId", "details.reporterId"] as const);
  for (const field of legs) {
    const docs = await sweep(field);
    if (docs === null) {
      // `continue`, not `return`: the legs are independent and half an erasure
      // beats none, as long as the step still reports itself incomplete.
      complete = false;
      continue;
    }
    let open = new Set<string>();
    if (field === "details.reporterId") {
      // The row follows its `reports` document: an open case keeps it, with
      // the reporter's uid nulled, exactly as `deleteUserReports` keeps the
      // report. A failed read keeps every row — keeping is recoverable,
      // deleting an open case's record is not — and the step says so.
      try {
        open = await openReportIds(
          db,
          docs.map(reportIdOfEvent),
        );
      } catch (err) {
        logger.error(
          "[deletion-cascade] report status unreadable; keeping reporter rows",
          {
            uid_prefix: uid.slice(0, 6),
            errCode: (err as { code?: number | string }).code ?? null,
            errName: err instanceof Error ? err.name : typeof err,
          },
        );
        complete = false;
        open = new Set(
          docs.map(reportIdOfEvent),
        );
      }
    }
    for (const doc of docs) {
      if (deletedIds.has(doc.id)) continue;
      if (field === "details.reporterId" && open.has(reportIdOfEvent(doc))) {
        reporterAnonymizations.push(doc);
        continue;
      }
      deletedIds.add(doc.id);
      deletions.push(doc);
    }
  }
  if (reporterAnonymizations.length > 0) {
    await commitInChunks(
      db,
      reporterAnonymizations,
      (batch, doc) => {
        batch.update(doc.ref, {
          "details.reporterId": null,
          reporterErasedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_anonymize",
          resourceType: SYSTEM_EVENTS,
          resourceId: doc.id,
          extra: { field: "details.reporterId" },
        });
      },
      {
        label: `system_events reporter anonymize for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
        strict: true,
      },
    );
  }
  if (deletions.length > 0) {
    await commitInChunks(
      db,
      deletions,
      (batch, doc) => {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: SYSTEM_EVENTS,
          resourceId: doc.id,
        });
      },
      {
        label: `BUT-2032: system_events delete for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
      },
    );
  }

  // The reported-side rows survive with the identifier removed. Read AFTER the
  // deletes above.
  //
  // Under a hold the identifier STAYS — that is the whole exception, and the
  // reports rows one collection over are held by the same decision. Returning
  // here rather than filtering below is deliberate: the sweep itself would be a
  // read whose only product is rows nothing may touch.
  if (held) return complete;

  const owned = await sweep("details.contentOwnerId");
  if (owned === null) {
    complete = false;
  } else {
    const toAnonymize = owned.filter((doc) => !deletedIds.has(doc.id));
    if (toAnonymize.length > 0) {
      await commitInChunks(
        db,
        toAnonymize,
        (batch, doc) => {
          batch.update(doc.ref, {
            "details.contentOwnerId": null,
            contentOwnerAnonymizedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          });
          stageCascadeAuditEntry(db, batch, {
            subjectUserId: uid,
            targetUid: null,
            operation: "cascade_anonymize",
            resourceType: SYSTEM_EVENTS,
            resourceId: doc.id,
            extra: { field: "details.contentOwnerId" },
          });
        },
        {
          label: `BUT-2032: system_events anonymize for ${uid.slice(0, 6)}`,
          opsPerItem: 2,
        },
      );
    }
  }

  return complete;
}

/**
 * Cap on one erasure's `report_history` sweeps. Same contract as
 * `MAX_SYSTEM_EVENT_SWEEP_ROWS`: decline above it rather than truncate.
 *
 * BOTH legs need it, and for the roster cap's reason rather than the poll
 * cap's: the row count is chosen by OTHER PEOPLE. Anyone may report this user
 * (the owner leg) and there is no client-side throttle on report creation, and
 * anyone may be reported by them (the reporter leg).
 */
const MAX_REPORT_HISTORY_SWEEP_ROWS = 2000;

/**
 * BUT-2046: the moderation strike record about the erased user, and the report
 * rows beneath it.
 *
 * `user_moderation/{contentOwnerId}` is keyed on the REPORTED person's uid and
 * holds their strike counter; `report_history/{reportId}` beneath it is one row
 * per report, each naming a reporter. Firestore never cascade-deletes a
 * subcollection, so the parent alone leaves every row standing.
 *
 * CHILDREN FIRST, parent last. The repo's rule about orphaning is a one-way
 * door does NOT bite here, and the reason is worth stating so a later reader
 * does not reason from the conversation-roster case by analogy: those rows are
 * discovered through a query on the PARENT, so losing the parent loses the
 * rows forever. These sit at a path derived from the uid alone, so a retry — and
 * `probeResidualData`'s own leg — reaches them whether or not the parent
 * survived. The order is kept anyway because it costs nothing and it is what
 * every sibling in this file does.
 */
export async function deleteModerationRecord(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const parent = db.collection(USER_MODERATION).doc(uid);
  const history = await parent
    .collection(REPORT_HISTORY)
    .limit(MAX_REPORT_HISTORY_SWEEP_ROWS + 1)
    .get();

  if (history.size > MAX_REPORT_HISTORY_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible report_history count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: history.size },
    );
    // The parent is left standing too: deleting it while its rows remain would
    // hide them from a reader without erasing them, and the probe leg below
    // counts them either way.
    return false;
  }

  if (!history.empty) {
    await commitInChunks(
      db,
      history.docs,
      (batch, doc) => {
        batch.delete(doc.ref);
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_delete",
          resourceType: REPORT_HISTORY,
          resourceId: doc.id,
        });
      },
      {
        label: `BUT-2046: report_history delete for ${uid.slice(0, 6)}`,
        opsPerItem: 2,
      },
    );
  }

  const batch = db.batch();
  batch.delete(parent);
  stageCascadeAuditEntry(db, batch, {
    subjectUserId: uid,
    targetUid: null,
    operation: "cascade_delete",
    resourceType: USER_MODERATION,
    resourceId: uid,
  });
  await batch.commit();
  return true;
}

/**
 * BUT-2046: the erased user as the REPORTER — their uid on rows that live under
 * OTHER people's moderation records.
 *
 * A cross-user sweep, and it runs AFTER tier 1 for the same reason
 * `deleteBlockMirrors` does: `onReportCreated` can write a row while the
 * cascade is running, and running last makes this the final word on everything
 * tier 1 removed.
 *
 * It does not close that race, and nothing here can. `onReportCreated` is an
 * `onDocumentCreated` trigger that re-throws for retry and has NO ordering
 * relationship to account deletion, so a report filed — or a delivery retried —
 * around the erasure lands a fresh row naming this uid afterwards. Accepted as a
 * named residual, the same call Malin made for the sibling `system_events` rows
 * on 2026-09-08, and the reason the 180-day TTL on `expireAt` matters: it is
 * what eventually removes such a row.
 *
 * The legacy shape is NOT reachable from here. Before BUT-2046 these rows were
 * entries in a `reportHistory` ARRAY on the parent, and a uid inside an array of
 * maps cannot be queried — so a reporter's uid in somebody else's un-migrated
 * document is reached by `admin/migrate-report-history.ts` and by nothing else.
 */
export async function deleteReportHistoryByReporter(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(REPORT_HISTORY)
    .where("reporterId", "==", uid)
    .limit(MAX_REPORT_HISTORY_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_REPORT_HISTORY_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible reporter row count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }

  if (snap.empty) return true;

  // The row follows its `reports` document (the doc id IS the report id): an
  // open case keeps it with the reporter's uid nulled. A failed read keeps
  // every row, and the step reports itself incomplete.
  let complete = true;
  let open: Set<string>;
  try {
    open = await openReportIds(db, snap.docs.map((d) => d.id));
  } catch (err) {
    logger.error(
      "[deletion-cascade] report status unreadable; keeping reporter rows",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
    complete = false;
    open = new Set(snap.docs.map((d) => d.id));
  }

  await commitInChunks(
    db,
    snap.docs,
    (batch, doc) => {
      if (open.has(doc.id)) {
        batch.update(doc.ref, { reporterId: null });
        stageCascadeAuditEntry(db, batch, {
          subjectUserId: uid,
          targetUid: null,
          operation: "cascade_anonymize",
          resourceType: REPORT_HISTORY,
          resourceId: doc.id,
          extra: { field: "reporterId" },
        });
        return;
      }
      batch.delete(doc.ref);
      stageCascadeAuditEntry(db, batch, {
        subjectUserId: uid,
        // `resourceId` is the REPORT id, so this row does not record whose
        // moderation record was touched — the owner leg's `resourceId` is the
        // uid, this one's is not. Naming the parent owner would put a third
        // party's uid in `audit_logs`, which is a privacy decision rather than
        // an omission.
        targetUid: null,
        operation: "cascade_delete",
        resourceType: REPORT_HISTORY,
        resourceId: doc.id,
      });
    },
    {
      label: `BUT-2046: reporter rows delete for ${uid.slice(0, 6)}`,
      opsPerItem: 2,
    },
  );
  return complete;
}

/**
 * BUT-1768: `realtime_menus` was in no tier at all — a collaborative menu the
 * user owns survived an Article 17 erasure intact, readable by every
 * participant, and no residual probe looked at it.
 *
 * `ownerId` is the owner field, NOT `userId`. That is the BUT-1396 trap this
 * step is written to avoid: the model writes `ownerId`, the `realtime_menus`
 * rule gates read/update/delete on it, and `on-profile-updated.ts` renames on
 * it — a `where("userId", "==", uid)` filter is syntactically perfect, throws
 * nothing and matches zero documents forever.
 *
 * Menus the user does NOT own are the other half (see [scrubLastEditor] and
 * [removeRealtimeParticipation]).
 */
export async function deleteRealtimeMenus(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const owned = await db
    .collection(Collections.realtimeMenus)
    .where("ownerId", "==", uid)
    .get();
  await deleteRealtimeDocsWithChildren(db, owned.docs);

  await scrubLastEditor(db, Collections.realtimeMenus, uid);
  const stillJoined = await removeRealtimeParticipation(
    db,
    Collections.realtimeMenus,
    uid,
  );
  await removeVoteEntries(db, stillJoined, uid);
  return true;
}

/**
 * BUT-2151: live menus (`realtime_resources`). Owned documents go, the
 * last-editor pair is anonymized on
 * the rest, and the user leaves every roster they were in. The roster leg
 * removes the uid from `participantIds` and `participants` together, which is
 * the pair the rules require to stay in step.
 */
export async function deleteRealtimeResources(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const votesCleared = await deleteLiveMenuVotes(db, uid);

  const owned = await db
    .collection(Collections.realtimeResources)
    .where("ownerId", "==", uid)
    .get();
  await deleteRealtimeDocsWithChildren(db, owned.docs);

  await scrubLastEditor(db, Collections.realtimeResources, uid);
  await removeRealtimeParticipation(db, Collections.realtimeResources, uid);
  return votesCleared;
}

export const MAX_LIVE_MENU_VOTE_SWEEP_ROWS = 2000;

/**
 * BUT-2118: the person's own ballot documents,
 * `realtime_resources/{menuId}/votes/{uid}`, on every live menu, including
 * menus they have LEFT. That last case is why this is a collection-group
 * query on `userId` and not a walk over the menus the roster sweep finds: a
 * leaver is no longer in `participantIds`, and their document stays until its
 * TTL. Owned menus lose all their ballots through
 * [deleteRealtimeDocsWithChildren]; this leg may delete the owner's own
 * document there too, which is harmless.
 *
 * Filtered on the parent collection, because the collection id `votes` is
 * shared with the legacy `realtime_menus/{id}/votes` documents; the legacy
 * uid-in-a-map residue stays with [removeVoteEntries].
 *
 * A failed chunk makes the step report failure rather than a clean one, and
 * the menu legs after it still run. Capped like the poll-vote sweep; the leg
 * in `probeResidualData` reads the same rows.
 */
export async function deleteLiveMenuVotes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const ballots = await liveMenuBallotRows(db, uid);
  if (ballots === null) {
    logger.error(
      "[deletion-cascade] implausible live-menu ballot count; not sweeping",
      { uid_prefix: uid.slice(0, 6) },
    );
    return false;
  }
  try {
    await commitInChunks(
      db,
      ballots,
      (batch, doc) => batch.delete(doc.ref),
      { label: "deleteLiveMenuVotes", strict: true },
    );
  } catch (err) {
    logger.error("[deletion-cascade] live-menu ballot sweep failed", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
  return true;
}

/** True for `realtime_resources/{id}`, and for nothing nested deeper. */
function isLiveMenuParent(ref: admin.firestore.DocumentReference): boolean {
  return (
    ref.parent.id === Collections.realtimeResources && ref.parent.parent === null
  );
}

/**
 * The erased user's ballot documents, found by collection group and kept only
 * under a top-level `realtime_resources` document. `null` when the read
 * exceeds the cap.
 */
async function liveMenuBallotRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const snap = await db
    .collectionGroup(Collections.liveMenuVotes)
    .where("userId", "==", uid)
    .limit(MAX_LIVE_MENU_VOTE_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_LIVE_MENU_VOTE_SWEEP_ROWS) return null;
  return snap.docs.filter((doc) => {
    const parent = doc.ref.parent.parent;
    return parent !== null && isLiveMenuParent(parent);
  });
}

/**
 * Strip `votes.<uid>` from every vote document under menus the user took part
 * in but does not own.
 *
 * `realtime_menus/{menuId}/votes/{voteId}` is NOT uid-keyed by document id
 * despite what the rules comment suggests: the doc id is the slot's vote id and
 * the ballot is a MAP, `votes: {userId -> optionId}`. So the deleted
 * user's uid survives one level below the document the participation sweep
 * cleans, on a menu that continues to exist for its owner.
 *
 * Scoped to the menus the participation sweep just found, which is the only
 * bounded handle there is: a map KEY cannot be queried, so a menu the user
 * voted in and later LEFT is out of reach here (the same class as messages in
 * a left conversation) and would need a full `collectionGroup("votes")` scan.
 * Recorded rather than silently skipped.
 */
async function removeVoteEntries(
  db: admin.firestore.Firestore,
  menus: admin.firestore.QueryDocumentSnapshot[],
  uid: string,
): Promise<void> {
  for (const menu of menus) {
    const votes = await menu.ref.collection("votes").get();
    const carrying = votes.docs.filter((v) => {
      const ballot = v.data().votes;
      return (
        !!ballot && typeof ballot === "object" && uid in (ballot as object)
      );
    });
    if (carrying.length === 0) continue;
    await commitInChunks(
      db,
      carrying,
      (batch, voteDoc) => {
        batch.update(voteDoc.ref, {
          [`votes.${uid}`]: admin.firestore.FieldValue.delete(),
        });
      },
      { label: "removeVoteEntries", strict: false },
    );
  }
}

/**
 * The rule-blessed child collections of a realtime document.
 *
 * `firestore.rules` declares `realtime_menus/{id}/presence/{userId}` and
 * `/votes/{voteId}`. Both are
 * uid-keyed and both carry personal data: a presence doc holds
 * `{displayName, isActive, lastSeen}`, and a vote document's `votes` map is
 * keyed `userId -> optionId`.
 */
const REALTIME_CHILD_COLLECTIONS = ["presence", "votes"] as const;

/**
 * Delete realtime parent documents AND their child subcollections.
 *
 * Firestore never cascades: `batch.delete(parentRef)` leaves every document
 * under `parent/presence` and `parent/votes` in place, orphaned. An orphan here
 * is the worst possible residual — unreadable by any client (both child rules
 * resolve participation through the parent, which no longer exists), unfindable
 * by any later erasure, and invisible to `probeResidualData`, which counts
 * TOP-LEVEL documents only. The cascade would push `realtime_menus` into
 * `deletedCollections` and the audit row would certify `gdprCompliant: true`
 * over a document still holding the deleted user's uid.
 *
 * Children first and STRICT, parent best-effort: if the child sweep cannot
 * complete, the parent must stay so a retry can still find the children through
 * it. The reverse order is precisely how an orphan is created.
 */
async function deleteRealtimeDocsWithChildren(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  for (const doc of docs) {
    for (const child of REALTIME_CHILD_COLLECTIONS) {
      const kids = await doc.ref.collection(child).get();
      if (kids.docs.length === 0) continue;
      await commitInChunks(
        db,
        kids.docs,
        (batch, kid) => batch.delete(kid.ref),
        { label: `deleteRealtimeChildren:${child}`, strict: true },
      );
    }
  }
  await batchDeleteAll(db, docs);
}

/**
 * Drop the deleted user from realtime documents they PARTICIPATE in but do not
 * own — the third residual on this surface, and the one nothing covered.
 *
 * `scrubLastEditor` only reaches documents where they happened to be the last
 * editor. A collaborator who joined, was seen, voted and never made the final
 * edit left three things behind on someone else's document, all of them visible
 * to the remaining collaborators: the `presence/{uid}` child document (which
 * carries a `displayName`), the `participants` MAP KEY, and their
 * `participantIds` entry. The map key is also live authorization —
 * `firestore.rules` grants update to `request.auth.uid in
 * resource.data.participantIds` — so leaving it is a dangling grant for an
 * account that no longer exists.
 *
 * Owned documents are excluded: the sibling leg has already deleted them, and
 * an update against a deleted document throws NOT_FOUND.
 *
 * Returns the non-owned documents it cleaned, so a caller can reach one level
 * further down (see [removeVoteEntries]).
 */
async function removeRealtimeParticipation(
  db: admin.firestore.Firestore,
  collection: string,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const joined = await db
    .collection(collection)
    .where("participantIds", "array-contains", uid)
    .get();
  const notOwned = joined.docs.filter((doc) => doc.data().ownerId !== uid);
  if (notOwned.length === 0) return notOwned;

  // BUT-2214: before the roster write below.
  await scrubDishCreator(db, notOwned, uid, collection);

  for (const doc of notOwned) {
    const presence = doc.ref.collection("presence").doc(uid);
    try {
      await presence.delete();
    } catch (err) {
      logger.warn("[deletion-cascade] realtime presence delete failed", {
        uid_prefix: uid.slice(0, 6),
        path: presence.path,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  await commitInChunks(
    db,
    notOwned,
    (batch, doc) => {
      batch.update(doc.ref, {
        participantIds: admin.firestore.FieldValue.arrayRemove(uid),
        [`participants.${uid}`]: admin.firestore.FieldValue.delete(),
      });
    },
    { label: `removeRealtimeParticipation:${collection}`, strict: false },
  );
  return notOwned;
}

/**
 * Anonymize the `lastEditedBy` / `lastEditedByDisplayName` pair on realtime
 * documents in [collection] that the deleted user last edited but does NOT own.
 *
 * The decision this encodes: the document itself stays. It belongs to its
 * owner, and the other participants are still collaborating on it — deleting
 * someone else's menu because a departing member touched it last would be
 * erasure of THEIR data, not of the deleted user's. What must go is the
 * identity pair, which `on-profile-updated.ts` maintains as a denormalised copy
 * of the user's profile name: without this it survives on a document other
 * people keep open indefinitely, and the rename propagator that used to keep it
 * current stops running the moment the account is gone.
 *
 * Anonymized rather than nulled, mirroring `deleteCommentsAndRatings` and the
 * shared-shopping-list item scrub: the fields are non-nullable in the client
 * model (`RealtimeResource`), so a null would fail the `as String` cast on read
 * for every remaining participant.
 *
 * Owned documents are excluded because the sibling leg has already deleted
 * them; a scrub of a deleted document throws NOT_FOUND.
 */
async function scrubLastEditor(
  db: admin.firestore.Firestore,
  collection: string,
  uid: string,
): Promise<void> {
  const edited = await db
    .collection(collection)
    .where("lastEditedBy", "==", uid)
    .get();
  const notOwned = edited.docs.filter((doc) => doc.data().ownerId !== uid);
  if (notOwned.length === 0) return;

  // Per-doc transaction, not a blind batch.update() from the query snapshot:
  // this is a REALTIME collection, so a different collaborator editing the
  // same doc between the query and the write is the expected case, not the
  // edge case. Re-checking lastEditedBy inside the transaction means a fresh
  // edit wins and is never reverted back to "deleted"; a stale write would
  // silently stamp someone else's just-made edit with the departed user's
  // tombstone. Best-effort per doc, mirroring the swallowed commitInChunks
  // failures this replaces.
  const chunkSize = 10;
  for (let i = 0; i < notOwned.length; i += chunkSize) {
    const chunk = notOwned.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (doc) => {
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(doc.ref);
            if (!fresh.exists) return;
            if (fresh.data()?.lastEditedBy !== uid) return;
            tx.update(doc.ref, {
              lastEditedBy: "deleted",
              lastEditedByDisplayName: "[Raderad användare]",
            });
          });
        } catch (err) {
          logger.warn(`scrubLastEditor:${collection}: doc write failed`, {
            uid_prefix: uid.slice(0, 6),
            docId: doc.id,
            errName: err instanceof Error ? err.name : typeof err,
          });
        }
      }),
    );
  }
}

/**
 * `users/{uid}` subcollections this cascade erases but the Art. 15 export
 * deliberately does NOT reproduce, each with the reason it is exempt.
 *
 * BUT-1992. The invariant is EXPORT ⊇ DELETION: anything erased on account
 * deletion must have been obtainable by its subject first, or it is erased
 * having never been disclosable. `scenario_exportCoversEveryDeletedSubcollection`
 * holds it, and a name that is neither exported nor listed here reddens.
 *
 * This lives in production source rather than in the test on purpose. An
 * exemption added here shows up in the diff a reviewer reads; one added inside
 * the test file reads as test bookkeeping and gets waved through — which is how
 * an escape hatch built to be deliberate becomes a rubber stamp.
 *
 * Malin's explicit calls, 2026-09-03, taken one question at a time against the
 * panel's split. She went AGAINST the recommendation on `rate_limits`, which was
 * to export it: the Security seat had measured that nothing secret is disclosed
 * (the limits live in client code and are already visible in the throttling copy
 * the user sees). She weighed
 * bundle legibility higher.
 * Recording it because a future reader will otherwise assume the security
 * argument won, and re-litigate a decision that was made on other grounds.
 *
 * An exemption the subject cannot see is an undisclosed gap, not a
 * minimisation decision (Art. 12(1), the BUT-1971 precedent).
 */
export const EXPORT_EXEMPT: Record<string, string> = {
  // ── Withheld on purpose, with a live writer. These are the decisions. ──
  rate_limits:
    "PLUMBING. " +
    "Malin, 2026-09-03, weighing bundle " +
    "legibility higher. Named in the bundle's data_minimisation line.",
  counters:
    "PLUMBING. Derived unread tallies over content this export already " +
    "reproduces in full, so they add nothing the bundle lacks. Their values " +
    "are also partly OTHER people's actions (the update limb accepts a " +
    "cross-user increment), so a per-actor breakdown must never be added. " +
    "Malin, 2026-09-03. Named in the bundle's data_minimisation line.",
  report_throttle:
    "PLUMBING: the cooldown between abuse reports, written by " +
    "firebase_report_repository.dart. NOT the same shape as rate_limits — its " +
    "doc id is the REPORTED user's uid (`contentOwnerId`), where rate_limits " +
    "ids are operation names. The substantive reason it is exempt is that the " +
    "reports themselves ARE exported (`reports` where `reporterId == uid`, " +
    "each already carrying `contentOwnerId`), so the throttle adds only a " +
    "derived recency stamp on top of rows the subject already receives. " +
    "NOT put to Malin — it was not among the three questions she was asked. " +
    "Named in the bundle's data_minimisation line like the two above.",

  block_mirror:
    "WITHHELD BY THE SAME DECISION as the `blocks` incoming direction, and " +
    "argued on its own facts rather than inherited. " +
    "`users/{uid}/block_mirror/current` holds the uids of everyone who has " +
    "blocked this user. Malin decided on 2026-09-05 (BUT-2018) that an " +
    "Art. 15 bundle must not tell a requester who blocked them nor how many " +
    "people did: Art. 15(4) permits withholding a copy that would adversely " +
    "affect the rights and freedoms of others, and a block is placed by " +
    "someone wanting distance from — often — the requester themselves. That " +
    "reasoning is about the FACT, so it reaches every store of it: the " +
    "`blocks` rows the mirror derives from, and this projection of them. " +
    "Withholding the source while exporting the copy would hand over the " +
    "same disclosure through a second door. " +
    "The omission is disclosed to the subject in the blocks section's own " +
    "`data_minimisation` line, which states that who has blocked them is " +
    "left out and why. " +
    "`scenario_blockMirrorExemptionRestsOnTheSameDecision` fails if that " +
    "section returns, so the dependency stays enforced rather than " +
    "described.",
  // ── Removed collection. Not a withholding, and not the family below. ──
  conversation_memberships:
    "REMOVED COLLECTION (BUT-1850, 2026-09-17). This is NOT a withholding " +
    "decision and rests on no Art. 15(4) argument — it is a claim about the " +
    "code: the client writer, the model and the firestore.rules block are all " +
    "deleted in the same change, so no new row can be created and no client " +
    "could read one if it were. Deliberately NOT prefixed NO LIVE WRITER: " +
    "that family means the collection is still readable and holds legacy rows " +
    "only, which is a materially different state from a deleted rules block. " +
    "The name stays in USER_SUBCOLLECTIONS for one release because it is then " +
    "the only remaining erasure handle — probeResidualData ENUMERATES, so " +
    "dropping it would leave a row written in the deploy window counted " +
    "forever with no deleter able to clear it. Scoped residual: for an " +
    "account that still holds rows written before the rules deploy, those " +
    "rows are erasable. BUT-2109 removes this entry " +
    "and the subs entry in the SAME edit — taking either alone reddens " +
    "scenario_exportCoversEveryDeletedSubcollection from one side or the " +
    "other. No disclosure site, deliberately: nothing is withheld, so no " +
    "data_minimisation line names it.",

  // ── No writer of the `users/{uid}` path. Swept for legacy rows only. ──
  // The cascade sweeps these so an account predating their removal cannot hold
  // rows the probe reports forever. Nothing writes them today, so for a current
  // account the export omits nothing.
  //
  // The residual the DPO seat named, recorded rather than argued away: for an
  // account that DOES still hold legacy rows, they are erasable but were never
  // exportable. Whether that is worth an export section for a shape no live
  // code writes is Malin's, and has not been asked.
  category_memberships:
    "NO LIVE WRITER of users/{uid}/category_memberships. Legacy sweep only.",
  connection_tests:
    "NO LIVE WRITER of users/{uid}/connection_tests. Legacy sweep only.",
  unified_recipes:
    "NO LIVE WRITER of users/{uid}/unified_recipes. Legacy sweep only.",
  conversations:
    "NO LIVE WRITER of the users/{uid}/conversations SUBCOLLECTION. The real " +
    "conversations are the top-level collection, which the export covers in " +
    "its own section. Legacy sweep only.",
  fcm_tokens:
    "NO LIVE WRITER of the users/{uid}/fcm_tokens SUBCOLLECTION — BUT-1990 " +
    "measured that it never had one. Device tokens live in the TOP-LEVEL " +
    "user_fcm_tokens, which the export reads by userId field. Legacy sweep " +
    "only; do not read the shared name as the same data.",
  user_shared_menus:
    "NO LIVE WRITER of the users/{uid}/user_shared_menus SUBCOLLECTION. The " +
    "share index is the TOP-LEVEL user_shared_menus/{recipientId}/" +
    "received_menus, and the shared menus themselves are exported by the " +
    "shared_content section. Same top-level-vs-subcollection name collision " +
    "as fcm_tokens. Legacy sweep only.",
  friendCategories:
    "NO LIVE WRITER of users/{uid}/friendCategories — the PRE-RENAME spelling " +
    "of friend_categories, which IS exported. `admin/migrate-friend-categories.ts` " +
    "moves a row under this spelling onto the live one. The alternative was a new " +
    "firestore.rules read block for the dead spelling, because the export runs " +
    "on the CLIENT SDK and that path has none. Malin chose the migration, " +
    "2026-09-08. Legacy sweep only.",
  rateLimits:
    "NO LIVE WRITER of users/{uid}/rateLimits — the PRE-RENAME spelling of " +
    "rate_limits, which is also exempt. One collection under two spellings, " +
    "evidenced by the rename commit, not two collections sharing a word. " +
    "So this inherits the standing decision rather than making a new one: " +
    "Malin, 2026-09-03, chose EXEMPT for rate_limits against the " +
    "recommendation to export it, weighing bundle legibility higher " +
    "(ADR-0011). Adding an export section here would reopen that " +
    "decision. Legacy sweep only. BUT-2040.",
  user_shared_shopping_lists:
    "NO LIVE WRITER of the users/{uid}/user_shared_shopping_lists " +
    "SUBCOLLECTION. The index is top-level, and the lists themselves are " +
    "exported by the shared_shopping_lists section (BUT-1732). Legacy sweep " +
    "only.",
};

export async function deleteUserPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // The whole COLLECTION, not `settings/preferences` by id (BUT-1957).
  // `probeResidualData` counts collections, so a delete keyed to one document
  // id leaves any second document under `settings` reported as residual with no
  // step able to remove it — a `gdprCompliant: false` nobody can clear, plus a
  // real Art. 17 residual. `firestore.rules` leaves the id unconstrained on an
  // owner-only create, so a second document is a client write away.
  // Idempotent, and still deletes `preferences`.
  const snap = await db.collection("users").doc(uid).collection("settings").get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteConsentRecords(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("consent")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * The `users/{uid}` subcollections `deleteUserSubcollections` sweeps.
 *
 * Exported (BUT-2043) so the guards and the reset script's unknown-collection
 * report read the REAL value instead of parsing this file as source text. Two
 * guards used to do that with `/"([A-Za-z_]+)"/` over a body with only `//`
 * comments stripped, which made a name carrying a digit invisible to them and
 * read a quoted name inside a block comment as a list entry. `EXPORT_EXEMPT`
 * below is the precedent, in this same file — no separate module is needed,
 * because nothing here runs at import.
 */
export const USER_SUBCOLLECTIONS: readonly string[] = [
  "conversation_memberships",
  "user_shared_menus",
  "user_shared_shopping_lists",
  "friend_categories",
  "friends",
  "category_preferences",
  "list_category_orders",
  "report_throttle",
  // BUT-1957: the win-back / activity-digest notification rows, written by
  // `analytics/detect-lapsed-users.ts` and `analytics/send-activity-digest.ts`.
  // They carry the push text ACTUALLY SHOWN to the user (`message`/`bodyShown`)
  // plus the win-back A/B assignment, and nothing reached them: deleting the
  // parent user document does not delete its subcollections, so every row
  // survived erasure.
  //
  // `deleteNotifications` is NOT this. That sweeps the TOP-LEVEL collection
  // `user_notifications` — a different collection whose name is one word away,
  // which is the likeliest reason this one went unnoticed for so long.
  "notifications",
  // Everything below is here for ONE reason: the probe in
  // `probeResidualData` ENUMERATES what is left under `users/{uid}` instead
  // of consulting a list. That makes it broader than any hand-written
  // deleter, and the direction of a disagreement matters — a row the probe
  // reports and nothing erases is a `gdprCompliant: false` that no code path
  // can ever clear. So the deleter must be a superset of the probe, which is
  // the rule `deleteWeeklyMenuPlans` already states about its own four
  // handles. A `.get()` on a collection that does not exist costs one empty
  // read, on a path that runs once per account, ever.
  //
  // WRITTEN TODAY, with no dedicated tier step of their own. Found by the
  // `subs` audit BUT-1957 asked for — the first pass of that audit scanned
  // for the literal `.collection("users").doc(x).collection("y")` chain and
  // therefore saw only the server; every Dart writer builds the path from a
  // `FirestoreCollections` constant and was invisible to it. Resolving the
  // constants is what turned these up.
  "onboarding", // onboarding_progress_service.dart
  "ingredients", // firebase_user_ingredient_repository.dart
  "rate_limits", // firebase_activity_event_repository.dart, and others
  "counters", // base_shared_content_repository.dart (unread counters)
  // BUT-612 attribution (channel, campaign, timestamps), written to
  // `users/{uid}/acquisition/current` by firebase_acquisition_repository.dart.
  // Found by the `integration-reviewer` gate, NOT by the drift guard, which
  // could not see it: that repository chains through a file-local `const`
  // rather than `FirestoreCollections.users` inline. The guard now resolves
  // local consts too, so the next one of this shape reddens.
  "acquisition",
  // P5-U26b: the user's own week menus and recipes that another person's save
  // overwrote, kept 30 days behind "Återställ" (produktregler.md:109), written
  // by firebase_overwritten_version_repository.dart. A TTL policy on
  // `expiresAt` removes each row after 30 days; this entry erases them at
  // once when the account goes. Exported in the account-subcollections
  // section, so EXPORT ⊇ DELETION holds.
  "overwritten_versions",
  // BUT-907: the user's own deleted recipes in the trash, written by the
  // trash repository in the same batch that deletes the recipe. A TTL policy
  // on `expireAt` removes each row; this entry erases them at once when the
  // account goes. Their photos
  // sit under `users/{uid}/recipes/`, which the Storage prefix delete covers.
  "trash",
  // NO live writer found in `lib/` or `functions/src`. Swept anyway, because
  // an account predating a writer's removal can still hold rows, and by the
  // superset rule above such a row would otherwise be permanently residual.
  // `fcm_tokens` was named here from the Art. 15 export, which read it while
  // nothing wrote it — BUT-1990 has since removed that reader.
  "category_memberships",
  "connection_tests",
  "unified_recipes",
  "conversations",
  "fcm_tokens",
  // BUT-2040: the PRE-RENAME spelling of `rate_limits` above — one
  // collection under two spellings, not two collections. Nothing has
  // written `users/{uid}/rateLimits` since commit b9a95bd02 (2026-03-19)
  // renamed `FirestoreCollections.userRateLimits` to `rate_limits`, and
  // `firestore.rules` has no block for the camelCase path, so no client
  // can recreate a row. The dry run of `admin/reset-user-data.ts` measured
  // 5 rows still standing in production on 2026-09-07.
  //
  // Without this entry the rows are unreachable: `probeResidualData`
  // ENUMERATES, so it counts them and stamps `residual_data_detected` on
  // every deletion of such an account, while no deleter can clear it. The
  // collection-group TTL on `expireAt` does not reach them either — a TTL
  // policy is keyed to an exact collection id, and `rateLimits` is not
  // `rate_limits`.
  "rateLimits",
  // BUT-2044: the PRE-RENAME spelling of `friend_categories`, from the SAME
  // rename commit as `rateLimits` above (b9a95bd02, 2026-03-19).
  // `admin/migrate-friend-categories.ts`
  // moves such a row to the live spelling; this sweep covers an account that
  // still holds one, including the collision case that script leaves standing.
  "friendCategories",
  // Pooled ratings (decision 12): the user's frozen pool events. Each delete
  // fires the Stage-B trigger (onPooledRatingEventWritten), which recomputes
  // the affected pool's canonical_recipe_stats — so erasing the rater also
  // shrinks the public averages they contributed to, with no explicit
  // recompute call (the established trigger separation).
  "canonical_rating_events",
  // BUT-1917: the block mirror, `users/{uid}/block_mirror/current`. This leg
  // erases the deleted user's OWN mirror — the list of who blocked THEM.
  // Removing their uid from OTHER people's mirrors is a separate, capped
  // step (`deleteBlockMirrors`), because that one is a cross-user sweep and
  // this list is only the owner's own subtree.
  "block_mirror",
];

export async function deleteUserSubcollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const userDoc = db.collection("users").doc(uid);
  // `notificationCounters` + `recentContentHashes` are intentionally NOT
  // included — `onUserDeleted` (cleanupContentGuardSubcollections) owns
  // those and runs automatically after `admin.auth().deleteUser(uid)`.
  const subs = USER_SUBCOLLECTIONS;
  for (const name of subs) {
    const snap = await userDoc.collection(name).get();
    await batchDeleteAll(db, snap.docs);
  }

  // BUT-1390: THESE rate-limit buckets live at the TOP-LEVEL
  // `system_rate_limits` collection (doc id `${uid}_${operation}`), so they
  // need their own sweep.
  //
  // This comment used to add that the `users/{uid}/rate_limits` entry above
  // "deleted nothing". That was true when BUT-1390 was written and is false
  // now: `firebase_activity_event_repository.dart` writes a bucket there, and
  // BUT-1957 put the entry back for exactly that reason. The two are separate
  // collections with separate writers, not one collection that moved.
  //
  // Erase the top-level ones via a documentId prefix range:
  //   startAt(`${uid}_`) .. endAt(`${uid}_`)
  // The upper bound's trailing  is a high-codepoint sentinel that is
  // INVISIBLE in most editors/diff viewers — it is load-bearing: WITHOUT it the
  // range collapses to the single (nonexistent) id `${uid}_` and erases nothing.
  // Do not "tidy" it away. The `_` separator additionally prevents matching a
  // different user whose uid is a prefix of this one. No field filter/index needed.
  const rlSnap = await db
    .collection("system_rate_limits")
    .orderBy(admin.firestore.FieldPath.documentId())
    .startAt(`${uid}_`)
    .endAt(`${uid}_`)
    .get();
  await batchDeleteAll(db, rlSnap.docs);

  return true;
}

export async function deleteUserProfile(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection("users").doc(uid).delete();
  return true;
}

/**
 * BUT-1838: erase the user's chat-group membership.
 *
 * **Why this is its own leg and not part of `deleteMessages`.** A group's
 * membership lives on `chat_groups/{id}.memberIds` and is MIRRORED onto the
 * conversation; one writer owns both (`groups/chat-group-writes.ts`). Letting
 * the conversation leg strip its half would leave the group still naming the
 * erased user — two copies of one fact, disagreeing, which is the failure
 * BUT-1798 already cost this project once. `deleteMessages` therefore skips any
 * conversation carrying a `groupId`, and this leg does the whole removal
 * through the shared writer.
 *
 * Three things happen per group, in this order:
 *
 *  1. **`createdBy` is re-homed** to a surviving admin (or member) when the
 *     erased user created a group that lives on. Same move `deleteFamilyData`
 *     already makes for households: without it a raw uid sits on a document
 *     other people keep reading, forever, which Art. 17 does not permit and no
 *     field-keyed probe would flag as "residual" once the membership is gone.
 *  2. **The membership goes**, through `stageMemberRemoval` — the same
 *     transaction that clears `memberIds`, `adminIds`, both display maps,
 *     `memberAddedBy`, the conversation's `participantIds`, all five uid-keyed
 *     conversation maps (including `memberSince`) and the roster row.
 *  3. **An emptied group is taken down**, roster FIRST. Deleting a conversation
 *     is what makes `parentDoc()` null in `firestore.rules`; with the bootstrap
 *     branch gone that no longer re-opens a write path, but orphaned roster rows
 *     still carry names and avatars, so the parent delete stays gated on
 *     `tryClearRoster` reporting success. A group left standing reports the step
 *     INCOMPLETE rather than quietly passing.
 *
 * Capped like every other sweep here. Above the cap it DECLINES rather than
 * truncating: a partial pass that reported success would certify an erasure it
 * did not perform.
 *
 * A separate sweep handles what the membership query cannot reach at all — a
 * departure tombstone (the uid is in it precisely because it left `memberIds`)
 * and the meal-vote pointer's owner uid (they can leave the chat and keep
 * owning the social group). See `clearUnreachableChatGroupResiduals`, run
 * BEFORE the loop below so this function's own cap cannot take it down
 * (BUT-1856).
 */
export const MAX_CHAT_GROUPS_PER_USER = 200;

export async function deleteChatGroupMemberships(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // FIRST, so the membership sweep declining below cannot take the two
  // independent residual legs down with it — they answer different queries and
  // a cap reached by one says nothing about the others.
  const residualsCleared = await clearUnreachableChatGroupResiduals(db, uid);

  const snap = await db
    .collection(Collections.chatGroups)
    .where("memberIds", "array-contains", uid)
    .limit(MAX_CHAT_GROUPS_PER_USER + 1)
    .get();

  if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
    logger.error(
      "[deletion-cascade] implausible chat-group count; declining the sweep",
      { uid_prefix: uid.slice(0, 6), groups: snap.size },
    );
    return false;
  }

  let complete = true;
  const removedAt = admin.firestore.Timestamp.now();

  for (const groupDoc of snap.docs) {
    try {
      const data = groupDoc.data();
      const conversationId =
        typeof data.conversationId === "string" ? data.conversationId : null;
      if (!conversationId) {
        // A group with members and no conversation is a shape no code path
        // produces. Loud, and not counted as done.
        complete = false;
        logger.error("[deletion-cascade] chat group has no conversationId", {
          uid_prefix: uid.slice(0, 6),
          groupId: groupDoc.id,
        });
        continue;
      }

      const memberIds: string[] = Array.isArray(data.memberIds)
        ? (data.memberIds as string[])
        : [];
      const adminIds: string[] = Array.isArray(data.adminIds)
        ? (data.adminIds as string[])
        : [];
      const survivors = memberIds.filter((u) => u !== uid);

      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(groupDoc.ref);
        if (!fresh.exists) return;
        stageMemberRemoval(tx, {
          db,
          groupId: groupDoc.id,
          conversationId,
          uid,
          removedAt,
        });
        if (survivors.length > 0 && data.createdBy === uid) {
          // Prefer a surviving ADMIN so the group keeps someone who can act on
          // it; fall back to any survivor rather than leaving a raw uid behind.
          const survivingAdmin = adminIds.find(
            (a) => a !== uid && survivors.includes(a),
          );
          tx.update(groupDoc.ref, {
            createdBy: survivingAdmin ?? survivors[0],
          });
        }
      });

      if (survivors.length === 0) {
        const cleared = await tryClearRoster(db, conversationId);
        if (!cleared) {
          complete = false;
          logger.warn(
            "[deletion-cascade] roster not clear; empty group left standing",
            {
              uid_prefix: uid.slice(0, 6),
              conversationId: logSafeConversationId(conversationId),
            },
          );
          continue;
        }
        const thread = await db
          .collection(Collections.messages)
          .where("conversationId", "==", conversationId)
          .get();
        await batchDeleteAll(db, thread.docs);
        await db.collection(Collections.conversations).doc(conversationId).delete();
        await groupDoc.ref.delete();
      }

    } catch (e) {
      complete = false;
      logger.error("[deletion-cascade] chat-group removal failed", {
        uid_prefix: uid.slice(0, 6),
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      });
    }
  }

  return complete && residualsCleared;
}

/**
 * BUT-1856: raw uids on `chat_groups` the sweep above cannot reach.
 *
 * Not an exhaustive list of that document's residuals — `createdBy` is re-homed
 * only for groups the erased user is still a MEMBER of, and `memberAddedBy`
 * VALUES survive for everyone they seated. Both predate this change and are
 * forward-only work; do not read the two legs below as covering the document.
 *
 * `departedUserIds` records who left a chat group or was removed from it, so
 * the meal-vote category sync cannot seat them again — a uid is in it precisely
 * because it is NOT in `memberIds`. `sourceCategoryOwnerId` names the owner of
 * the social group a meal-vote chat was built from, and outlives their
 * membership: they can leave the chat and still own the category. The sweep
 * above finds groups by `memberIds array-contains`, so it is structurally blind
 * to both, and each would otherwise sit forever on a document the surviving
 * members read — the same residual class `createdBy` is re-homed for.
 *
 * Dropping the pointer breaks nothing: the category itself goes in this same
 * cascade, so it is already dangling, and the group simply stops being any
 * category's chat.
 *
 * Capped and DECLINING per leg, like every other sweep here: a partial pass
 * that reported success would certify an erasure it did not perform.
 */
async function clearUnreachableChatGroupResiduals(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const legs = [
    {
      field: "departedUserIds",
      op: "array-contains" as const,
      patch: { departedUserIds: admin.firestore.FieldValue.arrayRemove(uid) },
    },
    {
      field: "sourceCategoryOwnerId",
      op: "==" as const,
      patch: {
        sourceCategoryId: admin.firestore.FieldValue.delete(),
        sourceCategoryOwnerId: admin.firestore.FieldValue.delete(),
      },
    },
  ];

  let complete = true;
  for (const leg of legs) {
    const snap = await db
      .collection(Collections.chatGroups)
      .where(leg.field, leg.op, uid)
      .limit(MAX_CHAT_GROUPS_PER_USER + 1)
      .get();

    if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
      logger.error(
        "[deletion-cascade] implausible chat-group residual count; declining",
        { uid_prefix: uid.slice(0, 6), field: leg.field, groups: snap.size },
      );
      complete = false;
      continue;
    }

    for (const groupDoc of snap.docs) {
      try {
        await groupDoc.ref.update(leg.patch);
      } catch (e) {
        complete = false;
        logger.error("[deletion-cascade] chat-group residual removal failed", {
          uid_prefix: uid.slice(0, 6),
          field: leg.field,
          errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
          errName: (e as Error | null)?.name,
        });
      }
    }
  }
  return complete;
}
