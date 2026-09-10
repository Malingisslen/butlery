/// Unit tests for QuantityParser - quantity string parsing
///
/// Tests Phase 0.9 quantity parsing including:
/// - Unicode fraction parsing (half, quarter, three-quarter)
/// - Mixed fraction parsing (whole + fraction)
/// - Decimal parsing with comma and period
/// - Whole number parsing
/// - ASCII fraction parsing (1/2, 3/4, 1 1/2)
/// - Invalid input handling with default fallback
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/quantity_parser.dart';

void main() {
  group('QuantityParser', () {
    group('Unicode fractions', () {
      test('should parse half fraction', () {
        expect(QuantityParser.parse('\u00BD'), equals(0.5));
      });

      test('should parse quarter fraction', () {
        expect(QuantityParser.parse('\u00BC'), equals(0.25));
      });

      test('should parse three-quarter fraction', () {
        expect(QuantityParser.parse('\u00BE'), equals(0.75));
      });

      test(
        'BUT-804 HIGH-AI7: parses the previously-missing Unicode fractions',
        () {
          // Without these, ingredient lines using these fractions fell
          // through to parse()'s 1.0 fallback. Each is from the Unicode
          // "Number Forms" block (U+2150\u2013U+215E).
          expect(QuantityParser.parse('\u2158'), closeTo(0.8, 1e-9)); // \u2158
          expect(
            QuantityParser.parse('\u2159'),
            closeTo(1 / 6, 1e-9),
          ); // \u2159
          expect(
            QuantityParser.parse('\u215A'),
            closeTo(5 / 6, 1e-9),
          ); // \u215A
          expect(
            QuantityParser.parse('\u2150'),
            closeTo(1 / 7, 1e-9),
          ); // \u2150
          expect(
            QuantityParser.parse('\u2151'),
            closeTo(1 / 9, 1e-9),
          ); // \u2151
          expect(QuantityParser.parse('\u2152'), equals(0.1)); // \u2152
        },
      );
    });

    group('Mixed fractions (whole + Unicode)', () {
      test('should parse whole number plus half', () {
        expect(QuantityParser.parse('2 \u00BD'), equals(2.5));
      });

      test('should parse whole number plus quarter', () {
        expect(QuantityParser.parse('1 \u00BC'), equals(1.25));
      });

      test('should parse whole number plus three-quarter', () {
        expect(QuantityParser.parse('3 \u00BE'), equals(3.75));
      });

      test('should parse large whole number plus half', () {
        expect(QuantityParser.parse('10 \u00BD'), equals(10.5));
      });
    });

    group('Decimal numbers', () {
      test('should parse Swedish comma decimal', () {
        expect(QuantityParser.parse('2,5'), equals(2.5));
      });

      test('should parse Swedish comma decimal with more precision', () {
        expect(QuantityParser.parse('3,14'), equals(3.14));
      });

      test('should parse period decimal', () {
        expect(QuantityParser.parse('3.14'), equals(3.14));
      });

      test('should parse leading zero comma decimal', () {
        expect(QuantityParser.parse('0,5'), equals(0.5));
      });

      test('should parse leading zero period decimal', () {
        expect(QuantityParser.parse('0.5'), equals(0.5));
      });
    });

    group('Whole numbers', () {
      test('should parse small whole number', () {
        expect(QuantityParser.parse('1'), equals(1.0));
      });

      test('should parse medium whole number', () {
        expect(QuantityParser.parse('400'), equals(400.0));
      });

      test('should parse large whole number', () {
        expect(QuantityParser.parse('1000'), equals(1000.0));
      });
    });

    group('Invalid input defaults to 1.0', () {
      test('should return 1.0 for empty string', () {
        expect(QuantityParser.parse(''), equals(1.0));
      });

      test('should return 1.0 for whitespace', () {
        expect(QuantityParser.parse(' '), equals(1.0));
      });

      test('should return 1.0 for alphabetic input', () {
        expect(QuantityParser.parse('abc'), equals(1.0));
      });
    });

    group('Trimming', () {
      test('should trim whitespace around Unicode fraction', () {
        expect(QuantityParser.parse(' \u00BD '), equals(0.5));
      });

      test('should trim whitespace around number', () {
        expect(QuantityParser.parse('  400  '), equals(400.0));
      });
    });

    group('ASCII fractions (parseAsciiFraction)', () {
      test('should parse simple 1/2 fraction', () {
        expect(QuantityParser.parseAsciiFraction('1/2'), equals(0.5));
      });

      test('should parse simple 3/4 fraction', () {
        expect(QuantityParser.parseAsciiFraction('3/4'), equals(0.75));
      });

      test('should parse simple 1/4 fraction', () {
        expect(QuantityParser.parseAsciiFraction('1/4'), equals(0.25));
      });

      test('should parse simple 1/3 fraction', () {
        final result = QuantityParser.parseAsciiFraction('1/3');
        expect(result, isNotNull);
        expect(result, closeTo(0.333, 0.001));
      });

      test('should parse mixed 1 1/2 fraction', () {
        expect(QuantityParser.parseAsciiFraction('1 1/2'), equals(1.5));
      });

      test('should parse mixed 2 1/4 fraction', () {
        expect(QuantityParser.parseAsciiFraction('2 1/4'), equals(2.25));
      });

      test('should parse mixed 3 3/4 fraction', () {
        expect(QuantityParser.parseAsciiFraction('3 3/4'), equals(3.75));
      });

      test('should return null for non-fraction input', () {
        expect(QuantityParser.parseAsciiFraction('abc'), isNull);
      });

      test('should return null for empty input', () {
        expect(QuantityParser.parseAsciiFraction(''), isNull);
      });

      test('should return null for whole number', () {
        expect(QuantityParser.parseAsciiFraction('5'), isNull);
      });

      test('should return null for division by zero', () {
        expect(QuantityParser.parseAsciiFraction('1/0'), isNull);
      });

      test('should return null for mixed fraction with zero denominator', () {
        expect(QuantityParser.parseAsciiFraction('2 1/0'), isNull);
      });

      test(
        'returns null (no FormatException) for digit runs that overflow int',
        () {
          // A 64-bit int cannot hold this; int.parse would throw. tryParse must
          // make the parser degrade gracefully instead of crashing the caller.
          final huge = '9' * 40;
          expect(QuantityParser.parseAsciiFraction('1/$huge'), isNull);
          expect(QuantityParser.parseAsciiFraction('$huge/2'), isNull);
          expect(
            QuantityParser.parseAsciiFraction('$huge $huge/$huge'),
            isNull,
          );
        },
      );
    });

    group('BUT-1943: non-finite quantities never reach the amount field', () {
      // `double.tryParse` answers Infinity from 309 nines and is still finite
      // at 308. Both numbers are asserted, so a future change to the fallback
      // cannot be read as having moved the boundary.
      test('309 nines is Infinity and falls back to 1.0', () {
        expect(double.tryParse('9' * 309), equals(double.infinity));
        expect(QuantityParser.parse('9' * 309), equals(1.0));
      });

      test('308 nines is finite and is returned unchanged', () {
        final finite = double.parse('9' * 308);
        expect(finite.isFinite, isTrue);
        expect(QuantityParser.parse('9' * 308), equals(finite));
      });

      test('the unicode-fraction branch has its own guard', () {
        // This path never reaches the check on the standard branch: it parses
        // its whole part separately and returns `whole + fraction`, which is
        // Infinity when the whole part overflows.
        expect(QuantityParser.parse('${'9' * 309}½'), equals(1.0));
        // The same shape at 308 does not fall back.
        expect(
          QuantityParser.parse('${'9' * 308}½'),
          equals(double.parse('9' * 308) + 0.5),
        );
      });
    });

    // BUT-2067: the shared guard. Pinned here rather than only at the call
    // sites, because the property belongs to the helper and the call sites all
    // fall back to the same 1.0 — a fixture at one of them cannot tell this
    // guard from a neighbouring one.
    group('BUT-2067: finiteQuantityOr1 guards an arithmetic RESULT', () {
      test('a finite result passes through untouched', () {
        expect(QuantityParser.finiteQuantityOr1(2.5, 'test'), 2.5);
        expect(QuantityParser.finiteQuantityOr1(0, 'test'), 0);
        expect(
          QuantityParser.finiteQuantityOr1(double.maxFinite, 'test'),
          double.maxFinite,
        );
      });

      test('an overflow falls back to 1.0', () {
        expect(
          QuantityParser.finiteQuantityOr1(double.maxFinite * 2, 'test'),
          1.0,
        );
        expect(
          QuantityParser.finiteQuantityOr1(double.negativeInfinity, 'test'),
          1.0,
        );
      });

      // NaN is the case an `!= double.infinity` guard would let through, and
      // it is reachable rather than theoretical: `double.tryParse` accepts the
      // literal token "NaN", and `createListFromRecipe` feeds it raw
      // ingredient text. `formatSwedishDecimal` renders NaN as the word "NaN"
      // and `parseSwedishDecimal` refuses to read it back — the same dead end
      // in the amount field that this ticket exists to close.
      test('NaN falls back to 1.0', () {
        expect(QuantityParser.finiteQuantityOr1(double.nan, 'test'), 1.0);
        expect(QuantityParser.finiteQuantityOr1(0 / 0, 'test'), 1.0);
      });
    });
  });
}
