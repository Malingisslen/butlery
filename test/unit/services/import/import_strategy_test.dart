/// Unit tests for ImportStrategy base classes - Strategy pattern interface and validation
///
/// Tests comprehensive import strategy base functionality including:
/// - ImportResult success and failure states
/// - ImportValidationMixin recipe validation
/// - Text normalization and cleaning
/// - Number and rating extraction
/// - Input validation helpers
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/models/recipe_unified.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Test implementation of ImportValidationMixin
class _TestImportValidator with ImportValidationMixin {}

void main() {
  group('ImportStrategy Base Classes', () {
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

    group('ImportResult', () {
      test('should create success result with recipe', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-123',
            title: 'Test Recipe',
            description: 'Test recipe description',
            ingredients: ['ingredient 1'],
            instructions: ['instruction 1'],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.personal,
        );

        // Act
        final result = ImportResult.success(
          recipe,
          warnings: ['Minor warning'],
          metadata: {'source': 'test'},
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, equals(recipe));
        expect(result.errorMessage, isNull);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains('Minor warning'));
        expect(result.hasMetadata, isTrue);
        expect(result.metadata!['source'], equals('test'));
      });

      test('should create failure result with error message', () {
        // Arrange
        const errorMessage = 'Failed to parse recipe';

        // Act
        final result = ImportResult.failure(
          errorMessage,
          warnings: ['Parse warning'],
          metadata: {'attemptedFormat': 'json'},
        );

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.recipe, isNull);
        expect(result.errorMessage, equals(errorMessage));
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains('Parse warning'));
        expect(result.hasMetadata, isTrue);
        expect(result.metadata!['attemptedFormat'], equals('json'));
      });

      test('should handle success result without optional parameters', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'test-456',
            title: 'Simple Recipe',
            description: 'Simple description',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.personal,
        );

        // Act
        final result = ImportResult.success(recipe);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, equals(recipe));
        expect(result.hasWarnings, isFalse);
        expect(result.hasMetadata, isFalse);
      });

      test('should handle failure result without optional parameters', () {
        // Act
        final result = ImportResult.failure('Error');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, equals('Error'));
        expect(result.hasWarnings, isFalse);
        expect(result.hasMetadata, isFalse);
      });

      test('should correctly identify empty warnings and metadata', () {
        // Act
        final result1 = ImportResult.success(
          Recipe(
            core: RecipeCore(
              id: 'test',
              title: 'Test',
              description: 'Test description',
              ingredients: [],
              instructions: [],
              mealType: 'huvudrätt',
            ),
            type: RecipeType.personal,
          ),
          warnings: [],
          metadata: {},
        );

        // Assert
        expect(result1.hasWarnings, isFalse);
        expect(result1.hasMetadata, isFalse);
      });
    });

    group('ImportValidationMixin - Recipe Validation', () {
      late _TestImportValidator validator;

      setUp(() {
        validator = _TestImportValidator();
      });

      test('should validate recipe name correctly', () {
        // Valid names
        expect(validator.isValidRecipeName('Swedish Meatballs'), isTrue);
        expect(validator.isValidRecipeName('AB'), isTrue); // Minimum 2 chars
        expect(validator.isValidRecipeName('  Spaced Name  '), isTrue);

        // Invalid names
        expect(validator.isValidRecipeName(''), isFalse);
        expect(validator.isValidRecipeName('  '), isFalse);
        expect(validator.isValidRecipeName('A'), isFalse); // Less than 2 chars
        expect(validator.isValidRecipeName(' A '), isFalse);
      });

      test('should validate ingredients list correctly', () {
        // Valid ingredients
        expect(validator.isValidIngredients(['2 dl milk', '3 eggs']), isTrue);
        expect(validator.isValidIngredients(['single ingredient']), isTrue);
        expect(validator.isValidIngredients(['', 'valid ingredient']), isTrue);
        expect(validator.isValidIngredients(['  spaced  ']), isTrue);

        // Invalid ingredients
        expect(validator.isValidIngredients([]), isFalse);
        expect(validator.isValidIngredients(['', '  ']), isFalse);
        expect(validator.isValidIngredients(['  ', '']), isFalse);
      });

      test('should validate instructions list correctly', () {
        // Valid instructions
        expect(
          validator.isValidInstructions(['Mix ingredients', 'Bake']),
          isTrue,
        );
        expect(validator.isValidInstructions(['single step']), isTrue);
        expect(validator.isValidInstructions(['', 'valid step']), isTrue);
        expect(
          validator.isValidInstructions(['  spaced instruction  ']),
          isTrue,
        );

        // Invalid instructions
        expect(validator.isValidInstructions([]), isFalse);
        expect(validator.isValidInstructions(['', '  ']), isFalse);
        expect(validator.isValidInstructions(['  ', '']), isFalse);
      });
    });

    group('ImportValidationMixin - Text Normalization', () {
      late _TestImportValidator validator;

      setUp(() {
        validator = _TestImportValidator();
      });

      test('should normalize whitespace in text', () {
        expect(
          validator.normalizeText('  multiple   spaces  '),
          equals('multiple spaces'),
        );
        expect(
          validator.normalizeText('tabs\t\there'),
          equals('tabs here'),
        );
        // Newlines are preserved (recipe text needs paragraph breaks)
        expect(
          validator.normalizeText('newlines\n\nhere'),
          contains('newlines'),
        );
        expect(
          validator.normalizeText('\r\nwindows\r\nline\r\nbreaks\r\n'),
          contains('windows'),
        );
      });

      test('should remove emoji from text', () {
        expect(
          validator.normalizeText('Recipe 🍕 with emoji'),
          equals('Recipe with emoji'),
        );
        expect(
          validator.normalizeText('Multiple 😀 emojis 🎉 here'),
          equals('Multiple emojis here'),
        );
        expect(
          validator.normalizeText('🔥Hot recipe🔥'),
          equals('Hot recipe'),
        );
      });

      test('should handle combined normalization', () {
        expect(
          validator.normalizeText('  Recipe  🍝  with   spaces  '),
          equals('Recipe with spaces'),
        );
        expect(
          validator.normalizeText('🎉\n\nNew\t\tRecipe\n\n🎉'),
          equals('New Recipe'),
        );
      });

      test('should preserve Swedish characters', () {
        expect(
          validator.normalizeText('Köttbullar med gräddsås'),
          equals('Köttbullar med gräddsås'),
        );
        expect(
          validator.normalizeText('Äppelpaj  med  vaniljsås'),
          equals('Äppelpaj med vaniljsås'),
        );
      });

      test('should handle empty and edge cases', () {
        expect(validator.normalizeText(''), equals(''));
        expect(validator.normalizeText('   '), equals(''));
        expect(validator.normalizeText('a'), equals('a'));
        expect(validator.normalizeText('🔥'), equals(''));
      });
    });

    group('ImportValidationMixin - Number Extraction', () {
      late _TestImportValidator validator;

      setUp(() {
        validator = _TestImportValidator();
      });

      test('should extract numbers from text', () {
        expect(validator.extractNumber('4 portioner'), equals(4));
        expect(validator.extractNumber('Baka i 30 minuter'), equals(30));
        expect(validator.extractNumber('Ger 12 st'), equals(12));
        expect(validator.extractNumber('200 grader'), equals(200));
      });

      test('should extract first number when multiple present', () {
        expect(validator.extractNumber('4-6 portioner'), equals(4));
        expect(validator.extractNumber('20-30 minuter'), equals(20));
        expect(validator.extractNumber('Steg 1 av 5'), equals(1));
      });

      test('should handle text without numbers', () {
        expect(validator.extractNumber('No numbers here'), isNull);
        expect(validator.extractNumber('Text only'), isNull);
        expect(validator.extractNumber(''), isNull);
      });

      test('should handle edge cases', () {
        expect(validator.extractNumber('0 portioner'), equals(0));
        expect(validator.extractNumber('9999 grader'), equals(9999));
        expect(validator.extractNumber('Number: 42'), equals(42));
      });
    });

    group('ImportValidationMixin - Rating Extraction', () {
      late _TestImportValidator validator;

      setUp(() {
        validator = _TestImportValidator();
      });

      test('should extract rating with "av 5" format', () {
        expect(validator.extractRating('4.5 av 5'), equals(4.5));
        expect(validator.extractRating('3 av 5'), equals(3.0));
        expect(validator.extractRating('5.0 av 5'), equals(5.0));
        expect(validator.extractRating('Betyg: 4.2 av 5'), equals(4.2));
      });

      test('should extract rating with "/5" format', () {
        expect(validator.extractRating('4.5/5'), equals(4.5));
        expect(validator.extractRating('3/5'), equals(3.0));
        expect(validator.extractRating('Rating: 4.8/5'), equals(4.8));
      });

      test('should extract rating with star format', () {
        expect(validator.extractRating('4.5*'), equals(4.5));
        expect(validator.extractRating('3*'), equals(3.0));
        expect(validator.extractRating('4.5⭐'), equals(4.5));
        expect(validator.extractRating('3⭐'), equals(3.0));
      });

      test('should validate rating range', () {
        expect(validator.extractRating('0.5 av 5'), isNull); // Too low
        expect(validator.extractRating('5.5 av 5'), isNull); // Too high
        expect(validator.extractRating('10 av 5'), isNull); // Invalid
        expect(validator.extractRating('1.0 av 5'), equals(1.0)); // Min valid
        expect(validator.extractRating('5.0 av 5'), equals(5.0)); // Max valid
      });

      test('should handle text without ratings', () {
        expect(validator.extractRating('No rating here'), isNull);
        expect(validator.extractRating('5 portioner'), isNull);
        expect(validator.extractRating(''), isNull);
      });

      test('should handle decimal ratings', () {
        expect(validator.extractRating('3.7 av 5'), equals(3.7));
        expect(validator.extractRating('4.25/5'), equals(4.25));
        expect(validator.extractRating('2.5⭐'), equals(2.5));
      });
    });
  });
}
