/**
 * PII scrubbing for recipe text before sending to LLM.
 *
 * Removes personally identifiable information:
 * - Email addresses
 * - Swedish phone numbers
 * - Swedish personal numbers (personnummer)
 * - Swedish street addresses (BUT-694 option c — deterministic heuristics)
 * - Person names in relation/honorific contexts (BUT-694 option c)
 * - URL query parameters (keeps base URL)
 *
 * IMPORTANT: These regex patterns must stay in sync with the Dart port at
 * lib/services/llm/pii_scrubber.dart — the client scrubs first (defence in
 * depth) so that Cloud Logging never ingests raw PII before this server-side
 * scrub runs. The BUT-694 heuristics additionally share a test-vector file
 * with the Dart port: src/__tests__/fixtures/pii-heuristic-vectors.json.
 */

export const REPLACEMENT_EMAIL = "[EMAIL]";
export const REPLACEMENT_PHONE = "[PHONE]";
export const REPLACEMENT_PERSONNUMMER = "[PERSONNUMMER]";
export const REPLACEMENT_ADDRESS = "[ADDRESS]";
export const REPLACEMENT_NAME = "[NAME]";
/** Opaque-token marker used by the URL scrubber. Must stay byte-identical
 *  with the Dart-side `_replacementOpaque` — parity is asserted by the
 *  shared scrubUrlParams test cases. */
export const REPLACEMENT_OPAQUE = ":redacted";

/** All PII replacement tokens emitted by `scrubPii`. The BUT-694 heuristic
 *  tokens are included so `redactionRatio` counts heuristic redactions into
 *  the ratio with unchanged semantics (token coverage over the scrubbed
 *  output). */
export const PII_TOKENS = [
  REPLACEMENT_EMAIL,
  REPLACEMENT_PHONE,
  REPLACEMENT_PERSONNUMMER,
  REPLACEMENT_ADDRESS,
  REPLACEMENT_NAME,
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
 *
 * The unit word must NOT continue into a longer word. ASCII `\b` is wrong
 * here: it reports a boundary between `l` and `ä` ("lägenhet"), so
 * "Storgatan 14 lägenhet 1203" would read as "14 l" (litres) and leak the
 * address. Use an explicit non-word lookahead that includes å/ä/ö instead.
 */
const UNIT_WORD_END = "(?![A-Za-zÅÄÖåäö0-9_])";
const UNIT_SUFFIX_LOOKAHEAD =
  "(?!\\s*(?:(?:min|sek|tim|timmar|minuter|sekunder|kr|st|g|kg|ml|dl|l|cl|tsk|msk|portioner)" +
  UNIT_WORD_END +
  "|°C|°F))";

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

/* ------------------------------------------------------------------------
 * BUT-694 (option c) — HEURISTIC CONTRACT for Swedish street addresses and
 * person names. Deterministic regex only: NO LLM, NO ONNX, NO general
 * capitalized-word NER.
 *
 * The Dart mirror (lib/services/llm/pii_scrubber.dart) is written FROM this
 * contract. The shared test-vector file
 * src/__tests__/fixtures/pii-heuristic-vectors.json is the sync mechanism —
 * any change to the rules below MUST update the vectors, and the Dart side
 * re-copies the file.
 *
 * RULE A — street addresses → "[ADDRESS]"
 *   Redact a word built from Swedish letters that ENDS in one of the closed
 *   street-suffix set
 *     { gatan, vägen, gränden, gränd, torget, stigen, allén, backen,
 *       platsen }
 *   when it is IMMEDIATELY followed by a house number: 1–4 digits with an
 *   optional attached letter ("14", "52B", "7a"). The whole span
 *   (street word + number) becomes "[ADDRESS]".
 *   Guards:
 *     1. House number is REQUIRED — "Vasagatan är vacker" is untouched.
 *     2. The suffix must have ≥1 preceding letter — the bare common nouns
 *        "vägen"/"gatan" ("gå längs vägen 5 ...") never match.
 *     3. The shared unit lookahead rejects numbers that start a cooking
 *        quantity — "Följ Ringvägen 5 minuter norrut" is untouched.
 *   Examples: "Storgatan 14" → "[ADDRESS]", "Ringvägen 52B" → "[ADDRESS]".
 *
 * RULE B — person names → "[NAME]"
 *   Redact ONLY a capitalized name word (optionally hyphen-doubled:
 *   "Karl-Erik"; genitive forms like "Elsas" match too) when directly
 *   preceded by a trigger from the closed set:
 *     relations:  mormor, farmor, morfar, farfar, moster, faster,
 *                 morbror, farbror, "min vän", "min väninna", "vår vän",
 *                 "vår väninna"
 *     honorifics: herr, fru, fröken
 *   The trigger word is KEPT; only the name is replaced:
 *   "mormor Astrid" → "mormor [NAME]", "fru Andersson" → "fru [NAME]".
 *   Guards (pinned as negative vectors):
 *     1. NO general capitalized-word NER — possessive recipe titles
 *        ("Janssons frestelse", "Gustavs special") and capitalized dish
 *        nouns ("Skagenröra", "Toscakaka") are untouched.
 *     2. Genitive relation + lowercase noun ("mormors äppelkaka") is
 *        untouched — the trigger requires whitespace right after the
 *        non-genitive relation word, and the following word must be
 *        capitalized.
 *     3. The trigger must start at a word boundary (sentence-initial
 *        capital allowed: "Farmor Elsa" works; "Frukost" never triggers
 *        "fru").
 * ---------------------------------------------------------------------- */

/** Closed suffix set for RULE A. Longer alternative first (gränden before
 *  gränd) so the full word is consumed. */
const STREET_SUFFIXES =
  "(?:gatan|vägen|gränden|gränd|torget|stigen|allén|backen|platsen)";

/**
 * RULE A regex. No leading `\b` — JS ASCII `\b` mis-fires before å/ä/ö; the
 * letter class itself extends the match left as far as the word goes, which
 * is what we want for redaction. The trailing `\b` sits after ASCII
 * digits/letters where it is reliable.
 *
 * The letter run is bounded at 60: an unbounded `+` backtracks O(n²) on long
 * unbroken letter runs (~4s on a 50k-char run, the structure-recipe input
 * cap). No real street name approaches 60 letters.
 */
const SWEDISH_STREET_ADDRESS_REGEX = new RegExp(
  "[A-Za-zÅÄÖåäöé]{1,60}" +
    STREET_SUFFIXES +
    "\\s+\\d{1,4}[A-Za-z]?\\b" +
    UNIT_SUFFIX_LOOKAHEAD,
  "g"
);

/** RULE B triggers. Case spelled per-letter instead of the `i` flag so the
 *  NAME part stays strictly capital-initial. */
const RELATION_OR_HONORIFIC =
  "(?:[Mm]ormor|[Ff]armor|[Mm]orfar|[Ff]arfar|[Mm]oster|[Ff]aster" +
  "|[Mm]orbror|[Ff]arbror|[Mm]in vän(?:inna)?|[Vv]år vän(?:inna)?" +
  "|[Hh]err|[Ff]röken|[Ff]ru)";

/**
 * RULE B regex. The lookbehind enforces a non-letter (or string start)
 * before the trigger; `\s+` after the trigger rejects genitives
 * ("mormors") and embedded matches ("Frukost"). Group 1 (trigger +
 * whitespace) is preserved by the `$1[NAME]` replacement.
 */
const RELATION_NAME_REGEX = new RegExp(
  "(?<=^|[^A-Za-zÅÄÖåäö])(" +
    RELATION_OR_HONORIFIC +
    "\\s+)[A-ZÅÄÖ][a-zåäöé]+(?:-[A-ZÅÄÖ][a-zåäöé]+)?",
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
  // BUT-694 heuristics run last: their inputs (street words, names) cannot
  // contain the earlier replacement tokens, so ordering is cosmetic — but
  // keeping deterministic order makes the Dart mirror trivially identical.
  result = result.replace(SWEDISH_STREET_ADDRESS_REGEX, REPLACEMENT_ADDRESS);
  result = result.replace(RELATION_NAME_REGEX, `$1${REPLACEMENT_NAME}`);
  return result;
}

/** Long unsplit alphanumeric run (hex hashes, base64 tokens, Algolia IDs). */
const LONG_ALPHANUMERIC_RUN = /[A-Za-z0-9]{16,}/;

/** Same pattern but global. Kept as a separate instance because sharing
 *  one `/g` regex between `.test()` (path-segment scrub) and `.replace()`
 *  (fragment scrub) is a JS footgun — `.test()` on a `/g` regex mutates
 *  `lastIndex`, returning alternating false/true on the same input. */
const LONG_ALPHANUMERIC_RUN_GLOBAL = /[A-Za-z0-9]{16,}/g;

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
 * BUT-765: redact opaque tokens inside URL fragments while preserving
 * recipe section anchors. Mirror of the Dart `_scrubFragment` helper —
 * keep these in lock-step.
 */
function scrubFragment(fragment: string): string {
  if (fragment.length < 16) return fragment;
  if (UUID_REGEX.test(fragment)) return REPLACEMENT_OPAQUE;
  return fragment.replace(LONG_ALPHANUMERIC_RUN_GLOBAL, REPLACEMENT_OPAQUE);
}

/**
 * Strip query parameters, opaque path-embedded tracker IDs, and opaque
 * fragment tokens from a URL. Returns the original string if it's not
 * a valid URL.
 *
 * BUT-692: prior implementation only stripped `?utm_*=...` style query
 * strings, leaving path-embedded tokens (`/r/<sessionToken>/...`,
 * `/track/abc-123-XYZ.../...`) intact. Slugs are preserved; UUIDs and
 * long opaque tokens are replaced with `:redacted`.
 *
 * BUT-534: fragment identifiers (`#ingredienser`, `#method`) survive
 * because they aren't transmitted in HTTP requests and recipe sites
 * use them as section anchors.
 *
 * BUT-765: but URL strings scrubbed here are also threaded into LLM
 * prompts + Cloud Logging via `httpsCallable`, so opaque fragment
 * tokens (`#token=eyJhbGc...`) DO leak even though the HTTP path
 * doesn't carry them. Apply opaque-token redaction to the fragment.
 */
// ---------------------------------------------------------------------------
// BUT-1413 gap 2: URL-slug PII heuristic.
//
// `scrubUrlParams` previously only replaced *opaque* path segments (≥20
// chars, URL-safe alphanumeric). Slug-embedded PII like `storgatan-14` or
// `mormor-anna` slipped through because:
//   a) segments are short (<20 chars), and
//   b) the street/name regexes expect space-separated tokens.
//
// Fix: replace slug delimiters (`-`, `_`) with spaces and run `scrubPii`;
// if the result differs the segment contains PII and is replaced with
// `:redacted`. Ordinary food slugs (all-lowercase dictionary words) never
// fire the address/name heuristics, so false-positive risk is negligible.
// ---------------------------------------------------------------------------

/** Returns true when replacing slug delimiters with spaces causes scrubPii
 *  to produce a different string — i.e. the segment contains street/name PII. */
function slugContainsPii(segment: string): boolean {
  const asTokens = segment.replace(/[-_]/g, " ");
  return scrubPii(asTokens) !== asTokens;
}

// ---------------------------------------------------------------------------
// BUT-1413 gap 3: base64-blob value heuristic.
//
// Minimum length before treating a string as an opaque base64 blob.
// A value ≥128 chars whose every character is in the standard base64 /
// base64url alphabet is passed through verbatim. The explicit OPAQUE_KEYS
// set is kept as the fast path; this heuristic catches blobs stored under
// unfamiliar key names.
// ---------------------------------------------------------------------------

const BASE64_BLOB_MIN_LENGTH = 128;
const BASE64_ALPHABET = /^[A-Za-z0-9+/\-_=]+$/;

/**
 * Exported for testing only; not part of the scrubPayload public contract.
 *
 * Returns true when `s` looks like a binary blob encoded in base64.
 * Guards (all three must hold):
 *   1. Length ≥ BASE64_BLOB_MIN_LENGTH (128) — avoids short coincidental hits.
 *   2. Every character is in the base64 / base64url alphabet.
 *   3. At least 25% of characters are uppercase letters or ASCII digits
 *      [A-Z0-9]. Real base64 of binary data is ~50%+ uppercase/digits;
 *      natural-language slugs (all-lowercase, hyphens) are near 0%, so a
 *      long lowercase slug that happens to be pure-base64-alphabet would be
 *      mis-classified as a blob and its slug-embedded PII would be skipped.
 *      The entropy fraction prevents that.
 */
export function looksLikeBase64Blob(s: string): boolean {
  if (s.length < BASE64_BLOB_MIN_LENGTH) return false;
  if (!BASE64_ALPHABET.test(s)) return false;
  // Entropy fraction guard: count [A-Z0-9] chars.
  let upperOrDigit = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if ((c >= 65 && c <= 90) || (c >= 48 && c <= 57)) upperOrDigit++;
  }
  return upperOrDigit / s.length >= 0.25;
}

// ---------------------------------------------------------------------------
// BUT-1413 gap 1 + gap 3: scrubPayload / _scrubStringLeaf.
//
// Dart has `scrubPayload` as the public entry point; TS callable functions
// currently inline their own scrub calls. Adding the same helper here so:
//   a) both ports expose an identical API surface,
//   b) the shared list-branch fix (gap 1) lives in one place, and
//   c) future callables can use scrubPayload instead of ad-hoc inline calls.
// ---------------------------------------------------------------------------

/** Keys whose values are opaque binary blobs and must NOT be scrubbed.
 *  BUT-1413 gap 3: kept as the fast path; `looksLikeBase64Blob` handles
 *  unknown key names. */
const OPAQUE_KEYS = new Set(["imageBase64"]);

/** Scrub a single string leaf, applying URL scrubbing when appropriate.
 *
 *  BUT-1413 gap 1: extracted so both the scalar and list branches in
 *  `scrubValue` share identical logic and cannot drift.
 *  "URL-shaped" = key contains "url" OR value starts with http(s)://. */
function scrubStringLeaf(key: string, value: string): string {
  const isUrl =
    key.toLowerCase().includes("url") ||
    value.startsWith("http://") ||
    value.startsWith("https://");
  return isUrl ? scrubPii(scrubUrlParams(value)) : scrubPii(value);
}

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

function scrubValue(key: string, value: JsonValue): JsonValue {
  if (OPAQUE_KEYS.has(key)) return value;
  if (typeof value === "string") {
    // BUT-1413 gap 3: skip base64 blobs regardless of key name.
    if (looksLikeBase64Blob(value)) return value;
    return scrubStringLeaf(key, value);
  }
  if (Array.isArray(value)) {
    // BUT-1413 gap 1: list string elements now go through scrubStringLeaf
    // so URL items in a list receive query-param stripping identical to the
    // scalar path above.
    // Note: nested lists ([[]]) are not part of the callable payload schema
    // and pass through intentionally — only string leaves and object values
    // are scrubbed within a list.
    return value.map((v) => {
      if (typeof v === "string") {
        if (looksLikeBase64Blob(v)) return v;
        return scrubStringLeaf(key, v);
      }
      if (v !== null && typeof v === "object" && !Array.isArray(v)) {
        return scrubPayload(v as Record<string, JsonValue>);
      }
      return v;
    });
  }
  if (value !== null && typeof value === "object") {
    return scrubPayload(value as Record<string, JsonValue>);
  }
  return value;
}

/** Recursively scrub every string value inside a JSON-like payload.
 *
 *  Mirrors the Dart `scrubPayload` function. Used to wrap `httpsCallable`
 *  input maps so that any nested text field is cleaned before leaving the
 *  device. Non-string leaves (numbers, bools, null) are passed through. */
export function scrubPayload(
  payload: Record<string, JsonValue>
): Record<string, JsonValue> {
  const out: Record<string, JsonValue> = {};
  for (const [key, value] of Object.entries(payload)) {
    out[key] = scrubValue(key, value);
  }
  return out;
}

export function scrubUrlParams(url: string): string {
  try {
    const parsed = new URL(url);
    parsed.search = "";
    // BUT-1413 gap 2: also replace segments that contain slug-embedded PII.
    // Decode each segment before the slug check so that percent-encoded names
    // like `mormor%20Anna` are caught the same way Dart's `Uri.pathSegments`
    // (which auto-decodes) catches them. `looksOpaquePathSegment` still
    // operates on the raw (encoded) form — malformed escapes are kept raw via
    // the catch block so the opaque-detection heuristic is unaffected.
    const segments = parsed.pathname.split("/").map((s) => {
      let decoded = s;
      try {
        decoded = decodeURIComponent(s);
      } catch {
        /* malformed percent-encoding — keep raw */
      }
      return looksOpaquePathSegment(s) || slugContainsPii(decoded)
        ? REPLACEMENT_OPAQUE
        : s;
    });
    parsed.pathname = segments.join("/");
    // BUT-765 parity guard: Dart's `Uri.fragment` getter returns the
    // *decoded* form (`%3D` → `=`); JS's `URL.hash` keeps the percent-
    // encoded form. Without `decodeURIComponent` here, an adversarial
    // input like `#token%3DeyJhbGc...{long}...` would redact on the Dart
    // side but slip through on the TS side because `%` breaks the
    // 16-char alphanumeric run. Decode first so both ports see the
    // same matchable content. Malformed escapes (`%xz`) throw URIError;
    // fall back to the raw form when that happens.
    if (parsed.hash) {
      const raw = parsed.hash.slice(1);
      let decoded = raw;
      try {
        decoded = decodeURIComponent(raw);
      } catch {
        decoded = raw;
      }
      const scrubbed = scrubFragment(decoded);
      parsed.hash = scrubbed.length > 0 ? `#${scrubbed}` : "";
    }
    return parsed.toString();
  } catch {
    return url;
  }
}
