/// Unit tests for SmartUnitConverter - Swedish-American measurement conversion
///
/// Tests comprehensive unit conversion including:
/// - American to Swedish conversions (cups, oz, tbsp, tsp, etc.)
/// - Swedish unit optimization (ml->dl->l, g->kg)
/// - Readability assessment logic
/// - Edge cases and boundary conditions
/// - Precision and rounding behavior
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/utils/text/unit_converter.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('SmartUnitConverter', () {
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

    group('American to Swedish Volume Conversions', () {
      test('should convert cups to deciliters', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'cup');
        expect(result.quantity, closeTo(2.37, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'cups');
        expect(result.quantity, closeTo(4.74, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(0.5, 'cup');
        expect(result.quantity, closeTo(1.185, 0.01));
        expect(result.unit, equals('dl'));
      });

      test('should convert fluid ounces appropriately', () {
        // Small amounts -> ml
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'fl oz');
        expect(result.quantity, closeTo(29.6, 0.1));
        expect(result.unit, equals('ml'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'floz');
        expect(result.quantity, closeTo(59.2, 0.1));
        expect(result.unit, equals('ml'));

        // BUG-11: bare "oz" is now weight (not fluid ounce)
        // 4 oz → ~113.2 g
        result = SmartUnitConverter.convertToReadableUnit(4.0, 'oz');
        expect(result.quantity, closeTo(113.2, 0.1));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(10.0, 'fl oz');
        expect(result.quantity, closeTo(2.94, 0.01));
        expect(result.unit, equals('dl'));
      });

      test('should convert tablespoons to matskedar with 1:1 mapping', () {
        // 1 tbsp (14.79 ml) ≈ 1 msk (15 ml) — close enough for cooking
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'tbsp');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('msk'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'tablespoon');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('msk'));

        result = SmartUnitConverter.convertToReadableUnit(3.0, 'tablespoons');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('msk'));
      });

      test('should convert teaspoons to teskedar with 1:1 mapping', () {
        // 1 tsp (4.93 ml) ≈ 1 tsk (5 ml) — close enough for cooking
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'tsp');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('tsk'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'teaspoon');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('tsk'));

        result = SmartUnitConverter.convertToReadableUnit(0.5, 'teaspoons');
        expect(result.quantity, equals(0.5));
        expect(result.unit, equals('tsk'));
      });

      test('should convert pints to deciliters', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'pint');
        expect(result.quantity, closeTo(4.73, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'pints');
        expect(result.quantity, closeTo(9.46, 0.01));
        expect(result.unit, equals('dl'));
      });

      test('should convert quarts to deciliters', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'quart');
        expect(result.quantity, closeTo(9.46, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(0.5, 'quarts');
        expect(result.quantity, closeTo(4.73, 0.01));
        expect(result.unit, equals('dl'));
      });

      test('should convert gallons to liters', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'gallon');
        expect(result.quantity, closeTo(3.79, 0.01));
        expect(result.unit, equals('l'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'gallons');
        expect(result.quantity, closeTo(7.58, 0.01));
        expect(result.unit, equals('l'));
      });
    });

    group('American to Swedish Weight Conversions', () {
      test('should convert pounds to grams', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'lb');
        expect(result.quantity, equals(454.0));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'lbs');
        expect(result.quantity, equals(908.0));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(1.0, 'pound');
        expect(result.quantity, equals(454.0));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(3.0, 'pounds');
        expect(result.quantity, equals(1362.0));
        expect(result.unit, equals('g'));
      });

      test('should convert ounces to grams', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'ounce');
        expect(result.quantity, closeTo(28.3, 0.1));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(8.0, 'ounces');
        expect(result.quantity, closeTo(226.4, 0.1));
        expect(result.unit, equals('g'));
      });
    });

    group('Swedish Volume Optimization', () {
      test('should convert milliliters appropriately', () {
        // Small amounts stay as ml
        var result = SmartUnitConverter.convertToReadableUnit(5.0, 'ml');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('ml'));

        // 10-99 ml -> cl
        result = SmartUnitConverter.convertToReadableUnit(15.0, 'ml');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('cl'));

        result = SmartUnitConverter.convertToReadableUnit(50.0, 'ml');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('cl'));

        // 100-999 ml -> dl
        result = SmartUnitConverter.convertToReadableUnit(150.0, 'ml');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(500.0, 'ml');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('dl'));

        // 1000+ ml -> l
        result = SmartUnitConverter.convertToReadableUnit(1500.0, 'ml');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('l'));

        result = SmartUnitConverter.convertToReadableUnit(2000.0, 'ml');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('l'));
      });

      test('should convert centiliters appropriately', () {
        // Small amounts stay as cl
        var result = SmartUnitConverter.convertToReadableUnit(5.0, 'cl');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('cl'));

        // 10-99 cl -> dl
        result = SmartUnitConverter.convertToReadableUnit(15.0, 'cl');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(50.0, 'cl');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('dl'));

        // 100+ cl -> l
        result = SmartUnitConverter.convertToReadableUnit(150.0, 'cl');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('l'));
      });

      test('should convert deciliters to liters when appropriate', () {
        // Small amounts stay as dl
        var result = SmartUnitConverter.convertToReadableUnit(5.0, 'dl');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('dl'));

        // 10+ dl -> l
        result = SmartUnitConverter.convertToReadableUnit(15.0, 'dl');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('l'));

        result = SmartUnitConverter.convertToReadableUnit(10.0, 'dl');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('l'));

        result = SmartUnitConverter.convertToReadableUnit(25.0, 'dl');
        expect(result.quantity, equals(2.5));
        expect(result.unit, equals('l'));
      });
    });

    group('Swedish Weight Optimization', () {
      test('should convert grams to kilograms when appropriate', () {
        // Small amounts stay as g
        var result = SmartUnitConverter.convertToReadableUnit(500.0, 'g');
        expect(result.quantity, equals(500.0));
        expect(result.unit, equals('g'));

        // 1000+ g -> kg
        result = SmartUnitConverter.convertToReadableUnit(1000.0, 'g');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('kg'));

        result = SmartUnitConverter.convertToReadableUnit(1500.0, 'g');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('kg'));

        result = SmartUnitConverter.convertToReadableUnit(2250.0, 'g');
        expect(result.quantity, equals(2.25));
        expect(result.unit, equals('kg'));
      });

      test('should convert milligrams to grams when appropriate', () {
        // Small amounts stay as mg
        var result = SmartUnitConverter.convertToReadableUnit(500.0, 'mg');
        expect(result.quantity, equals(500.0));
        expect(result.unit, equals('mg'));

        // 1000+ mg -> g
        result = SmartUnitConverter.convertToReadableUnit(1000.0, 'mg');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('g'));

        result = SmartUnitConverter.convertToReadableUnit(5000.0, 'mg');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('g'));
      });
    });

    group('Swedish Cooking Measurements', () {
      test('should convert kryddmått to teskedar', () {
        // Small amounts stay as krm
        var result = SmartUnitConverter.convertToReadableUnit(3.0, 'krm');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('krm'));

        // 5+ krm -> tsk
        result = SmartUnitConverter.convertToReadableUnit(5.0, 'krm');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('tsk'));

        result = SmartUnitConverter.convertToReadableUnit(10.0, 'krm');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('tsk'));
      });

      test('should convert teskedar appropriately', () {
        // Small amounts stay as tsk
        var result = SmartUnitConverter.convertToReadableUnit(2.0, 'tsk');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('tsk'));

        // 3-14 tsk -> msk
        result = SmartUnitConverter.convertToReadableUnit(3.0, 'tsk');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('msk'));

        result = SmartUnitConverter.convertToReadableUnit(6.0, 'tsk');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('msk'));

        // 15+ tsk -> dl (fallback for large amounts)
        result = SmartUnitConverter.convertToReadableUnit(15.0, 'tsk');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(30.0, 'tsk');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));
      });

      test('should convert matskedar to deciliters', () {
        // Small amounts stay as msk
        var result = SmartUnitConverter.convertToReadableUnit(3.0, 'msk');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('msk'));

        // 5+ msk -> dl
        result = SmartUnitConverter.convertToReadableUnit(5.0, 'msk');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(10.0, 'msk');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(15.0, 'msk');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('dl'));
      });
    });

    group('Should Convert Logic', () {
      test('should always convert American units', () {
        expect(SmartUnitConverter.shouldConvert(1.0, 'cup'), isTrue);
        expect(SmartUnitConverter.shouldConvert(2.0, 'cups'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'tbsp'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'tablespoon'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'tsp'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'teaspoon'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'oz'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'fl oz'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'lb'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'pound'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'pint'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'quart'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1.0, 'gallon'), isTrue);
      });

      test('should convert Swedish units when appropriate', () {
        // Should convert
        expect(SmartUnitConverter.shouldConvert(1000.0, 'g'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1500.0, 'g'), isTrue);
        expect(SmartUnitConverter.shouldConvert(15.0, 'dl'), isTrue);
        expect(SmartUnitConverter.shouldConvert(1000.0, 'ml'), isTrue);
        expect(SmartUnitConverter.shouldConvert(5.0, 'krm'), isTrue);
        expect(SmartUnitConverter.shouldConvert(5.0, 'msk'), isTrue);

        // Should not convert
        expect(SmartUnitConverter.shouldConvert(500.0, 'g'), isFalse);
        expect(SmartUnitConverter.shouldConvert(5.0, 'dl'), isFalse);
        expect(
          SmartUnitConverter.shouldConvert(50.0, 'ml'),
          isTrue,
        ); // 50 ml -> 5 cl
        expect(SmartUnitConverter.shouldConvert(2.0, 'krm'), isFalse);
        expect(SmartUnitConverter.shouldConvert(2.0, 'msk'), isFalse);
      });

      test('should convert based on readability improvement', () {
        // dl to l conversion
        expect(SmartUnitConverter.shouldConvert(10.0, 'dl'), isTrue);
        expect(SmartUnitConverter.shouldConvert(15.0, 'dl'), isTrue);
        expect(SmartUnitConverter.shouldConvert(5.0, 'dl'), isFalse);

        // g to kg conversion
        expect(SmartUnitConverter.shouldConvert(1000.0, 'g'), isTrue);
        expect(SmartUnitConverter.shouldConvert(2000.0, 'g'), isTrue);
        expect(SmartUnitConverter.shouldConvert(750.0, 'g'), isFalse);

        // Small units upward conversion
        expect(SmartUnitConverter.shouldConvert(5.0, 'krm'), isTrue);
        expect(SmartUnitConverter.shouldConvert(3.0, 'tsk'), isTrue);
        expect(SmartUnitConverter.shouldConvert(5.0, 'msk'), isTrue);
      });
    });

    group('Edge Cases and Unknown Units', () {
      test('should preserve unknown units', () {
        var result = SmartUnitConverter.convertToReadableUnit(5.0, 'unknown');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('unknown'));

        result = SmartUnitConverter.convertToReadableUnit(100.0, 'xyz');
        expect(result.quantity, equals(100.0));
        expect(result.unit, equals('xyz'));
      });

      test('should handle zero quantities', () {
        var result = SmartUnitConverter.convertToReadableUnit(0.0, 'cup');
        expect(result.quantity, equals(0.0));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(0.0, 'g');
        expect(result.quantity, equals(0.0));
        expect(result.unit, equals('g'));
      });

      test('should handle negative quantities', () {
        var result = SmartUnitConverter.convertToReadableUnit(-1.0, 'cup');
        expect(result.quantity, closeTo(-2.37, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(-1000.0, 'g');
        expect(result.quantity, equals(-1.0));
        expect(result.unit, equals('kg'));
      });

      test('should handle very large quantities', () {
        var result = SmartUnitConverter.convertToReadableUnit(10000.0, 'g');
        expect(result.quantity, equals(10.0));
        expect(result.unit, equals('kg'));

        result = SmartUnitConverter.convertToReadableUnit(10000.0, 'ml');
        expect(result.quantity, equals(10.0));
        expect(result.unit, equals('l'));
      });

      test('should handle case variations', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'CUP');
        expect(result.quantity, closeTo(2.37, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(1.0, 'Cup');
        expect(result.quantity, closeTo(2.37, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(1000.0, 'G');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('kg'));
      });
    });

    group('ConvertedMeasurement', () {
      test('should create measurement correctly', () {
        final measurement = ConvertedMeasurement(2.5, 'dl');
        expect(measurement.quantity, equals(2.5));
        expect(measurement.unit, equals('dl'));
      });

      test('BUT-899: negative volume quantities convert symmetrically '
          'to mass', () {
        // The gram branch always normalised with .abs() so -500g → -0.5kg
        // (sign preserved, threshold crossed). The volume branches did
        // not, so -500ml stayed -500ml. This test pins the now-consistent
        // behaviour across all volume + spoon branches.

        // Volume: ml → l
        var result = SmartUnitConverter.convertToReadableUnit(-1500.0, 'ml');
        expect(result.quantity, equals(-1.5));
        expect(result.unit, equals('l'));

        // Volume: ml → dl
        result = SmartUnitConverter.convertToReadableUnit(-300.0, 'ml');
        expect(result.quantity, equals(-3.0));
        expect(result.unit, equals('dl'));

        // Volume: cl → l
        result = SmartUnitConverter.convertToReadableUnit(-200.0, 'cl');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('l'));

        // Volume: dl → l
        result = SmartUnitConverter.convertToReadableUnit(-20.0, 'dl');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('l'));

        // Mass: mg → g
        result = SmartUnitConverter.convertToReadableUnit(-2000.0, 'mg');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('g'));

        // Spoons: tsk → msk
        result = SmartUnitConverter.convertToReadableUnit(-6.0, 'tsk');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('msk'));

        // Spoons: msk → dl
        result = SmartUnitConverter.convertToReadableUnit(-10.0, 'msk');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('dl'));

        // krm → tsk
        result = SmartUnitConverter.convertToReadableUnit(-10.0, 'krm');
        expect(result.quantity, equals(-2.0));
        expect(result.unit, equals('tsk'));

        // Re-pin the canonical g → kg case to make the symmetry explicit.
        // Note: threshold is `abs() >= 1000`, so -1500 g → -1.5 kg.
        result = SmartUnitConverter.convertToReadableUnit(-1500.0, 'g');
        expect(result.quantity, equals(-1.5));
        expect(result.unit, equals('kg'));
      });

      test('should format toString with Swedish fractions', () {
        var measurement = ConvertedMeasurement(0.5, 'dl');
        expect(measurement.toString(), contains('½'));
        expect(measurement.toString(), contains('dl'));

        measurement = ConvertedMeasurement(1.5, 'l');
        expect(
          measurement.toString(),
          contains('1 ½'),
        ); // Space between integer and fraction
        expect(measurement.toString(), contains('l'));

        measurement = ConvertedMeasurement(2.0, 'kg');
        expect(measurement.toString(), contains('2'));
        expect(measurement.toString(), contains('kg'));
      });
    });

    // BUT-1278: the canonical-base reducer the MenuShoppingAggregator relies
    // on to sum compatible-but-different units before display. The aggregator
    // tests exercise the dl+ml / kg+g happy paths end-to-end; these pin the
    // reducer's OWN contract — every supported unit's factor, the family
    // separation invariant, and the null return that keeps non-measure units
    // (st, klyfta, unknown text) from ever being cross-merged.
    group('toCanonicalBase (BUT-1278)', () {
      test('reduces every volume unit to ml with the right factor', () {
        // Intent: a volume line in any supported unit lands in the SAME
        // base (ml) with the documented multiplier, so two volume lines can
        // be summed regardless of which unit each was written in.
        void expectMl(double q, String unit, double ml) {
          final c = SmartUnitConverter.toCanonicalBase(q, unit);
          expect(c, isNotNull, reason: '$unit must be a recognized volume');
          expect(c!.baseUnit, 'ml');
          expect(
            c.quantity,
            closeTo(ml, 1e-9),
            reason: '$q $unit should be $ml ml',
          );
        }

        expectMl(1, 'l', 1000);
        expectMl(1, 'dl', 100);
        expectMl(1, 'cl', 10);
        expectMl(1, 'ml', 1);
        expectMl(1, 'msk', 15);
        expectMl(1, 'tsk', 5);
        expectMl(1, 'krm', 1);
      });

      test('reduces every weight unit to g with the right factor', () {
        void expectG(double q, String unit, double g) {
          final c = SmartUnitConverter.toCanonicalBase(q, unit);
          expect(c, isNotNull, reason: '$unit must be a recognized weight');
          expect(c!.baseUnit, 'g');
          expect(
            c.quantity,
            closeTo(g, 1e-9),
            reason: '$q $unit should be $g g',
          );
        }

        expectG(1, 'kg', 1000);
        expectG(1, 'hg', 100); // hektogram — only reachable via this reducer
        expectG(1, 'g', 1);
        expectG(1000, 'mg', 1); // 1000 mg = 1 g, the mg factor (0.001)
      });

      test('accepts Swedish full-word + uppercase/whitespace unit forms', () {
        // Intent: aggregation lowercases/trims, but the reducer must defend
        // its own input so recipes written "Matsked"/"KILO"/" dl " still fold
        // into the same family rather than silently falling through to null.
        expect(SmartUnitConverter.toCanonicalBase(1, 'matsked')!.quantity, 15);
        expect(SmartUnitConverter.toCanonicalBase(1, 'tesked')!.quantity, 5);
        expect(SmartUnitConverter.toCanonicalBase(1, 'kilo')!.quantity, 1000);
        expect(
          SmartUnitConverter.toCanonicalBase(1, 'deciliter')!.quantity,
          100,
        );
        expect(
          SmartUnitConverter.toCanonicalBase(1, ' DL ')!.quantity,
          100,
          reason: 'unit string is lowercased + trimmed before lookup',
        );
      });

      test('returns null for unit-less counts and unknown text', () {
        // Intent: this is the guard that keeps "2 st ägg" and "1 klyfta
        // vitlök" from being cross-merged with anything — null means
        // "only sum on an exact unit-string match", never via a family.
        for (final unit in ['st', 'klyfta', 'förp', 'paket', '', 'gurkor']) {
          expect(
            SmartUnitConverter.toCanonicalBase(2, unit),
            isNull,
            reason: '"$unit" has no measurement family',
          );
        }
      });

      test(
        'volume and weight reduce to DIFFERENT bases (never cross-merge)',
        () {
          // Intent: pins the load-bearing invariant behind "200 g + 1 dl stays
          // two honest lines" — a regression that mapped g→ml (or shared a
          // base) would silently sum mass and volume into one wrong number.
          final vol = SmartUnitConverter.toCanonicalBase(1, 'dl')!;
          final weight = SmartUnitConverter.toCanonicalBase(100, 'g')!;
          expect(
            vol.baseUnit,
            isNot(weight.baseUnit),
            reason: 'volume(ml) and weight(g) must never share a base unit',
          );
        },
      );

      test('preserves sign so a stray negative is not silently zeroed', () {
        // Intent: the reducer is a multiply, not a threshold — it must carry
        // the sign through rather than clamping (matches the BUT-899
        // sign-symmetric posture of the readability converter).
        final c = SmartUnitConverter.toCanonicalBase(-2, 'dl');
        expect(c!.quantity, closeTo(-200, 1e-9));
      });
    });
  });
}
