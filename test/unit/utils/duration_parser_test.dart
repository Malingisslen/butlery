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
        parseSwedishDuration('ca 20 minuter'),
        const Duration(minutes: 20),
      );
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
          'Häll smeten i en smord form och grädda i 175°C i ca 45 minuter.',
        ),
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

    // BUT-1691, the phantom-boundary direction. The unit's trailing edge is
    // `SwedishWordBoundary.after`, never ASCII `\b`: Dart's `\b` treats å/ä/ö
    // as NON-word, so it fires between a one-letter unit and a Swedish vowel
    // and the single letter is read as a unit. Measured 2026-08-05 against a
    // `\b` replica — every fixture below came back as a real duration, and no
    // other test in this file puts å/ä/ö immediately after a unit, so the whole
    // change was unpinned here.
    test('"2 hål" is not 2 hours (ASCII \\b fires between "h" and "å")', () {
      expect(parseSwedishDuration('Gör 2 hål i degen'), isNull);
      expect(parseSwedishDuration('Stick 3 hål i locket'), isNull);
    });

    test('"30 säsonger" is not 30 seconds', () {
      expect(parseSwedishDuration('30 säsonger senare'), isNull);
    });

    test('the boundary costs no recall on real one-letter units', () {
      // Recall control for the tightening above: a legitimate unit followed by
      // a space, a normal letter or end-of-line must still parse, or the two
      // negatives above would also be satisfied by a parser gone blind.
      expect(parseSwedishDuration('1 h'), const Duration(hours: 1));
      expect(
        parseSwedishDuration('Låt stå 2 h och rör om'),
        const Duration(hours: 2),
      );
      expect(parseSwedishDuration('Vänta 30 s'), const Duration(seconds: 30));
    });
  });

  group('word-number phrases (BUT-604)', () {
    test('"en halvtimme" → 30 minutes', () {
      expect(
        parseSwedishDuration('Låt vila en halvtimme'),
        const Duration(minutes: 30),
      );
    });

    test('"en halv timme" (split form) → 30 minutes', () {
      expect(
        parseSwedishDuration('Jäs under bakduk en halv timme'),
        const Duration(minutes: 30),
      );
    });

    test('"en kvart" → 15 minutes', () {
      expect(
        parseSwedishDuration('Låt stå en kvart'),
        const Duration(minutes: 15),
      );
    });

    test('"tre kvart" → 45 minutes', () {
      expect(
        parseSwedishDuration('Grädda i ugnen tre kvart'),
        const Duration(minutes: 45),
      );
    });

    test('"en timme" → 1 hour', () {
      expect(
        parseSwedishDuration('Låt jäsa en timme'),
        const Duration(hours: 1),
      );
    });

    test('case-insensitive: "En Kvart" → 15 minutes', () {
      expect(
        parseSwedishDuration('En Kvart i kylen'),
        const Duration(minutes: 15),
      );
    });

    test('"kvart i fem" idiom without "en/tre" prefix does not match', () {
      expect(parseSwedishDuration('Servera kvart i fem'), isNull);
    });
  });

  group('parseSwedishDurationMatch — span contract (BUT-604)', () {
    test('numeric phrase span covers exactly the duration mention', () {
      const line = 'Grädda i 25 min mitt i ugnen';
      final match = parseSwedishDurationMatch(line)!;

      expect(match.duration, const Duration(minutes: 25));
      expect(
        line.substring(match.start, match.end),
        '25 min',
        reason:
            'The chip renders this substring — it must cover the '
            'value + unit, nothing else.',
      );
    });

    test('word phrase span covers exactly the phrase', () {
      const line = 'Låt vila en halvtimme innan servering';
      final match = parseSwedishDurationMatch(line)!;

      expect(match.duration, const Duration(minutes: 30));
      expect(line.substring(match.start, match.end), 'en halvtimme');
    });

    test('range span includes the lower bound', () {
      const line = 'Koka 10-15 min';
      final match = parseSwedishDurationMatch(line)!;

      expect(match.duration, const Duration(minutes: 15));
      expect(
        line.substring(match.start, match.end),
        '10-15 min',
        reason:
            'Chipping only "15 min" out of "10-15 min" would read '
            'as a different instruction.',
      );
    });

    test('earliest mention wins when numeric and word phrases coexist', () {
      const line = 'Vila en kvart, grädda sedan 25 min';
      final match = parseSwedishDurationMatch(line)!;

      expect(match.duration, const Duration(minutes: 15));
      expect(line.substring(match.start, match.end), 'en kvart');
    });

    test('no duration → null (callers fall back to plain text)', () {
      expect(parseSwedishDurationMatch('Rör ner smöret'), isNull);
    });
  });
}
