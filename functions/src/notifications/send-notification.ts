/**
 * FCM Push Notification Cloud Function
 *
 * Sends push notifications to users via Firebase Cloud Messaging.
 * Supports both display notifications and silent data-only messages.
 *
 * Features:
 * - Fetches user FCM tokens from Firestore
 * - Handles multi-device delivery (sendEachForMulticast)
 * - Cleans up invalid tokens automatically
 * - Supports silent notifications for background sync
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { checkRateLimit, enforceRateLimit } from "../middleware/rate_limiter";
import { isAllowedUrl } from "../shared/url-safety";
import {
  getActiveTokensForUser,
  deactivateStaleTokens,
  findInvalidTokens,
} from "../shared/fcm-tokens";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { buildNotificationPayload } from "../shared/notification-payload";
import { evaluateSendGate } from "../shared/notification-gate";
import { recordNotificationSendEvent } from "../shared/notification-send-events";

/**
 * Sanitizes user-provided text by stripping HTML tags.
 *
 * Prevents potential issues with HTML content in notifications:
 * - Some devices may render HTML unexpectedly
 * - Future web notification support would be vulnerable to XSS
 * - Ensures consistent plain-text display across all platforms
 */
function sanitizeText(text: string | undefined): string | undefined {
  if (!text) return text;
  // Strip all HTML tags and decode common HTML entities
  return text
    .replace(/<[^>]*>/g, "") // Remove HTML tags
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .trim();
}

interface NotificationRequest {
  targetUserId: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  imageUrl?: string;
  silent?: boolean;
}

interface NotificationResponse {
  success: boolean;
  successCount: number;
  failureCount: number;
  error?: string;
}

/**
 * Sends a push notification to a specific user.
 *
 * Fetches all registered FCM tokens for the user and sends
 * the notification to all their devices. Invalid tokens are
 * automatically removed from the database.
 */
export const sendNotification = onCall(
  // BUT-760: user-facing callable — App Check defense-in-depth. Inert until
  // App Check flipped to Enforce in console.
  { enforceAppCheck: true },
  async (request: CallableRequest<NotificationRequest>): Promise<NotificationResponse> => {
    // Validate authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to send notifications"
      );
    }

    const callerUid = request.auth.uid;
    const data = request.data;

    // Rate limit check
    const rateLimitResult = await checkRateLimit(callerUid, "sendNotification");
    if (!rateLimitResult.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Rate limit exceeded. Please try again later."
      );
    }

    const { targetUserId, title, body, data: payload, imageUrl, silent } = data;

    // Validate required fields
    if (!targetUserId) {
      throw new HttpsError(
        "invalid-argument",
        "targetUserId is required"
      );
    }

    if (!silent && (!title || !body)) {
      throw new HttpsError(
        "invalid-argument",
        "title and body are required for display notifications"
      );
    }

    // Authorization: verify caller can send to target user
    if (callerUid !== targetUserId) {
      // Check friendship (direct document lookup — O(1))
      const friendDoc = await admin.firestore()
        .collection('users').doc(callerUid)
        .collection('friends').doc(targetUserId)
        .get();

      if (!friendDoc.exists) {
        // Check pending friend request in either direction
        const [sentRequest, receivedRequest] = await Promise.all([
          admin.firestore()
            .collection('social_requests')
            .where('fromUserId', '==', callerUid)
            .where('toUserId', '==', targetUserId)
            .limit(1).get(),
          admin.firestore()
            .collection('social_requests')
            .where('fromUserId', '==', targetUserId)
            .where('toUserId', '==', callerUid)
            .limit(1).get(),
        ]);

        if (sentRequest.empty && receivedRequest.empty) {
          logger.warn(
            `Unauthorized notification attempt: ${callerUid} -> ${targetUserId}`
          );
          throw new HttpsError(
            'permission-denied',
            'Not authorized to send notifications to this user'
          );
        }
      }
    }

    try {
      const result = await dispatchNotification({
        targetUserId,
        title,
        body,
        data: payload,
        imageUrl,
        silent,
      });
      return result;
    } catch (error) {
      // BUT-641: helper throws on missing/unknown schema fields. Surface
      // as `invalid-argument` so the client sees a useful error instead
      // of a generic `internal` (which would also trigger client retry).
      if (
        error instanceof Error &&
        error.message.startsWith("buildNotificationPayload:")
      ) {
        logger.warn(
          `Rejected notification to ${targetUserId}: ${error.message}`
        );
        throw new HttpsError("invalid-argument", error.message);
      }

      logger.error(
        `Failed to send notification to user ${targetUserId}:`,
        error
      );

      throw new HttpsError(
        "internal",
        "Failed to send notification"
      );
    }
  }
);

/**
 * Core dispatch shared by the single-call and batch paths. Gates non-silent
 * notifications through `sendPushToUserRespectingPreferences` so the master
 * toggle and Europe/Stockholm quiet hours are honored (BUT-438 bug class —
 * C3 side-finding from the 04-25 sprint).
 *
 * Silent pushes intentionally bypass the gate: they are background-sync
 * payloads (`contentAvailable: true`) that never reach the user's lock screen
 * or sound, so quiet hours don't apply, and a user who has muted visible
 * notifications still wants their data to sync.
 *
 * For non-silent pushes the helper builds a fixed payload shape (title +
 * body + data only). Optional fields the legacy direct path used —
 * `imageUrl`, iOS `badge`, Android `defaultVibrateTimings` — are dropped
 * when the helper handles delivery; that's the cost of the gate. The core
 * title/body/data still arrives.
 *
 * Exposed for testing — call sites use it via the single-call wrapper or
 * `sendNotificationInternal`.
 */
export interface DispatchOptions {
  targetUserId: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  imageUrl?: string;
  silent?: boolean;
  /**
   * Test seam: override the prefs-aware send. Production resolves to
   * `sendPushToUserRespectingPreferences` from the shared helper.
   */
  preferenceAwareSend?: typeof sendPushToUserRespectingPreferences;
  /** Test seam: override the silent-path admin send. */
  silentSend?: (
    message: admin.messaging.MulticastMessage
  ) => Promise<admin.messaging.BatchResponse>;
  /** Test seam: override the token lookup. */
  getTokens?: typeof getActiveTokensForUser;
  /**
   * Test seam: override the BUT-647/BUT-645 pre-send gate. Production
   * resolves to `evaluateSendGate` from the shared helper.
   */
  gate?: typeof evaluateSendGate;
  /** Test seam: override the send-event recorder. */
  recordEvent?: typeof recordNotificationSendEvent;
}

export async function dispatchNotification(
  opts: DispatchOptions
): Promise<NotificationResponse> {
  const {
    targetUserId,
    title,
    body,
    data: payload,
    imageUrl,
    silent,
    preferenceAwareSend = sendPushToUserRespectingPreferences,
    silentSend = (msg) => admin.messaging().sendEachForMulticast(msg),
    getTokens = getActiveTokensForUser,
    gate = evaluateSendGate,
    recordEvent = recordNotificationSendEvent,
  } = opts;

  if (silent) {
    return await dispatchSilent({
      targetUserId,
      data: payload,
      silentSend,
      getTokens,
    });
  }

  // BUT-647 + BUT-645: server-side pre-send gate. Drops if the type's RC
  // flag is off; drops or delays if the user is inside their quiet-hours
  // window. The gate handles its own analytics + scheduled-queue enqueue
  // so the dispatcher doesn't have to know about either subsystem.
  const notificationType = payload?.notificationType;
  if (notificationType) {
    const decision = await gate({
      userId: targetUserId,
      notificationType,
      payload: {
        title: sanitizeText(title) || "Butlery",
        body: sanitizeText(body) || "",
        data: sanitizeData(payload, imageUrl),
      },
    });
    if (decision.action !== "proceed") {
      return {
        success: true, // gate decisions are not failures
        successCount: 0,
        failureCount: 0,
      };
    }
  }

  // Non-silent: route through the preference-aware gate. The category param
  // is `reEngagement` because the BUT-438 contract only types that literal;
  // for callable-driven pushes (friend requests, recipe shares, etc.) the
  // category gate is N/A — the master toggle + quiet hours are the gates
  // we actually care about here. The client-side `categorySettings` map
  // governs whether the callable is invoked at all.
  const result = await preferenceAwareSend(
    targetUserId,
    {
      title: sanitizeText(title) || "Butlery",
      body: sanitizeText(body) || "",
    },
    "reEngagement",
    sanitizeData(payload, imageUrl)
  );

  if (!result.sent) {
    logger.info(
      `Notification gated for user ${targetUserId}: ${result.reason}`
    );
    return {
      success: true, // gating is not a failure
      successCount: 0,
      failureCount: 0,
    };
  }

  // BUT-645: record send-event for CTR analytics. Best-effort — failure
  // here is logged but does not propagate. Skipped if no notification type
  // (legacy callers without the BUT-641 schema field).
  if (notificationType) {
    await recordEvent({
      userId: targetUserId,
      notificationType,
      channel: "fcm",
    });
  }

  return {
    success: (result.successCount ?? 0) > 0,
    successCount: result.successCount ?? 0,
    failureCount: result.failureCount ?? 0,
  };
}

/**
 * Funnels the client-supplied `data` map through `buildNotificationPayload`
 * (BUT-641) so every push carries a consistent `{route, targetId,
 * notificationType}` triple. The client is the source of truth for these
 * three values; everything else in `data` is preserved as additional data.
 *
 * `imageUrl` is appended to the additional-data slot so the client can
 * still render rich content if the OS supports it. The notification
 * payload itself drops `imageUrl` (no rich-image FCM field) but surfacing
 * it through `data` preserves the URL for the client to handle.
 *
 * Throws via `buildNotificationPayload` if any of the schema fields are
 * missing or `route` is unknown — surfaced as `HttpsError("invalid-
 * argument", ...)` by the callable wrapper.
 */
function sanitizeData(
  data: Record<string, string> | undefined,
  imageUrl: string | undefined
): Record<string, string> {
  const incoming: Record<string, string> = { ...(data || {}) };

  // Pull schema fields out so they don't end up in `additionalData` AND
  // get re-applied by the helper (the latter would be redundant but
  // harmless). Empty `targetId` is allowed for routes that don't need
  // one, so we only require it to be present (non-undefined).
  const route = incoming.route;
  const targetId = incoming.targetId ?? "";
  const notificationType = incoming.notificationType;
  delete incoming.route;
  delete incoming.targetId;
  delete incoming.notificationType;

  if (imageUrl && isAllowedUrl(imageUrl)) {
    incoming.imageUrl = imageUrl;
  }

  return buildNotificationPayload({
    route,
    targetId,
    notificationType,
    additionalData: incoming,
  });
}

interface DispatchSilentOpts {
  targetUserId: string;
  data?: Record<string, string>;
  silentSend: (
    message: admin.messaging.MulticastMessage
  ) => Promise<admin.messaging.BatchResponse>;
  getTokens: typeof getActiveTokensForUser;
}

async function dispatchSilent(
  opts: DispatchSilentOpts
): Promise<NotificationResponse> {
  const { targetUserId, data: payload, silentSend, getTokens } = opts;

  const { tokens, tokenDocIds } = await getTokens(targetUserId);

  if (tokens.length === 0) {
    return {
      success: true,
      successCount: 0,
      failureCount: 0,
    };
  }

  // Silent pushes go through the schema funnel too (BUT-641). Even
  // background-sync payloads need a `route`/`notificationType` so the
  // client can dispatch the work and attribute it for analytics.
  const message: admin.messaging.MulticastMessage = {
    tokens,
    data: sanitizeData(payload, undefined),
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          contentAvailable: true,
        },
      },
      headers: {
        "apns-priority": "5",
        "apns-push-type": "background",
      },
    },
  };

  const response = await silentSend(message);

  const invalidTokens = findInvalidTokens(response, tokens);
  await deactivateStaleTokens(invalidTokens, tokenDocIds, targetUserId);

  return {
    success: response.failureCount < tokens.length,
    successCount: response.successCount,
    failureCount: response.failureCount,
  };
}

/**
 * H14: Validate a single notification request.
 * Returns null if valid, error message if invalid.
 */
function validateNotification(notification: NotificationRequest): string | null {
  if (!notification) {
    return "notification object is required";
  }
  if (!notification.targetUserId || typeof notification.targetUserId !== "string") {
    return "targetUserId is required and must be a string";
  }
  if (notification.targetUserId.length > 128) {
    return "targetUserId exceeds maximum length";
  }
  if (!notification.silent) {
    if (!notification.title || typeof notification.title !== "string") {
      return "title is required for display notifications";
    }
    if (!notification.body || typeof notification.body !== "string") {
      return "body is required for display notifications";
    }
    if (notification.title.length > 100) {
      return "title exceeds maximum length (100 chars)";
    }
    if (notification.body.length > 500) {
      return "body exceeds maximum length (500 chars)";
    }
  }
  if (notification.imageUrl && typeof notification.imageUrl !== "string") {
    return "imageUrl must be a string";
  }
  return null;
}

/**
 * Largest batch the callable accepts, and the unit the batch bucket is sized in.
 *
 * BUT-1692: exported so `RATE_LIMIT_CONFIGS.sendNotificationBatch.maxTokens`
 * can be pinned to it by a test. The two numbers are one decision: the batch
 * bucket is denominated in NOTIFICATIONS, so a bucket smaller than the cap
 * would deny every full-size batch outright, and a bucket larger than the cap
 * would hand out burst budget no caller can spend.
 */
export const MAX_BATCH_NOTIFICATIONS = 100;

/**
 * BUT-1664: parse and bound the batch payload, THEN charge the dedicated
 * `sendNotificationBatch` bucket one token per notification.
 *
 * Two ordering facts this encodes:
 * - The charge lands on the batch bucket scaled by size. Charging a flat token
 *   (and against the single-send bucket) let a caller push 100 notifications
 *   for the price of one, so the batch path was ~100x cheaper to abuse than
 *   sending the same pushes one at a time.
 * - Only the NON-ARRAY and oversized rejections run before the charge, so
 *   those two are rejected as `invalid-argument` without consuming the
 *   caller's budget — while the charge still lands before the per-target
 *   authorization loop, which costs a Firestore read per unique target.
 *   BUT-1692: this used to claim "a malformed ... payload", which overstated
 *   it. Per-ELEMENT malformation is NOT covered — `assertBatchValid` runs
 *   after this function returns, so a poison-pill batch (e.g. a `null`
 *   element) is charged for its full size before being rejected. That is the
 *   deliberate trade: element validation costs a pass over the array, and the
 *   caller who sent it should pay for the batch they claimed to send.
 *
 * An empty array still costs one token: a no-op spam loop must not be free.
 *
 * BUT-1692: the denial goes through `enforceRateLimit`, not a bare
 * `checkRateLimit` + hand-rolled throw. `enforceRateLimit` writes the
 * `system_events` `rate_limit_violation` audit row via
 * `logRateLimitViolation`; the old local throw skipped it, so batch abuse left
 * no trace for monitoring. The batch path is the one that mattered first
 * because its bucket is charged per NOTIFICATION, so one denied call can
 * represent up to `MAX_BATCH_NOTIFICATIONS` suppressed pushes. The single-send
 * callable above still does `checkRateLimit` + a local throw and therefore
 * still writes no audit row — a known follow-up, not a claim that this file is
 * now uniformly audited.
 *
 * Exported as a test seam (`enforce`) — production resolves to
 * `enforceRateLimit`.
 */
export async function preflightNotificationBatch(opts: {
  callerUid: string;
  notifications: unknown;
  enforce?: typeof enforceRateLimit;
}): Promise<NotificationRequest[]> {
  const { callerUid, notifications, enforce = enforceRateLimit } = opts;

  if (!Array.isArray(notifications)) {
    throw new HttpsError(
      "invalid-argument",
      "notifications array is required"
    );
  }

  if (notifications.length > MAX_BATCH_NOTIFICATIONS) {
    throw new HttpsError(
      "invalid-argument",
      `Maximum ${MAX_BATCH_NOTIFICATIONS} notifications per batch`
    );
  }

  await enforce(
    callerUid,
    "sendNotificationBatch",
    Math.max(1, notifications.length)
  );

  return notifications as NotificationRequest[];
}

/**
 * H14: reject a batch containing ANY invalid notification.
 *
 * Called immediately after the preflight and BEFORE the per-target
 * authorization loop. That ordering is load-bearing in two ways:
 * - `preflightNotificationBatch` casts the payload without checking element
 *   shape, so an element like `null` would reach `n.targetUserId` and throw a
 *   raw TypeError. The callable surfaces that as `internal`, and `internal`
 *   triggers a CLIENT RETRY (see the BUT-641 note above) — a poison-pill batch
 *   would loop, re-charging the rate-limit bucket and re-crashing every time,
 *   instead of failing terminally as `invalid-argument`.
 * - The authorization loop costs up to three Firestore reads per unique
 *   target (100 targets ≈ 300 reads). A batch already known to be invalid
 *   must never pay for it.
 *
 * Exported as a test seam.
 */
export function assertBatchValid(notifications: unknown[]): void {
  const validationErrors: { index: number; error: string }[] = [];
  notifications.forEach((notification, index) => {
    const error = validateNotification(notification as NotificationRequest);
    if (error) {
      validationErrors.push({ index, error });
    }
  });

  if (validationErrors.length === 0) return;

  logger.warn(
    `H14: Batch has ${validationErrors.length} invalid notifications`,
    { errors: validationErrors.slice(0, 5) } // Log first 5 errors
  );
  throw new HttpsError(
    "invalid-argument",
    `${validationErrors.length} notifications failed validation. ` +
    `First error at index ${validationErrors[0].index}: ${validationErrors[0].error}`
  );
}

/**
 * Sends notifications to multiple users (batch operation).
 *
 * Useful for group notifications or announcements.
 * H14: Validates each notification before processing.
 */
export const sendNotificationBatch = onCall(
  // BUT-760: user-facing callable — App Check defense-in-depth. Inert until
  // App Check flipped to Enforce in console.
  { enforceAppCheck: true },
  async (
    request: CallableRequest<{ notifications: NotificationRequest[] }>
  ): Promise<{ results: NotificationResponse[] }> => {
    // Validate authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to send notifications"
      );
    }

    const callerUid = request.auth.uid;

    // BUT-1664: validate + size-bound the payload, then charge the dedicated
    // batch bucket by notification count. Runs before the authorization loop
    // below, which costs a Firestore read per unique target.
    const notifications = await preflightNotificationBatch({
      callerUid,
      notifications: request.data?.notifications,
    });

    // H14: every element is validated and REJECTED here, before anything
    // below dereferences it or spends a Firestore read on it.
    assertBatchValid(notifications);

    // Authorization: verify caller can send to all target users
    const uniqueTargets = [...new Set(
      notifications.map((n) => n.targetUserId).filter((id) => id !== callerUid)
    )];

    if (uniqueTargets.length > 0) {
      // Check friendship + friend requests for each unique target
      const unauthorizedTargets: string[] = [];

      for (const targetId of uniqueTargets) {
        // Check friendship (direct document lookup — O(1))
        const friendDoc = await admin.firestore()
          .collection('users').doc(callerUid)
          .collection('friends').doc(targetId)
          .get();

        if (!friendDoc.exists) {
          // Check pending friend request in either direction
          const [sentRequest, receivedRequest] = await Promise.all([
            admin.firestore()
              .collection('social_requests')
              .where('fromUserId', '==', callerUid)
              .where('toUserId', '==', targetId)
              .limit(1).get(),
            admin.firestore()
              .collection('social_requests')
              .where('fromUserId', '==', targetId)
              .where('toUserId', '==', callerUid)
              .limit(1).get(),
          ]);

          if (sentRequest.empty && receivedRequest.empty) {
            unauthorizedTargets.push(targetId);
          }
        }
      }

      if (unauthorizedTargets.length > 0) {
        logger.warn(
          `Unauthorized batch notification: ${callerUid} -> ${unauthorizedTargets.join(", ")}`
        );
        throw new HttpsError(
          "permission-denied",
          `Not authorized to send notifications to ${unauthorizedTargets.length} target user(s)`
        );
      }
    }

    logger.info(
      `Processing batch of ${notifications.length} notifications`
    );

    // Process notifications in parallel with some concurrency control
    const results: NotificationResponse[] = [];
    const batchSize = 10;

    for (let i = 0; i < notifications.length; i += batchSize) {
      const batch = notifications.slice(i, i + batchSize);
      const batchResults = await Promise.all(
        batch.map(async (notification) => {
          try {
            // Recursively call the single notification logic
            const result = await sendNotificationInternal(notification);
            return result;
          } catch (error) {
            return {
              success: false,
              successCount: 0,
              failureCount: 1,
              error: String(error),
            };
          }
        })
      );
      results.push(...batchResults);
    }

    return { results };
  }
);

/**
 * Internal helper for sending a single notification.
 * Shared logic between single and batch operations. Routes through
 * `dispatchNotification` so the same preference + quiet-hours gates apply
 * as in the single-call path.
 */
async function sendNotificationInternal(
  data: NotificationRequest
): Promise<NotificationResponse> {
  const { targetUserId, title, body, data: payload, imageUrl, silent } = data;

  if (!targetUserId) {
    return {
      success: false,
      successCount: 0,
      failureCount: 0,
      error: "targetUserId is required",
    };
  }

  try {
    return await dispatchNotification({
      targetUserId,
      title,
      body,
      data: payload,
      imageUrl,
      silent,
    });
  } catch (error) {
    return {
      success: false,
      successCount: 0,
      failureCount: 1,
      error: String(error),
    };
  }
}
