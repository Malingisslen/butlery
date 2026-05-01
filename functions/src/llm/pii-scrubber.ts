/**
 * PII scrubbing for recipe text before sending to LLM.
 *
 * Removes personally identifiable information:
 * - Email addresses
 * - Swedish phone numbers
 * - Swedish personal numbers (personnummer)
 * - URL query parameters (keeps base URL)
 *
 * IMPORTANT: These regex patterns must stay in sync with the Dart port at
 * lib/services/llm/pii_scrubber.dart — the client scrubs first (defence in
 * depth) so that Cloud Logging never ingests raw PII before this server-side
 * scrub runs.
 */

export const REPLACEMENT_EMAIL = "[EMAIL]";
export const REPLACEMENT_PHONE = "[PHONE]";
export const REPLACEMENT_PERSONNUMMER = "[PERSONNUMMER]";

/** All PII replacement tokens emitted by `scrubPii`. */
export const PII_TOKENS = [
  REPLACEMENT_EMAIL,
  REPLACEMENT_PHONE,
  REPLACEMENT_PERSONNUMMER,
] as const;

/**
 * Fraction of characters in `original` that the scrubber replaced.
 * Uses replacement-token coverage as the proxy: every emitted token
 * was a redacted span in the input.
 */
export function redactionRatio(original: string, scrubbed: string): number {
  if (!original) return 0;
  let nonTokenLen = scrubbed.length;
  for (const token of PII_TOKENS) {
    let idx = 0;
    while ((idx = scrubbed.indexOf(token, idx)) !== -1) {
      nonTokenLen -= token.length;
      idx += token.length;
    }
  }
  const redacted = Math.max(
    0,
    Math.min(original.length, original.length - nonTokenLen)
  );
  return redacted / original.length;
}

/** Email pattern */
const EMAIL_REGEX = /[\w.-]+@[\w.-]+\.\w+/g;

/**
 * Swedish personnummer: YYMMDD-XXXX or YYYYMMDD-XXXX.
 *
 * Why the hyphen is required: without it, any run of 10-12 digits matches,
 * which false-positives on EAN-13 barcodes (e.g. 7310865111294) and product
 * codes. The `+` separator is used for people over 100 years old.
 * Word boundaries (\b) prevent matching mid-barcode like 12345901015-1234.
 */
const PERSONNUMMER_REGEX = /\b(?:\d{6}|\d{8})[-+]\d{4}\b/g;

/**
 * Unit suffixes that indicate a number range is NOT a phone number.
 * Applied as a negative lookahead on the phone regex to avoid scrubbing
 * cooking ranges like "04-05 min" or "10-15 minuter".
 */
const UNIT_SUFFIX_LOOKAHEAD =
  "(?!\\s*(?:min\\b|sek\\b|tim\\b|timmar\\b|minuter\\b|sekunder\\b|°C|°F|kr\\b|st\\b|g\\b|kg\\b|ml\\b|dl\\b|l\\b|cl\\b|tsk\\b|msk\\b|portioner\\b))";

/**
 * Swedish phone numbers.
 *
 * Two accepted shapes:
 *   - Country-code: +46 or 0046 followed by 8-10 digits (separators allowed).
 *   - National:     leading 0 followed by 6-9 more digits (separators allowed).
 *
 * We require the leading country/trunk marker so "04-05 min" (a cooking range)
 * does not match — raw "04-05" has no +46 and no second zero grouping.
 */
const SWEDISH_PHONE_REGEX = new RegExp(
  "(?:\\+46|0046|\\b0)[-\\s]?\\d{1,3}[-\\s]?\\d{2,4}[-\\s]?\\d{2,4}(?:[-\\s]?\\d{2,4})?" +
    UNIT_SUFFIX_LOOKAHEAD,
  "g"
);

/**
 * Remove PII from text before sending to LLM.
 */
export function scrubPii(text: string): string {
  let result = text;
  result = result.replace(EMAIL_REGEX, REPLACEMENT_EMAIL);
  // Personnummer before phone: a personnummer matches the loose phone shape
  // too, and we want the more specific label when both apply.
  result = result.replace(PERSONNUMMER_REGEX, REPLACEMENT_PERSONNUMMER);
  result = result.replace(SWEDISH_PHONE_REGEX, REPLACEMENT_PHONE);
  return result;
}

/** Long unsplit alphanumeric run (hex hashes, base64 tokens, Algolia IDs). */
const LONG_ALPHANUMERIC_RUN = /[A-Za-z0-9]{16,}/;

/** RFC 4122 / RFC 9562 UUID layout, case-insensitive. */
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** URL-safe alphanumeric (`A-Z a-z 0-9 _ -`). */
const URL_SAFE_ALPHANUMERIC = /^[A-Za-z0-9_-]+$/;

/**
 * Best-effort detector for path segments that look like opaque tracker IDs
 * rather than human-readable slugs. Mirrors the Dart implementation in
 * lib/services/llm/pii_scrubber.dart — must produce identical decisions.
 *
 * False-negative-biased: title-cased English slugs slip through because
 * we cannot distinguish them from random tokens without semantic analysis.
 */
function looksOpaquePathSegment(segment: string): boolean {
  if (segment.length < 20) return false;
  if (!URL_SAFE_ALPHANUMERIC.test(segment)) return false;
  if (UUID_REGEX.test(segment)) return true;
  return LONG_ALPHANUMERIC_RUN.test(segment);
}

/**
 * Strip query parameters, fragment, AND opaque path-embedded tracker IDs
 * from a URL. Returns the original string if it's not a valid URL.
 *
 * BUT-692: prior implementation only stripped `?utm_*=...` style query
 * strings, leaving path-embedded tokens (`/r/<sessionToken>/...`,
 * `/track/abc-123-XYZ.../...`) intact. Slugs are preserved; UUIDs and
 * long opaque tokens are replaced with `:redacted`.
 */
export function scrubUrlParams(url: string): string {
  try {
    const parsed = new URL(url);
    parsed.search = "";
    parsed.hash = "";
    const segments = parsed.pathname
      .split("/")
      .map((s) => (looksOpaquePathSegment(s) ? ":redacted" : s));
    parsed.pathname = segments.join("/");
    return parsed.toString();
  } catch {
    return url;
  }
}
