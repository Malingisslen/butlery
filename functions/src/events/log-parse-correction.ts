/**
 * BUT-595: Parse Correction Logging — server-side per-field correction log.
 *
 * Closes the parse-quality feedback loop. When a user edits a parsed recipe,
 * the client computes a per-field diff (RecipeDiffCalculator) and calls this
 * function once per corrected field. Each field becomes its own document in
 * `parse_corrections_v2` so the dataset is queryable for "which sites/tiers
 * produce which kinds of errors" without unpacking nested arrays.
 *
 * Why a new collection (`parse_corrections_v2`) instead of `parsing_corrections`:
 * the existing collection is the aggregate-per-recipe schema consumed by
 * `analyzeCorrections` for alias learning. Per BUT-595's "clean schema
 * separation" guidance and to avoid breaking that downstream trigger, the
 * per-field docs land in a separate collection. The brief named the target
 * `parsing_corrections`; the rationale for the rename is captured here so a
 * future reader knows the two collections are intentional, not duplicate.
 *
 * Security:
 *   - Authenticated callable (auth context required).
 *   - Rate-limited via `enforceRateLimit`.
 *   - Server applies `scrubPii()` to fromValue/toValue (defence in depth — the
 *     client also scrubs and truncates).
 *   - PII redaction guard: if scrubbing replaces >50% of either value the
 *     correction is dropped (likely a user pasted personal text into a recipe
 *     field — don't pollute the training dataset).
 *   - Whitespace-only / case-only diffs are dropped (signal-to-noise).
 *   - Userid + recipeId arrive pre-hashed from the client; we do not log raw
 *     ids server-side.
 *
 * Append-only contract: clients can never read this collection; the firestore
 * rules block read+write entirely and admin SDK is the only writer.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { scrubPii, redactionRatio } from "../llm/pii-scrubber";

const getDb = () => admin.firestore();

export const VALID_TIERS = [
  "site_config",
  "regex",
  "llm",
  "schema_org",
  "rule_based",
  "selective_enhance",
  "structured_extraction",
  "web_scraper",
  "html_text_parse",
  "user_assisted",
];

export const VALID_FIELDS = [
  "title",
  "portions",
  "time",
  "ingredients",
  "instructions",
];

export const MAX_VALUE_CHARS = 500;

/** Hash should be the hex output of SHA-256. Defensive sanity check. */
export const HASH_REGEX = /^[a-f0-9]{16,128}$/i;

/** Threshold above which we drop a correction as PII-poisoned. */
export const HEAVY_REDACTION_THRESHOLD = 0.5;

export interface ParseCorrectionData {
  correctedField?: string;
  fromValue?: string;
  toValue?: string;
  sourceTier?: string;
  promptVersion?: string;
  domain?: string;
  userIdHash?: string;
  recipeIdHash?: string;
}

export function truncate(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.length <= MAX_VALUE_CHARS ? value : value.substring(0, MAX_VALUE_CHARS);
}

export function isWhitespaceOrCaseOnlyDiff(from: string, to: string): boolean {
  // Whitespace collapse: any-run-of-WS → single space, then trim.
  const collapse = (s: string) => s.replace(/\s+/g, " ").trim().toLowerCase();
  return collapse(from) === collapse(to);
}

// `redactionRatio` is re-exported for tests / downstream consumers.
export { redactionRatio };

/**
 * Decision outcomes from the validate-and-scrub pipeline. The handler turns
 * `{kind: 'invalid'}` into HttpsError, `{kind: 'skip'}` into a no-op success,
 * and `{kind: 'write'}` into a Firestore add.
 */
export type ValidationResult =
  | { kind: "invalid"; reason: string }
  | { kind: "skip"; reason: "whitespace_or_case_only" | "pii_heavy" }
  | {
      kind: "write";
      doc: Record<string, unknown>;
    };

/**
 * Pure validation + sanitisation pipeline. Extracted so the unit tests can
 * exercise it without spinning up the callable runtime or Firestore.
 */
export function validateAndPreparePayload(
  data: ParseCorrectionData
): ValidationResult {
  const correctedField =
    typeof data.correctedField === "string" &&
    VALID_FIELDS.includes(data.correctedField)
      ? data.correctedField
      : null;
  if (!correctedField) {
    return { kind: "invalid", reason: "correctedField" };
  }

  const sourceTier =
    typeof data.sourceTier === "string" && VALID_TIERS.includes(data.sourceTier)
      ? data.sourceTier
      : null;
  if (!sourceTier) {
    return { kind: "invalid", reason: "sourceTier" };
  }

  const userIdHash =
    typeof data.userIdHash === "string" && HASH_REGEX.test(data.userIdHash)
      ? data.userIdHash
      : null;
  const recipeIdHash =
    typeof data.recipeIdHash === "string" && HASH_REGEX.test(data.recipeIdHash)
      ? data.recipeIdHash
      : null;
  if (!userIdHash || !recipeIdHash) {
    return { kind: "invalid", reason: "hashes" };
  }

  const rawFrom = truncate(data.fromValue);
  const rawTo = truncate(data.toValue);

  if (isWhitespaceOrCaseOnlyDiff(rawFrom, rawTo)) {
    return { kind: "skip", reason: "whitespace_or_case_only" };
  }

  const scrubbedFrom = scrubPii(rawFrom);
  const scrubbedTo = scrubPii(rawTo);

  if (
    redactionRatio(rawFrom, scrubbedFrom) > HEAVY_REDACTION_THRESHOLD ||
    redactionRatio(rawTo, scrubbedTo) > HEAVY_REDACTION_THRESHOLD
  ) {
    return { kind: "skip", reason: "pii_heavy" };
  }

  const promptVersion =
    sourceTier === "llm" && typeof data.promptVersion === "string"
      ? data.promptVersion.substring(0, 64)
      : null;

  const domain =
    typeof data.domain === "string" && data.domain.length > 0
      ? data.domain.substring(0, 128).toLowerCase().replace(/^www\./, "")
      : null;

  return {
    kind: "write",
    doc: {
      correctedField,
      fromValue: scrubbedFrom,
      toValue: scrubbedTo,
      sourceTier,
      ...(promptVersion ? { promptVersion } : {}),
      ...(domain ? { domain } : {}),
      userIdHash,
      recipeIdHash,
      schemaVersion: "v2-perfield",
    },
  };
}

export const logParseCorrection = onCall(
  async (request: CallableRequest<ParseCorrectionData>) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be logged in to log parse corrections"
      );
    }

    const userId = request.auth.uid;
    const data = request.data ?? {};

    // 60/min — corrections fire on save, capped naturally by recipe-save cadence.
    await enforceRateLimit(userId, "logParseCorrection");

    const result = validateAndPreparePayload(data);

    if (result.kind === "invalid") {
      throw new HttpsError(
        "invalid-argument",
        `Invalid payload: ${result.reason}`
      );
    }

    if (result.kind === "skip") {
      logger.debug("logParseCorrection skipped", { reason: result.reason });
      return { success: true, skipped: result.reason };
    }

    const doc = {
      ...result.doc,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await getDb().collection("parse_corrections_v2").add(doc);
      logger.info("Parse correction logged", {
        correctedField: result.doc.correctedField,
        sourceTier: result.doc.sourceTier,
        domain: result.doc.domain,
      });
      return { success: true };
    } catch (error) {
      logger.error("Failed to log parse correction", { error });
      throw new HttpsError("internal", "Failed to log parse correction");
    }
  }
);
