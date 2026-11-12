import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
import { hashUid } from "../../shared/hash-uid";
import { RUN_UID_HASH_FIELD } from "./ingredient-change-requests";
import { APPELLANT_ID, MODERATION_APPEALS } from "../../moderation/appeals";
import { REPORTS } from "../../moderation/report-status";
import { SYSTEM_EVENTS } from "./moderation";

export async function probeNotificationDelivery(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
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
  return residual;
}

export async function probeOwnerKeyedDocs(
  db: admin.firestore.Firestore,
  uid: string,
  held: boolean,
): Promise<number> {
  let residual = 0;
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
    // `scrubIngredientChangeRequestAuthors`, both fields it nulls.
    [Collections.ingredientChangeRequests, "createdBy", "=="],
    [Collections.ingredientChangeRequests, "withdrawnBy", "=="],
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
  return residual;
}

export async function probeIngredientChangeRuns(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // `scrubIngredientChangeRequestAuthors`' run-record leg, which holds the
  // uid's HASH, so it cannot ride the uid-valued loop above.
  try {
    const snap = await db
      .collection(Collections.ingredientChangeRuns)
      .where(RUN_UID_HASH_FIELD, "==", hashUid(uid))
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual owner-keyed docs", {
        uid_prefix: uid.slice(0, 6),
        collection: Collections.ingredientChangeRuns,
        field: RUN_UID_HASH_FIELD,
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed", {
      uid_prefix: uid.slice(0, 6),
      collection: Collections.ingredientChangeRuns,
      field: RUN_UID_HASH_FIELD,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
