import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/import_strategy.dart';

import '../../../test_support/base_unit_test.dart';

// Test class that uses ImportValidationMixin
class TestImportValidator with ImportValidationMixin {}

void main() {
  group('ImportValidationMixin', () {
    late TestImportValidator validator;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() {
      validator = TestImportValidator();
    });
    
    tearDown(() {
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Recipe Name Validation', () {
      test('should validate valid recipe names', () {
        // Arrange
        const validNames = [
          'Köttbullar',
          'Pannkakor med sylt',
          'AB',  // Minimum 2 characters
          'Very Long Recipe Name That Is Still Valid',
          'Recipe with åäö characters',
          'Recipe with 123 numbers',
        ];
        
        // Act & Assert
        for (final name in validNames) {
          expect(validator.isValidRecipeName(name), isTrue,
              reason: 'Should be valid: "$name"');
        }
      });
      
      test('should reject invalid recipe names', () {
        // Arrange
        const invalidNames = [
          '',          // Empty
          ' ',         // Only spaces
          '  ',        // Multiple spaces
          '\t',        // Tab
          '\n',        // Newline
          'A',         // Too short (less than 2 chars)
          ' A ',       // Too short after trim
        ];
        
        // Act & Assert
        for (final name in invalidNames) {
          expect(validator.isValidRecipeName(name), isFalse,
              reason: 'Should be invalid: "$name"');
        }
      });
      
      test('should handle trimming correctly', () {
        // Arrange
        const namesWithSpaces = [
          ('  Valid Name  ', true),
          ('  AB  ', true),
          ('  A  ', false),  // Too short after trim
          ('     ', false),  // Only spaces
        ];
        
        // Act & Assert
        for (final testCase in namesWithSpaces) {
          expect(validator.isValidRecipeName(testCase.$1), equals(testCase.$2),
              reason: 'Name "${testCase.$1}" should be ${testCase.$2}');
        }
      });
    });
    
    group('Ingredients Validation', () {
      test('should validate valid ingredient lists', () {
        // Arrange
        final validIngredients = [
          ['500 g köttfärs'],
          ['ingredient1', 'ingredient2'],
          ['3 ägg', '5 dl mjölk', '3 dl vetemjöl'],
          ['Single ingredient'],
          ['  Ingredient with spaces  '],  // Should trim
        ];
        
        // Act & Assert
        for (final ingredients in validIngredients) {
          expect(validator.isValidIngredients(ingredients), isTrue,
              reason: 'Should be valid: $ingredients');
        }
      });
      
      test('should reject invalid ingredient lists', () {
        // Arrange
        final invalidIngredients = [
          <String>[],           // Empty list
          [''],                 // Single empty string
          ['', ''],            // Multiple empty strings
          ['  ', '\t', '\n'],  // Only whitespace
        ];
        
        // Act & Assert
        for (final ingredients in invalidIngredients) {
          expect(validator.isValidIngredients(ingredients), isFalse,
              reason: 'Should be invalid: $ingredients');
        }
      });
      
      test('should accept mixed valid and empty ingredients', () {
        // Arrange
        final mixedIngredients = [
          '', 
          'Valid ingredient',
          '  ',  // Will be trimmed to empty
          'Another valid one',
        ];
        
        // Act
        final isValid = validator.isValidIngredients(mixedIngredients);
        
        // Assert
        expect(isValid, isTrue); // At least one valid ingredient exists
      });
    });
    
    group('Instructions Validation', () {
      test('should validate valid instruction lists', () {
        // Arrange
        final validInstructions = [
          ['Blanda alla ingredienser'],
          ['Step 1', 'Step 2'],
          ['Koka pasta', 'Stek bacon', 'Servera'],
          ['Single instruction'],
          ['  Instruction with spaces  '],  // Should trim
        ];
        
        // Act & Assert
        for (final instructions in validInstructions) {
          expect(validator.isValidInstructions(instructions), isTrue,
              reason: 'Should be valid: $instructions');
        }
      });
      
      test('should reject invalid instruction lists', () {
        // Arrange
        final invalidInstructions = [
          <String>[],           // Empty list
          [''],                 // Single empty string
          ['', ''],            // Multiple empty strings
          ['  ', '\t', '\n'],  // Only whitespace
        ];
        
        // Act & Assert
        for (final instructions in invalidInstructions) {
          expect(validator.isValidInstructions(instructions), isFalse,
              reason: 'Should be invalid: $instructions');
        }
      });
      
      test('should accept mixed valid and empty instructions', () {
        // Arrange
        final mixedInstructions = [
          '', 
          'Valid instruction',
          '  ',  // Will be trimmed to empty
          'Another valid one',
        ];
        
        // Act
        final isValid = validator.isValidInstructions(mixedInstructions);
        
        // Assert
        expect(isValid, isTrue); // At least one valid instruction exists
      });
    });
    
    group('Text Normalization', () {
      test('should normalize whitespace', () {
        // Arrange
        const inputs = [
          ('  Too   many    spaces  ', 'Too many spaces'),
          ('Line\nbreaks\nhere', 'Line breaks here'),
          ('Tabs\there\ttoo', 'Tabs here too'),
          ('\r\nWindows\r\nlinebreaks\r\n', 'Windows linebreaks'),
          ('   ', ''),  // Only spaces should become empty
        ];
        
        // Act & Assert
        for (final testCase in inputs) {
          final normalized = validator.normalizeText(testCase.$1);
          expect(normalized, equals(testCase.$2),
              reason: 'Input "${testCase.$1}" should normalize to "${testCase.$2}"');
        }
      });
      
      test('should remove emojis', () {
        // Arrange
        const inputs = [
          ('Recipe 🔥 with emojis 💯', 'Recipe with emojis'),
          ('🍕 Pizza recipe 🍕', 'Pizza recipe'),
          ('Multiple 😀😃😄 emojis', 'Multiple emojis'),
          ('Swedish text åäö 🇸🇪', 'Swedish text åäö'),  // Preserve Swedish, remove flag
        ];
        
        // Act & Assert
        for (final testCase in inputs) {
          final normalized = validator.normalizeText(testCase.$1);
          // The normalization removes emojis and normalizes spaces
          expect(normalized.trim(), equals(testCase.$2),
              reason: 'Input "${testCase.$1}" should remove emojis');
        }
      });
      
      test('should preserve Swedish characters', () {
        // Arrange
        const swedishTexts = [
          'Köttbullar med gräddsås',
          'Räksmörgås',
          'Ärtsoppa',
          'Smörgåstårta',
          'Köttfärssås',
        ];
        
        // Act & Assert
        for (final text in swedishTexts) {
          final normalized = validator.normalizeText(text);
          
          // Check that Swedish characters are preserved
          if (text.contains('å')) expect(normalized, contains('å'));
          if (text.contains('ä')) expect(normalized, contains('ä'));
          if (text.contains('ö')) expect(normalized, contains('ö'));
          if (text.contains('Å')) expect(normalized, contains('Å'));
          if (text.contains('Ä')) expect(normalized, contains('Ä'));
          if (text.contains('Ö')) expect(normalized, contains('Ö'));
        }
      });
      
      test('should handle edge cases', () {
        // Arrange & Act & Assert
        expect(validator.normalizeText(''), equals(''));
        expect(validator.normalizeText('NoChangesNeeded'), equals('NoChangesNeeded'));
        expect(validator.normalizeText('123'), equals('123'));
        expect(validator.normalizeText('!@#\$%^&*()'), equals('!@#\$%^&*()'));
      });
    });
    
    group('Number Extraction', () {
      test('should extract numbers from text', () {
        // Arrange
        const testCases = [
          ('4 portioner', 4),
          ('30 minuter', 30),
          ('Steg 2: Blanda', 2),
          ('15-20 minuter', 15),  // Takes first number
          ('100g mjöl', 100),
          ('2.5 dl', 2),  // Integer extraction only
        ];
        
        // Act & Assert
        for (final testCase in testCases) {
          final number = validator.extractNumber(testCase.$1);
          expect(number, equals(testCase.$2),
              reason: 'Should extract ${testCase.$2} from "${testCase.$1}"');
        }
      });
      
      test('should return null when no number found', () {
        // Arrange
        const noNumberTexts = [
          'No numbers here',
          'Några ingredienser',
          'Ett par minuter',  // Swedish text numbers
          '',
          'Special characters !@#',
        ];
        
        // Act & Assert
        for (final text in noNumberTexts) {
          expect(validator.extractNumber(text), isNull,
              reason: 'Should not find number in "$text"');
        }
      });
      
      test('should handle Swedish number words', () {
        // Note: Current implementation only extracts digits, not word numbers
        // This is correct behavior but worth documenting
        
        // Arrange
        const swedishNumbers = [
          'en portion',     // one
          'två portioner',  // two
          'tre steg',       // three
          'fyra personer',  // four
        ];
        
        // Act & Assert
        for (final text in swedishNumbers) {
          expect(validator.extractNumber(text), isNull,
              reason: 'Does not extract Swedish word numbers from "$text"');
        }
      });
    });
    
    group('Rating Extraction', () {
      test('should extract ratings with Swedish format', () {
        // Arrange
        const testCases = [
          ('4.5 av 5', 4.5),
          ('3 av 5 stjärnor', 3.0),
          ('5/5', 5.0),
          ('2.5/5 poäng', 2.5),
          ('Rating: 4/5', 4.0),
        ];
        
        // Act & Assert
        for (final testCase in testCases) {
          final rating = validator.extractRating(testCase.$1);
          expect(rating, equals(testCase.$2),
              reason: 'Should extract ${testCase.$2} from "${testCase.$1}"');
        }
      });
      
      test('should extract ratings with star symbols', () {
        // Arrange
        const testCases = [
          ('5 ⭐', 5.0),
          ('4.5*', 4.5),
          ('3 stjärnor ⭐', 3.0),
        ];
        
        // Act & Assert
        for (final testCase in testCases) {
          final rating = validator.extractRating(testCase.$1);
          expect(rating, equals(testCase.$2),
              reason: 'Should extract ${testCase.$2} from "${testCase.$1}"');
        }
      });
      
      test('should validate rating range', () {
        // Arrange
        const invalidRatings = [
          '0 av 5',     // Too low
          '6/5',        // Too high
          '10 av 5',    // Way too high
          '-1 av 5',    // Negative
          '0.5 av 5',   // Below 1.0
        ];
        
        // Act & Assert
        for (final text in invalidRatings) {
          expect(validator.extractRating(text), isNull,
              reason: 'Should reject out-of-range rating in "$text"');
        }
      });
      
      test('should return null when no rating found', () {
        // Arrange
        const noRatingTexts = [
          'No rating here',
          'Mycket gott recept',
          '5 portioner',  // Not a rating
          'Step 3 of 5',  // Not a rating
          '',
        ];
        
        // Act & Assert
        for (final text in noRatingTexts) {
          expect(validator.extractRating(text), isNull,
              reason: 'Should not find rating in "$text"');
        }
      });
      
      test('should handle decimal ratings', () {
        // Arrange
        const decimalRatings = [
          ('1.5 av 5', 1.5),
          ('2.25/5', 2.25),
          ('3.7 ⭐', 3.7),
          ('4.99 av 5', 4.99),
        ];
        
        // Act & Assert
        for (final testCase in decimalRatings) {
          final rating = validator.extractRating(testCase.$1);
          expect(rating, equals(testCase.$2),
              reason: 'Should extract ${testCase.$2} from "${testCase.$1}"');
        }
      });
    });
    
    group('Edge Cases and Error Handling', () {
      test('should handle null-like inputs gracefully', () {
        // Test that methods handle edge cases without throwing
        
        // Recipe name validation
        expect(() => validator.isValidRecipeName(''), returnsNormally);
        
        // Ingredients validation
        expect(() => validator.isValidIngredients([]), returnsNormally);
        expect(() => validator.isValidIngredients(['']), returnsNormally);
        
        // Instructions validation
        expect(() => validator.isValidInstructions([]), returnsNormally);
        expect(() => validator.isValidInstructions(['']), returnsNormally);
        
        // Text normalization
        expect(() => validator.normalizeText(''), returnsNormally);
        
        // Number extraction
        expect(() => validator.extractNumber(''), returnsNormally);
        
        // Rating extraction
        expect(() => validator.extractRating(''), returnsNormally);
      });
      
      test('should handle very long inputs', () {
        // Arrange
        final longText = 'A' * 10000;  // Very long string
        final longList = List.generate(1000, (i) => 'Ingredient $i');
        
        // Act & Assert - Should not throw or hang
        expect(() => validator.isValidRecipeName(longText), returnsNormally);
        expect(() => validator.isValidIngredients(longList), returnsNormally);
        expect(() => validator.isValidInstructions(longList), returnsNormally);
        expect(() => validator.normalizeText(longText), returnsNormally);
        expect(() => validator.extractNumber(longText), returnsNormally);
        expect(() => validator.extractRating(longText), returnsNormally);
      });
      
      test('should handle special characters', () {
        // Arrange
        const specialChars = '!@#\$%^&*()_+-=[]{}|;:\'",.<>?/\\`~';
        
        // Act
        final normalized = validator.normalizeText(specialChars);
        
        // Assert - Special characters should be preserved (except emojis)
        expect(normalized, equals(specialChars));
      });
    });
  });
}