/// Unit tests for TextFormatting - Swedish text formatting and number processing
///
/// Tests comprehensive Swedish text formatting including:
/// - Unicode normalization and cleanup
/// - Swedish decimal comma notation
/// - Unicode fraction formatting (½, ¼, ¾)
/// - Portion and time pattern detection
/// - Number parsing with cultural adaptation
/// - Edge cases and boundary conditions
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/utils/text/text_formatting.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('TextFormatting', () {
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    group('Normalize Text', () {
      test('should remove mathematical Unicode styling', () {
        // Mathematical bold letters (U+1D400-U+1D7FF range)
        expect(TextFormatting.normalizeText('𝐀𝐁𝐂'), equals('ABC'));
        expect(TextFormatting.normalizeText('𝐚𝐛𝐜'), equals('abc'));
        expect(TextFormatting.normalizeText('𝟏𝟐𝟑'), equals('123'));
      });

      test('should normalize whitespace to single spaces', () {
        expect(
          TextFormatting.normalizeText('  multiple   spaces  '),
          equals('multiple spaces'),
        );
        expect(
          TextFormatting.normalizeText('tabs\t\there'),
          equals('tabs here'),
        );
        expect(
          TextFormatting.normalizeText('newlines\n\nhere'),
          equals('newlines here'),
        );
        expect(
          TextFormatting.normalizeText('\r\nwindows\r\nline\r\nbreaks\r\n'),
          equals('windows line breaks'),
        );
      });

      test('should handle mixed Unicode and whitespace', () {
        expect(
          TextFormatting.normalizeText('𝐀𝐁𝐂   text'),
          equals('ABC text'),
        );
        expect(
          TextFormatting.normalizeText('  𝐚𝐛𝐜  mixed  '),
          equals('abc mixed'),
        );
        expect(
          TextFormatting.normalizeText('𝟏𝟐𝟑\t\nnumbers'),
          equals('123 numbers'),
        );
      });

      test('should preserve standard characters', () {
        expect(TextFormatting.normalizeText('ABC123'), equals('ABC123'));
        expect(TextFormatting.normalizeText('åäö ÅÄÖ'), equals('åäö ÅÄÖ'));
        expect(
          TextFormatting.normalizeText('special!@#'),
          equals('special!@#'),
        );
      });

      test('should handle empty and edge cases', () {
        expect(TextFormatting.normalizeText(''), equals(''));
        expect(TextFormatting.normalizeText('   '), equals(''));
        expect(TextFormatting.normalizeText('\t\n\r'), equals(''));
        expect(TextFormatting.normalizeText('a'), equals('a'));
      });
    });

    group('Is Portion Or Time Line', () {
      test('should detect portion indicators', () {
        expect(TextFormatting.isPortionOrTimeLine('4 portioner'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('2 port'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('6 pers'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('8 personer'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('10 st'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('12 stycken'), isTrue);
      });

      test('should detect time indicators', () {
        expect(TextFormatting.isPortionOrTimeLine('15 min'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('30 minuter'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('45 min ugnstid'), isTrue);
        expect(
          TextFormatting.isPortionOrTimeLine('Tillagning: 20 minuter'),
          isTrue,
        );
      });

      test('should detect ranges', () {
        expect(TextFormatting.isPortionOrTimeLine('4-6 portioner'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('2 - 4 pers'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('10-15 min'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('20 - 30 minuter'), isTrue);
      });

      test('should be case insensitive', () {
        expect(TextFormatting.isPortionOrTimeLine('4 PORTIONER'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('15 MIN'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('2 Pers'), isTrue);
        expect(TextFormatting.isPortionOrTimeLine('30 Minuter'), isTrue);
      });

      test('should reject non-matching text', () {
        expect(TextFormatting.isPortionOrTimeLine('ingrediens'), isFalse);
        expect(TextFormatting.isPortionOrTimeLine('mjölk'), isFalse);
        expect(
          TextFormatting.isPortionOrTimeLine('portioner utan nummer'),
          isFalse,
        );
        expect(
          TextFormatting.isPortionOrTimeLine('minuter utan nummer'),
          isFalse,
        );
        expect(TextFormatting.isPortionOrTimeLine(''), isFalse);
      });

      test('should handle embedded patterns', () {
        expect(
          TextFormatting.isPortionOrTimeLine('Receptet ger 4 portioner'),
          isTrue,
        );
        expect(
          TextFormatting.isPortionOrTimeLine('Baka i 25 minuter i ugn'),
          isTrue,
        );
        expect(TextFormatting.isPortionOrTimeLine('För 2-3 personer'), isTrue);
      });
    });

    group('Format Fractional', () {
      test('should format decimals with Swedish comma', () {
        expect(TextFormatting.formatFractional(2.5), equals('2,5'));
        expect(TextFormatting.formatFractional(3.14), equals('3,14'));
        expect(TextFormatting.formatFractional(0.5), equals('0,5'));
        expect(TextFormatting.formatFractional(1.25), equals('1,25'));
      });

      test('should handle whole numbers without decimals', () {
        expect(TextFormatting.formatFractional(1.0), equals('1'));
        expect(TextFormatting.formatFractional(5.0), equals('5'));
        expect(TextFormatting.formatFractional(100.0), equals('100'));
        expect(TextFormatting.formatFractional(0.0), equals('0'));
      });

      test('should remove trailing zeros', () {
        expect(TextFormatting.formatFractional(2.10), equals('2,1'));
        expect(TextFormatting.formatFractional(3.20), equals('3,2'));
        expect(TextFormatting.formatFractional(4.50), equals('4,5'));
        expect(TextFormatting.formatFractional(1.00), equals('1'));
      });

      test('should limit to 2 decimal places', () {
        expect(TextFormatting.formatFractional(1.999), equals('2'));
        expect(TextFormatting.formatFractional(2.111), equals('2,11'));
        expect(TextFormatting.formatFractional(3.456), equals('3,46'));
        expect(TextFormatting.formatFractional(0.001), equals('0'));
      });

      test('should handle negative numbers', () {
        expect(TextFormatting.formatFractional(-2.5), equals('-2,5'));
        expect(TextFormatting.formatFractional(-1.0), equals('-1'));
        expect(TextFormatting.formatFractional(-0.5), equals('-0,5'));
        expect(TextFormatting.formatFractional(-3.14), equals('-3,14'));
      });

      test('should handle edge cases', () {
        expect(TextFormatting.formatFractional(0.001), equals('0'));
        expect(TextFormatting.formatFractional(0.004), equals('0'));
        expect(TextFormatting.formatFractional(0.005), equals('0,01'));
        expect(TextFormatting.formatFractional(999.99), equals('999,99'));
      });
    });

    group('Parse Swedish Number', () {
      test('should parse Swedish decimal comma format', () {
        expect(TextFormatting.parseSwedishNumber('2,5'), equals(2.5));
        expect(TextFormatting.parseSwedishNumber('3,14'), equals(3.14));
        expect(TextFormatting.parseSwedishNumber('0,5'), equals(0.5));
        expect(TextFormatting.parseSwedishNumber('100,25'), equals(100.25));
      });

      test('should parse international decimal point format', () {
        expect(TextFormatting.parseSwedishNumber('2.5'), equals(2.5));
        expect(TextFormatting.parseSwedishNumber('3.14'), equals(3.14));
        expect(TextFormatting.parseSwedishNumber('0.5'), equals(0.5));
        expect(TextFormatting.parseSwedishNumber('100.25'), equals(100.25));
      });

      test('should parse whole numbers', () {
        expect(TextFormatting.parseSwedishNumber('1'), equals(1.0));
        expect(TextFormatting.parseSwedishNumber('42'), equals(42.0));
        expect(TextFormatting.parseSwedishNumber('100'), equals(100.0));
        expect(TextFormatting.parseSwedishNumber('0'), equals(0.0));
      });

      test('should handle whitespace', () {
        expect(TextFormatting.parseSwedishNumber(' 2,5 '), equals(2.5));
        expect(TextFormatting.parseSwedishNumber('\t3.14\t'), equals(3.14));
        expect(TextFormatting.parseSwedishNumber('  42  '), equals(42.0));
        expect(TextFormatting.parseSwedishNumber('\n1,5\n'), equals(1.5));
      });

      test('should handle negative numbers', () {
        expect(TextFormatting.parseSwedishNumber('-2,5'), equals(-2.5));
        expect(TextFormatting.parseSwedishNumber('-3.14'), equals(-3.14));
        expect(TextFormatting.parseSwedishNumber('-42'), equals(-42.0));
        expect(TextFormatting.parseSwedishNumber('-0,5'), equals(-0.5));
      });

      test('should return 1.0 for invalid input', () {
        expect(TextFormatting.parseSwedishNumber(''), equals(1.0));
        expect(TextFormatting.parseSwedishNumber('abc'), equals(1.0));
        expect(TextFormatting.parseSwedishNumber('2,5,3'), equals(1.0));
        expect(TextFormatting.parseSwedishNumber('två'), equals(1.0));
        expect(TextFormatting.parseSwedishNumber('NaN'), equals(1.0));
      });
    });

    group('To Swedish Half Fraction', () {
      test('should format half fractions', () {
        expect(TextFormatting.toSwedishHalfFraction(0.5), equals('½'));
        expect(TextFormatting.toSwedishHalfFraction(1.5), equals('1 ½'));
        expect(TextFormatting.toSwedishHalfFraction(2.5), equals('2 ½'));
        expect(TextFormatting.toSwedishHalfFraction(10.5), equals('10 ½'));
      });

      test('should format quarter fractions', () {
        expect(TextFormatting.toSwedishHalfFraction(0.25), equals('¼'));
        expect(TextFormatting.toSwedishHalfFraction(1.25), equals('1 ¼'));
        expect(TextFormatting.toSwedishHalfFraction(2.25), equals('2 ¼'));
        expect(TextFormatting.toSwedishHalfFraction(5.25), equals('5 ¼'));
      });

      test('should format three-quarter fractions', () {
        expect(TextFormatting.toSwedishHalfFraction(0.75), equals('¾'));
        expect(TextFormatting.toSwedishHalfFraction(1.75), equals('1 ¾'));
        expect(TextFormatting.toSwedishHalfFraction(2.75), equals('2 ¾'));
        expect(TextFormatting.toSwedishHalfFraction(3.75), equals('3 ¾'));
      });

      test('should handle floating-point precision', () {
        expect(TextFormatting.toSwedishHalfFraction(0.5001), equals('½'));
        expect(TextFormatting.toSwedishHalfFraction(0.4999), equals('½'));
        expect(TextFormatting.toSwedishHalfFraction(0.2501), equals('¼'));
        expect(TextFormatting.toSwedishHalfFraction(0.2499), equals('¼'));
        expect(TextFormatting.toSwedishHalfFraction(0.7501), equals('¾'));
        expect(TextFormatting.toSwedishHalfFraction(0.7499), equals('¾'));
      });

      test('should display third fractions with unicode symbols', () {
        expect(TextFormatting.toSwedishHalfFraction(1.0 / 3), equals('⅓'));
        expect(
          TextFormatting.toSwedishHalfFraction(1 + 1.0 / 3),
          equals('1 ⅓'),
        );
        expect(TextFormatting.toSwedishHalfFraction(2.0 / 3), equals('⅔'));
        expect(
          TextFormatting.toSwedishHalfFraction(2 + 2.0 / 3),
          equals('2 ⅔'),
        );
      });

      test('should fallback to decimal format for non-fractions', () {
        expect(TextFormatting.toSwedishHalfFraction(0.1), equals('0,1'));
        expect(TextFormatting.toSwedishHalfFraction(3.14), equals('3,14'));
      });

      test('should handle whole numbers', () {
        expect(TextFormatting.toSwedishHalfFraction(1.0), equals('1'));
        expect(TextFormatting.toSwedishHalfFraction(5.0), equals('5'));
        expect(TextFormatting.toSwedishHalfFraction(0.0), equals('0'));
        expect(TextFormatting.toSwedishHalfFraction(100.0), equals('100'));
      });

      test('should handle negative fractions', () {
        expect(TextFormatting.toSwedishHalfFraction(-0.5), equals('-½'));
        expect(TextFormatting.toSwedishHalfFraction(-1.5), equals('-1 ½'));
        expect(TextFormatting.toSwedishHalfFraction(-0.25), equals('-¼'));
        expect(TextFormatting.toSwedishHalfFraction(-0.75), equals('-¾'));
        expect(TextFormatting.toSwedishHalfFraction(-2.5), equals('-2 ½'));
      });
    });

    group('Legacy Function Exports', () {
      test('should export normalizeText function', () {
        expect(normalizeText('  test  '), equals('test'));
        expect(normalizeText('𝐀𝐁𝐂'), equals('ABC'));
      });

      test('should export isPortionOrTimeLine function', () {
        expect(isPortionOrTimeLine('4 portioner'), isTrue);
        expect(isPortionOrTimeLine('30 min'), isTrue);
        expect(isPortionOrTimeLine('ingrediens'), isFalse);
      });

      test('should export formatFractional function', () {
        expect(formatFractional(2.5), equals('2,5'));
        expect(formatFractional(3.0), equals('3'));
      });

      test('should export parseSwedishNumber function', () {
        expect(parseSwedishNumber('2,5'), equals(2.5));
        expect(parseSwedishNumber('3.14'), equals(3.14));
      });

      test('should export toSwedishHalfFraction function', () {
        expect(toSwedishHalfFraction(0.5), equals('½'));
        expect(toSwedishHalfFraction(1.5), equals('1 ½'));
      });
    });

    group('Edge Cases and Special Values', () {
      test('should handle very large numbers', () {
        expect(TextFormatting.formatFractional(999999.99), equals('999999,99'));
        expect(
          TextFormatting.parseSwedishNumber('999999,99'),
          equals(999999.99),
        );
        expect(
          TextFormatting.toSwedishHalfFraction(999999.5),
          equals('999999 ½'),
        );
      });

      test('should handle very small numbers', () {
        expect(TextFormatting.formatFractional(0.001), equals('0'));
        expect(TextFormatting.formatFractional(0.01), equals('0,01'));
        expect(TextFormatting.parseSwedishNumber('0,001'), equals(0.001));
      });

      test('should handle special float values', () {
        expect(TextFormatting.formatFractional(0.0), equals('0'));
        expect(TextFormatting.formatFractional(-0.0), equals('0'));

        // Infinity and NaN cases
        expect(
          TextFormatting.toSwedishHalfFraction(double.infinity),
          equals('∞'),
        );
        expect(
          TextFormatting.toSwedishHalfFraction(double.negativeInfinity),
          equals('-∞'),
        );
        expect(TextFormatting.toSwedishHalfFraction(double.nan), equals('NaN'));
      });

      test('should handle Unicode edge cases in normalizeText', () {
        // Empty Unicode range
        expect(
          TextFormatting.normalizeText('\u{1D3FF}'),
          equals('\u{1D3FF}'),
        ); // Just before range
        expect(
          TextFormatting.normalizeText('\u{1D800}'),
          equals('\u{1D800}'),
        ); // Just after range

        // Mixed content
        expect(
          TextFormatting.normalizeText('Normal 𝐀𝐁𝐂 text'),
          equals('Normal ABC text'),
        );
      });
    });
  });
}
