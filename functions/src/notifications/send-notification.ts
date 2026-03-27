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

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { checkRateLimit } from "../middleware/rate_limiter";
import { isAllowedUrl } from "../shared/url-safety";
import {
  getActiveTokensForUser,
  deactivateStaleTokens,
  findInvalidTokens,
} from "../shared/fcm-tokens";

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
export const sendNotification = functions.https.onCall(
  async (data: NotificationRequest, context): Promise<NotificationResponse> => {
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to send notifications"
      );
    }

    const callerUid = context.auth.uid;

    // Rate limit check
    const rateLimitResult = await checkRateLimit(callerUid, "sendNotification");
    if (!rateLimitResult.allowed) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Rate limit exceeded. Please try again later."
      );
    }

    const { targetUserId, title, body, data: payload, imageUrl, silent } = data;

    // Validate required fields
    if (!targetUserId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUserId is required"
      );
    }

    if (!silent && (!title || !body)) {
      throw new functions.https.HttpsError(
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
            .collection('friend_requests')
            .where('fromUserId', '==', callerUid)
            .where('toUserId', '==', targetUserId)
            .limit(1).get(),
          admin.firestore()
            .collection('friend_requests')
            .where('fromUserId', '==', targetUserId)
            .where('toUserId', '==', callerUid)
            .limit(1).get(),
        ]);

        if (sentRequest.empty && receivedRequest.empty) {
          functions.logger.warn(
            `Unauthorized notification attempt: ${callerUid} -> ${targetUserId}`
          );
          throw new functions.https.HttpsError(
            'permission-denied',
            'Not authorized to send notifications to this user'
          );
        }
      }
    }

    try {
      // Fetch user's active FCM tokens (per-device document model)
      const { tokens, tokenDocIds } = await getActiveTokensForUser(targetUserId);

      if (tokens.length === 0) {
        functions.logger.info(
          `No active FCM tokens for user ${targetUserId}`
        );
        return {
          success: true,
          successCount: 0,
          failureCount: 0,
        };
      }

      functions.logger.info(
        `Sending notification to ${tokens.length} device(s) for user ${targetUserId}`
      );

      // Build the message
      const message: admin.messaging.MulticastMessage = {
        tokens,
        data: payload || {},
      };

      // Add notification payload for display notifications
      if (!silent) {
        message.notification = {
          title: sanitizeText(title) || "Butlery",
          body: sanitizeText(body) || "",
        };

        if (imageUrl && isAllowedUrl(imageUrl)) {
          message.notification.imageUrl = imageUrl;
        }

        // Android-specific configuration
        message.android = {
          priority: "high",
          notification: {
            channelId: "butlery_notifications",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        };

        // iOS-specific configuration
        message.apns = {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        };
      } else {
        // Silent notification configuration
        message.android = {
          priority: "high",
        };
        message.apns = {
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
          headers: {
            "apns-priority": "5",
            "apns-push-type": "background",
          },
        };
      }

      // Send to all devices
      const response = await admin.messaging().sendEachForMulticast(message);

      functions.logger.info(
        `Notification sent: ${response.successCount} success, ${response.failureCount} failures`
      );

      // Mark stale tokens as inactive in their per-device documents
      const invalidTokens = findInvalidTokens(response, tokens);
      await deactivateStaleTokens(invalidTokens, tokenDocIds, targetUserId);

      return {
        success: response.failureCount < tokens.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (error) {
      functions.logger.error(
        `Failed to send notification to user ${targetUserId}:`,
        error
      );

      throw new functions.https.HttpsError(
        "internal",
        "Failed to send notification"
      );
    }
  }
);

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
 * Sends notifications to multiple users (batch operation).
 *
 * Useful for group notifications or announcements.
 * H14: Validates each notification before processing.
 */
export const sendNotificationBatch = functions.https.onCall(
  async (
    data: { notifications: NotificationRequest[] },
    context
  ): Promise<{ results: NotificationResponse[] }> => {
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to send notifications"
      );
    }

    const callerUid = context.auth.uid;

    // Rate limit check for batch operations
    const rateLimitResult = await checkRateLimit(callerUid, "sendNotification");
    if (!rateLimitResult.allowed) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Rate limit exceeded. Please try again later."
      );
    }

    const { notifications } = data;

    if (!notifications || !Array.isArray(notifications)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "notifications array is required"
      );
    }

    // Limit batch size to prevent abuse
    if (notifications.length > 100) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Maximum 100 notifications per batch"
      );
    }

    // H14: Pre-validate all notifications before processing
    const validationErrors: { index: number; error: string }[] = [];
    notifications.forEach((notification, index) => {
      const error = validateNotification(notification);
      if (error) {
        validationErrors.push({ index, error });
      }
    });

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
              .collection('friend_requests')
              .where('fromUserId', '==', callerUid)
              .where('toUserId', '==', targetId)
              .limit(1).get(),
            admin.firestore()
              .collection('friend_requests')
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
        functions.logger.warn(
          `Unauthorized batch notification: ${callerUid} -> ${unauthorizedTargets.join(", ")}`
        );
        throw new functions.https.HttpsError(
          "permission-denied",
          `Not authorized to send notifications to ${unauthorizedTargets.length} target user(s)`
        );
      }
    }

    if (validationErrors.length > 0) {
      functions.logger.warn(
        `H14: Batch has ${validationErrors.length} invalid notifications`,
        { errors: validationErrors.slice(0, 5) } // Log first 5 errors
      );
      throw new functions.https.HttpsError(
        "invalid-argument",
        `${validationErrors.length} notifications failed validation. ` +
        `First error at index ${validationErrors[0].index}: ${validationErrors[0].error}`
      );
    }

    functions.logger.info(
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
 * Shared logic between single and batch operations.
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
    // Fetch user's active FCM tokens (per-device document model)
    const { tokens, tokenDocIds } = await getActiveTokensForUser(targetUserId);

    if (tokens.length === 0) {
      return {
        success: true,
        successCount: 0,
        failureCount: 0,
      };
    }

    const message: admin.messaging.MulticastMessage = {
      tokens,
      data: payload || {},
    };

    if (!silent) {
      message.notification = {
        title: sanitizeText(title) || "",
        body: sanitizeText(body) || "",
      };
      if (imageUrl && isAllowedUrl(imageUrl)) {
        message.notification.imageUrl = imageUrl;
      }
      message.android = {
        priority: "high",
        notification: {
          channelId: "butlery_notifications",
          priority: "high",
          defaultSound: true,
        },
      };
      message.apns = {
        payload: {
          aps: {
            sound: "default",
          },
        },
      };
    } else {
      message.android = { priority: "high" };
      message.apns = {
        payload: { aps: { contentAvailable: true } },
        headers: { "apns-priority": "5", "apns-push-type": "background" },
      };
    }

    const response = await admin.messaging().sendEachForMulticast(message);

    // Mark stale tokens as inactive in their per-device documents
    const invalidTokens = findInvalidTokens(response, tokens);
    await deactivateStaleTokens(invalidTokens, tokenDocIds, targetUserId);

    return {
      success: response.failureCount < tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    return {
      success: false,
      successCount: 0,
      failureCount: 1,
      error: String(error),
    };
  }
}
