/**
 * BUT-2414: the requester's own account rows that erasure deletes and no
 * other export section reads.
 *
 * Each section's query is the predicate of the cascade step named beside it.
 */

import * as admin from "firebase-admin";
import { Collections } from "../../shared/collections";
import { RETENTION_ANALYTICS_PARENTS } from "../../account/account-deletion-cascade";
import {
  RECOVERY_ATTEMPTS_COLLECTION,
  uidAttemptKey,
} from "../../account/mfa-recovery-attempts";
import {
  Allowlist,
  FileLister,
  Row,
  cappedDocs,
  project,
  scalars,
  sortRows,
} from "./project";

/** One section: its response key and its reader. */
export interface SectionDef {
  name: string;
  read: (
    database: admin.firestore.Firestore,
    uid: string,
    bucket: () => FileLister,
  ) => Promise<Row[]>;
}

/** The row cap a section declines above unless it names its own. */
export const MAX_SECTION_ROWS = 2000;

/** `TagOverrideLogEntry.toFirestore` (`lib/models/tagging/tag_override_log_entry.dart`). */
export const TAG_OVERRIDE_KEYS: Allowlist = {
  ...scalars("id", "userId", "recipeId", "type", "tag", "direction", "timestamp"),
  triggeringIngredients: "strings",
};

/** `ParsingCorrection.toFirestore` (`lib/models/parsing/parsing_correction.dart`) and the three correction models it nests. */
export const PARSING_CORRECTION_KEYS: Allowlist = {
  ...scalars(
    "id", "recipeId", "userId", "timestamp", "source", "domain",
    "successfulTier", "originalQuality", "totalCorrections",
  ),
  titleCorrection: { map: scalars("original", "corrected") },
  portionsCorrection: { map: scalars("original", "corrected") },
  timeCorrection: { map: scalars("original", "corrected") },
  ingredientCorrections: {
    list: scalars(
      "type", "originalIndex", "correctedIndex", "originalLine",
      "originalQuantity", "originalUnit", "originalName", "correctedLine",
      "correctedName", "quantityChanged", "unitChanged", "nameChanged",
    ),
  },
  instructionCorrections: {
    list: scalars(
      "type", "originalIndex", "correctedIndex", "originalText", "correctedText",
    ),
  },
};

/** What `consumeGuestCall` and `refundGuestCall` write (`llm/guest-import-quota.ts`). */
export const GUEST_QUOTA_KEYS: Allowlist = {
  importIds: "strings",
  imports: { mapOf: scalars("open", "day", "spent") },
  ...scalars("calls", "updatedAt"),
};

/** The per-user row `computeFeatureRetention` writes. */
export const FEATURE_RETENTION_KEYS: Allowlist = scalars(
  "userId",
  "date",
  "cooked",
  "imported",
  "shared",
  "mealPlanned",
  "shopped",
);

/** `analytics/retention/events` rows (`analytics/track-retention.ts`). */
export const RETENTION_EVENT_KEYS: Allowlist = scalars(
  "userId",
  "day",
  "timestamp",
  "wasActive",
  "lifecycleStage",
);

/** `analytics/lapsed_users/events` rows (`analytics/lapsed-users-page.ts`). */
export const LAPSED_EVENT_KEYS: Allowlist = scalars(
  "userId",
  "daysInactive",
  "detectedAt",
  "notificationSent",
  "variant",
  "contextKey",
);

/** The scheduler's writes (`account/account-deletion-schedule.ts`). */
export const DELETION_REQUEST_KEYS: Allowlist = scalars(
  "requestedAt",
  "scheduledFor",
  "reason",
  "attempts",
  "processingStartedAt",
);

/** `reserveAttempt` (`account/mfa-recovery-attempts.ts`). */
export const RECOVERY_ATTEMPT_KEYS: Allowlist = scalars(
  "failures",
  "windowStart",
  "lockedUntil",
  "expiresAt",
);

/** `enqueueScheduledNotification`; `payload.data` is not exported. */
export const SCHEDULED_NOTIFICATION_KEYS: Allowlist = {
  ...scalars(
    "notificationType",
    "deliverAt",
    "status",
    "createdAt",
    "attempts",
    "expireAt",
  ),
  payload: { map: scalars("title", "body") },
};

/** `recordNotificationSendEvent` (`shared/notification-send-events.ts`). */
export const SEND_EVENT_KEYS: Allowlist = scalars(
  "notificationType",
  "sentAt",
  "channel",
  "expireAt",
);

/** `recordNotificationOpened` (`notifications/record-notification-opened.ts`). */
export const OPENED_EVENT_KEYS: Allowlist = scalars(
  "notificationId",
  "notificationType",
  "route",
  "openedAt",
  "expireAt",
);

/** `notification-rate-cap.ts`, one document per day. */
export const NOTIFICATION_COUNTER_KEYS: Allowlist = scalars(
  "count",
  "criticalCount",
  "lastUpdated",
);

/** `social/duplicate-content-guard.ts`, one document per surface. */
export const CONTENT_HASH_KEYS: Allowlist = {
  hashes: { list: scalars("hash", "at") },
};

/**
 * `createShortUrl` (`firebase_deeplink_repository.dart`) with the `metadata`
 * map `_generateInternalShortUrl` passes it; the id is the short code.
 */
export const DEEP_LINK_KEYS: Allowlist = {
  ...scalars("longUrl", "createdAt"),
  metadata: { map: scalars("isActive", "expiresAt") },
};

function rowsWithId(
  docs: admin.firestore.QueryDocumentSnapshot[],
  keys: Allowlist,
  idKey = "id",
): Row[] {
  return sortRows(
    docs.map((doc) => ({ [idKey]: doc.id, ...project(doc.data(), keys) })),
    idKey,
  );
}

async function oneDoc(
  ref: admin.firestore.DocumentReference,
  keys: Allowlist,
): Promise<Row[]> {
  const snap = await ref.get();
  const data = snap.data();
  return snap.exists && data !== undefined ? [project(data, keys)] : [];
}

/**
 * The section for each `analytics/{parent}/events` leg of
 * `deleteRetentionAnalytics`. A parent added to the cascade without a section
 * here does not compile.
 */
export const RETENTION_SECTION_OF: Readonly<
  Record<(typeof RETENTION_ANALYTICS_PARENTS)[number], string>
> = {
  retention: "retention_events",
  lapsed_users: "lapsed_user_events",
};

async function eventRows(
  events: admin.firestore.CollectionReference,
  uid: string,
  keys: Allowlist,
): Promise<Row[]> {
  return rowsWithId(
    await cappedDocs(events.where("userId", "==", uid), MAX_SECTION_ROWS, events.path),
    keys,
  );
}

/** A top-level collection read on `userId == uid`. */
function byUserId(collection: string, keys: Allowlist): SectionDef["read"] {
  return async (database, uid) =>
    rowsWithId(
      await cappedDocs(
        database.collection(collection).where("userId", "==", uid),
        MAX_SECTION_ROWS,
        collection,
      ),
      keys,
    );
}

/** A `users/{uid}/{name}` subcollection, read whole. */
function ownSubcollection(name: string, keys: Allowlist): SectionDef["read"] {
  return async (database, uid) =>
    rowsWithId(
      await cappedDocs(
        database.collection(Collections.users).doc(uid).collection(name),
        MAX_SECTION_ROWS,
        name,
      ),
      keys,
    );
}

export const ACCOUNT_SECTIONS: readonly SectionDef[] = [
  // deleteTagOverridesLog
  { name: "tag_overrides_log", read: byUserId("tag_overrides_log", TAG_OVERRIDE_KEYS) },
  // deleteParsingCorrections
  { name: "parsing_corrections", read: byUserId("parsing_corrections", PARSING_CORRECTION_KEYS) },
  {
    // deleteGuestQuota
    name: "guest_quota",
    read: (database, uid) =>
      oneDoc(database.collection(Collections.guestQuotas).doc(uid), GUEST_QUOTA_KEYS),
  },
  {
    // deleteFeatureRetentionFlags
    name: "feature_retention_rows",
    read: async (database, uid) =>
      rowsWithId(
        await cappedDocs(
          database
            .collection("analytics")
            .doc("feature_retention")
            .collection("users")
            .where("userId", "==", uid),
          MAX_SECTION_ROWS,
          "feature_retention_rows",
        ),
        FEATURE_RETENTION_KEYS,
      ),
  },
  // deleteRetentionAnalytics, one section per parent it sweeps
  {
    name: RETENTION_SECTION_OF.retention,
    read: (database, uid) =>
      eventRows(
        database.collection("analytics").doc("retention").collection("events"),
        uid,
        RETENTION_EVENT_KEYS,
      ),
  },
  {
    name: RETENTION_SECTION_OF.lapsed_users,
    read: (database, uid) =>
      eventRows(
        database.collection("analytics").doc("lapsed_users").collection("events"),
        uid,
        LAPSED_EVENT_KEYS,
      ),
  },
  {
    // deleteAccountDeletionRequest
    name: "account_deletion_request",
    read: (database, uid) =>
      oneDoc(
        database.collection(Collections.accountDeletionRequests).doc(uid),
        DELETION_REQUEST_KEYS,
      ),
  },
  {
    // deleteMfaRecoveryData, the attempts leg
    name: "mfa_recovery_attempts",
    read: (database, uid) =>
      oneDoc(
        database.collection(RECOVERY_ATTEMPTS_COLLECTION).doc(uidAttemptKey(uid)),
        RECOVERY_ATTEMPT_KEYS,
      ),
  },
  // onUserDeleted's cleanupNotificationQueuesWithDb, one section per collection
  {
    name: "scheduled_notifications",
    read: byUserId("scheduled_notifications", SCHEDULED_NOTIFICATION_KEYS),
  },
  { name: "notification_send_events", read: byUserId("notification_send_events", SEND_EVENT_KEYS) },
  {
    name: "notification_opened_events",
    read: byUserId("notification_opened_events", OPENED_EVENT_KEYS),
  },
  {
    // deleteDeepLinks
    name: "deep_links",
    read: async (database, uid) =>
      rowsWithId(
        await cappedDocs(
          database.collection(Collections.deepLinks).where("createdBy", "==", uid),
          MAX_SECTION_ROWS,
          Collections.deepLinks,
        ),
        DEEP_LINK_KEYS,
      ),
  },
  // onUserDeleted's per-user subcollection purge
  {
    name: "notification_counters",
    read: ownSubcollection("notificationCounters", NOTIFICATION_COUNTER_KEYS),
  },
  {
    name: "recent_content_hashes",
    read: ownSubcollection("recentContentHashes", CONTENT_HASH_KEYS),
  },
];
