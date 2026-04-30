/**
 * Record a notification-tap event server-side (security-review C1 fix).
 *
 * Without this, `notification_opened_events` is never written, and
 * `suppressLowPerformers` computes CTR = 0 / N for every type — auto-
 * disabling the entire notification surface within one week.
 *
 * Why a callable (server-write) and not a direct client write to
 * Firestore: keeps the Firestore-rules surface narrow. Adding a new
 * client-writable collection means a new ruleset (owner-create-only,
 * immutable, schema-validated). A callable does the auth + dedup +
 * schema-validation in TypeScript and writes server-side under
 * existing admin privileges.
 *
 * Dedup contract: a single `(userId, notificationId)` pair counts as
 * one open. Idempotent — multiple taps of the same notification do
 * NOT inflate CTR. Implementation: deterministic doc id =
 * `<userId>_<notificationId>` so a second `set()` is a no-op overwrite.
 *
 * Schema written to `notification_opened_events/<dedupId>`:
 *   {
 *     userId: string,
 *     notificationId: string,        // client-supplied; usually FCM message id
 *     notificationType: string,      // analytics tag (e.g. "comment_posted")
 *     route: string?,                // route the open dispatched (BUT-641)
 *     openedAt: Timestamp,           // server-stamped
 *     expireAt: Timestamp,           // openedAt + 30d for TTL parity
 *   }
 *
 * 30-day TTL parallel to `notification_send_events`. GDPR cascade lives
 * in `on-user-deleted.ts`.
 *
 * **Manual setup required (one-shot, per environment)**: this module
 * guarantees `expireAt` is written, but the policy that actually deletes
 * expired docs has to be enabled separately:
 *   `gcloud firestore fields ttls update expireAt \
 *      --collection-group=notification_opened_events --enable-ttl`
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const TTL_DAYS = 30;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

export interface RecordNotificationOpenedRequest {
  notificationId: string;
  notificationType: string;
  route?: string;
}

export interface RecordNotificationOpenedResponse {
  success: boolean;
  /** Whether this call wrote a new doc (false on dedup). */
  recorded: boolean;
}

/**
 * Internal core — exported so the test suite can exercise the logic
 * without spinning up a callable harness.
 */
export interface RecordOpenedDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

export async function runRecordNotificationOpened(
  userId: string,
  req: RecordNotificationOpenedRequest,
  deps: RecordOpenedDeps = {}
): Promise<RecordNotificationOpenedResponse> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? new Date();

  // Validate. Payloads come from clients on bad networks — be strict.
  if (typeof req.notificationId !== "string" || !req.notificationId) {
    throw new Error("notificationId is required");
  }
  if (typeof req.notificationType !== "string" || !req.notificationType) {
    throw new Error("notificationType is required");
  }
  if (req.notificationId.length > 256 || req.notificationType.length > 64) {
    throw new Error("field exceeds maximum length");
  }
  if (req.route !== undefined) {
    if (typeof req.route !== "string") {
      throw new Error("route must be a string when provided");
    }
    if (req.route.length > 256) {
      throw new Error("route field exceeds maximum length");
    }
  }

  // Deterministic doc id = `<userId>_<notificationId>`. A second tap
  // for the same notification overwrites itself — CTR is not inflated.
  // Sanitize because `notificationId` may contain `/` (slashes are
  // illegal in doc ids).
  const sanitizedNotificationId = req.notificationId.replace(/[/]/g, "_");
  const dedupId = `${userId}_${sanitizedNotificationId}`;
  const ref = db.collection("notification_opened_events").doc(dedupId);

  const expireAt = new Date(now.getTime() + TTL_DAYS * MS_PER_DAY);

  // Check existence first to drive the `recorded` flag honestly. We
  // could just `set()` blindly, but the caller (and analytics) benefits
  // from knowing whether this was a first-tap or a duplicate.
  const existing = await ref.get();
  if (existing.exists) {
    return { success: true, recorded: false };
  }

  await ref.set({
    userId,
    notificationId: req.notificationId,
    notificationType: req.notificationType,
    route: req.route ?? null,
    openedAt: admin.firestore.Timestamp.fromDate(now),
    expireAt: admin.firestore.Timestamp.fromDate(expireAt),
  });

  return { success: true, recorded: true };
}

export const recordNotificationOpened = onCall(
  async (
    request: CallableRequest<RecordNotificationOpenedRequest>
  ): Promise<RecordNotificationOpenedResponse> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to record a notification open"
      );
    }
    const userId = request.auth.uid;
    try {
      return await runRecordNotificationOpened(userId, request.data);
    } catch (err) {
      if (err instanceof Error) {
        // Validation errors are programmer/client bugs — surface as
        // invalid-argument, not internal (no retry will help).
        if (
          err.message.includes("required") ||
          err.message.includes("maximum length") ||
          err.message.includes("must be a string")
        ) {
          logger.warn("recordNotificationOpened: validation failed", {
            userId,
            err: err.message,
          });
          throw new HttpsError("invalid-argument", err.message);
        }
      }
      logger.error("recordNotificationOpened: write failed", { userId, err });
      throw new HttpsError("internal", "Failed to record notification open");
    }
  }
);
