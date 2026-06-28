/// Client-side PII scrubbing for text sent to LLM Cloud Functions.
///
/// Defence-in-depth: the server-side scrubber at
/// functions/src/llm/pii-scrubber.ts is the authoritative line of defence, but
/// Cloud Logging ingests the raw callable payload before server code runs.
/// Scrubbing on the client first prevents raw PII from ever reaching the logs.
///
/// IMPORTANT: Keep these regex patterns in sync with the TypeScript port at
/// functions/src/llm/pii-scrubber.ts — they define the same contract and must
/// produce identical replacements.
library;

const String _replacementEmail = '[EMAIL]';
const String _replacementPhone = '[PHONE]';
const String _replacementPersonnummer = '[PERSONNUMMER]';

/// BUT-694 heuristic tokens. Byte-identical with the TS-side
/// `REPLACEMENT_ADDRESS` / `REPLACEMENT_NAME` so the server's
/// `redactionRatio` (token coverage over scrubbed output) counts
/// client-emitted heuristic redactions with unchanged semantics.
const String _replacementAddress = '[ADDRESS]';
const String _replacementName = '[NAME]';

/// Opaque-token marker used by the URL scrubber. Must stay byte-identical
/// with the TS-side `REPLACEMENT_OPAQUE` — the parity test cases in
/// `test/unit/services/llm/pii_scrubber_test.dart` and
/// `functions/src/__tests__/pii-scrubber.test.ts` assert on this exact string.
const String _replacementOpaque = ':redacted';

/// Email pattern.
final RegExp _emailRegex = RegExp(r'[\w.-]+@[\w.-]+\.\w+');

/// Swedish personnummer: YYMMDD-XXXX or YYYYMMDD-XXXX.
///
/// The hyphen (or `+` for 100+ yr old) is required so that EAN-13 barcodes and
/// other digit runs do not match. Word boundaries prevent mid-token matches.
final RegExp _personnummerRegex = RegExp(r'\b(?:\d{6}|\d{8})[-+]\d{4}\b');

/// Unit suffixes that signal a hyphenated number range is NOT a phone number
/// (recipe durations, temperatures, quantities).
///
/// The unit word must NOT continue into a longer word. ASCII `\b` is wrong
/// here: it reports a boundary between `l` and `ä` ("lägenhet"), so
/// "Storgatan 14 lägenhet 1203" would read as "14 l" (litres) and leak the
/// address. Use an explicit non-word lookahead that includes å/ä/ö instead.
const String _unitWordEnd = r'(?![A-Za-zÅÄÖåäö0-9_])';
const String _unitSuffixLookahead =
    r'(?!\s*(?:(?:min|sek|tim|timmar|minuter|sekunder|kr|st|g|kg|ml|dl|l|cl|tsk|msk|portioner)'
    '$_unitWordEnd'
    '|°C|°F))';

/// Swedish phone numbers: +46 / 0046 / leading-0 trunk, followed by digit
/// groups with optional `-`/space separators. Negative lookahead rejects
/// cooking-unit suffixes to avoid scrubbing ranges like "04-05 min".
final RegExp _swedishPhoneRegex = RegExp(
  r'(?:\+46|0046|\b0)[-\s]?\d{1,3}[-\s]?\d{2,4}[-\s]?\d{2,4}(?:[-\s]?\d{2,4})?'
  '$_unitSuffixLookahead',
);

// ---------------------------------------------------------------------------
// BUT-694 (option c) — Swedish street-address + person-name heuristics.
//
// Mirror of the HEURISTIC CONTRACT block in functions/src/llm/pii-scrubber.ts.
// The contract is pinned by the shared vector file copied to
// test/unit/services/llm/fixtures/pii-heuristic-vectors.json — any rule change
// starts on the TS side and re-copies the vectors here.
//
// RULE A: word ending in a closed street-suffix set + REQUIRED house number
//         (1-4 digits, optional attached letter) → "[ADDRESS]". Guards: ≥1
//         letter before the suffix (bare "vägen"/"gatan" never match), and
//         the shared cooking-unit lookahead rejects quantities
//         ("Ringvägen 5 minuter" stays).
// RULE B: closed relation/honorific trigger + capitalized (optionally
//         hyphen-doubled) name → trigger kept, name → "[NAME]". NO general
//         capitalized-word NER — possessive recipe titles stay.
// ---------------------------------------------------------------------------

/// Closed suffix set for RULE A. Longer alternative first (gränden before
/// gränd) so the full word is consumed.
const String _streetSuffixes =
    '(?:gatan|vägen|gränden|gränd|torget|stigen|allén|backen|platsen)';

/// RULE A regex. No leading `\b` — like JS, Dart's ASCII `\b` mis-fires
/// before å/ä/ö; the letter class itself extends the match left as far as
/// the word goes, which is what we want for redaction. The trailing `\b`
/// sits after ASCII digits/letters where it is reliable.
///
/// The letter run is bounded at 60: an unbounded `+` backtracks O(n²) on
/// long unbroken letter runs. No real street name approaches 60 letters.
final RegExp _swedishStreetAddressRegex = RegExp(
  '[A-Za-zÅÄÖåäöé]{1,60}$_streetSuffixes'
  r'\s+\d{1,4}[A-Za-z]?\b'
  '$_unitSuffixLookahead',
);

/// RULE B triggers. Case spelled per-letter instead of `caseSensitive: false`
/// so the NAME part stays strictly capital-initial.
const String _relationOrHonorific =
    '(?:[Mm]ormor|[Ff]armor|[Mm]orfar|[Ff]arfar'
    '|[Mm]oster|[Ff]aster|[Mm]orbror|[Ff]arbror'
    '|[Mm]in vän(?:inna)?|[Vv]år vän(?:inna)?'
    '|[Hh]err|[Ff]röken|[Ff]ru)';

/// RULE B regex. The lookbehind enforces a non-letter (or string start)
/// before the trigger — using a letter class instead of `\b` for the same
/// å/ä/ö reason as RULE A; `\s+` after the trigger rejects genitives
/// ("mormors") and embedded matches ("Frukost"). Group 1 (trigger +
/// whitespace) is preserved by the replacement.
final RegExp _relationNameRegex = RegExp(
  '(?<=^|[^A-Za-zÅÄÖåäö])($_relationOrHonorific'
  r'\s+)[A-ZÅÄÖ][a-zåäöé]+(?:-[A-ZÅÄÖ][a-zåäöé]+)?',
);

/// Remove PII from [text] before sending to an LLM Cloud Function.
///
/// Returns [text] unchanged if nothing matches. Personnummer is scrubbed
/// before phone so the more specific label wins when both regexes match the
/// same span.
String scrubPii(String text) {
  var result = text;
  result = result.replaceAll(_emailRegex, _replacementEmail);
  result = result.replaceAll(_personnummerRegex, _replacementPersonnummer);
  result = result.replaceAll(_swedishPhoneRegex, _replacementPhone);
  // BUT-694 heuristics run last — same deterministic order as the TS side.
  result = result.replaceAll(_swedishStreetAddressRegex, _replacementAddress);
  result = result.replaceAllMapped(
    _relationNameRegex,
    (m) => '${m.group(1)!}$_replacementName',
  );
  return result;
}

/// Strip query parameters, opaque path-embedded tracker IDs, and opaque
/// fragment tokens from [url]. Returns [url] unchanged if it cannot be parsed.
///
/// BUT-692: previously only scrubbed `?utm_*=...` style query strings, leaving
/// path-embedded tokens like `/r/<sessionToken>/...` or
/// `/track/abc-123-XYZ.../...` intact. Path segments judged opaque by
/// [_looksOpaquePathSegment] are replaced with the literal `:redacted`.
/// Heuristic, not exhaustive — slugs like `gulasch-med-svamp-russin`
/// remain intact; opaque tokens (UUIDs, Algolia object IDs, base64-ish
/// blobs) are stripped.
///
/// BUT-534: fragment identifiers were preserved wholesale because they
/// aren't transmitted in HTTP requests — recipe sites use `#ingredienser`
/// / `#method` as section anchors.
///
/// BUT-765: but URLs scrubbed here are also threaded into LLM prompts +
/// Cloud Logging via `httpsCallable`, so opaque fragment tokens
/// (`#token=eyJhbGc...`) DO leak even though the HTTP path doesn't carry
/// them. Apply the opaque-detection heuristic to the fragment as well:
/// short slug-shaped anchors survive, UUID-shaped fragments redact
/// wholesale, and long alphanumeric runs inside keyed fragments
/// (`#token=...`) are redacted in-place.
String scrubUrlParams(String url) {
  try {
    final parsed = Uri.parse(url);
    if (!parsed.hasScheme) return url;
    // BUT-1413 gap 2: also redact segments that contain slug-embedded PII
    // (street addresses, names). `_looksOpaquePathSegment` handles random
    // tokens (UUIDs, hex hashes); `_slugContainsPii` handles human-readable
    // PII like `storgatan-14` or `mormor-anna`.
    final scrubbedSegments = parsed.pathSegments
        .map(
          (seg) => (_looksOpaquePathSegment(seg) || _slugContainsPii(seg))
              ? _replacementOpaque
              : seg,
        )
        .toList(growable: false);
    return parsed
        .replace(
          pathSegments: scrubbedSegments,
          query: '',
          fragment: _scrubFragment(parsed.fragment),
        )
        .toString();
  } catch (_) {
    return url;
  }
}

// ---------------------------------------------------------------------------
// BUT-1413 gap 3: base64-blob value heuristic.
//
// A string is treated as an opaque binary blob (and passed through verbatim)
// when it is at least 128 characters long AND consists exclusively of the
// standard base64 / base64url alphabet (A-Z a-z 0-9 + / - _ =). The 128-char
// floor is conservative — the longest "normal" text value in an LLM payload
// is unlikely to be pure-base64, and real image thumbnails are rarely shorter.
// This supplements `_opaqueKeys` (which is kept as the fast path) so that a
// blob stored under an unfamiliar key name is still skipped.
// ---------------------------------------------------------------------------

/// Minimum length before a value is considered a base64 blob.
const int _base64BlobMinLength = 128;

/// Base64 / base64url alphabet. Padding `=` is included.
final RegExp _base64Alphabet = RegExp(r'^[A-Za-z0-9+/\-_=]+$');

/// Returns true when [s] looks like a binary blob encoded in base64.
/// Guards (all three must hold):
///   1. Length ≥ [_base64BlobMinLength] (128) — avoids short coincidental hits.
///   2. Every character is in the base64 / base64url alphabet.
///   3. At least 25% of characters are uppercase letters or ASCII digits
///      (`[A-Z0-9]`). Real base64 of binary data is ~50%+ uppercase/digits;
///      natural-language slugs (all-lowercase, hyphens) are near 0%, so a
///      long lowercase slug that happens to be pure-base64-alphabet would be
///      mis-classified as a blob and its slug-embedded PII would be skipped.
///      The entropy fraction prevents that.
bool _looksLikeBase64Blob(String s) {
  if (s.length < _base64BlobMinLength) return false;
  if (!_base64Alphabet.hasMatch(s)) return false;
  // Entropy fraction guard: count [A-Z0-9] chars.
  var upperOrDigit = 0;
  for (final c in s.codeUnits) {
    if ((c >= 65 && c <= 90) || (c >= 48 && c <= 57)) upperOrDigit++;
  }
  return upperOrDigit / s.length >= 0.25;
}

// ---------------------------------------------------------------------------
// BUT-1413 gap 2: URL-slug PII heuristic.
//
// `scrubUrlParams` already replaces *opaque* path segments (≥20 chars,
// URL-safe-alphanumeric). It does NOT catch slug-embedded PII like
// `storgatan-14` or `mormor-anna` because:
//   a) those segments are short (<20 chars), and
//   b) the street/name regexes expect space-separated tokens.
//
// Fix: before returning a scrubbed URL, scan each path segment for
// slug-embedded PII by replacing `-`/`_` delimiters with spaces and
// running `scrubPii`. If the result differs, the segment contained PII
// and its original form is removed (replaced with `:redacted`).
// The segment itself stays intact if `scrubPii` is a no-op — no false
// positives from ordinary slugs like `gulasch-med-svamp-russin`.
// ---------------------------------------------------------------------------

/// Converts slug delimiters (`-`, `_`) to spaces and applies `scrubPii`;
/// returns true if any PII was detected.
bool _slugContainsPii(String segment) {
  final asTokens = segment.replaceAll(RegExp(r'[-_]'), ' ');
  return scrubPii(asTokens) != asTokens;
}

/// BUT-765: redact opaque tokens inside URL fragments while preserving
/// recipe section anchors. Short fragments (<16 chars) and slug-shaped
/// fragments survive; UUID-shaped fragments redact wholesale; long
/// alphanumeric runs inside the fragment are replaced with `:redacted`,
/// catching JWT, base64-ish, and Algolia-shaped tokens in `key=value`
/// fragment forms (`#token=eyJhbGc...` → `#token=:redacted`).
String _scrubFragment(String fragment) {
  if (fragment.length < 16) return fragment;
  if (_uuidRegex.hasMatch(fragment)) return _replacementOpaque;
  return fragment.replaceAll(_longAlphanumericRun, _replacementOpaque);
}

/// Long unsplit alphanumeric run — typical of hex hashes, base64 tokens,
/// Algolia object IDs. The 16-char threshold keeps Swedish slug groups
/// (which top out around 8-10 chars between hyphens) safe.
final RegExp _longAlphanumericRun = RegExp(r'[A-Za-z0-9]{16,}');

/// 8-4-4-4-12 lowercase hex layout — RFC 4122 / RFC 9562 UUIDs.
/// Case-insensitive flag handles the all-uppercase Microsoft variant.
final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// URL-safe alphanumeric (`A-Z a-z 0-9 _ -`). Path segments containing
/// other characters (Unicode, percent-encoded bytes, dots) are left alone.
final RegExp _urlSafeAlphanumeric = RegExp(r'^[A-Za-z0-9_-]+$');

/// Best-effort detector for path segments that look like opaque tracker
/// IDs rather than human-readable slugs. False-negative-biased: a
/// title-cased English phrase like `Recipe-Name-Article` still passes
/// through because we cannot distinguish it from a slug without semantic
/// analysis. Only segments that are UUID-shaped OR contain a long unsplit
/// alphanumeric run are redacted.
bool _looksOpaquePathSegment(String segment) {
  if (segment.length < 20) return false;
  if (!_urlSafeAlphanumeric.hasMatch(segment)) return false;
  if (_uuidRegex.hasMatch(segment)) return true;
  return _longAlphanumericRun.hasMatch(segment);
}

/// Keys whose values are opaque binary blobs and must NOT be scrubbed.
/// Scrubbing a base64 image would be wasted CPU and could corrupt the blob
/// if, by pure coincidence, the base64 alphabet produced an `@` neighborhood.
/// BUT-1413 gap 3: kept as the fast path; `_looksLikeBase64Blob` handles
/// unknown key names below.
const Set<String> _opaqueKeys = {'imageBase64'};

/// Recursively scrub every string value inside a JSON-like payload.
///
/// Used to wrap the `httpsCallable` input map so that any nested text field
/// (recipe text, source URL, context) is cleaned before it leaves the device.
/// Non-string leaves (numbers, bools, null) are passed through untouched.
/// Keys in [_opaqueKeys] are forwarded verbatim.
Map<String, dynamic> scrubPayload(Map<String, dynamic> payload) {
  return payload.map((key, value) => MapEntry(key, _scrubValue(key, value)));
}

/// Scrub a single string leaf, applying URL scrubbing when appropriate.
///
/// BUT-1413 gap 1: extracted so both the scalar and list branches in
/// [_scrubValue] share identical logic and cannot drift.
/// "URL-shaped" is detected by key name OR by the value starting with
/// `http://`/`https://` so list items under a generic key are also covered.
String _scrubStringLeaf(String key, String value) {
  final isUrl =
      key.toLowerCase().contains('url') ||
      value.startsWith('http://') ||
      value.startsWith('https://');
  return isUrl ? scrubPii(scrubUrlParams(value)) : scrubPii(value);
}

dynamic _scrubValue(String key, dynamic value) {
  // Fast-path: explicit opaque-key allowlist (e.g. imageBase64).
  if (_opaqueKeys.contains(key)) return value;
  if (value is String) {
    // BUT-1413 gap 3: skip base64 blobs regardless of key name.
    if (_looksLikeBase64Blob(value)) return value;
    return _scrubStringLeaf(key, value);
  }
  if (value is Map<String, dynamic>) {
    return scrubPayload(value);
  }
  if (value is List) {
    // BUT-1413 gap 1: list string elements now go through _scrubStringLeaf
    // so URL items in a list receive query-param stripping identical to the
    // scalar path above.
    // Note: nested lists ([[]]) are not part of the callable payload schema
    // and pass through intentionally — only string leaves and map values
    // are scrubbed within a list.
    return value.map((v) {
      if (v is String) {
        if (_looksLikeBase64Blob(v)) return v;
        return _scrubStringLeaf(key, v);
      }
      if (v is Map<String, dynamic>) return scrubPayload(v);
      return v;
    }).toList();
  }
  return value;
}
