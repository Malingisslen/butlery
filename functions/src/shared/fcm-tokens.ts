/**
 * Shared FCM Token Utilities
 *
 * Queries active FCM tokens for a user from the per-device document model.
 * The Flutter client stores tokens as individual documents in `user_fcm_tokens`
 * with document IDs formatted as `{userId}_{deviceId}`, each containing:
 *   - userId: string
 *   - token: string
 *   - isActive: boolean
 *   - platform: string
 *   - lastUpdated: Timestamp
 *
 * Also handles stale token cleanup after FCM delivery failures.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export interface TokenQueryResult {
  tokens: string[];
  /** Map from token string to its Firestore document ID, for targeted cleanup */
  tokenDocIds: Map<string, string>;
}

/**
 * Fetches all active FCM tokens for a user by querying the per-device
 * document collection. Returns both the token strings and a mapping
 * to document IDs so stale tokens can be deactivated individually.
 */
export async function getActiveTokensForUser(
  targetUserId: string
): Promise<TokenQueryResult> {
  const tokensSnapshot = await admin
    .firestore()
    .collection("user_fcm_tokens")
    .where("userId", "==", targetUserId)
    .where("isActive", "==", true)
    .get();

  const tokens: string[] = [];
  const tokenDocIds = new Map<string, string>();

  for (const doc of tokensSnapshot.docs) {
    const token = doc.data().token as string | undefined;
    if (token) {
      tokens.push(token);
      tokenDocIds.set(token, doc.id);
    }
  }

  return { tokens, tokenDocIds };
}

/**
 * Marks stale/invalid FCM tokens as inactive in Firestore.
 * Called after sendEachForMulticast reports delivery failures
 * with token-specific error codes.
 */
export async function deactivateStaleTokens(
  invalidTokens: string[],
  tokenDocIds: Map<string, string>,
  targetUserId: string
): Promise<void> {
  if (invalidTokens.length === 0) return;

  logger.info(
    `Deactivating ${invalidTokens.length} stale token(s) for user ${targetUserId}`
  );

  const db = admin.firestore();
  const batch = db.batch();

  for (const token of invalidTokens) {
    const docId = tokenDocIds.get(token);
    if (docId) {
      batch.update(db.collection("user_fcm_tokens").doc(docId), {
        isActive: false,
        deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        deactivationReason: "fcm_delivery_failure",
      });
    }
  }

  try {
    await batch.commit();
  } catch (error) {
    // Don't fail the notification if token cleanup fails
    logger.warn(
      `Failed to deactivate stale tokens for ${targetUserId}: ${error}`
    );
  }
}

/**
 * Identifies invalid tokens from an FCM multicast response.
 * Returns tokens that should be deactivated.
 */
/**
 * Sends a push notification to all active devices for a user.
 * Handles token lookup, message construction, delivery, and stale token cleanup.
 */
export async function sendPushToUser(
  userId: string,
  notification: { title: string; body: string },
  data?: Record<string, string>
): Promise<{ successCount: number; failureCount: number }> {
  const { tokens, tokenDocIds } = await getActiveTokensForUser(userId);
  if (tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification,
    data: data || {},
    android: {
      priority: "high",
      notification: {
        channelId: "butlery_notifications",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: { aps: { sound: "default" } },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  const invalidTokens = findInvalidTokens(response, tokens);
  await deactivateStaleTokens(invalidTokens, tokenDocIds, userId);
  return { successCount: response.successCount, failureCount: response.failureCount };
}

/**
 * Identifies invalid tokens from an FCM multicast response.
 * Returns tokens that should be deactivated.
 */
export function findInvalidTokens(
  response: admin.messaging.BatchResponse,
  tokens: string[]
): string[] {
  const invalidTokens: string[] = [];

  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      const error = resp.error;
      if (
        error?.code === "messaging/invalid-registration-token" ||
        error?.code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(tokens[idx]);
      }
      logger.warn(
        `Failed to send to token ${idx}: ${error?.message}`
      );
    }
  });

  return invalidTokens;
}
