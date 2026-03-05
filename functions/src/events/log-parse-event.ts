/**
 * Parse Event Logging - Server-side analytics for recipe parsing
 *
 * P1-4 Security: Tier attempts array is validated per-entry (max 10,
 * tier names checked against VALID_TIERS, values clamped). Client also
 * sends domain and unknownDomain flag for site coverage analytics.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";

// Note: db is accessed lazily to ensure initializeApp() has been called
const getDb = () => admin.firestore();

/**
 * Valid import sources
 */
const VALID_SOURCES = ["url", "text", "instagram", "tiktok", "youtube", "ocr"];

/** Valid parsing tier names (must match Dart-side tier identifiers). */
const VALID_TIERS = ["SchemaOrg", "SiteConfig", "RuleBased", "LLM", "SelectiveEnhance"];

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
 * Validate and normalize source type
 */
function validateSource(source: unknown): string {
  if (typeof source !== "string") {
    return "unknown";
  }
  const normalized = source.toLowerCase().trim();
  return VALID_SOURCES.includes(normalized) ? normalized : "unknown";
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
  source?: string;
  success?: boolean;
  fromCache?: boolean;
  parseTimeMs?: number;
  parserVersion?: string;
  domain?: string;
  successfulTier?: string;
  finalQuality?: number;
  usedLlm?: boolean;
  totalCostSek?: number;
  tierAttempts?: TierAttemptEntry[];
  unknownDomain?: boolean;
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
 * @param data - Parse event data from client
 * @param context - Firebase callable context with auth info
 * @returns Success status
 */
export const logParseEvent = functions.https.onCall(
  async (data: ParseEventData, context) => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in to log parse events"
      );
    }

    const userId = context.auth.uid;

    // Rate limiting: 30 requests per minute, 10 refilled per minute
    await enforceRateLimit(userId, "logParseEvent");

    // Validate required field
    const sanitizedUrl = sanitizeUrl(data.url);
    if (!sanitizedUrl && !data.source) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Either url or source must be provided"
      );
    }

    // Validate tier attempts array (max 10 entries, validated per-entry)
    const tierAttempts = Array.isArray(data.tierAttempts)
      ? data.tierAttempts.slice(0, 10).map((entry: TierAttemptEntry) => ({
          tier: typeof entry.tier === "string" && VALID_TIERS.includes(entry.tier) ? entry.tier : "unknown",
          success: Boolean(entry.success),
          quality: typeof entry.quality === "number" ? clamp(entry.quality, 0, 1) : 0,
          durationMs: typeof entry.durationMs === "number" ? clamp(entry.durationMs, 0, 60000) : 0,
        }))
      : null;

    // P1-4: Accept validated scalars + validated tier attempts array
    const trustedFields = {
      userId,
      url: sanitizedUrl,
      domain: typeof data.domain === "string" ? data.domain.toLowerCase().replace(/^www\./, "") : extractDomain(data.url),
      source: validateSource(data.source),
      success: Boolean(data.success),
      fromCache: Boolean(data.fromCache),
      parseTimeMs: clamp(data.parseTimeMs, 0, 60000),
      parserVersion: validateParserVersion(data.parserVersion),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      successfulTier: typeof data.successfulTier === "string" && VALID_TIERS.includes(data.successfulTier) ? data.successfulTier : null,
      finalQuality: typeof data.finalQuality === "number" ? clamp(data.finalQuality, 0, 1) : null,
      usedLlm: typeof data.usedLlm === "boolean" ? data.usedLlm : null,
      totalCostSek: typeof data.totalCostSek === "number" ? clamp(data.totalCostSek, 0, 10) : null,
      ...(tierAttempts ? { tierAttempts } : {}),
      ...(data.unknownDomain === true ? { unknownDomain: true } : {}),
    };

    try {
      await getDb().collection("parse_events").add(trustedFields);

      functions.logger.info("Parse event logged", {
        userId,
        domain: trustedFields.domain,
        source: trustedFields.source,
        success: trustedFields.success,
      });

      return { success: true };
    } catch (error) {
      functions.logger.error("Failed to log parse event", { error, userId });
      throw new functions.https.HttpsError(
        "internal",
        "Failed to log parse event"
      );
    }
  }
);
