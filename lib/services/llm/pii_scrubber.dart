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

/// Email pattern.
final RegExp _emailRegex = RegExp(r'[\w.-]+@[\w.-]+\.\w+');

/// Swedish personnummer: YYMMDD-XXXX or YYYYMMDD-XXXX.
///
/// The hyphen (or `+` for 100+ yr old) is required so that EAN-13 barcodes and
/// other digit runs do not match. Word boundaries prevent mid-token matches.
final RegExp _personnummerRegex = RegExp(r'\b(?:\d{6}|\d{8})[-+]\d{4}\b');

/// Unit suffixes that signal a hyphenated number range is NOT a phone number
/// (recipe durations, temperatures, quantities).
const String _unitSuffixLookahead =
    r'(?!\s*(?:min\b|sek\b|tim\b|timmar\b|minuter\b|sekunder\b|°C|°F|kr\b|st\b|g\b|kg\b|ml\b|dl\b|l\b|cl\b|tsk\b|msk\b|portioner\b))';

/// Swedish phone numbers: +46 / 0046 / leading-0 trunk, followed by digit
/// groups with optional `-`/space separators. Negative lookahead rejects
/// cooking-unit suffixes to avoid scrubbing ranges like "04-05 min".
final RegExp _swedishPhoneRegex = RegExp(
  r'(?:\+46|0046|\b0)[-\s]?\d{1,3}[-\s]?\d{2,4}[-\s]?\d{2,4}(?:[-\s]?\d{2,4})?'
  '$_unitSuffixLookahead',
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
  return result;
}

/// Strip query parameters, fragment, AND opaque path-embedded tracker IDs
/// from [url]. Returns [url] unchanged if it cannot be parsed.
///
/// BUT-692: previously only scrubbed `?utm_*=...` style query strings, leaving
/// path-embedded tokens like `/r/<sessionToken>/...` or
/// `/track/abc-123-XYZ.../...` intact. Path segments judged opaque by
/// [_looksOpaquePathSegment] are replaced with the literal `:redacted`.
/// Heuristic, not exhaustive — slugs like `gulasch-med-svamp-russin`
/// remain intact; opaque tokens (UUIDs, Algolia object IDs, base64-ish
/// blobs) are stripped.
String scrubUrlParams(String url) {
  try {
    final parsed = Uri.parse(url);
    if (!parsed.hasScheme) return url;
    final scrubbedSegments = parsed.pathSegments
        .map((seg) => _looksOpaquePathSegment(seg) ? ':redacted' : seg)
        .toList(growable: false);
    return parsed
        .replace(pathSegments: scrubbedSegments, query: '', fragment: '')
        .toString();
  } catch (_) {
    return url;
  }
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

dynamic _scrubValue(String key, dynamic value) {
  if (_opaqueKeys.contains(key)) return value;
  if (value is String) {
    // URLs get query-param stripping in addition to PII scrub; the key name
    // is the cheapest signal we have for "this field is a URL".
    if (key.toLowerCase().contains('url')) {
      return scrubPii(scrubUrlParams(value));
    }
    return scrubPii(value);
  }
  if (value is Map<String, dynamic>) {
    return scrubPayload(value);
  }
  if (value is List) {
    return value.map((v) {
      if (v is String) return scrubPii(v);
      if (v is Map<String, dynamic>) return scrubPayload(v);
      return v;
    }).toList();
  }
  return value;
}
