import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/utils/duration_parser.dart';

/// BUT-406: parser unit tests. Fixtures sourced from the Swedish-site HTML
/// in `test/fixtures/swedish_sites/{arla,ica}_test_data.dart` — we re-state
/// the relevant substrings here rather than parsing HTML, because the
/// parser's contract is "given an instruction line, return a Duration".
void main() {
  group('parseSwedishDuration — happy path', () {
    test('"10 min" → 10 minutes', () {
      expect(parseSwedishDuration('10 min'), const Duration(minutes: 10));
    });

    test('"10 minuter" → 10 minutes', () {
      expect(parseSwedishDuration('10 minuter'), const Duration(minutes: 10));
    });

    test('"1 minut" (singular) → 1 minute', () {
      expect(parseSwedishDuration('1 minut'), const Duration(minutes: 1));
    });

    test('"ca 20 minuter" → 20 minutes (prefix tolerated)', () {
      expect(
          parseSwedishDuration('ca 20 minuter'), const Duration(minutes: 20));
    });

    test('"Låt koka i 10 min" → 10 minutes (instruction prefix tolerated)', () {
      expect(
        parseSwedishDuration('Låt koka i 10 min'),
        const Duration(minutes: 10),
      );
    });

    test('"10-15 min" → uses upper bound (15 minutes)', () {
      expect(parseSwedishDuration('10-15 min'), const Duration(minutes: 15));
    });

    test('"10–15 min" (en-dash) → uses upper bound (15 minutes)', () {
      expect(parseSwedishDuration('10–15 min'), const Duration(minutes: 15));
    });

    test('"1 timme" → 1 hour', () {
      expect(parseSwedishDuration('1 timme'), const Duration(hours: 1));
    });

    test('"2 timmar" → 2 hours', () {
      expect(parseSwedishDuration('2 timmar'), const Duration(hours: 2));
    });

    test('"1 h" → 1 hour (English-style shorthand)', () {
      expect(parseSwedishDuration('1 h'), const Duration(hours: 1));
    });

    test('"30 sek" → 30 seconds', () {
      expect(parseSwedishDuration('30 sek'), const Duration(seconds: 30));
    });

    test('"30 sekunder" → 30 seconds', () {
      expect(
        parseSwedishDuration('30 sekunder'),
        const Duration(seconds: 30),
      );
    });

    test('decimal with comma: "1,5 h" → 1h30m', () {
      expect(
        parseSwedishDuration('1,5 h'),
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('case-insensitive: "10 MIN" → 10 minutes', () {
      expect(parseSwedishDuration('10 MIN'), const Duration(minutes: 10));
    });
  });

  group('parseSwedishDuration — real fixture phrases', () {
    // These strings appear verbatim in the Arla/ICA HTML fixtures.
    test('Arla: "Ställ smeten kallt i kylen i ca 30 minuter."', () {
      expect(
        parseSwedishDuration('Ställ smeten kallt i kylen i ca 30 minuter.'),
        const Duration(minutes: 30),
      );
    });

    test('Arla: "grädda i 175°C i ca 45 minuter."', () {
      expect(
        parseSwedishDuration(
            'Häll smeten i en smord form och grädda i 175°C i ca 45 minuter.'),
        const Duration(minutes: 45),
      );
    });

    test('ICA: "ca 10-12 minuter" → upper bound 12', () {
      expect(
        parseSwedishDuration(
          'Stek bullarna i smör på medelhög värme tills de är genomstekta, ca 10-12 minuter.',
        ),
        const Duration(minutes: 12),
      );
    });

    test('ICA: "5-10 minuter" → upper bound 10', () {
      expect(
        parseSwedishDuration(
          'För extra fluffiga pannkakor, låt smeten vila i 5-10 minuter innan stekning.',
        ),
        const Duration(minutes: 10),
      );
    });
  });

  group('parseSwedishDuration — negative cases', () {
    test('no time phrase → null', () {
      expect(parseSwedishDuration('Rör ner smöret'), isNull);
    });

    test('empty string → null', () {
      expect(parseSwedishDuration(''), isNull);
    });

    test('24 timmar (out of range ≤ 12h) → null', () {
      expect(parseSwedishDuration('Koka i 24 timmar'), isNull);
    });

    test('exactly 12h → accepted (inclusive upper bound)', () {
      expect(
        parseSwedishDuration('Jäs i 12 timmar'),
        const Duration(hours: 12),
      );
    });

    test('just over 12h → null', () {
      expect(parseSwedishDuration('13 timmar'), isNull);
    });

    test('0 min → null (not positive)', () {
      expect(parseSwedishDuration('0 min'), isNull);
    });

    test('bare number with no unit → null', () {
      expect(parseSwedishDuration('Tillsätt 10 lök'), isNull);
    });

    test('temperature (°C) is not mistaken for a duration', () {
      expect(
        parseSwedishDuration('Värm ugnen till 200 grader'),
        isNull,
      );
    });
  });
}
