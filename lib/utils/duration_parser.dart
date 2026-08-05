/// Swedish-duration parser for cooking-mode step timers (BUT-406).
///
/// Reads a recipe instruction line and, if it mentions a time, returns that
/// duration. Designed to tolerate the messy shapes real recipes use:
///
/// - `10 min`, `10 minuter`, `10 minut`
/// - `10-15 min` → uses the upper bound (15)
/// - `ca 20 minuter` (and other prefixes like `ungefär`, `cirka`, `i`, `låt koka i`)
/// - `1 timme`, `2 timmar`, `1 h`, `1.5 h`
/// - `30 sek`, `30 sekunder`, `30 s`
/// - BUT-604: word-number phrases — `en halvtimme`, `en halv timme`,
///   `en kvart`, `tre kvart(ar)`, `en timme`
///
/// Case-insensitive. Returns `null` when no match is found or when the parsed
/// duration falls outside `0 < x ≤ 12h` — the cooking-mode timer widget caps
/// at 2h but the parser itself rejects pathological inputs like `24 timmar`
/// to avoid surprising UX if upstream bounds change.
library;

import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// Upper bound for a legal parsed duration. Anything longer is returned as
/// `null` on the assumption that it's a recipe total, not a single step.
const Duration _maxDuration = Duration(hours: 12);

/// Match groups:
/// 1. optional lower bound of a range (ignored — we use the upper bound)
/// 2. numeric value (int or decimal with `,`/`.`)
/// 3. unit token
/// The unit's trailing edge is [SwedishWordBoundary.after], never ASCII `\b`.
/// Dart's `\b` treats å/ä/ö as NON-word, so it fires between the one-letter
/// units and a Swedish vowel and the single letter is read as a unit:
/// `2 hål i degen` parsed as 2 HOURS, `30 säsonger` as 30 seconds (BUT-1691,
/// the phantom-boundary direction). No legitimate Swedish duration puts å/ä/ö
/// immediately after the unit with no separator, so nothing is lost.
final RegExp _durationPattern = RegExp(
  r'(?:(\d+(?:[,\.]\d+)?)\s*[-–]\s*)?'
  r'(\d+(?:[,\.]\d+)?)\s*'
  r'(timmar|timme|timar|tim|tmr|h|minuter|minut|min|sekunder|sekund|sek|s)'
  '${SwedishWordBoundary.after}',
  caseSensitive: false,
);

/// BUT-604: word-number duration phrases that carry no digits. Ordered so
/// the longer "en halv timme" wins over a bare "timme" suffix elsewhere.
/// Quarter-forms: "en kvart" = 15 min, "tre kvart"/"tre kvartar" = 45 min.
final RegExp _wordDurationPattern = RegExp(
  r'\b(en\s+halvtimme|en\s+halv\s+timme|tre\s+kvartar|tre\s+kvart|en\s+kvart|en\s+timme)\b',
  caseSensitive: false,
);

Duration? _wordPhraseToDuration(String phrase) {
  final normalized = phrase.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return switch (normalized) {
    'en halvtimme' || 'en halv timme' => const Duration(minutes: 30),
    'en kvart' => const Duration(minutes: 15),
    'tre kvart' || 'tre kvartar' => const Duration(minutes: 45),
    'en timme' => const Duration(hours: 1),
    _ => null,
  };
}

/// A parsed duration plus the character span of the phrase that produced it
/// (BUT-604) — lets UI render the phrase itself as a tappable timer chip.
class DurationMatch {
  final Duration duration;

  /// Start offset (inclusive) of the matched phrase in the source line.
  final int start;

  /// End offset (exclusive) of the matched phrase in the source line.
  final int end;

  const DurationMatch({
    required this.duration,
    required this.start,
    required this.end,
  });
}

/// Parses the first duration mention in a Swedish cooking instruction.
///
/// Returns `null` when:
/// - the line has no time token,
/// - the parsed value is `≤ 0`, or
/// - the parsed value exceeds [_maxDuration] (12 hours).
///
/// Examples:
/// ```dart
/// parseSwedishDuration('Låt koka i 10 min')           // 10 minutes
/// parseSwedishDuration('ca 20 minuter')               // 20 minutes
/// parseSwedishDuration('Grädda i 10-15 min')          // 15 minutes (upper)
/// parseSwedishDuration('Låt stå i 1 timme')           // 1 hour
/// parseSwedishDuration('Vila en halvtimme')           // 30 minutes (BUT-604)
/// parseSwedishDuration('Jäs en kvart')                // 15 minutes (BUT-604)
/// parseSwedishDuration('Koka i 24 timmar')            // null (out of range)
/// parseSwedishDuration('Rör ner smöret')              // null (no time)
/// ```
Duration? parseSwedishDuration(String line) =>
    parseSwedishDurationMatch(line)?.duration;

/// Span-aware variant of [parseSwedishDuration] (BUT-604): returns the first
/// duration mention together with the character range of the matched phrase,
/// so callers can render that phrase as an inline tappable chip. Same
/// null-contract as [parseSwedishDuration]. When both a numeric and a
/// word-phrase mention exist, the one appearing first in the line wins.
DurationMatch? parseSwedishDurationMatch(String line) {
  if (line.isEmpty) return null;

  final numeric = _firstNumericMatch(line);
  final word = _firstWordMatch(line);

  if (numeric == null) return word;
  if (word == null) return numeric;
  return numeric.start <= word.start ? numeric : word;
}

DurationMatch? _firstNumericMatch(String line) {
  final match = _durationPattern.firstMatch(line);
  if (match == null) return null;

  final valueStr = match.group(2);
  final unit = match.group(3)?.toLowerCase();
  if (valueStr == null || unit == null) return null;

  final value = double.tryParse(valueStr.replaceAll(',', '.'));
  if (value == null) return null;

  final duration = _toDuration(value, unit);
  if (duration == null) return null;

  // Clamp: reject non-positive and anything longer than 12h.
  if (duration <= Duration.zero) return null;
  if (duration > _maxDuration) return null;

  return DurationMatch(
    duration: duration,
    start: match.start,
    end: match.end,
  );
}

DurationMatch? _firstWordMatch(String line) {
  final match = _wordDurationPattern.firstMatch(line);
  if (match == null) return null;

  final duration = _wordPhraseToDuration(match.group(1)!);
  if (duration == null) return null;

  return DurationMatch(
    duration: duration,
    start: match.start,
    end: match.end,
  );
}

/// Converts a (value, unit-token) pair into a [Duration]. Unit tokens are
/// matched against the Swedish short- and long-forms supported by the regex.
Duration? _toDuration(double value, String unit) {
  // Microseconds preserves decimals like 1.5 h → 1h30m without drifting.
  final micros = switch (unit) {
    'h' ||
    'tim' ||
    'tmr' ||
    'timar' ||
    'timme' ||
    'timmar' => (value * Duration.microsecondsPerHour).round(),
    'min' ||
    'minut' ||
    'minuter' => (value * Duration.microsecondsPerMinute).round(),
    's' ||
    'sek' ||
    'sekund' ||
    'sekunder' => (value * Duration.microsecondsPerSecond).round(),
    _ => null,
  };
  if (micros == null) return null;
  return Duration(microseconds: micros);
}
