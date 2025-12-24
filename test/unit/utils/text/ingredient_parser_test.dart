/// Unit tests for IngredientParser - Swedish ingredient parsing and formatting
///
/// Tests comprehensive Swedish ingredient parsing including:
/// - Swedish fraction parsing (½, ¼, ¾)
/// - Mixed fraction formats
/// - Unit detection and extraction
/// - American to Swedish unit conversion
/// - Ingredient scaling with smart unit conversion
/// - Edge cases and error handling
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/utils/text/ingredient_parser.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('IngredientParser', () {
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

    group('Quantity Parsing', () {
      test('should parse Swedish unicode fractions', () {
        expect(IngredientParser.parseQuantity('½'), equals(0.5));
        expect(IngredientParser.parseQuantity('¼'), equals(0.25));
        expect(IngredientParser.parseQuantity('¾'), equals(0.75));
      });

      test('should parse mixed fractions with Swedish notation', () {
        expect(IngredientParser.parseQuantity('2 ½'), equals(2.5));
        expect(IngredientParser.parseQuantity('1 ¼'), equals(1.25));
        expect(IngredientParser.parseQuantity('3 ¾'), equals(3.75));
        expect(IngredientParser.parseQuantity('10 ½'), equals(10.5));
      });

      test('should parse decimal numbers with comma', () {
        expect(IngredientParser.parseQuantity('2,5'), equals(2.5));
        expect(IngredientParser.parseQuantity('3,14'), equals(3.14));
        expect(IngredientParser.parseQuantity('0,5'), equals(0.5));
        expect(IngredientParser.parseQuantity('100,25'), equals(100.25));
      });

      test('should parse decimal numbers with period', () {
        expect(IngredientParser.parseQuantity('2.5'), equals(2.5));
        expect(IngredientParser.parseQuantity('3.14'), equals(3.14));
        expect(IngredientParser.parseQuantity('0.5'), equals(0.5));
      });

      test('should parse whole numbers', () {
        expect(IngredientParser.parseQuantity('400'), equals(400.0));
        expect(IngredientParser.parseQuantity('1'), equals(1.0));
        expect(IngredientParser.parseQuantity('1000'), equals(1000.0));
      });

      test('should handle edge cases', () {
        expect(IngredientParser.parseQuantity(''), equals(1.0));
        expect(IngredientParser.parseQuantity(' '), equals(1.0));
        expect(IngredientParser.parseQuantity('abc'), equals(1.0));
        expect(IngredientParser.parseQuantity(' ½ '), equals(0.5));
      });
    });

    group('Ingredient Parsing - Swedish Format', () {
      test('should parse traditional Swedish ingredients', () {
        var result = IngredientParser.parseIngredient('2 dl mjölk');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));
        expect(result.name, equals('mjölk'));

        result = IngredientParser.parseIngredient('½ msk salt');
        expect(result.quantity, equals(0.5));
        expect(result.unit, equals('msk'));
        expect(result.name, equals('salt'));

        result = IngredientParser.parseIngredient('3 tsk vaniljsocker');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('tsk'));
        expect(result.name, equals('vaniljsocker'));
      });

      test('should parse weight measurements', () {
        var result = IngredientParser.parseIngredient('400g mjöl');
        expect(result.quantity, equals(400.0));
        expect(result.unit, equals('g'));
        expect(result.name, equals('mjöl'));

        result = IngredientParser.parseIngredient('1 kg potatis');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('kg'));
        expect(result.name, equals('potatis'));

        result = IngredientParser.parseIngredient('250 g smör');
        expect(result.quantity, equals(250.0));
        expect(result.unit, equals('g'));
        expect(result.name, equals('smör'));
      });

      test('should parse mixed fractions in ingredients', () {
        var result = IngredientParser.parseIngredient('1 ½ dl grädde');
        expect(result.quantity, equals(1.5));
        expect(result.unit, equals('dl'));
        expect(result.name, equals('grädde'));

        result = IngredientParser.parseIngredient('2 ¼ msk socker');
        expect(result.quantity, equals(2.25));
        expect(result.unit, equals('msk'));
        expect(result.name, equals('socker'));
      });

      test('should parse packaging units', () {
        var result =
            IngredientParser.parseIngredient('1 burk krossade tomater');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('burk'));
        expect(result.name, equals('krossade tomater'));

        result = IngredientParser.parseIngredient('2 pkt jäst');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('pkt'));
        expect(result.name, equals('jäst'));

        result = IngredientParser.parseIngredient('1 påse vaniljsocker');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('påse'));
        expect(result.name, equals('vaniljsocker'));
      });

      test('should parse counting units', () {
        var result = IngredientParser.parseIngredient('3 st ägg');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('st'));
        expect(result.name, equals('ägg'));

        result = IngredientParser.parseIngredient('4 klyfta vitlök');
        expect(result.quantity, equals(4.0));
        expect(result.unit, equals('klyfta'));
        expect(result.name, equals('vitlök'));

        result = IngredientParser.parseIngredient('5 skiva bröd');
        expect(result.quantity, equals(5.0));
        expect(result.unit, equals('skiva'));
        expect(result.name, equals('bröd'));
      });

      test('should parse ingredients with compound names', () {
        var result =
            IngredientParser.parseIngredient('400 g finhackad gul lök');
        expect(result.quantity, equals(400.0));
        expect(result.unit, equals('g'));
        expect(result.name, equals('finhackad gul lök'));

        result = IngredientParser.parseIngredient('2 dl vispgrädde 40%');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));
        expect(result.name, equals('vispgrädde 40%'));
      });
    });

    group('Ingredient Parsing - American Format', () {
      test('should parse cup measurements', () {
        var result = IngredientParser.parseIngredient('1 cup flour');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('cup'));
        expect(result.name, equals('flour'));

        result = IngredientParser.parseIngredient('2 cups water');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('cups'));
        expect(result.name, equals('water'));
      });

      test('should parse tablespoon and teaspoon', () {
        var result = IngredientParser.parseIngredient('2 tbsp butter');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('tbsp'));
        expect(result.name, equals('butter'));

        result = IngredientParser.parseIngredient('1 tablespoon oil');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('tablespoon'));
        expect(result.name, equals('oil'));

        result = IngredientParser.parseIngredient('½ tsp salt');
        expect(result.quantity, equals(0.5));
        expect(result.unit, equals('tsp'));
        expect(result.name, equals('salt'));
      });

      test('should parse ounces and pounds', () {
        var result = IngredientParser.parseIngredient('8 oz cheese');
        expect(result.quantity, equals(8.0));
        expect(result.unit, equals('oz'));
        expect(result.name, equals('cheese'));

        result = IngredientParser.parseIngredient('2 lb meat');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('lb'));
        expect(result.name, equals('meat'));

        result = IngredientParser.parseIngredient('3 pounds potatoes');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('pounds'));
        expect(result.name, equals('potatoes'));
      });
    });

    group('Edge Cases and Special Formats', () {
      test('should handle ingredients without units', () {
        var result = IngredientParser.parseIngredient('1 stor gul lök');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals(''));
        expect(result.name, equals('stor gul lök'));

        result = IngredientParser.parseIngredient('3 ägg');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals(''));
        expect(result.name, equals('ägg'));
      });

      test('should handle ingredients without quantities', () {
        var result = IngredientParser.parseIngredient('salt');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals(''));
        expect(result.name, equals('salt'));

        result = IngredientParser.parseIngredient('peppar efter smak');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals(''));
        expect(result.name, equals('peppar efter smak'));
      });

      test('should handle attached units', () {
        var result = IngredientParser.parseIngredient('400g kött');
        expect(result.quantity, equals(400.0));
        expect(result.unit, equals('g'));
        expect(result.name, equals('kött'));

        result = IngredientParser.parseIngredient('2dl vatten');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));
        expect(result.name, equals('vatten'));

        result = IngredientParser.parseIngredient('½dl olja');
        expect(result.quantity, equals(0.5));
        expect(result.unit, equals('dl'));
        expect(result.name, equals('olja'));
      });

      test('should handle special Swedish units', () {
        var result = IngredientParser.parseIngredient('1 krm salt');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('krm'));
        expect(result.name, equals('salt'));

        result = IngredientParser.parseIngredient('1 nypa socker');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('nypa'));
        expect(result.name, equals('socker'));

        result = IngredientParser.parseIngredient('1 skvätt vinäger');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals('skvätt'));
        expect(result.name, equals('vinäger'));
      });

      test('should handle empty and invalid input', () {
        var result = IngredientParser.parseIngredient('');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals(''));
        expect(result.name, equals(''));

        result = IngredientParser.parseIngredient('   ');
        expect(result.quantity, equals(1.0));
        expect(result.unit, equals(''));
        expect(result.name, equals(''));
      });

      test('should handle Swedish characters in names', () {
        var result = IngredientParser.parseIngredient('2 dl mjölk från Skåne');
        expect(result.quantity, equals(2.0));
        expect(result.unit, equals('dl'));
        expect(result.name,
            equals('mjölk från skåne')); // Parser lowercases the input

        result = IngredientParser.parseIngredient('100 g räkor från Smögen');
        expect(result.quantity, equals(100.0));
        expect(result.unit, equals('g'));
        expect(result.name,
            equals('räkor från smögen')); // Parser lowercases the input

        result = IngredientParser.parseIngredient('3 st ägg från höns');
        expect(result.quantity, equals(3.0));
        expect(result.unit, equals('st'));
        expect(result.name, equals('ägg från höns'));
      });
    });

    group('Ingredient Scaling and Formatting', () {
      test('should scale simple ingredients', () {
        var result =
            IngredientParser.scaleAndFormatIngredient('2 dl mjölk', 2.0);
        expect(result, contains('4'));
        expect(result, contains('dl'));
        expect(result, contains('mjölk'));

        result = IngredientParser.scaleAndFormatIngredient('400 g mjöl', 0.5);
        expect(result, contains('200'));
        expect(result, contains('g'));
        expect(result, contains('mjöl'));
      });

      test('should scale with fraction formatting', () {
        var result =
            IngredientParser.scaleAndFormatIngredient('1 dl mjölk', 0.5);
        expect(result, contains('½'));
        expect(result, contains('dl'));
        expect(result, contains('mjölk'));

        result =
            IngredientParser.scaleAndFormatIngredient('1 msk socker', 0.25);
        expect(result, contains('¼'));
        expect(result, contains('msk'));
        expect(result, contains('socker'));
      });

      test('should handle scaling edge cases', () {
        // Empty ingredient
        expect(IngredientParser.scaleAndFormatIngredient('', 2.0), equals(''));

        // Zero scale factor
        expect(
          IngredientParser.scaleAndFormatIngredient('2 dl mjölk', 0),
          equals('2 dl mjölk'),
        );

        // Negative scale factor
        expect(
          IngredientParser.scaleAndFormatIngredient('2 dl mjölk', -1),
          equals('2 dl mjölk'),
        );
      });

      test('should preserve original for ingredients without quantities', () {
        var result = IngredientParser.scaleAndFormatIngredient('salt', 2.0);
        expect(result, equals('salt'));

        result =
            IngredientParser.scaleAndFormatIngredient('peppar efter smak', 0.5);
        expect(result, equals('peppar efter smak'));
      });
    });

    group('ParsedIngredient Model', () {
      test('should create parsed ingredient correctly', () {
        const parsed = ParsedIngredient(
          quantity: 2.5,
          unit: 'dl',
          name: 'mjölk',
        );

        expect(parsed.quantity, equals(2.5));
        expect(parsed.unit, equals('dl'));
        expect(parsed.name, equals('mjölk'));
      });

      test('should generate correct key for grouping', () {
        const parsed1 = ParsedIngredient(
          quantity: 2.0,
          unit: 'dl',
          name: 'mjölk',
        );
        expect(parsed1.key, equals('dl mjölk'));

        const parsed2 = ParsedIngredient(
          quantity: 1.0,
          unit: '',
          name: 'stor lök',
        );
        expect(parsed2.key, equals('stor lök'));
      });

      test('should format toString correctly', () {
        const parsed1 = ParsedIngredient(
          quantity: 2.5,
          unit: 'dl',
          name: 'mjölk',
        );
        expect(parsed1.toString(), equals('2.5 dl mjölk'));

        const parsed2 = ParsedIngredient(
          quantity: 3.0,
          unit: '',
          name: 'ägg',
        );
        expect(parsed2.toString(), equals('3.0 ägg'));
      });

      test('should implement equality correctly', () {
        const parsed1 = ParsedIngredient(
          quantity: 2.0,
          unit: 'dl',
          name: 'mjölk',
        );

        const parsed2 = ParsedIngredient(
          quantity: 2.0,
          unit: 'dl',
          name: 'mjölk',
        );

        const parsed3 = ParsedIngredient(
          quantity: 3.0,
          unit: 'dl',
          name: 'mjölk',
        );

        expect(parsed1, equals(parsed2));
        expect(parsed1, isNot(equals(parsed3)));
      });

      test('should generate consistent hash codes', () {
        const parsed1 = ParsedIngredient(
          quantity: 2.0,
          unit: 'dl',
          name: 'mjölk',
        );

        const parsed2 = ParsedIngredient(
          quantity: 2.0,
          unit: 'dl',
          name: 'mjölk',
        );

        expect(parsed1.hashCode, equals(parsed2.hashCode));
      });
    });
  });
}
