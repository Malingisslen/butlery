/**
 * Server-Side Rate Limiting Middleware for Cloud Functions
 *
 * Validates rate limits before processing requests to prevent abuse.
 *
 * Features:
 * - Token bucket algorithm validation
 * - Reads/writes server-side buckets at system_rate_limits/{userId}_{operation}
 *   (top-level, NOT a user subcollection — so clients can't reset their own
 *   limits by deleting docs; cleaned up weekly by cleanupOldRateLimits)
 * - Per-user DAILY cap (BUT-1477) on operations that declare `dailyLimit` —
 *   the per-minute bucket alone lets a patient abuser make thousands of LLM
 *   calls/day; the daily counter (same doc, same transaction) bounds worst-case
 *   per-user spend. Resets at UTC midnight, matching checkGlobalLimit's day key.
 * - Returns HTTP 429 with Retry-After header when exceeded
 * - Fails CLOSED on Firestore errors (denies the request — see the
 *   checkRateLimit catch block, not a graceful allow)
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
import { logger } from "firebase-functions/logger";
import { hashUid } from "../shared/hash-uid";

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
  /**
   * BUT-1477: optional per-user daily request cap (UTC day). Set on expensive
   * operations — LLM-backed ones, and since BUT-1838 the write-amplified
   * `createChatGroup`; omitted → no daily enforcement. Counted per request, not
   * per token.
   */
  dailyLimit?: number;
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
  /** BUT-1477: UTC day key the daily counter belongs to (optional — absent on
   * docs written before the daily cap shipped; treated as a fresh day). */
  dayKey?: string;
  /** BUT-1477: requests made during `dayKey`. */
  dailyCount?: number;
}

// =============================================================================
// Rate Limit Configurations (Mirror client-side)
// =============================================================================

/**
 * Rate limit configurations per operation type.
 * These mirror the client-side configurations for consistency.
 *
 * Exported (BUT-1573) so the production `dailyLimit` values are pinned by a
 * test — deleting or weakening one now regresses rate-limiter-daily-cap.test.ts
 * instead of shipping silently. All FOUR are pinned: the three LLM-spend caps
 * and, since BUT-1838, `createChatGroup`. Add a fifth and pin it in the same
 * edit — this sentence QUANTIFIES, so it goes stale by addition with its own
 * bytes untouched, which is how it was wrong between BUT-1838 shipping and
 * BUT-1838's own follow-up catching it.
 */
export const RATE_LIMIT_CONFIGS: Record<string, RateLimitConfig> = {
  // LLM Operations (expensive - strict limits)
  // BUT-1477 dailyLimit rationale: the minute bucket alone permits ~4300
  // structureRecipe calls/day (3/min sustained). Daily caps bound a single
  // account's worst-case LLM spend while staying far above real usage (a
  // heavy user imports a few dozen recipes/day at most).
  structureRecipe: {
    maxTokens: 10,
    refillRate: 3,
    refillIntervalMs: 60000, // 1 minute
    dailyLimit: 100,
  },
  ocrRecipeImage: {
    maxTokens: 5,
    refillRate: 2,
    refillIntervalMs: 60000,
    dailyLimit: 50,
  },

  // BUT-1838: chat-group membership callables. These replace CLIENT writes whose
  // create rules carried `rateLimitWrite('conversations', 10)` and
  // `('conversation_membership', 5)` — conjuncts that never actually bound:
  // `rateLimitWrite` is `!exists(bucket) || …`, and nothing in `lib/` writes
  // either bucket, so both were permanently true. (The bucket is self-written
  // too, so a tampered client would skip the stamp regardless.) The Admin SDK
  // bypasses rules either way, so this token bucket ESTABLISHES the first real
  // bound on these operations rather than restoring one — which is a stronger
  // reason to keep it, not a weaker one. Denominated in CALLS, not members — a single add-members call
  // is capped separately by MAX_CHAT_GROUP_MEMBERS.
  //
  // Creating groups carries a daily cap as well: a group create writes a group
  // document, a conversation, N roster rows and a system message, so it is the
  // most write-amplified of the three and the obvious one to abuse.
  createChatGroup: {
    maxTokens: 5,
    refillRate: 5,
    refillIntervalMs: 60000,
    dailyLimit: 50,
  },
  // Add and remove churn a group's members. Higher burst than create because
  // building a group's roster is a legitimate rapid sequence, and because
  // remove is also how you LEAVE — a user must never be rate-limited out of
  // leaving a group they want out of.
  addChatGroupMembers: {
    maxTokens: 20,
    refillRate: 10,
    refillIntervalMs: 60000,
  },
  removeChatGroupMember: {
    maxTokens: 20,
    refillRate: 10,
    refillIntervalMs: 60000,
  },

  // Notification Operations
  sendNotification: {
    maxTokens: 60,
    refillRate: 30,
    refillIntervalMs: 60000,
  },
  // BUT-1664: denominated in NOTIFICATIONS, not calls. The callable charges
  // one token per notification in the batch, so `maxTokens` must cover one
  // full-size batch (the callable caps at 100) or every large batch would be
  // denied outright. `refillRate` matches sendNotification's 30/min so the
  // sustained per-notification budget is the same whichever path a caller uses.
  sendNotificationBatch: {
    maxTokens: 100,
    refillRate: 30,
    refillIntervalMs: 60000,
  },

  // Import Operations (LLM-backed downstream — carries a daily cap too)
  importRecipe: {
    maxTokens: 10,
    refillRate: 3,
    refillIntervalMs: 60000,
    dailyLimit: 100,
  },

  // BUT-1386: signup age-verification callable. A user calls it ~once at
  // onboarding; a tight per-user bucket plus the per-IP audit cap in the CF
  // bound a retry storm or a single-account abuse loop.
  verifySignupAge: {
    maxTokens: 5,
    refillRate: 5,
    refillIntervalMs: 60000,
  },

  // BUT-1629: minor searchability opt-in callable. A privacy toggle is flipped
  // a handful of times ever, so this is purely an abuse/retry-storm bound —
  // tight enough that a scripted loop can't hammer the Admin-SDK write path,
  // loose enough that a user flipping the switch back and forth never notices.
  setProfileSearchability: {
    maxTokens: 10,
    refillRate: 5,
    refillIntervalMs: 60000,
  },

  // Analytics/Logging Operations (moderate limits)
  logParseEvent: {
    maxTokens: 30,
    refillRate: 10,
    refillIntervalMs: 60000,
  },
  // BUT-1378: parse corrections fire on every recipe save. Declared explicitly
  // (was silently falling through to `default`'s 30/10, contradicting the
  // call-site's documented 60/min). 60 burst, refilling 60/min ≈ 1/sec.
  logParseCorrection: {
    maxTokens: 60,
    refillRate: 60,
    refillIntervalMs: 60000,
  },
  // BUT-449: Web error reporting. Slightly tighter than logParseEvent —
  // a runaway error loop could otherwise flood Cloud Logging cheaply.
  logWebError: {
    maxTokens: 20,
    refillRate: 5,
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
 * Test seam: overrides the Firestore handle used by checkRateLimit so the
 * transaction wiring (daily-cap deny-before-consume, counter persistence) can
 * be exercised without an emulator. Production never sets this; pass null to
 * restore the real Admin SDK handle. Mirrors __resetGlobalLimitsCacheForTest.
 */
let firestoreForTest: admin.firestore.Firestore | null = null;

export function __setFirestoreForTest(
  db: admin.firestore.Firestore | null
): void {
  firestoreForTest = db;
}

function getFirestore(): admin.firestore.Firestore {
  return firestoreForTest ?? admin.firestore();
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
  return getFirestore()
    .collection("system_rate_limits")
    .doc(`${userId}_${operationType}`);
}

/**
 * Result of refilling a bucket up to `now`.
 *
 * `effectiveRefill` is the timestamp that must be persisted as the new
 * `lastRefill`. It is NOT simply `now`: when only a fraction of a refill
 * interval has elapsed we credit the corresponding fraction of a token and
 * carry the unused remainder forward by advancing `lastRefill` only by the
 * time we actually consumed. Persisting `now` instead would discard that
 * sub-interval progress, so a user requesting faster than one interval would
 * never refill and stay locked out far longer than the configured rate.
 */
interface RefillResult {
  tokens: number;
  effectiveRefill: Date;
}

/**
 * Calculate current available tokens based on time elapsed, crediting
 * fractional-interval progress instead of flooring it away.
 *
 * Exported as a test seam (the refill math is the BUT bug-35 fix); not part
 * of the public middleware contract.
 */
export function calculateCurrentTokens(
  storedTokens: number,
  lastRefill: Date,
  config: RateLimitConfig
): RefillResult {
  const now = Date.now();
  const elapsed = Math.max(0, now - lastRefill.getTime());

  // Continuous refill: tokens accrue at refillRate per refillIntervalMs.
  const tokensPerMs = config.refillRate / config.refillIntervalMs;
  const refilled = storedTokens + elapsed * tokensPerMs;
  const tokens = Math.min(config.maxTokens, refilled);

  // If the bucket capped out, anchor lastRefill at `now` (all elapsed time is
  // accounted for). Otherwise advance it by the whole-millisecond span of the
  // tokens we actually credited, leaving the sub-token remainder of time to
  // accrue on the next call.
  let effectiveRefill: Date;
  if (tokens >= config.maxTokens) {
    effectiveRefill = new Date(now);
  } else {
    const creditedMs = Math.floor((tokens - storedTokens) / tokensPerMs);
    effectiveRefill = new Date(lastRefill.getTime() + creditedMs);
  }

  return { tokens, effectiveRefill };
}

/** UTC day key — same shape as checkGlobalLimit's dayKey (month is 0-based;
 * only used for equality, never parsed back). */
function utcDayKey(now: Date): string {
  return `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
}

/** Outcome of the per-user daily-cap evaluation (BUT-1477). */
export interface DailyCapResult {
  allowed: boolean;
  /** Requests already made today (0 after a UTC-day rollover). */
  priorDailyCount: number;
  /** Day key to persist alongside the incremented counter. */
  dayKey: string;
  /** Set when denied: ms until the counter resets (next UTC midnight). */
  retryAfterMs?: number;
}

/**
 * Evaluate the per-user daily cap against the stored counter.
 *
 * Pure function, exported as a test seam (mirrors calculateCurrentTokens);
 * not part of the public middleware contract. A stored counter from an
 * earlier UTC day (or a pre-BUT-1477 doc with no counter) reads as 0.
 */
export function evaluateDailyCap(
  stored: { dayKey?: string; dailyCount?: number } | undefined,
  config: RateLimitConfig,
  now: Date
): DailyCapResult {
  const dayKey = utcDayKey(now);
  const priorDailyCount =
    stored?.dayKey === dayKey ? (stored.dailyCount ?? 0) : 0;

  if (config.dailyLimit !== undefined && priorDailyCount >= config.dailyLimit) {
    const nextUtcMidnight = Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1
    );
    return {
      allowed: false,
      priorDailyCount,
      dayKey,
      retryAfterMs: nextUtcMidnight - now.getTime(),
    };
  }

  return { allowed: true, priorDailyCount, dayKey };
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
    const result = await getFirestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      const now = new Date();

      let currentTokens: number;
      // Timestamp to persist as the new lastRefill. Preserves sub-interval
      // refill progress (see calculateCurrentTokens) rather than resetting to
      // `now`, which would strand fractional accrual and lock users out early.
      let refillAnchor: Date;
      let storedData: StoredRateLimit | undefined;

      if (doc.exists) {
        storedData = doc.data() as StoredRateLimit;
        const refill = calculateCurrentTokens(
          storedData.tokens,
          storedData.lastRefill.toDate(),
          config
        );
        currentTokens = refill.tokens;
        refillAnchor = refill.effectiveRefill;
      } else {
        // First request - start with full bucket
        currentTokens = config.maxTokens;
        refillAnchor = now;
      }

      // BUT-1477: per-user daily cap, checked before consuming minute-bucket
      // tokens (a denied request must not eat bucket capacity). Same
      // transaction, same doc — no extra reads.
      const dailyCap = evaluateDailyCap(storedData, config, now);
      if (!dailyCap.allowed) {
        const retryAfterMs = dailyCap.retryAfterMs ?? 24 * 60 * 60 * 1000;
        return {
          allowed: false,
          remainingTokens: currentTokens,
          retryAfterMs,
          reason:
            `Daily limit reached for ${operationType}. ` +
            `Resets in ${Math.ceil(retryAfterMs / 1000)} seconds (midnight UTC).`,
        };
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

      // Consume tokens and update Firestore. The daily counter is tracked for
      // every operation (observability); it's only ENFORCED when the config
      // declares a dailyLimit.
      const newTokens = currentTokens - tokensRequired;
      const updateData: Partial<StoredRateLimit> = {
        tokens: newTokens,
        lastRefill: admin.firestore.Timestamp.fromDate(refillAnchor),
        operationType,
        updatedAt: admin.firestore.Timestamp.now(),
        dayKey: dailyCap.dayKey,
        dailyCount: dailyCap.priorDailyCount + 1,
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
    logger.error(
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
    // BUT-1692: `getFirestore()`, not `admin.firestore()` directly. This row is
    // the whole reason callers must go through `enforceRateLimit` rather than
    // `checkRateLimit` + a local throw, so a test has to be able to observe it;
    // bypassing the seam made the audit write assertable only against a live
    // emulator, which is why the batch path shipped without that assertion.
    await getFirestore().collection("system_events").add({
      type: "rate_limit_violation",
      userIdHash: hashUid(userId),
      operationType,
      remainingTokens: result.remainingTokens,
      retryAfterMs: result.retryAfterMs,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // Don't fail the request if logging fails
    logger.warn("Failed to log rate limit violation:", error);
  }
}

// =============================================================================
// Global Aggregate Limits
// =============================================================================

/**
 * Hardcoded defaults for the global aggregate caps. Used as fallback when
 * `system/config` is missing the override fields, malformed, or unreachable.
 *
 * BUT-687: live values come from `system/config.globalHourlyLimit` /
 * `system/config.globalDailyLimit` (same Firestore doc as the BUT-439 kill
 * switch). Module-scope cache lasts the entire warm-instance lifetime —
 * which under sustained traffic can be 30+ minutes. Operator overrides
 * propagate on the *next cold start*, not within the cache TTL. Acceptable
 * because these caps are a soft cost-shaping lever; the master kill
 * (`aiEnabled`) is the authoritative emergency brake.
 */
const DEFAULT_GLOBAL_HOURLY_LIMIT = 1000;
const DEFAULT_GLOBAL_DAILY_LIMIT = 10000;

interface GlobalLimits {
  hourly: number;
  daily: number;
}

let cachedGlobalLimits: GlobalLimits | null = null;

/**
 * Optional override of the Firestore loader for unit tests. When set, takes
 * precedence over the default `system/config` read. Reset between tests with
 * `__resetGlobalLimitsCacheForTest()`.
 */
let globalLimitsLoaderForTest:
  | (() => Promise<Partial<GlobalLimits> | null>)
  | null = null;

function readPositiveNumber(
  data: unknown,
  key: string,
  fallback: number
): number {
  const v = (data as Record<string, unknown> | null | undefined)?.[key];
  return typeof v === "number" && Number.isFinite(v) && v > 0 ? v : fallback;
}

async function loadGlobalLimits(): Promise<GlobalLimits> {
  if (cachedGlobalLimits) return cachedGlobalLimits;
  try {
    const data = globalLimitsLoaderForTest
      ? await globalLimitsLoaderForTest()
      : (await admin.firestore().doc("system/config").get()).data();
    cachedGlobalLimits = {
      hourly: readPositiveNumber(
        data,
        "globalHourlyLimit",
        DEFAULT_GLOBAL_HOURLY_LIMIT
      ),
      daily: readPositiveNumber(
        data,
        "globalDailyLimit",
        DEFAULT_GLOBAL_DAILY_LIMIT
      ),
    };
  } catch (err) {
    logger.warn("Failed to load global rate limits, using defaults", err);
    cachedGlobalLimits = {
      hourly: DEFAULT_GLOBAL_HOURLY_LIMIT,
      daily: DEFAULT_GLOBAL_DAILY_LIMIT,
    };
  }
  return cachedGlobalLimits;
}

/**
 * Test seam: clear the module-scope cache so a subsequent `checkGlobalLimit`
 * re-reads from the Firestore stub. Production code never calls this.
 */
export function __resetGlobalLimitsCacheForTest(
  loader?: () => Promise<Partial<GlobalLimits> | null>
): void {
  cachedGlobalLimits = null;
  globalLimitsLoaderForTest = loader ?? null;
}

/**
 * Check global aggregate LLM call limits.
 * Uses Firestore atomic increments on system/llmLimits document.
 * Limits themselves come from `system/config` (BUT-687), with hardcoded
 * fallbacks if the doc / fields are missing.
 *
 * @returns true if within limits, false if exceeded
 */
export async function checkGlobalLimit(): Promise<boolean> {
  // Load limits first (loader may be a test seam that doesn't touch Firestore).
  const { hourly: hourlyLimit, daily: dailyLimit } = await loadGlobalLimits();

  try {
    const limitsRef = admin.firestore().doc("system/llmLimits");
    const result = await admin.firestore().runTransaction(async (tx) => {
      const doc = await tx.get(limitsRef);
      const now = new Date();
      const currentHour = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}-${now.getUTCHours()}`;
      const currentDay = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

      const data = doc.exists ? doc.data()! : {};

      // Reset counters if period changed
      const hourlyCount = data.hourKey === currentHour ? (data.hourlyCount ?? 0) : 0;
      const dailyCount = data.dayKey === currentDay ? (data.dailyCount ?? 0) : 0;

      if (hourlyCount >= hourlyLimit || dailyCount >= dailyLimit) {
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
    logger.error("Global limit check failed, denying request:", error);
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

    // BUT-1577: check the PER-USER limit before touching the global counter.
    // checkGlobalLimit atomically *increments* the shared hourly/daily LLM
    // budget, so running it first let a user whose own limit denies the request
    // still inflate that shared counter — a single abuser could exhaust the
    // global budget for everyone with requests that never ran. The per-user
    // gate runs first; the global increment happens only once the per-user
    // check has allowed the request.
    const rateLimitResult = await checkRateLimit(userId, operationType, tokensRequired);

    if (!rateLimitResult.allowed) {
      // Log violation for monitoring
      await logRateLimitViolation(userId, operationType, rateLimitResult);

      // Return 429 with Retry-After
      const retryAfterSeconds = Math.ceil((rateLimitResult.retryAfterMs || 60000) / 1000);

      logger.warn(
        `Rate limit exceeded for user ${hashUid(userId)} on ${operationType}. ` +
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

    // Per-user check passed — now consume the global aggregate budget.
    const globalAllowed = await checkGlobalLimit();
    if (!globalAllowed) {
      logger.warn(
        `Global LLM limit exceeded for ${operationType} by user ${hashUid(userId)}`
      );
      throw new HttpsError(
        "resource-exhausted",
        "Systemets kapacitetsgräns har nåtts. Försök igen senare."
      );
    }

    // Both limits passed - execute handler
    logger.info(
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
