/**
 * Server-Side Rate Limiting Middleware for Cloud Functions
 *
 * Validates rate limits before processing requests to prevent abuse.
 * Works with existing client-side rate limit records in Firestore.
 *
 * Features:
 * - Token bucket algorithm validation
 * - Reads from /users/{userId}/rateLimits/{operation}
 * - Returns HTTP 429 with Retry-After header when exceeded
 * - Graceful fallback on errors (allows request but logs)
 *
 * Usage:
 * ```typescript
 * export const myFunction = onCall(
 *   { ...options },
 *   withRateLimit('operationName', async (request) => {
 *     // handler logic
 *   })
 * );
 * ```
 */

import * as admin from "firebase-admin";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";

// =============================================================================
// Types
// =============================================================================

export interface RateLimitConfig {
  /** Maximum tokens in bucket */
  maxTokens: number;
  /** Tokens refilled per interval */
  refillRate: number;
  /** Refill interval in milliseconds */
  refillIntervalMs: number;
}

export interface RateLimitCheckResult {
  allowed: boolean;
  remainingTokens: number;
  retryAfterMs?: number;
  reason?: string;
}

interface StoredRateLimit {
  tokens: number;
  lastRefill: admin.firestore.Timestamp;
  operationType: string;
  updatedAt: admin.firestore.Timestamp;
}

// =============================================================================
// Rate Limit Configurations (Mirror client-side)
// =============================================================================

/**
 * Rate limit configurations per operation type.
 * These mirror the client-side configurations for consistency.
 */
const RATE_LIMIT_CONFIGS: Record<string, RateLimitConfig> = {
  // LLM Operations (expensive - strict limits)
  structureRecipe: {
    maxTokens: 10,
    refillRate: 3,
    refillIntervalMs: 60000, // 1 minute
  },
  ocrRecipeImage: {
    maxTokens: 5,
    refillRate: 2,
    refillIntervalMs: 60000,
  },

  // Notification Operations
  sendNotification: {
    maxTokens: 60,
    refillRate: 30,
    refillIntervalMs: 60000,
  },
  sendNotificationBatch: {
    maxTokens: 10,
    refillRate: 5,
    refillIntervalMs: 60000,
  },

  // Import Operations
  importRecipe: {
    maxTokens: 10,
    refillRate: 3,
    refillIntervalMs: 60000,
  },

  // Analytics/Logging Operations (moderate limits)
  logParseEvent: {
    maxTokens: 30,
    refillRate: 10,
    refillIntervalMs: 60000,
  },

  // Default for unspecified operations
  default: {
    maxTokens: 30,
    refillRate: 10,
    refillIntervalMs: 60000,
  },
};

// =============================================================================
// Rate Limit Functions
// =============================================================================

/**
 * Get rate limit configuration for an operation.
 */
function getConfig(operationType: string): RateLimitConfig {
  return RATE_LIMIT_CONFIGS[operationType] || RATE_LIMIT_CONFIGS["default"];
}

/**
 * Get Firestore reference for rate limit document.
 * Stored under system_rate_limits/ (not user subcollection) so clients cannot
 * reset their own limits by deleting documents.
 */
function getRateLimitRef(
  userId: string,
  operationType: string
): admin.firestore.DocumentReference {
  return admin
    .firestore()
    .collection("system_rate_limits")
    .doc(`${userId}_${operationType}`);
}

/**
 * Calculate current available tokens based on time elapsed.
 */
function calculateCurrentTokens(
  storedTokens: number,
  lastRefill: Date,
  config: RateLimitConfig
): number {
  const now = Date.now();
  const elapsed = now - lastRefill.getTime();
  const intervalsElapsed = Math.floor(elapsed / config.refillIntervalMs);
  const tokensToAdd = intervalsElapsed * config.refillRate;

  return Math.min(config.maxTokens, storedTokens + tokensToAdd);
}

/**
 * Check if a rate limit allows the request.
 *
 * @param userId - User making the request
 * @param operationType - Type of operation (e.g., 'structureRecipe')
 * @param tokensRequired - Number of tokens to consume (default: 1)
 * @returns RateLimitCheckResult with allowed status and details
 */
export async function checkRateLimit(
  userId: string,
  operationType: string,
  tokensRequired: number = 1
): Promise<RateLimitCheckResult> {
  const config = getConfig(operationType);
  const docRef = getRateLimitRef(userId, operationType);

  try {
    // Use transaction for atomic read-update
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      const now = new Date();

      let currentTokens: number;
      let lastRefill: Date;

      if (doc.exists) {
        const data = doc.data() as StoredRateLimit;
        lastRefill = data.lastRefill.toDate();
        currentTokens = calculateCurrentTokens(data.tokens, lastRefill, config);
      } else {
        // First request - start with full bucket
        currentTokens = config.maxTokens;
        lastRefill = now;
      }

      // Check if enough tokens available
      if (currentTokens < tokensRequired) {
        // Calculate when tokens will be available
        const tokensNeeded = tokensRequired - currentTokens;
        const intervalsNeeded = Math.ceil(tokensNeeded / config.refillRate);
        const retryAfterMs = intervalsNeeded * config.refillIntervalMs;

        return {
          allowed: false,
          remainingTokens: currentTokens,
          retryAfterMs,
          reason: `Rate limit exceeded for ${operationType}. Try again in ${Math.ceil(retryAfterMs / 1000)} seconds.`,
        };
      }

      // Consume tokens and update Firestore
      const newTokens = currentTokens - tokensRequired;
      const updateData: Partial<StoredRateLimit> = {
        tokens: newTokens,
        lastRefill: admin.firestore.Timestamp.fromDate(now),
        operationType,
        updatedAt: admin.firestore.Timestamp.now(),
      };

      if (doc.exists) {
        transaction.update(docRef, updateData);
      } else {
        transaction.set(docRef, updateData);
      }

      return {
        allowed: true,
        remainingTokens: newTokens,
      };
    });

    return result;
  } catch (error) {
    // Fail closed — deny on Firestore errors to prevent abuse
    functions.logger.error(
      `Rate limit check failed for ${operationType}, denying request:`,
      error
    );

    return {
      allowed: false,
      remainingTokens: 0,
      retryAfterMs: 30000,
      reason: "Rate limit check unavailable. Please try again shortly.",
    };
  }
}

/**
 * Log rate limit violation for monitoring.
 */
async function logRateLimitViolation(
  userId: string,
  operationType: string,
  result: RateLimitCheckResult
): Promise<void> {
  try {
    await admin.firestore().collection("system_events").add({
      type: "rate_limit_violation",
      userId,
      operationType,
      remainingTokens: result.remainingTokens,
      retryAfterMs: result.retryAfterMs,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // Don't fail the request if logging fails
    functions.logger.warn("Failed to log rate limit violation:", error);
  }
}

// =============================================================================
// Global Aggregate Limits
// =============================================================================

/** Global limits: 1000 calls/hour, 10000 calls/day */
const GLOBAL_HOURLY_LIMIT = 1000;
const GLOBAL_DAILY_LIMIT = 10000;

/**
 * Check global aggregate LLM call limits.
 * Uses Firestore atomic increments on system/llmLimits document.
 *
 * @returns true if within limits, false if exceeded
 */
export async function checkGlobalLimit(): Promise<boolean> {
  const limitsRef = admin.firestore().doc("system/llmLimits");

  try {
    const result = await admin.firestore().runTransaction(async (tx) => {
      const doc = await tx.get(limitsRef);
      const now = new Date();
      const currentHour = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}-${now.getUTCHours()}`;
      const currentDay = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

      const data = doc.exists ? doc.data()! : {};

      // Reset counters if period changed
      const hourlyCount = data.hourKey === currentHour ? (data.hourlyCount ?? 0) : 0;
      const dailyCount = data.dayKey === currentDay ? (data.dailyCount ?? 0) : 0;

      if (hourlyCount >= GLOBAL_HOURLY_LIMIT || dailyCount >= GLOBAL_DAILY_LIMIT) {
        return false;
      }

      tx.set(limitsRef, {
        hourKey: currentHour,
        hourlyCount: hourlyCount + 1,
        dayKey: currentDay,
        dailyCount: dailyCount + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return true;
    });

    return result;
  } catch (error) {
    // Fail closed on error — deny request to prevent abuse bypass
    functions.logger.error("Global limit check failed, denying request:", error);
    return false;
  }
}

// =============================================================================
// Middleware Wrapper
// =============================================================================

/**
 * Higher-order function that wraps a callable handler with rate limiting.
 *
 * @param operationType - Type of operation for rate limiting
 * @param handler - The original request handler
 * @param tokensRequired - Number of tokens to consume per request (default: 1)
 * @returns Wrapped handler that enforces rate limits
 *
 * @example
 * ```typescript
 * export const structureRecipe = onCall<StructureRecipeRequest>(
 *   { secrets: [...], memory: "512MiB" },
 *   withRateLimit('structureRecipe', async (request) => {
 *     // Original handler logic
 *   })
 * );
 * ```
 */
export function withRateLimit<TRequest, TResponse>(
  operationType: string,
  handler: (request: CallableRequest<TRequest>) => Promise<TResponse>,
  tokensRequired: number = 1
): (request: CallableRequest<TRequest>) => Promise<TResponse> {
  return async (request: CallableRequest<TRequest>): Promise<TResponse> => {
    // Must be authenticated
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Du måste vara inloggad för att använda denna funktion."
      );
    }

    const userId = request.auth.uid;

    // Check global aggregate limit before per-user limit
    const globalAllowed = await checkGlobalLimit();
    if (!globalAllowed) {
      functions.logger.warn(
        `Global LLM limit exceeded for ${operationType} by user ${userId}`
      );
      throw new HttpsError(
        "resource-exhausted",
        "Systemets kapacitetsgräns har nåtts. Försök igen senare."
      );
    }

    // Check per-user rate limit
    const rateLimitResult = await checkRateLimit(userId, operationType, tokensRequired);

    if (!rateLimitResult.allowed) {
      // Log violation for monitoring
      await logRateLimitViolation(userId, operationType, rateLimitResult);

      // Return 429 with Retry-After
      const retryAfterSeconds = Math.ceil((rateLimitResult.retryAfterMs || 60000) / 1000);

      functions.logger.warn(
        `Rate limit exceeded for user ${userId} on ${operationType}. ` +
        `Remaining: ${rateLimitResult.remainingTokens}, Retry after: ${retryAfterSeconds}s`
      );

      throw new HttpsError(
        "resource-exhausted",
        `Du har gjort för många förfrågningar. Försök igen om ${retryAfterSeconds} sekunder.`,
        {
          retryAfterSeconds,
          remainingTokens: rateLimitResult.remainingTokens,
        }
      );
    }

    // Rate limit passed - execute handler
    functions.logger.info(
      `Rate limit passed for ${operationType}: ${rateLimitResult.remainingTokens} tokens remaining`
    );

    return handler(request);
  };
}

/**
 * Standalone rate limit check without middleware wrapping.
 * Useful for checking limits before expensive operations.
 *
 * @throws HttpsError if rate limit exceeded
 */
export async function enforceRateLimit(
  userId: string,
  operationType: string,
  tokensRequired: number = 1
): Promise<void> {
  const result = await checkRateLimit(userId, operationType, tokensRequired);

  if (!result.allowed) {
    await logRateLimitViolation(userId, operationType, result);

    const retryAfterSeconds = Math.ceil((result.retryAfterMs || 60000) / 1000);

    throw new HttpsError(
      "resource-exhausted",
      `Rate limit exceeded for ${operationType}. Try again in ${retryAfterSeconds} seconds.`,
      {
        retryAfterSeconds,
        remainingTokens: result.remainingTokens,
      }
    );
  }
}
