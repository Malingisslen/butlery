/**
 * Parse Event Logging - Server-side analytics for recipe parsing
 *
 * P1-4 Security: Server ignores client-provided tierSummaries,
 * only trusts server-validated fields. This prevents clients from
 * injecting false analytics data.
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
 * Interface for parse event data
 */
interface ParseEventData {
  url?: string;
  source?: string;
  success?: boolean;
  fromCache?: boolean;
  parseTimeMs?: number;
  parserVersion?: string;
  // Note: tierSummaries intentionally NOT included - P1-4 security
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

    // P1-4: Only accept trusted fields, ignore client tierSummaries
    const trustedFields = {
      userId,
      url: sanitizedUrl,
      domain: extractDomain(data.url),
      source: validateSource(data.source),
      success: Boolean(data.success),
      fromCache: Boolean(data.fromCache),
      parseTimeMs: clamp(data.parseTimeMs, 0, 60000),
      parserVersion: validateParserVersion(data.parserVersion),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      // Note: We do NOT include any client-provided tier data
      // Server would need to reconstruct this from its own sources if needed
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
