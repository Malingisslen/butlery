import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
import { hashUid } from "../../shared/hash-uid";
import { APPELLANT_ID, MODERATION_APPEALS } from "../../moderation/appeals";
import { REPORTS } from "../../moderation/report-status";
// P6-U09: the two-step-verification collections. Imported rather than
// retyped so the cascade and the writer cannot disagree about a name or about
// the shape of the per-account counter key.
import {
  BACKUP_CODES_COLLECTION,
  RECOVERY_ATTEMPTS_COLLECTION,
  uidAttemptKey,
} from "../mfa-backup-codes";
import { DeletionResult } from "./core";
import { RETENTION_ANALYTICS_PARENTS } from "./own-account-data";
import { commentLikeRows } from "./comments-ratings";
import { COMMENT_REACTION_KEYS } from "./recipe-members-reactions";
import { SYSTEM_EVENTS, USER_MODERATION, REPORT_HISTORY } from "./moderation";
import { liveMenuBallotRows } from "./realtime";
import { TRIGGER_OWNED_SUBCOLLECTIONS } from "./user-subcollections";

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
  // BUT-2463: short links are keyed on `createdBy`.
  try {
    const snap = await db
      .collection(Collections.deepLinks)
      .where("createdBy", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.deepLinks}: ${count} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.deepLinks}`,
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
  // failed commit can leave up to 500 rows whose DOCUMENT ID is the erased uid, claim-lint:ok moved unchanged, BUT-2113
  // with the step reporting a clean erasure. This leg is the only thing that claim-lint:ok moved unchanged, BUT-2113
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
  // not see is the one the cascade never touched for two years. The claim-lint:ok moved unchanged, BUT-2113
  // `participantIds` legs are the only map-shaped residual Firestore can claim-lint:ok moved unchanged, BUT-2113
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
    // BUT-1798: shared_content membership. The scrub above is the only thing claim-lint:ok moved unchanged, BUT-2113
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
    // `details.contentOwnerId` is not redundant with the legs beside it: it is claim-lint:ok moved unchanged, BUT-2113
    // the only thing that measures whether the ANONYMIZE half ran, since a claim-lint:ok moved unchanged, BUT-2113
    // deleted row and an un-anonymized one are indistinguishable to the legs
    // beside it.
    // Both of these are skipped under a hold, and they must move TOGETHER with
    // the deleter's `legs` array — two spellings of one decision about which
    // rows survive a hold, and the day they disagree the erasure lies about
    // itself: `details.userId` carries the REPORTED
    // person's uid on the threshold alert, which a hold keeps, and claim-lint:ok moved unchanged, BUT-2113
    // `details.contentOwnerId` is the leg whose own comment calls it the only claim-lint:ok moved unchanged, BUT-2113
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
  //  2. a list still owned by the uid with NO other member left — an orphan no claim-lint:ok moved unchanged, BUT-2113
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
