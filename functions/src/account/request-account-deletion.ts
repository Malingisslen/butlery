/**
 * BUT-788: server-side account deletion.
 *
 * Replaces the prior client-driven cascade that ran in
 * `lib/services/account/account_deletion_service.dart`. Eliminates the
 * auth-context-race: client called `firebaseAuth.user.delete()` directly,
 * which invalidated the session before the Firestore cascade could
 * complete — risking orphaned Firestore data the client could no longer
 * touch, or audit-log rows with the wrong actor.
 *
 * **New flow**
 *
 *   1. Client (`AccountDeletionService.deleteUserAccount`) signs the user
 *      in fresh, then calls this callable.
 *   2. Callable validates `auth_time < 5 min` (re-auth requirement).
 *   3. Cascade module (`account-deletion-cascade.ts`) deletes the user's
 *      own-data across ~25 Firestore collections, run as Admin SDK.
 *   4. Storage prefix `users/{uid}/` is wiped.
 *   5. `admin.auth().deleteUser(uid)` runs LAST. This fires the existing
 *      `onUserDeleted` v1 auth trigger which handles cross-user cleanup
 *      (reverse friendships, group memberships, friend counts, presence
 *      rows, notification queues, content tombstones, report anonymization,
 *      etc.). The two surface areas compose: this CF owns own-data; the
 *      trigger owns cross-user-data.
 *   6. Audit-log entry written to `deletion_audit_logs` with a 180-day TTL
 *      via `expireAt` (matches `cleanupOldAuditLogs` retention).
 *
 * **Re-auth check**: the callable rejects with `failed-precondition` +
 * `requires-recent-login` code if the ID token's `auth_time` is older
 * than 5 minutes. Client surfaces this to the deletion confirmation UI
 * to trigger a re-authentication prompt.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  DeletionResult,
  runStep,
  probeResidualData,
  deleteRecipes,
  deleteMenus,
  deleteShoppingLists,
  deletePersonalTags,
  deletePersonalTagGroups,
  deleteTagOverridesLog,
  deleteCookSnaps,
  deleteActivityEvents,
  deleteFeatureRetentionFlags,
  deleteRetentionAnalytics,
  deleteNotificationEffectiveness,
  deleteWeeklyMenuPlans,
  deletePantryItems,
  deleteFamilyData,
  deleteMessages,
  deleteChatGroupMemberships,
  removeFromSharedContent,
  deleteCommentsAndRatings,
  deletePingsByUser,
  deleteUserReports,
  deleteFcmTokens,
  deleteNotificationPreferences,
  deleteNotifications,
  deleteNotificationAnalytics,
  deleteRealtimeRecipes,
  deleteRealtimeMenus,
  deleteUserPreferences,
  deleteConsentRecords,
  deleteUserSubcollections,
  deleteUserProfile,
} from "./account-deletion-cascade";

const db = admin.firestore();

/** Re-auth window: ID token `auth_time` must be within this many seconds. */
const REAUTH_MAX_AGE_SECONDS = 5 * 60;

/** GDPR Art. 5(1)(e) — aligns with `cleanup-audit-logs.ts` expireAt TTL. */
const AUDIT_LOG_RETENTION_DAYS = 180;

export interface RequestAccountDeletionRequest {
  /** Free-text reason supplied by the user; surfaces in the audit log. */
  reason?: string;
}

export interface RequestAccountDeletionResponse {
  success: boolean;
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
  auditLogId: string | null;
}

/**
 * Hash an email with SHA-256 for audit storage. Mirrors the prior client
 * implementation (`CryptoUtils.sha256Hash`) so audit-log readers don't
 * need a schema change.
 */
async function sha256Hash(input: string): Promise<string> {
  const { createHash } = await import("crypto");
  return createHash("sha256").update(input).digest("hex");
}

export const requestAccountDeletion = onCall<RequestAccountDeletionRequest>(
  {
    memory: "512MiB",
    timeoutSeconds: 540,
    // CORS allowlist mirrors exportAuditLogs (BUT-770) — same app origins.
    cors: ["https://butlery.app", "https://www.butlery.app"],
    // BUT-760: user-facing account callable — App Check defense-in-depth.
    // Inert until App Check flipped to Enforce in console.
    enforceAppCheck: true,
  },
  async (request): Promise<RequestAccountDeletionResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    // Re-auth gate: token must be < 5 min old. The `auth_time` claim is a
    // unix-seconds timestamp set when the user last authenticated. A stale
    // session token means the user could have walked away from the device;
    // we don't permanently delete data without a fresh credential.
    const authTimeSec = request.auth.token.auth_time;
    if (typeof authTimeSec !== "number") {
      throw new HttpsError(
        "unauthenticated",
        "Missing auth_time claim — re-authenticate.",
      );
    }
    const nowSec = Math.floor(Date.now() / 1000);
    const ageSec = nowSec - authTimeSec;
    if (ageSec > REAUTH_MAX_AGE_SECONDS) {
      throw new HttpsError(
        "failed-precondition",
        "Recent sign-in required (re-authenticate within last 5 minutes).",
        { code: "requires-recent-login" },
      );
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email ?? "unknown";
    const reason =
      typeof request.data?.reason === "string" && request.data.reason.length > 0
        ? request.data.reason
        : "user_request";

    return runAccountDeletion(uid, email, reason);
  },
);

/** Production entry point — wraps the cascade with the live Firestore. */
export async function runAccountDeletion(
  uid: string,
  email: string,
  reason: string,
): Promise<RequestAccountDeletionResponse> {
  return runAccountDeletionWithDeps(
    {
      db,
      auth: admin.auth(),
      storage: admin.storage(),
    },
    uid,
    email,
    reason,
  );
}

/** Dependency-injected core — exposed for tests. */
export interface DeletionDeps {
  db: admin.firestore.Firestore;
  auth: admin.auth.Auth;
  storage: admin.storage.Storage;
}

export async function runAccountDeletionWithDeps(
  deps: DeletionDeps,
  uid: string,
  email: string,
  reason: string,
): Promise<RequestAccountDeletionResponse> {
  const { db: database, auth, storage } = deps;
  logger.info("[requestAccountDeletion] starting", { uid_prefix: uid.slice(0, 6) });

  const result: DeletionResult = {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
  };

  // Tier 1 (parallel): own content + own writes on cross-user surfaces.
  const tier1: Array<[string, () => Promise<boolean>]> = [
    ["recipes", () => deleteRecipes(database, uid)],
    ["menus", () => deleteMenus(database, uid)],
    ["shopping_lists", () => deleteShoppingLists(database, uid)],
    ["personal_tags", () => deletePersonalTags(database, uid)],
    ["personal_tag_groups", () => deletePersonalTagGroups(database, uid)],
    ["tag_overrides_log", () => deleteTagOverridesLog(database, uid)],
    ["cook_snaps", () => deleteCookSnaps(database, uid)],
    ["activity_events", () => deleteActivityEvents(database, uid)],
    // BUT-1789: one behavioural row per active day, kept forever until now.
    ["feature_retention", () => deleteFeatureRetentionFlags(database, uid)],
    // BUT-1800: `analytics/retention/events` and `analytics/lapsed_users/events`.
    ["retention_analytics", () => deleteRetentionAnalytics(database, uid)],
    ["weekly_menu_plans", () => deleteWeeklyMenuPlans(database, uid)],
    ["pantry_items", () => deletePantryItems(database, uid)],
    ["family_data", () => deleteFamilyData(database, uid)],
    // BUT-1838: chat-group membership. MUST exist alongside `messages`, which
    // deliberately skips any conversation carrying a `groupId` — this leg owns
    // both halves of a group membership so the two copies cannot disagree.
    ["chat_groups", () => deleteChatGroupMemberships(database, uid)],
    ["messages", () => deleteMessages(database, uid)],
    ["shared_content", () => removeFromSharedContent(database, uid)],
    ["comments_ratings", () => deleteCommentsAndRatings(database, uid)],
    ["pings", () => deletePingsByUser(database, uid)],
    ["reports", () => deleteUserReports(database, uid)],
    ["fcm_tokens", () => deleteFcmTokens(database, uid)],
    [
      "notification_preferences",
      () => deleteNotificationPreferences(database, uid),
    ],
    ["notifications", () => deleteNotifications(database, uid)],
    ["notification_analytics", () => deleteNotificationAnalytics(database, uid)],
    // BUT-1956: `analytics/notifications/effectiveness`. NOT covered by the
    // line above — that one sweeps TOP-LEVEL `notification_*` collections,
    // and this is a subcollection under a fixed `analytics/` document.
    [
      "notification_effectiveness",
      () => deleteNotificationEffectiveness(database, uid),
    ],
    ["realtime_recipes", () => deleteRealtimeRecipes(database, uid)],
    // BUT-1768: `realtime_menus` had no tier entry at all — the sibling
    // collection was cascaded, this one survived every erasure.
    ["realtime_menus", () => deleteRealtimeMenus(database, uid)],
    ["storage_files", () => deleteUserStorageFiles(storage, uid)],
  ];
  await Promise.all(tier1.map(([name, fn]) => runStep(name, result, fn)));

  // Tier 2 (parallel after T1): subcollections under users/{uid}.
  const tier2: Array<[string, () => Promise<boolean>]> = [
    ["preferences", () => deleteUserPreferences(database, uid)],
    ["consent_records", () => deleteConsentRecords(database, uid)],
    ["user_subcollections", () => deleteUserSubcollections(database, uid)],
  ];
  await Promise.all(tier2.map(([name, fn]) => runStep(name, result, fn)));

  // Tier 3: the user root doc itself. Sequential to T2 — subcollections
  // first, root last, so a partial T2 failure doesn't leave the root doc
  // orphaned with subcoll data.
  await runStep("profile", result, () => deleteUserProfile(database, uid));

  // Probe — check residual data BEFORE auth delete so the audit log
  // reflects the cascade outcome (auth-delete failure is recorded separately).
  await probeResidualData(database, uid, result);

  // Final step: auth deletion. This fires `onUserDeleted` which owns
  // cross-user cleanup (friendships, friend counts, social_requests,
  // public_profile, presence rows, notification queues, legacy sharedWith
  // arrays, content guard subcollections, sharedBy tombstone, report
  // anonymization). The trigger runs out-of-band and may complete after
  // this callable returns — that's intentional, the callable doesn't
  // block on cross-user cleanup.
  let authDeleted = true;
  try {
    await auth.deleteUser(uid);
  } catch (err) {
    authDeleted = false;
    result.failedCollections.push("auth_deletion");
    result.errors.push(
      `auth_deletion: ${err instanceof Error ? err.message : String(err)}`,
    );
    logger.error("[requestAccountDeletion] auth.deleteUser failed", { err });
  }

  // Audit log — written under deletion_audit_logs (distinct from generic
  // audit_logs) preserving the schema readable by GDPR-export tooling.
  let auditLogId: string | null = null;
  try {
    auditLogId = await writeDeletionAuditLog(database, uid, email, reason, result);
  } catch (err) {
    logger.error("[requestAccountDeletion] audit-log write failed", { err });
    result.errors.push(
      `audit_log: ${err instanceof Error ? err.message : String(err)}`,
    );
  }

  const success = authDeleted && result.failedCollections.length === 0;
  logger.info("[requestAccountDeletion] completed", {
    uid_prefix: uid.slice(0, 6),
    success,
    deletedCount: result.deletedCollections.length,
    failedCount: result.failedCollections.length,
  });

  return {
    success,
    deletedCollections: result.deletedCollections,
    failedCollections: result.failedCollections,
    errors: result.errors,
    auditLogId,
  };
}

/**
 * Delete the user's Storage prefix. Best-effort: a Storage failure is
 * recorded but doesn't abort the cascade. The bucket may have many files
 * (recipe photos, cook-snap images) — `deleteFiles` does the recursive
 * walk for us.
 */
export async function deleteUserStorageFiles(
  storage: admin.storage.Storage,
  uid: string,
): Promise<boolean> {
  try {
    await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
    return true;
  } catch (err) {
    logger.error("[requestAccountDeletion] storage delete failed", { err });
    return false;
  }
}

/**
 * Write the deletion-audit row. Same schema as the prior client-side
 * `_createDeletionAuditLog` so any GDPR-export dashboards reading
 * `deletion_audit_logs` continue to work.
 */
async function writeDeletionAuditLog(
  database: admin.firestore.Firestore,
  uid: string,
  email: string,
  reason: string,
  result: DeletionResult,
): Promise<string> {
  const emailHash = await sha256Hash(email);
  const expireAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + AUDIT_LOG_RETENTION_DAYS * 24 * 60 * 60 * 1000),
  );
  const docRef = await database.collection("deletion_audit_logs").add({
    userId: uid,
    emailHash,
    reason,
    deletedCollections: result.deletedCollections,
    failedCollections: result.failedCollections,
    deletionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    expireAt,
    gdprCompliant: result.failedCollections.length === 0,
  });
  return docRef.id;
}
