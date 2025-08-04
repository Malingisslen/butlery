import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/menu_service.dart';
// Menu repository not needed
import '../../../helpers/mock_factories.dart';
import '../../../helpers/test_service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}
// MockMenuRepository not needed

void main() {
  late MenuService sut;
  // MockMenuRepository not needed

  setUpAll(() {
    TestServiceLocator.initialize();
    registerFallbackValue(SharedMenuFactory.empty());
  });

  setUp(() {
    // Create instance
    sut = MenuService();
  });

  group('MenuService - NLP and Menu Generation', () {
    test('should generate menu from Swedish numeric quantities', () async {
      // Given
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Lunch'),
        RecipeFactory.build(category: 'Lunch'),
        RecipeFactory.build(category: 'Middag'),
        RecipeFactory.build(category: 'Middag'),
      ];

      // When
      final result = await sut.generateMenuFromPrompt(
        '2 frukoster och 1 lunch',
        recipes,
      );

      // Then
      expect(result['Frukost']?.length, equals(2));
      expect(result['Lunch']?.length, equals(1));
      expect(result['Middag'], isNull);
    });

    test('should generate menu from Swedish word numbers', () async {
      // Given
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Middag'),
        RecipeFactory.build(category: 'Middag'),
        RecipeFactory.build(category: 'Middag'),
        RecipeFactory.build(category: 'Middag'),
      ];

      // When
      final result = await sut.generateMenuFromPrompt(
        'tre frukoster och fyra middagar',
        recipes,
      );

      // Then
      expect(result['Frukost']?.length, equals(3));
      expect(result['Middag']?.length, equals(4));
    });

    test('should handle complex prompts with multiple separators', () async {
      // Given
      final recipes = List.generate(
          20,
          (i) => RecipeFactory.build(
                category: ['Frukost', 'Lunch', 'Middag', 'Mellanmål'][i % 4],
              ));

      // When
      final result = await sut.generateMenuFromPrompt(
        'två frukoster, tre luncher & en middag; ett mellanmål',
        recipes,
      );

      // Then
      expect(result['Frukost']?.length, equals(2));
      expect(result['Lunch']?.length, equals(3));
      expect(result['Middag']?.length, equals(1));
      expect(result['Mellanmål']?.length, equals(1));
    });

    test('should handle plural forms correctly', () async {
      // Given
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Middag'),
        RecipeFactory.build(category: 'Middag'),
      ];

      // When
      final result = await sut.generateMenuFromPrompt(
        '3 frukostar och 2 middagar', // plural forms
        recipes,
      );

      // Then
      expect(result['Frukost']?.length, equals(3));
      expect(result['Middag']?.length, equals(2));
    });

    test('should handle case variations', () async {
      // Given
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Lunch'),
        RecipeFactory.build(category: 'Middag'),
      ];

      // When
      final result = await sut.generateMenuFromPrompt(
        'EN FRUKOST och en LUNCH, 1 middag',
        recipes,
      );

      // Then
      expect(result['Frukost']?.length, equals(1));
      expect(result['Lunch']?.length, equals(1));
      expect(result['Middag']?.length, equals(1));
    });

    test('should return empty map for invalid input', () async {
      // Given
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Lunch'),
      ];

      // Test cases
      final testCases = [
        '',
        '   ',
        'invalid text without numbers',
        'hello world',
      ];

      for (final input in testCases) {
        // When
        final result = await sut.generateMenuFromPrompt(input, recipes);

        // Then
        expect(result, isEmpty, reason: 'Failed for input: "$input"');
      }
    });

    test('should handle insufficient recipes gracefully', () async {
      // Given - Only 2 breakfast recipes available
      final recipes = [
        RecipeFactory.build(category: 'Frukost'),
        RecipeFactory.build(category: 'Frukost'),
      ];

      // When - Request 5 breakfasts
      final result = await sut.generateMenuFromPrompt(
        'fem frukoster',
        recipes,
      );

      // Then - Should only return 2 (all available)
      expect(result['Frukost']?.length, equals(2));
    });

    test('should handle Swedish number words correctly', () async {
      // Given
      final recipes = List.generate(
          10,
          (i) => RecipeFactory.build(
                category: 'Frukost',
              ));

      // Test all Swedish number words
      final testCases = {
        'en frukost': 1,
        'ett mellanmål': 0, // No mellanmål available
        'två frukoster': 2,
        'tre frukoster': 3,
        'fyra frukoster': 4,
        'fem frukoster': 5,
        'sex frukoster': 6,
        'sju frukoster': 7,
        'åtta frukoster': 8,
        'nio frukoster': 9,
        'tio frukoster': 10,
      };

      for (final entry in testCases.entries) {
        // When
        final result = await sut.generateMenuFromPrompt(
          entry.key,
          recipes,
        );

        // Then
        if (entry.value > 0) {
          expect(result['Frukost']?.length, equals(entry.value),
              reason: 'Failed for: ${entry.key}');
        } else {
          expect(result, isEmpty, reason: 'Failed for: ${entry.key}');
        }
      }
    });

    test('should select random recipes from available options', () async {
      // Given - Multiple recipes of same type
      final recipes = List.generate(
          10,
          (i) => RecipeFactory.build(
                id: 'frukost_$i',
                category: 'Frukost',
              ));

      // When - Generate multiple times
      final results = <Set<String>>[];
      for (int i = 0; i < 5; i++) {
        final menu = await sut.generateMenuFromPrompt(
          'tre frukoster',
          recipes,
        );
        final ids = menu['Frukost']!.map((r) => r.id).toSet();
        results.add(ids);
      }

      // Then - Should have some variation (not always same recipes)
      // At least one result should be different from another
      bool hasVariation = false;
      for (int i = 0; i < results.length - 1; i++) {
        for (int j = i + 1; j < results.length; j++) {
          if (!results[i].containsAll(results[j]) ||
              !results[j].containsAll(results[i])) {
            hasVariation = true;
            break;
          }
        }
        if (hasVariation) break;
      }

      expect(hasVariation, isTrue,
          reason: 'Menu generation should have some randomness');
    });
  });
}