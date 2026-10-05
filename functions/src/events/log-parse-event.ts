/**
 * Parse Event Logging - Server-side analytics for recipe parsing
 *
 * P1-4 Security: Tier attempts array is validated per-entry (max 10,
 * tier names checked against VALID_TIERS, values clamped). Client also
 * sends domain and unknownDomain flag for site coverage analytics.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { DART_TIER_NAMES } from "../shared/parse-tier-vocabulary";

// Note: db is accessed lazily to ensure initializeApp() has been called
const getDb = () => admin.firestore();

/**
 * BUT-1478: parse_events stores raw userId + sanitized URL, so unbounded
 * retention is a GDPR Art. 5(1)(e) surface. Every doc carries `expireAt`,
 * mirroring `llm_response_samples` (llm-sample-capture.ts): enable a Firestore
 * TTL policy on `expireAt` for this collection so docs are reaped. 30 days
 * matches the sample-capture window; history is preserved in aggregate form —
 * daily-snapshots.ts rolls events up per day/domain and site_configs keeps
 * cumulative success/failure counters, neither of which is TTL'd.
 */
const RETENTION_DAYS = 30;

/**
 * BUT-1478: TTL timestamp for a parse event created at `nowMs`.
 *
 * Exported as a test seam (same pattern as validateDomain below and
 * evaluateDailyCap in rate_limiter.ts): the retention window is the
 * load-bearing GDPR guarantee, so the 30-day math is pinned by
 * log-parse-event-expiry.test.ts rather than living inline in the handler
 * where a refactor could silently drop it. Also used by the one-time
 * backfill script (admin/backfill-parse-event-expiry.ts).
 */
export function computeExpireAt(nowMs: number): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(
    nowMs + RETENTION_DAYS * 24 * 60 * 60 * 1000
  );
}

/**
 * BUT-2238: an import writes ONE event, from the app's ImportManager. These
 * lists mirror the Dart side (ImportChannel, ImportEvent.strategyId and
 * ImportErrorCode in lib/services/import/); import_event_vocabulary_test.dart
 * reads this file and fails when the two drift.
 */
export const VALID_CHANNELS = ["link", "text", "photo", "voice", "file"];
export const VALID_STRATEGIES = [
  "url",
  "text",
  "photo",
  "voice",
  "youtube",
  "tiktok",
  "instagram",
  "archive",
  "cache",
  "unknown",
];
export const VALID_OUTCOMES = ["recipe", "assistance", "failure"];
export const VALID_ERROR_CODES = [
  "unknown",
  "network",
  "rateLimited",
  "llmQuotaExceeded",
  "invalidUrl",
  "urlNotAccessible",
  "platformBlocked",
  "noRecipeContent",
  "ocrFailed",
  "parsingFailed",
  "saveFailed",
  "cancelled",
];

/**
 * BUT-1646/BUT-1486: valid parsing tier names — the raw CamelCase Dart
 * identifiers the parse-event logger sends. Sourced from the canonical shared
 * vocabulary (DART_TIER_NAMES) so this third tier-name copy can never drift
 * from the correction path or the Dart client; a tripwire in
 * parse-tier-vocabulary.test.ts goes red if it does. Widened to readonly
 * string[] so the membership checks below accept an arbitrary string argument.
 */
export const VALID_TIERS: readonly string[] = DART_TIER_NAMES;

/**
 * Sanitize URL by removing sensitive query parameters
 */
function sanitizeUrl(url: unknown): string | null {
  if (typeof url !== "string" || !url) {
    return null;
  }

  try {
    const parsed = new URL(url);
    // Remove common tracking/session parameters
    const sensitiveParams = [
      "token",
      "session",
      "auth",
      "key",
      "password",
      "pwd",
      "secret",
    ];
    sensitiveParams.forEach((param) => parsed.searchParams.delete(param));
    return parsed.toString();
  } catch {
    // Invalid URL, return null
    return null;
  }
}

/**
 * Extract domain from URL
 */
function extractDomain(url: unknown): string | null {
  if (typeof url !== "string" || !url) {
    return null;
  }

  try {
    const parsed = new URL(url);
    // Remove 'www.' prefix for consistency
    return parsed.hostname.replace(/^www\./, "").toLowerCase();
  } catch {
    return null;
  }
}

/**
 * Validate a registrable hostname.
 *
 * The client supplies `domain` directly, and we use it verbatim as a
 * site_configs document ID. Without validation a caller could auto-create
 * config docs from arbitrary or malformed strings (empty, path-like values
 * containing "/", oversized blobs). Accept only lowercase dotted hostnames:
 * dot-separated labels of [a-z0-9-], each starting/ending alphanumeric, at
 * least two labels (a TLD), bounded length. Returns the normalized hostname
 * or null when invalid.
 */
export function validateDomain(domain: unknown): string | null {
  if (typeof domain !== "string") {
    return null;
  }
  const normalized = domain.toLowerCase().replace(/^www\./, "").trim();
  // Overall length guard (RFC 1035 caps hostnames at 253 chars) and a strict
  // label/TLD shape. No "/", no whitespace, no leading/trailing dots.
  if (normalized.length === 0 || normalized.length > 253) {
    return null;
  }
  const hostnameRegex =
    /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;
  return hostnameRegex.test(normalized) ? normalized : null;
}

/** The value when it is one of [allowed], else null. */
function oneOf(value: unknown, allowed: readonly string[]): string | null {
  return typeof value === "string" && allowed.includes(value) ? value : null;
}

/**
 * Clamp a number between min and max
 */
function clamp(value: unknown, min: number, max: number): number {
  const num = typeof value === "number" ? value : 0;
  return Math.max(min, Math.min(max, num));
}

/**
 * Validate parser version format (semver-like)
 */
function validateParserVersion(version: unknown): string | null {
  if (typeof version !== "string") {
    return null;
  }
  // Accept versions like "1.0.0", "2.0.0-beta", etc.
  const versionRegex = /^\d+\.\d+\.\d+(-\w+)?$/;
  return versionRegex.test(version) ? version : null;
}

/**
 * Interface for a single tier attempt entry from the client.
 */
interface TierAttemptEntry {
  tier?: string;
  success?: boolean;
  quality?: number;
  durationMs?: number;
}

/**
 * Interface for parse event data
 */
interface ParseEventData {
  url?: string;
  channel?: string;
  strategy?: string;
  outcome?: string;
  errorCode?: string;
  success?: boolean;
  fromCache?: boolean;
  parseTimeMs?: number;
  parserVersion?: string;
  domain?: string;
  successfulTier?: string;
  finalQuality?: number;
  usedLlm?: boolean;
  estimatedCostUsd?: number;
  tierAttempts?: TierAttemptEntry[];
  unknownDomain?: boolean;
}

/**
 * BUT-2238: the client fields a parse event keeps, each validated or dropped.
 * Exported as a test seam (log-parse-event-fields.test.ts), like
 * validateDomain and computeExpireAt.
 */
export function sanitizeParseEvent(data: ParseEventData) {
  const tierAttempts = Array.isArray(data.tierAttempts)
    ? data.tierAttempts.slice(0, 10).map((entry: TierAttemptEntry) => ({
        tier: typeof entry.tier === "string" && VALID_TIERS.includes(entry.tier) ? entry.tier : "unknown",
        success: Boolean(entry.success),
        quality: typeof entry.quality === "number" ? clamp(entry.quality, 0, 1) : 0,
        durationMs: typeof entry.durationMs === "number" ? clamp(entry.durationMs, 0, 60000) : 0,
      }))
    : null;
  const outcome = oneOf(data.outcome, VALID_OUTCOMES);
  return {
    url: sanitizeUrl(data.url),
    // Validate the client-supplied domain (it becomes a site_configs doc ID).
    // Fall back to the domain parsed from the URL, which new URL() already
    // guarantees is a real hostname.
    domain: validateDomain(data.domain) ?? extractDomain(data.url),
    channel: oneOf(data.channel, VALID_CHANNELS),
    strategy: oneOf(data.strategy, VALID_STRATEGIES),
    outcome,
    success: Boolean(data.success),
    errorCode: outcome === "failure" ? oneOf(data.errorCode, VALID_ERROR_CODES) : null,
    fromCache: Boolean(data.fromCache),
    parseTimeMs: clamp(data.parseTimeMs, 0, 60000),
    parserVersion: validateParserVersion(data.parserVersion),
    successfulTier: typeof data.successfulTier === "string" && VALID_TIERS.includes(data.successfulTier) ? data.successfulTier : null,
    finalQuality: typeof data.finalQuality === "number" ? clamp(data.finalQuality, 0, 1) : null,
    usedLlm: typeof data.usedLlm === "boolean" ? data.usedLlm : null,
    estimatedCostUsd: typeof data.estimatedCostUsd === "number" ? clamp(data.estimatedCostUsd, 0, 1) : null,
    ...(tierAttempts ? { tierAttempts } : {}),
    ...(data.unknownDomain === true ? { unknownDomain: true } : {}),
  };
}

/**
 * logParseEvent - Cloud Callable for logging parse events
 *
 * This function logs recipe parsing events for analytics purposes.
 * It implements P1-4 security by:
 * - Requiring authentication
 * - Ignoring client-provided tierSummaries (untrusted)
 * - Only accepting validated/sanitized fields
 * - Using server timestamps
 *
 */
export const logParseEvent = onCall(
  // BUT-760: user-facing import-telemetry callable — App Check
  // defense-in-depth. Inert until App Check flipped to Enforce in console.
  { enforceAppCheck: true },
  async (request: CallableRequest<ParseEventData>) => {
    // Require authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be logged in to log parse events"
      );
    }

    const userId = request.auth.uid;
    const data = request.data;

    // Rate limiting: 30 requests per minute, 10 refilled per minute
    await enforceRateLimit(userId, "logParseEvent");

    const fields = sanitizeParseEvent(data);
    if (!fields.url && !fields.channel) {
      throw new HttpsError(
        "invalid-argument",
        "Either url or channel must be provided"
      );
    }

    // P1-4: only validated client fields, plus server-owned ones
    const trustedFields = {
      userId,
      ...fields,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      // BUT-1478: TTL field — see computeExpireAt/RETENTION_DAYS above.
      expireAt: computeExpireAt(Date.now()),
    };

    try {
      await getDb().collection("parse_events").add(trustedFields);

      // Update site_configs success/failure counts (server-side, replaces dead client writes)
      if (trustedFields.domain) {
        const siteUpdate: Record<string, unknown> = trustedFields.success
          ? {
              successCount: admin.firestore.FieldValue.increment(1),
              lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
            }
          : {
              failureCount: admin.firestore.FieldValue.increment(1),
              lastFailureAt: admin.firestore.FieldValue.serverTimestamp(),
            };
        siteUpdate.lastUpdated = admin.firestore.FieldValue.serverTimestamp();

        await getDb()
          .collection("site_configs")
          .doc(trustedFields.domain)
          .set(siteUpdate, { merge: true });
      }

      logger.info("Parse event logged", {
        userId,
        domain: trustedFields.domain,
        channel: trustedFields.channel,
        success: trustedFields.success,
      });

      return { success: true };
    } catch (error) {
      logger.error("Failed to log parse event", { error, userId });
      throw new HttpsError(
        "internal",
        "Failed to log parse event"
      );
    }
  }
);
