/**
 * PII scrubbing for recipe text before sending to LLM.
 *
 * Removes personally identifiable information:
 * - Email addresses
 * - Swedish phone numbers
 * - Swedish personal numbers (personnummer)
 * - URL query parameters (keeps base URL)
 */

const REPLACEMENT = "[BORTTAGET]";

/** Email pattern */
const EMAIL_REGEX = /[\w.-]+@[\w.-]+\.\w+/g;

/** Swedish phone: +46 or 0-prefixed, with optional dashes/spaces */
const SWEDISH_PHONE_REGEX = /(\+46|0)\d{1,3}[-\s]?\d{2,3}[-\s]?\d{2,4}/g;

/** Swedish personal number: 6-8 digits, optional dash, 4 digits */
const PERSONNUMMER_REGEX = /\d{6,8}[-]?\d{4}/g;

/**
 * Remove PII from text before sending to LLM.
 */
export function scrubPii(text: string): string {
  let result = text;
  result = result.replace(EMAIL_REGEX, REPLACEMENT);
  result = result.replace(SWEDISH_PHONE_REGEX, REPLACEMENT);
  result = result.replace(PERSONNUMMER_REGEX, REPLACEMENT);
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
