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
 * with merge — all safe to re-run if the caller retries after a partial
 * failure. The post-cascade probe (`probeResidualData`) confirms the
 * highest-risk collections are empty after the run.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../shared/batch-update";

// Mirrors lib/core/extensions/iterable_extensions.dart:18.
// Firestore allows 500 ops/batch; 450 leaves audit/cleanup headroom.
const BATCH_CHUNK = 450;

export interface DeletionResult {
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
}

export type Step = () => Promise<boolean>;

/**
 * Run one cascade step, recording its outcome on `result`. Never throws —
 * a step exception is logged and rolled into `failedCollections`.
 */
export async function runStep(
  name: string,
  result: DeletionResult,
  step: Step,
): Promise<void> {
  try {
    const ok = await step();
    if (ok) {
      result.deletedCollections.push(name);
    } else {
      result.failedCollections.push(name);
    }
  } catch (err) {
    result.failedCollections.push(name);
    result.errors.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    logger.error(`[deletion-cascade] step ${name} failed`, { err });
  }
}

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
  const probes = ["recipes", "user_notifications", "user_fcm_tokens"] as const;
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
  if (residual > 0 && !result.failedCollections.includes("residual_data_detected")) {
    result.failedCollections.push("residual_data_detected");
  }
}

/** Batch-delete every doc, chunked at 450 ops/batch. */
async function batchDeleteAll(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  await commitInChunks(
    db,
    docs,
    (batch, doc) => batch.delete(doc.ref),
    { label: "batchDeleteAll", strict: false },
  );
}

// ─── Tier 1: own content ──────────────────────────────────────────────────

export async function deleteRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [sub, top] = await Promise.all([
    db.collection("users").doc(uid).collection("recipes").get(),
    db.collection("recipes").where("userId", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [...sub.docs, ...top.docs]);
  return true;
}

export async function deleteMenus(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Subcollection menus under users/{uid}
  const sub = await db.collection("users").doc(uid).collection("menus").get();
  await batchDeleteAll(db, sub.docs);

  // BUT-746: top-level shared menus owned by uid.
  const owned = await db
    .collection("menus")
    .where("sharedByUserId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // BUT-747: scrub uid from sharedToUserIds on inbound menus.
  const inbound = await db
    .collection("menus")
    .where("sharedToUserIds", "array-contains", uid)
    .get();
  if (inbound.docs.length > 0) {
    await commitInChunks(
      db,
      inbound.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        });
      },
      { label: "scrubInboundMenus", strict: false },
    );
  }
  return true;
}

export async function deleteShoppingLists(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const sub = await db
    .collection("users")
    .doc(uid)
    .collection("shopping_lists")
    .get();
  await batchDeleteAll(db, sub.docs);

  // Scrub assignedToUserId/purchasedByUserId across collaborative lists.
  const shared = await db
    .collection("unified_shared_shopping_lists")
    .where(`memberPermissions.${uid}`, "!=", null)
    .get();
  for (const listDoc of shared.docs) {
    const data = listDoc.data();
    const items = data.items;
    if (!Array.isArray(items)) continue;
    let changed = false;
    const scrubbed = items.map((raw) => {
      if (!raw || typeof raw !== "object") return raw;
      const item = { ...(raw as Record<string, unknown>) };
      if (item.assignedToUserId === uid) {
        item.assignedToUserId = null;
        item.assignedToDisplayName = null;
        item.assignedAt = null;
        changed = true;
      }
      if (item.purchasedByUserId === uid) {
        item.purchasedByUserId = null;
        item.purchasedByDisplayName = null;
        item.purchasedAt = null;
        changed = true;
      }
      return item;
    });
    if (changed) {
      await listDoc.ref.update({ items: scrubbed });
    }
  }
  return true;
}

export async function deletePersonalTags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tags")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deletePersonalTagGroups(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tag_groups")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteCookSnaps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("cook_snaps")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteActivityEvents(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("activity_events")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteWeeklyMenuPlans(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const owned = await db
    .collection("weekly_menu_plans")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // Scrub uid from group plans. If a plan ends up empty, delete it.
  const groupPlans = await db
    .collection("group_weekly_menu_plans")
    .where("participantUserIds", "array-contains", uid)
    .get();
  if (groupPlans.docs.length > 0) {
    await commitInChunks(
      db,
      groupPlans.docs,
      (batch, doc) => {
        const data = doc.data();
        const participantsRaw = data.participants;
        const participants = Array.isArray(participantsRaw)
          ? participantsRaw
              .filter((m) => m && typeof m === "object")
              .map((m) => ({ ...(m as Record<string, unknown>) }))
              .filter((m) => m.userId !== uid)
          : [];
        const userIdsRaw = data.participantUserIds;
        const userIds = Array.isArray(userIdsRaw)
          ? (userIdsRaw as unknown[]).filter((id) => id !== uid)
          : [];
        if (userIds.length === 0) {
          batch.delete(doc.ref);
        } else {
          batch.update(doc.ref, {
            participants,
            participantUserIds: userIds,
            [`memberPermissions.${uid}`]: admin.firestore.FieldValue.delete(),
          });
        }
      },
      { label: "scrubGroupWeeklyMenuPlans", strict: false },
    );
  }
  return true;
}

export async function deletePantryItems(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("pantry")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// ─── Tier 1: social-self (own writes on cross-user surfaces) ─────────────

export async function deleteMessages(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const convos = await db
    .collection("conversations")
    .where("participantIds", "array-contains", uid)
    .get();

  // Bounded parallelism: 10 conversations / wave. Mirrors prior client behavior.
  const chunkSize = 10;
  for (let i = 0; i < convos.docs.length; i += chunkSize) {
    const chunk = convos.docs.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (convoDoc) => {
        const messages = await convoDoc.ref.collection("messages").get();
        await batchDeleteAll(db, messages.docs);
        const participants = Array.isArray(convoDoc.data().participantIds)
          ? (convoDoc.data().participantIds as string[])
          : [];
        if (participants.length <= 2) {
          await convoDoc.ref.delete();
        } else {
          await convoDoc.ref.update({
            participantIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      }),
    );
  }
  return true;
}

export async function removeFromSharedContent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [members, engagements] = await Promise.all([
    db.collectionGroup("members").where("userId", "==", uid).get(),
    db.collectionGroup("engagements").where("userId", "==", uid).get(),
  ]);

  // Scrub sharedToUserIds on each parent shared_content doc.
  if (members.docs.length > 0) {
    await commitInChunks(
      db,
      members.docs,
      (batch, doc) => {
        const parentRef = doc.ref.parent.parent;
        if (parentRef) {
          batch.update(parentRef, {
            sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      },
      { label: "scrubSharedToUserIds", strict: false },
    );
  }
  await batchDeleteAll(db, members.docs);
  await batchDeleteAll(db, engagements.docs);

  // Delete shared_content owned by uid (members subcollection first).
  const owned = await db
    .collection("shared_content")
    .where("sharedByUserId", "==", uid)
    .get();
  for (const doc of owned.docs) {
    const childMembers = await doc.ref.collection("members").get();
    await batchDeleteAll(db, childMembers.docs);
  }
  await batchDeleteAll(db, owned.docs);
  return true;
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

export async function deleteUserReports(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("reports")
    .where("reporterId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// ─── Tier 1: profile-side own data ───────────────────────────────────────

export async function deleteFcmTokens(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("user_fcm_tokens")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteNotificationPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Doc id is the user id per FirebaseNotificationsRepository convention.
  await db.collection("user_notification_preferences").doc(uid).delete();
  return true;
}

export async function deleteNotifications(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("user_notifications")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteNotificationAnalytics(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [history, batches, engagement, deliverySender, deliveryTarget] =
    await Promise.all([
      db.collection("notification_history").where("userId", "==", uid).get(),
      db.collection("notification_batches").where("userId", "==", uid).get(),
      db
        .collection("notification_engagement")
        .where("userId", "==", uid)
        .get(),
      db.collection("notification_delivery").where("senderId", "==", uid).get(),
      db
        .collection("notification_delivery")
        .where("targetUserId", "==", uid)
        .get(),
    ]);
  await batchDeleteAll(db, [
    ...history.docs,
    ...batches.docs,
    ...engagement.docs,
    ...deliverySender.docs,
    ...deliveryTarget.docs,
  ]);
  return true;
}

export async function deleteRealtimeRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("realtime_recipes")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// ─── Tier 2: user subcollections ─────────────────────────────────────────

export async function deleteUserPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db
    .collection("users")
    .doc(uid)
    .collection("settings")
    .doc("preferences")
    .delete();
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

export async function deleteUserSubcollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const userDoc = db.collection("users").doc(uid);
  // `notificationCounters` + `recentContentHashes` are intentionally NOT
  // included — `onUserDeleted` (cleanupContentGuardSubcollections) owns
  // those and runs automatically after `admin.auth().deleteUser(uid)`.
  const subs = [
    "conversation_memberships",
    "rate_limits",
    "user_shared_menus",
    "user_shared_shopping_lists",
    "friend_categories",
    "friends",
    "category_preferences",
    "list_category_orders",
    "report_throttle",
  ];
  for (const name of subs) {
    const snap = await userDoc.collection(name).get();
    await batchDeleteAll(db, snap.docs);
  }
  return true;
}

// ─── Tier 3: user root doc ───────────────────────────────────────────────

export async function deleteUserProfile(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection("users").doc(uid).delete();
  return true;
}

// `BATCH_CHUNK` referenced for parity with prior chunk-size documentation.
void BATCH_CHUNK;
