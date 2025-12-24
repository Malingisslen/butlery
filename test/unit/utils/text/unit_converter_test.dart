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

        // Larger amounts -> dl
        result = SmartUnitConverter.convertToReadableUnit(4.0, 'oz');
        expect(result.quantity, closeTo(1.176, 0.01));
        expect(result.unit, equals('dl'));

        result = SmartUnitConverter.convertToReadableUnit(10.0, 'fl oz');
        expect(result.quantity, closeTo(2.94, 0.01));
        expect(result.unit, equals('dl'));
      });

      test('should convert tablespoons to matskedar', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'tbsp');
        expect(result.quantity, closeTo(0.89, 0.01));
        expect(result.unit, equals('msk'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'tablespoon');
        expect(result.quantity, closeTo(1.78, 0.01));
        expect(result.unit, equals('msk'));

        result = SmartUnitConverter.convertToReadableUnit(3.0, 'tablespoons');
        expect(result.quantity, closeTo(2.67, 0.01));
        expect(result.unit, equals('msk'));
      });

      test('should convert teaspoons to teskedar', () {
        var result = SmartUnitConverter.convertToReadableUnit(1.0, 'tsp');
        expect(result.quantity, closeTo(0.84, 0.01));
        expect(result.unit, equals('tsk'));

        result = SmartUnitConverter.convertToReadableUnit(2.0, 'teaspoon');
        expect(result.quantity, closeTo(1.68, 0.01));
        expect(result.unit, equals('tsk'));

        result = SmartUnitConverter.convertToReadableUnit(0.5, 'teaspoons');
        expect(result.quantity, closeTo(0.42, 0.01));
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
        expect(SmartUnitConverter.shouldConvert(50.0, 'ml'),
            isTrue); // 50 ml -> 5 cl
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

      test('should format toString with Swedish fractions', () {
        var measurement = ConvertedMeasurement(0.5, 'dl');
        expect(measurement.toString(), contains('½'));
        expect(measurement.toString(), contains('dl'));

        measurement = ConvertedMeasurement(1.5, 'l');
        expect(measurement.toString(),
            contains('1 ½')); // Space between integer and fraction
        expect(measurement.toString(), contains('l'));

        measurement = ConvertedMeasurement(2.0, 'kg');
        expect(measurement.toString(), contains('2'));
        expect(measurement.toString(), contains('kg'));
      });
    });
  });
}
