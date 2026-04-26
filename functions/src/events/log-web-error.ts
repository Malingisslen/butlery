/**
 * BUT-449: Web error logging.
 *
 * Flutter Crashlytics has no web SDK. To still aggregate web errors in
 * the same GCP project as native, the client (web only) ships error
 * events here and we re-emit them as structured Cloud Logging entries
 * tagged `event=web_error`. Cloud Monitoring alerts on rate.
 *
 * Defence-in-depth:
 *   - The client scrubs PII via `lib/services/llm/pii_scrubber.dart`
 *     before the payload leaves the device — Cloud Logging ingests the
 *     raw callable input before we run, so client-side scrubbing is the
 *     authoritative line.
 *   - This function scrubs again as a server-side safety net (a future
 *     non-Dart caller, or a stale client, could skip the client scrub).
 *   - Authenticated callable: anonymous error spam is rejected.
 *   - Rate-limited via the shared middleware so a runaway loop on one
 *     user can't flood Cloud Logging.
 *   - PII guard: drop the report if the message field is >50% redacted
 *     (likely a stack interpolation contained the user's email/phone).
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { scrubPii, redactionRatio } from "../llm/pii-scrubber";
import { hashUid } from "../shared/hash-uid";

const MAX_MESSAGE_CHARS = 2000;
const MAX_STACK_CHARS = 8000;
const MAX_CONTEXT_CHARS = 1000;
const HEAVY_REDACTION_THRESHOLD = 0.5;
const ALLOWED_PLATFORMS = new Set(["web"]);

export interface WebErrorData {
  message?: string;
  stack?: string;
  context?: string;
  fatal?: boolean;
  platform?: string;
  occurredAt?: string;
}

export type WebErrorValidation =
  | { kind: "invalid"; reason: string }
  | { kind: "skip"; reason: "pii_heavy" }
  | {
      kind: "log";
      payload: {
        message: string;
        stack: string | null;
        context: string | null;
        fatal: boolean;
        platform: string;
        occurredAt: string;
      };
    };

function truncate(value: unknown, max: number): string {
  if (typeof value !== "string") return "";
  return value.length <= max ? value : value.substring(0, max);
}

/**
 * Pure validation pipeline. Extracted so unit tests can exercise it
 * without spinning up the callable runtime.
 */
export function validateAndScrubWebError(
  data: WebErrorData
): WebErrorValidation {
  const rawMessage = truncate(data.message, MAX_MESSAGE_CHARS);
  if (!rawMessage) {
    return { kind: "invalid", reason: "message" };
  }

  const platform = typeof data.platform === "string" ? data.platform : "web";
  if (!ALLOWED_PLATFORMS.has(platform)) {
    return { kind: "invalid", reason: "platform" };
  }

  const scrubbedMessage = scrubPii(rawMessage);
  if (
    redactionRatio(rawMessage, scrubbedMessage) > HEAVY_REDACTION_THRESHOLD
  ) {
    return { kind: "skip", reason: "pii_heavy" };
  }

  const rawStack = truncate(data.stack, MAX_STACK_CHARS);
  const stack = rawStack ? scrubPii(rawStack) : null;

  const rawContext = truncate(data.context, MAX_CONTEXT_CHARS);
  const context = rawContext ? scrubPii(rawContext) : null;

  const fatal = typeof data.fatal === "boolean" ? data.fatal : false;

  // occurredAt is a hint; trust the server clock for the canonical
  // timestamp in the log entry.
  const occurredAt =
    typeof data.occurredAt === "string" && data.occurredAt.length <= 64
      ? data.occurredAt
      : new Date().toISOString();

  return {
    kind: "log",
    payload: {
      message: scrubbedMessage,
      stack,
      context,
      fatal,
      platform,
      occurredAt,
    },
  };
}

export const logWebError = onCall<WebErrorData>(
  {
    memory: "256MiB",
    timeoutSeconds: 10,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request: CallableRequest<WebErrorData>) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be logged in to log web errors"
      );
    }

    const userId = request.auth.uid;
    await enforceRateLimit(userId, "logWebError");

    const result = validateAndScrubWebError(request.data ?? {});

    if (result.kind === "invalid") {
      throw new HttpsError(
        "invalid-argument",
        `Invalid payload: ${result.reason}`
      );
    }

    if (result.kind === "skip") {
      logger.debug("logWebError skipped", { reason: result.reason });
      return { success: true, skipped: result.reason };
    }

    // Re-emit as a structured log entry. Filterable in Cloud Logging via
    // `jsonPayload.event=web_error` (or `severity=ERROR` for fatal).
    const severity = result.payload.fatal ? "ERROR" : "WARNING";
    logger.write({
      severity,
      message: "[web_error] " + result.payload.message,
      labels: {
        event: "web_error",
        platform: result.payload.platform,
        fatal: String(result.payload.fatal),
      },
      // Hashed UID — never log raw to keep error stream non-PII.
      userIdHash: hashUid(userId),
      occurredAt: result.payload.occurredAt,
      stack: result.payload.stack,
      context: result.payload.context,
    });

    return { success: true };
  }
);
