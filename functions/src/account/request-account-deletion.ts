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
  deleteIngredientSuggestions,
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
  deleteModerationSystemEvents,
  deleteModerationRecord,
  deleteReportHistoryByReporter,
  deleteBlocks,
  deleteBlockMirrors,
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
  USER_MODERATION,
} from "./account-deletion-cascade";
import { applyErasureHold } from "../moderation/erasure-hold";

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
  /**
   * BUT-2046 follow-up: records lawfully KEPT under Art. 17(3), so the client
   * can give the person the Art. 12(4) notice before it logs them out.
   *
   * This list is a hand-written allowlist and the timestamp does not survive
   * the callable boundary as a `Timestamp`, so `holdUntil` is sent as an ISO
   * string. Adding a field to `DeletionResult` does NOT put it here — that gap
   * is the whole reason this field is written down rather than assumed.
   */
  retained: Array<{
    resourceType: string;
    legalBasis: string;
    holdUntil: string;
    provisional: boolean;
  }>;
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
    retained: [],
  };

  // BUT-2046 follow-up: evaluate the legal hold BEFORE tier 1, because steps
  // inside it, the residual probe, and the `onUserDeleted` trigger afterwards
  // all need the answer — and an answer computed twice at two times is two
  // answers. It is EVALUATED once here and READ everywhere else; the daily
  // sweep recomputes only whether the case is still open, never the scope.
  //
  // A failure here is a failure of the erasure, not a silent "no hold":
  // `applyErasureHold` reports one through `ok`, which `runStep` records in
  // `failedCollections` exactly as it records a throw. Falling through to
  // `retained: []` would erase evidence the law says to keep, quietly.
  // NOT a collection name: `deletedCollections` is the ops-readable record of
  // what an erasure removed, and this step removes nothing — under a hold it
  // WRITES. A collection-shaped name there would put two answers about one
  // document in the same audit row, beside `retained` saying it was kept.
  await runStep("erasure_hold_evaluated", result, async () => {
    const outcome = await applyErasureHold(database, uid);
    // Assigned BEFORE the failure is reported: `ok: false` means the erasure is
    // incomplete, but `retained` is still the authoritative answer, and losing
    // it would let the steps below destroy what the hold decided to keep.
    result.retained = outcome.retained;
    return outcome.ok;
  });
  // Scoped to the resource rather than to `retained` being non-empty — see the
  // note on `held` in `probeResidualData`, which must agree with this line.
  const held = result.retained.some(
    (r) => r.resourceType === USER_MODERATION,
  );

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
    // BUT-2028: uid-keyed rows no erasure path reached. Ships with its probe
    // leg; may find zero rows until a client first writes one.
    [
      "ingredient_suggestions",
      () => deleteIngredientSuggestions(database, uid),
    ],
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
    // BUT-1917: the top-level `blocks` collection, both directions. No step
    // reached it before and no probe leg named it, so the gap was silent
    // rather than reported. Both now ship together, per the rule stated on
    // `probeResidualData`'s own list: a deleter without a probe is how an
    // erasure becomes silently incomplete.
    ["blocks", () => deleteBlocks(database, uid)],
    ["reports", () => deleteUserReports(database, uid)],
    // BUT-2032: the moderation rows the report trigger writes into the admin
    // ops log. Beside `reports` because it is the same event seen from the
    // other side, and in the CASCADE rather than in `onUserDeleted` because the
    // residual probe runs before `auth.deleteUser` and the trigger after it.
    [
      "moderation_system_events",
      () => deleteModerationSystemEvents(database, uid, held),
    ],
    // BUT-2046: the strike record keyed on this uid, and the report rows
    // beneath it. The REPORTER half is a cross-user sweep and runs after tier 1.
    //
    // Under a hold the whole step is skipped and reported DONE, not failed —
    // the record is the evidence being kept, and `sweepErasureHolds` runs this
    // exact function once the hold lifts.
    // Under a hold the step is not registered at all, rather than registered
    // as a no-op success: pushing "user_moderation" into `deletedCollections`
    // would claim the record was deleted on the same audit row where
    // `retained` says it was kept.
    ...(held
      ? []
      : ([
          ["user_moderation", () => deleteModerationRecord(database, uid)],
        ] as Array<[string, () => Promise<boolean>]>)),
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

  // BUT-1917: the erased uid inside OTHER people's block mirrors. AFTER tier 1
  // rather than inside it, and that ordering is the whole point: `deleteBlocks`
  // runs in tier 1, an Admin-SDK delete fires `syncBlockMirror` exactly like a
  // client delete, and a rebuild that read `blocks` before those deletes
  // committed can land afterwards and put the uid straight back. Running beside
  // it made which write landed last a coin flip; running after makes this the
  // last word for everything tier 1 removed.
  //
  // It does not close the race — a trigger can still land after THIS step, and
  // nothing here can stop that. What closes it is the weekly reconciliation
  // (`runReconcileBlockMirrors`), which is why that pass is wired into the
  // maintenance chain rather than left as an unexported function.
  await runStep("block_mirrors", result, () =>
    deleteBlockMirrors(database, uid),
  );

  // BUT-2046: the erased uid as a REPORTER, on rows under OTHER people's
  // moderation records. After tier 1 for the same reason as the block mirrors
  // above — `onReportCreated` can write such a row while the cascade runs, so
  // this being last makes it the final word on everything tier 1 removed. It
  // does not close that race; nothing here can, and the rows carry a 180-day
  // TTL for exactly that reason.
  await runStep("report_history_as_reporter", result, () =>
    deleteReportHistoryByReporter(database, uid),
  );

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
    retained: result.retained.map((r) => ({
      resourceType: r.resourceType,
      legalBasis: r.legalBasis,
      holdUntil: r.holdUntil.toDate().toISOString(),
      provisional: r.provisional,
    })),
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
    // Unchanged, and deliberately so: `gdprCompliant` is driven by
    // `failedCollections` ALONE. A lawful hold is recorded beside it, never
    // inside it — an Art. 17(3) exception is a compliant outcome, and folding
    // it into this flag would report a correct erasure as a broken one with
    // nothing able to clear the record.
    gdprCompliant: result.failedCollections.length === 0,
    retained: result.retained.map((r) => ({
      resourceType: r.resourceType,
      legalBasis: r.legalBasis,
      holdUntil: r.holdUntil,
      // The ops row should be able to tell a decided hold from an undecidable
      // one; `erasure_holds/{uid}` and the `cascade_retain` row both record it,
      // and a reader who has only this row should not have to go looking.
      //
      // This is the SECOND hand-written projection of `RetainedRecord`, and the
      // warning on the response allowlist is as true here: a field added to
      // that type reaches the client through one of these and the operator
      // through the other, and neither by itself.
      provisional: r.provisional,
    })),
  });
  return docRef.id;
}
