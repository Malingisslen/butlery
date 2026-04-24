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

const REPLACEMENT_EMAIL = "[EMAIL]";
const REPLACEMENT_PHONE = "[PHONE]";
const REPLACEMENT_PERSONNUMMER = "[PERSONNUMMER]";

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

/**
 * Strip query parameters from a URL, keeping only the base path.
 * Returns the original string if it's not a valid URL.
 */
export function scrubUrlParams(url: string): string {
  try {
    const parsed = new URL(url);
    parsed.search = "";
    parsed.hash = "";
    return parsed.toString();
  } catch {
    return url;
  }
}
