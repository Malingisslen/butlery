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
///
/// Case-insensitive. Returns `null` when no match is found or when the parsed
/// duration falls outside `0 < x ≤ 12h` — the cooking-mode timer widget caps
/// at 2h but the parser itself rejects pathological inputs like `24 timmar`
/// to avoid surprising UX if upstream bounds change.
library;

/// Upper bound for a legal parsed duration. Anything longer is returned as
/// `null` on the assumption that it's a recipe total, not a single step.
const Duration _maxDuration = Duration(hours: 12);

/// Match groups:
/// 1. optional lower bound of a range (ignored — we use the upper bound)
/// 2. numeric value (int or decimal with `,`/`.`)
/// 3. unit token
final RegExp _durationPattern = RegExp(
  r'(?:(\d+(?:[,\.]\d+)?)\s*[-–]\s*)?'
  r'(\d+(?:[,\.]\d+)?)\s*'
  r'(timmar|timme|timar|tim|tmr|h|minuter|minut|min|sekunder|sekund|sek|s)\b',
  caseSensitive: false,
);

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
/// parseSwedishDuration('Koka i 24 timmar')            // null (out of range)
/// parseSwedishDuration('Rör ner smöret')              // null (no time)
/// ```
Duration? parseSwedishDuration(String line) {
  if (line.isEmpty) return null;

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

  return duration;
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
    'timmar' =>
      (value * Duration.microsecondsPerHour).round(),
    'min' ||
    'minut' ||
    'minuter' =>
      (value * Duration.microsecondsPerMinute).round(),
    's' ||
    'sek' ||
    'sekund' ||
    'sekunder' =>
      (value * Duration.microsecondsPerSecond).round(),
    _ => null,
  };
  if (micros == null) return null;
  return Duration(microseconds: micros);
}
