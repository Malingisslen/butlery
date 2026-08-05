import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// Finds a recipe's cooking time by reading the LABEL that introduces it, not
/// by grabbing the first number on the page.
///
/// What this actually adds over `TextImportStrategy._extractTime` is narrower
/// than it looks, and worth stating so nobody re-derives it: that method's
/// FIRST pattern is already `tid\s*:\s*(\d+)\s*min`, so simple labelled lines
/// were never the problem. The genuinely new behaviour is three things —
/// waiting time is REJECTED rather than mistaken for the answer, a total
/// outranks a phase regardless of which appears first, and the composite
/// "1 timme och 10 minuter" is summed instead of read as 60.
///
/// Waiting is not work: `Vilotid` and `Kyltid` are recognised precisely so they
/// can be refused. Returns null rather than guessing, so the caller's cruder
/// fallback still covers pages that carry no label at all.
class RecipeTimeExtractor {
  const RecipeTimeExtractor._();

  /// Mirrors `DurationParser`'s own 12-hour sanity cap. Kept here because the
  /// composite branch never reaches that parser.
  static const int _maxMinutes = 12 * 60;

  /// Labels that mean "this is how long the dish takes". Ranked: an explicit
  /// total wins over a single phase, because a page carrying both means the
  /// phase is one part of the total, not the whole.
  ///
  /// Bare `tid` needs BOTH guards: the boundary helper stops it matching inside
  /// `koktid` / `vilotid` / `arbetstid`, and the colon stops it firing inside
  /// ordinary prose — "Ta ut smöret i god tid, ca 20 min innan" was otherwise
  /// read as a 20-minute dish total. The compound labels need no colon; the
  /// corpus writes "Tillagningstid 40 minuter" without one.
  static final RegExp _totalPattern = RegExp(
    '${SwedishWordBoundary.bounded(r"tillagningstid|total\s+tid|totaltid")}'
    '|'
    '${SwedishWordBoundary.before}'
    r'tid(?=\s*:)',
    caseSensitive: false,
  );

  static final RegExp _phasePattern = _labels([
    'koktid',
    'gräddningstid',
    'bakningstid',
    'friteringstid',
    'stektid',
    'ugnstid',
  ]);

  /// Time the cook waits through rather than works through. Never the answer —
  /// listed so it can be actively refused.
  static final RegExp _waitPattern = _labels([
    'vilotid',
    'kyltid',
    'jästid',
    'marineringstid',
    'svalningstid',
  ]);

  /// One pre-compiled bounded alternation per group. Built once: this runs per
  /// line of every imported recipe, and compiling a RegExp per label per line
  /// cost hundreds of compilations on a single cookbook page.
  static RegExp _labels(List<String> labels) =>
      SwedishWordBoundary.boundedRegExp(
        labels.map(RegExp.escape).join('|'),
        caseSensitive: false,
      );

  /// The dish's time in minutes, or null when no labelled time is present.
  ///
  /// Null is a real answer meaning "this text does not say" — the caller
  /// decides whether to fall back to something cruder. It is deliberately not
  /// 0 and not a guess, and [_minutesFrom] enforces that.
  static int? extract(String text) {
    if (text.isEmpty) return null;

    int? total;
    int? phase;
    for (final line in text.split('\n')) {
      final lower = line.toLowerCase();
      final hasTotal = _totalPattern.hasMatch(lower);
      final hasPhase = _phasePattern.hasMatch(lower);

      // A wait label only discards the line when nothing on it is work. OCR
      // collapses adjacent bullet rows, and a merged
      // "Tillagningstid: 45 minuter Vilotid: 2 timmar" used to be skipped
      // whole — handing the answer to the fallback, which returned the 2
      // hours this class exists to refuse.
      if (!hasTotal && !hasPhase) continue;

      if (total == null && hasTotal) {
        total = _minutesAfter(line, _totalPattern);
      } else if (phase == null && hasPhase) {
        phase = _minutesAfter(line, _phasePattern);
      }
      if (total != null) break;
    }
    return total ?? phase;
  }

  /// Reads the duration that FOLLOWS the label, stopping at any wait label
  /// further along the same line. Reading the whole line instead would take
  /// whichever number came first, which on a collapsed row is a coin flip.
  static int? _minutesAfter(String line, RegExp label) {
    final at = label.firstMatch(line.toLowerCase());
    if (at == null) return null;
    var tail = line.substring(at.end);
    final wait = _waitPattern.firstMatch(tail.toLowerCase());
    if (wait != null) tail = tail.substring(0, wait.start);
    return _minutesFrom(tail);
  }

  /// `DurationParser` owns every ordinary form ("45 minuter", "1 timme",
  /// "ca 20 min", "en halvtimme"). It cannot own the COMPOSITE — it returns
  /// the FIRST match, so "1 timme och 10 minuter" would come back as 60. The
  /// corpus carries that form on real pages, and
  /// `potatisratter/PXL_20260602_192552636/recipe-01` is a verified gold of 70.
  /// So the composite is summed here and everything else is delegated.
  static int? _minutesFrom(String line) {
    final composite = _compositePattern.firstMatch(line);
    if (composite != null) {
      final hours = int.tryParse(composite.group(1).orEmpty());
      final minutes = int.tryParse(composite.group(2).orEmpty());
      if (hours != null && minutes != null) {
        // Bounded by the SAME contract as the delegate below, because this
        // branch returns before ever reaching it. Unbounded it answered 0 for
        // "0 tim 0 min" — non-null, so it wins the caller's `??` and suppresses
        // the fallback — and 6939 for "99 timmar och 999 min", walking past
        // DurationParser's own 12-hour sanity cap.
        final summed = hours * 60 + minutes;
        if (summed >= 1 && summed <= _maxMinutes) return summed;
      }
    }
    final parsed = parseSwedishDuration(line)?.inMinutes;
    // NB: `parseSwedishDuration` already applies [_maxMinutes] itself; the
    // check below is only the sub-minute floor.
    // Below a minute truncates to 0, and 0 is NOT null — it would win the
    // caller's `??`, suppress the fallback that had the right answer, and land
    // in `Recipe.timeMinutes`, where `recipe_operations.dart` treats `<= 0` as
    // a validation failure. "Friteringstid: 45 sekunder" is a real label.
    return (parsed == null || parsed < 1) ? null : parsed;
  }

  /// `1 timme och 10 minuter` → 70.
  ///
  /// Every boundary here is load-bearing and each one has a failing input:
  /// - the leading lookbehind stops the hour group eating the decimal half of
  ///   "1,5 timme 20 min" (which read as 5 h + 20 min = 320);
  /// - [SwedishWordBoundary.after], never ASCII `\b`, because `\b` fires
  ///   between `h` and `å` — "2 hål i degen, 20 min" read as 140 (BUT-1691,
  ///   the phantom-boundary direction);
  /// - an explicit joiner instead of a permissive `[^0-9]{0,12}?` bridge, so
  ///   "1 timme, ca 20 min per sida" is left to `DurationParser` (60) rather
  ///   than summed into 80.
  static final RegExp _compositePattern = RegExp(
    r'(?<![0-9,.])(\d{1,2})\s*(?:timm(?:e|ar)|tim|h)'
    '${SwedishWordBoundary.after}'
    r'\s*(?:och\s+|,\s*)?(\d{1,3})\s*min',
    caseSensitive: false,
  );
}
