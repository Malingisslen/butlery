import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";
// P6-U09: the two-step-verification collections. Imported rather than
// retyped so the cascade and the writer cannot disagree about a name or about
// the shape of the per-account counter key.
import {
  BACKUP_CODES_COLLECTION,
  RECOVERY_ATTEMPTS_COLLECTION,
  uidAttemptKey,
} from "../mfa-backup-codes";
import { batchDeleteAll } from "./core";

/**
 * P6-U09: the account's two-step-verification recovery data.
 *
 * - `mfa_backup_codes/{uid}` holds the salted scrypt hashes of the user's ten
 *   backup codes and when the set was created. Keyed by the raw uid and kept
 *   until two-step verification is switched off, so without this step it
 *   outlives the account for good.
 * - `mfa_recovery_attempts/uid_{uid}` is the per-account wrong-code counter.
 *   It carries `expiresAt` for the TTL policy, but it is keyed by the raw uid,
 *   so it is personal data for as long as it stands and goes with the account
 *   rather than waiting for the sweep.
 *
 * The OTHER rows in `mfa_recovery_attempts` are deliberately not touched:
 * `ip_<HMAC(pepper, ip)>` and the single `global` counter. Nothing in them
 * names an account, the key cannot be reversed without the server-only
 * pepper, and there is no field or key this step could select them by. Their
 * retention bound is the TTL on `expiresAt` (one hour window, one hour
 * lockout at most). Registered with that reason in
 * `COLLECTIONS_DELIBERATELY_UNTOUCHED` (admin/reset-collection-lists.ts).
 *
 * Both are single documents at known ids, so this is two deletes; deleting a
 * missing document is a no-op, which keeps the step idempotent. Both ship with
 * an existence leg in `probeResidualData`.
 */
export async function deleteMfaRecoveryData(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection(BACKUP_CODES_COLLECTION).doc(uid).delete();
  await db
    .collection(RECOVERY_ATTEMPTS_COLLECTION)
    .doc(uidAttemptKey(uid))
    .delete();
  return true;
}

/**
 * BUT-920: a guest's AI-import count, `guest_quotas/{uid}`. Keyed by the raw
 * uid and written only by the import callables, so nothing else removes it.
 * An account upgraded from a guest keeps the same uid and the document until
 * this step runs. Deleting a missing document is a no-op, so the step is
 * idempotent; its existence leg is in `probeResidualData`.
 */
export async function deleteGuestQuota(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection(Collections.guestQuotas).doc(uid).delete();
  return true;
}

/**
 * Hard ceiling for [deleteHouseholdAllergenShares]. The document id is
 * `{householdId}_{userId}`, so a user holds at most one share per household;
 * above this the sweep declines.
 *
 * Exported so its scenario can import it rather than retype the number.
 */
export const MAX_HOUSEHOLD_SHARE_SWEEP_ROWS = 50;

/**
 * BUT-1693: a member's own allergen list shared with their household
 * (`household_allergen_shares`, Art. 9 data under explicit consent).
 *
 * Found by the flat `userId` field, never through the user's current
 * household: the id format lets one user hold shares under several household
 * ids. Declines above [MAX_HOUSEHOLD_SHARE_SWEEP_ROWS] rather than truncating,
 * like [deleteIngredientSuggestions].
 */
export async function deleteHouseholdAllergenShares(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("household_allergen_shares")
    .where("userId", "==", uid)
    .limit(MAX_HOUSEHOLD_SHARE_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_HOUSEHOLD_SHARE_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible household allergen share count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * BUT-1789: the per-user-per-day feature-retention rows written by
 * `analytics/compute-feature-retention.ts`.
 *
 * `analytics/feature_retention/users/{uid}_{yyyy-mm-dd}` is one document PER
 * ACTIVE DAY, carrying the uid in the id, in a `userId` field, and a behavioural
 * profile of that person's day (did they cook, import, share, meal-plan, shop).
 * Nothing deleted them: no cascade step, no TTL, and no accepted-deviation entry
 * saying that was on purpose — so an account erased under Article 17 left a
 * dated row for every day it was ever active, indefinitely.
 *
 * A TTL is NOT the alternative here, and the reason is worth stating so it is
 * not "simplified" into one later: these rows live in the SUBCOLLECTION
 * `analytics/feature_retention/users`, whose collectionGroup id is `users` —
 * the same id as the top-level profile collection. A TTL fieldOverride on
 * collectionGroup `users` would arm a delete policy over real user documents.
 *
 * The filter is the writer's own `userId` field rather than a documentId prefix
 * range: the writer sets it on every row (`batch.set({ userId, date, ...})`),
 * and a single-field equality needs no composite index. The id-prefix form
 * would work too but depends on the `{uid}_{date}` id convention holding
 * forever, which is a weaker handle than the field the writer is contractually
 * writing.
 *
 * The `daily/{date}` aggregates are deliberately NOT touched — integer counts,
 * no uid, no re-derivation on erasure. That residual is the accepted deviation
 * recorded for BUT-1789.
 */
export async function deleteFeatureRetentionFlags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("analytics")
    .doc("feature_retention")
    .collection("users")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * The `analytics/{parent}/events` collections this cascade sweeps. ONE list:
 * the deleter and `probeResidualData`'s matching leg both read it, and a probe
 * that ranges over fewer parents than its deleter certifies a bad erasure clean.
 */
export const RETENTION_ANALYTICS_PARENTS = ["retention", "lapsed_users"] as const;

/**
 * BUT-1800: uid-bearing analytics rows under `analytics/retention` and
 * `analytics/lapsed_users`, which BUT-1789 left behind.
 *
 * `analytics/retention/events/{uid}_dN` (`analytics/track-retention.ts`) and
 * `analytics/lapsed_users/events/{uid}_{type}_{lastActiveAt ms}` (`analytics/detect-lapsed-users.ts`)
 * both carry the uid in a `userId` field, so Art. 17 reaches them exactly as it
 * reached the feature-retention rows.
 *
 * Shaped on `deleteFeatureRetentionFlags`.
 *
 * The filter is the writer's own `userId` field on both. A single-field
 * equality needs no composite index.
 *
 * Neither parent has an aggregate sibling to preserve.
 *
 * The per-parent catch below covers the QUERY only. `batchDeleteAll` commits
 * non-strict, so a failed chunk is still swallowed and this function can return
 * true with rows left behind — which is why the matching leg in
 * `probeResidualData` is the load-bearing half, not this one.
 */
export async function deleteRetentionAnalytics(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const failed: string[] = [];
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    // Per-parent, for the reason the probe leg states: sharing one catch lets a
    // failure on the first parent skip the second, and the caller cannot tell
    // "swept both" from "threw before reaching the second".
    try {
      const snap = await db
        .collection("analytics")
        .doc(parent)
        .collection("events")
        .where("userId", "==", uid)
        .get();
      await batchDeleteAll(db, snap.docs);
    } catch (err) {
      failed.push(parent);
      logger.error("[deletion-cascade] analytics sweep failed", {
        uid_prefix: uid.slice(0, 6),
        parent,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  if (failed.length > 0) {
    throw new Error(`analytics erasure incomplete: ${failed.join(", ")}`);
  }
  return true;
}

/**
 * BUT-1956: `analytics/notifications/effectiveness/{notificationId}`, written
 * daily by `analytics/correlate-notifications.ts` with a RAW `userId` in the
 * document. Nothing erased it and nothing expires it.
 *
 * Why nothing reached it. It is a subcollection under a FIXED `analytics/`
 * document, which makes it structurally invisible to both loops in
 * `probeResidualData` — one walks top-level collections, the other walks
 * `users/{uid}/...`. The two neighbouring sweeps look like they should cover it
 * and do not: `deleteNotificationAnalytics` sweeps the TOP-LEVEL collections
 * with a `notification_` prefix, and `cleanupNotificationQueuesWithDb` covers
 * three other top-level ones.
 *
 * Same shape as `deleteRetentionAnalytics`, but its own function rather than a
 * `RETENTION_ANALYTICS_PARENTS` entry: that loop is hardcoded to an `events`
 * child collection, and this one is `effectiveness`.
 *
 * A single-field equality needs no composite index, so `firestore.indexes.json`
 * is deliberately untouched — an unnecessary `--force` index deploy has already
 * destroyed live TTL policies in this project once.
 *
 * The sibling `analytics/notifications/summary/{date}` is a uid-free daily
 * aggregate and is deliberately NOT touched: Art. 17 does not reach it, and
 * nothing recomputes it from these rows, so erasing a departed user here
 * changes no stored rate.
 *
 * As with `deleteRetentionAnalytics`, the load-bearing half is the matching leg
 * in `probeResidualData`, not this function: `batchDeleteAll` commits
 * non-strict, so a failed chunk is swallowed and this can return true with rows
 * left behind.
 */
export async function deleteNotificationEffectiveness(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("analytics")
    .doc("notifications")
    .collection("effectiveness")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

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
      db.collection("notification_engagement").where("userId", "==", uid).get(),
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
