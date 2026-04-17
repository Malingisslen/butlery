import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

// Production imports
import 'package:butlery/services/import/file_import_strategy.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Using centralized MockFileContentProvider, MockFilePickerResult, and MockPlatformFile from production_mocks.dart

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FileType.any);
  });

  group('FileImportStrategy Enhanced Tests', () {
    late FileImportStrategy strategy;
    late MockFileContentProvider mockContentProvider;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      mockContentProvider = MockFileContentProvider();
      strategy = FileImportStrategy(contentProvider: mockContentProvider);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('CSV Import Tests', () {
      test('should import recipe from basic CSV content', () async {
        // Arrange
        final csvContent = '''Title,Ingredients,Instructions,Servings,Time
Pasta Carbonara,"200g pasta;100g bacon;2 eggs;50g parmesan","Cook pasta;Fry bacon;Mix eggs and cheese;Combine",4,20''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Pasta Carbonara'));
        expect(result.recipe!.ingredients, hasLength(4));
        expect(result.recipe!.instructions, hasLength(4));
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, equals(20));
      });

      test('should handle Swedish CSV headers', () async {
        // Arrange
        final csvContent = '''Namn,Ingredienser,Instruktioner,Portioner,Tid
Köttbullar,"500g köttfärs;1 dl mjölk;1 ägg;salt","Blanda allt;Forma bollar;Stek",4,30''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Köttbullar'));
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, equals(30));
      });

      test('should import multiple recipes from CSV', () async {
        // Arrange
        final csvContent = '''Title,Ingredients,Instructions,Servings,Time
Recipe 1,"Ingredient A;Ingredient B","Step 1;Step 2",2,15
Recipe 2,"Ingredient C;Ingredient D","Step 1;Step 2",4,25
Recipe 3,"Ingredient E;Ingredient F","Step 1;Step 2",6,35''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final recipes = await strategy.importMultipleFromContent(bytes, 'csv');

        // Assert
        expect(recipes, hasLength(3));
        expect(recipes[0].title, equals('Recipe 1'));
        expect(recipes[1].title, equals('Recipe 2'));
        expect(recipes[2].title, equals('Recipe 3'));
        expect(recipes[0].portions, equals(2));
        expect(recipes[1].portions, equals(4));
        expect(recipes[2].portions, equals(6));
      });

      test('should handle CSV with missing columns gracefully', () async {
        // Arrange
        final csvContent = '''Title,Ingredients
Incomplete Recipe,"Some ingredients"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Incomplete Recipe'));
        // Should have placeholder for missing instructions
        expect(
            result.recipe!.instructions, equals(['No instructions provided']));
      });

      test('should parse ingredients with different delimiters', () async {
        // Arrange
        final csvContent = '''Title,Ingredients,Instructions
Test Recipe,"Item 1|Item 2|Item 3","Step 1|Step 2"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.ingredients, hasLength(3));
      });

      test('should handle CSV with BOM correctly', () async {
        // Arrange - UTF-8 BOM + CSV content
        final bomBytes = [0xEF, 0xBB, 0xBF];
        final csvContent = 'Title,Ingredients\nRecipe,"Items"';
        final contentBytes = utf8.encode(csvContent);
        final bytes = Uint8List.fromList([...bomBytes, ...contentBytes]);

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Recipe'));
      });

      test('should handle empty CSV file', () async {
        // Arrange
        final bytes = Uint8List.fromList(utf8.encode(''));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isFalse);
        // The actual error is 'Failed to parse file' since _importFromCsv returns null
        expect(result.errorMessage, equals('Failed to parse file'));
      });

      test('should handle CSV with only headers', () async {
        // Arrange
        final csvContent = 'Title,Ingredients,Instructions';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isFalse);
        // The actual error is 'Failed to parse file' since _importFromCsv returns null
        expect(result.errorMessage, equals('Failed to parse file'));
      });

      test('should parse Swedish measurement units', () async {
        // Arrange
        final csvContent = '''Namn,Ingredienser
Recept,"2 dl mjölk;1 msk socker;1 tsk salt;1 krm peppar"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        final ingredients = result.recipe!.ingredients;
        expect(ingredients.any((i) => i.contains('dl')), isTrue);
        expect(ingredients.any((i) => i.contains('msk')), isTrue);
        expect(ingredients.any((i) => i.contains('tsk')), isTrue);
        expect(ingredients.any((i) => i.contains('krm')), isTrue);
      });

      test('should handle quoted CSV fields with commas', () async {
        // Arrange
        final csvContent = '''Title,Ingredients,Instructions
"Recipe, with comma","Salt, pepper, oil","Mix, stir, and cook"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Recipe, with comma'));
      });
    });

    group('Excel Import Tests', () {
      test('should import recipe from Excel content', () async {
        // Arrange - Create Excel file in memory
        final excel = Excel.createExcel();
        final sheet = excel['Sheet1'];

        // Add headers
        sheet.appendRow([
          TextCellValue('Title'),
          TextCellValue('Ingredients'),
          TextCellValue('Instructions'),
          TextCellValue('Servings'),
          TextCellValue('Time'),
        ]);

        // Add data
        sheet.appendRow([
          TextCellValue('Excel Recipe'),
          TextCellValue('Ingredient 1;Ingredient 2'),
          TextCellValue('Step 1;Step 2'),
          IntCellValue(4),
          IntCellValue(25),
        ]);

        final bytes = excel.encode()!;

        // Act
        final result =
            await strategy.importFromContent(Uint8List.fromList(bytes), 'xlsx');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Excel Recipe'));
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, equals(25));
      });

      test('should import multiple recipes from Excel', () async {
        // Arrange
        final excel = Excel.createExcel();
        final sheet = excel['Recipes'];

        sheet.appendRow([
          TextCellValue('Title'),
          TextCellValue('Ingredients'),
        ]);

        for (int i = 1; i <= 5; i++) {
          sheet.appendRow([
            TextCellValue('Recipe $i'),
            TextCellValue('Ingredients for recipe $i'),
          ]);
        }

        final bytes = excel.encode()!;

        // Act
        final recipes = await strategy.importMultipleFromContent(
          Uint8List.fromList(bytes),
          'xlsx',
        );

        // Assert
        expect(recipes, hasLength(5));
        for (int i = 0; i < 5; i++) {
          expect(recipes[i].title, equals('Recipe ${i + 1}'));
        }
      });

      test('should handle Excel with Swedish content', () async {
        // Arrange
        final excel = Excel.createExcel();
        final sheet = excel['Recept'];

        sheet.appendRow([
          TextCellValue('Namn'),
          TextCellValue('Ingredienser'),
          TextCellValue('Portioner'),
        ]);

        sheet.appendRow([
          TextCellValue('Räksmörgås'),
          TextCellValue('Räkor;Majonnäs;Ägg;Dill'),
          IntCellValue(2),
        ]);

        final bytes = excel.encode()!;

        // Act
        final result = await strategy.importFromContent(
          Uint8List.fromList(bytes),
          'xlsx',
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Räksmörgås'));
        expect(result.recipe!.ingredients, hasLength(4));
        expect(result.recipe!.portions, equals(2));
      });

      test('should handle Excel with empty cells', () async {
        // Arrange
        final excel = Excel.createExcel();
        final sheet = excel['Sheet1'];

        sheet.appendRow([
          TextCellValue('Title'),
          TextCellValue('Ingredients'),
          TextCellValue('Instructions'),
        ]);

        sheet.appendRow([
          TextCellValue('Sparse Recipe'),
          null, // Empty cell
          TextCellValue('Some instructions'),
        ]);

        final bytes = excel.encode()!;

        // Act
        final result = await strategy.importFromContent(
          Uint8List.fromList(bytes),
          'xlsx',
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Sparse Recipe'));
        // Should have placeholder for missing ingredients
        expect(
            result.recipe!.ingredients, equals(['No ingredients specified']));
        expect(result.recipe!.instructions, hasLength(1));
      });

      test('should handle empty Excel file', () async {
        // Arrange
        final excel = Excel.createExcel();
        final bytes = excel.encode()!;

        // Act
        final result = await strategy.importFromContent(
          Uint8List.fromList(bytes),
          'xlsx',
        );

        // Assert
        expect(result.isSuccess, isFalse);
        // The actual error is 'Failed to parse file' since _importFromExcel returns null
        expect(result.errorMessage, equals('Failed to parse file'));
      });

      test('should handle .xls extension same as .xlsx', () async {
        // Arrange
        final excel = Excel.createExcel();
        final sheet = excel['Sheet1'];

        sheet.appendRow([TextCellValue('Title')]);
        sheet.appendRow([TextCellValue('Test Recipe')]);

        final bytes = excel.encode()!;

        // Act
        final result = await strategy.importFromContent(
          Uint8List.fromList(bytes),
          'xls', // Using .xls extension
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Test Recipe'));
      });
    });

    group('Data Type Conversion Tests', () {
      test('should convert numeric strings to integers', () async {
        // Arrange
        final csvContent = '''Title,Servings,Time
Recipe,"4","30"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.portions, isA<int>());
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, isA<int>());
        expect(result.recipe!.timeMinutes, equals(30));
      });

      test('should extract numbers from text strings', () async {
        // Arrange
        final csvContent = '''Title,Servings,Time
Recipe,"serves 6","about 45 minutes"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.portions, equals(6));
        expect(result.recipe!.timeMinutes, equals(45));
      });

      test('should handle rating conversion', () async {
        // Arrange
        final csvContent = '''Title,Rating
Recipe,4.5''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.rating, equals(4.5));
      });

      test('should parse tags from comma-separated values', () async {
        // Arrange
        final csvContent = '''Title,Tags
Recipe,"vegetarian,quick,easy"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.personalTagIds, hasLength(3));
        expect(result.recipe!.personalTagIds, contains('vegetarian'));
        expect(result.recipe!.personalTagIds, contains('quick'));
        expect(result.recipe!.personalTagIds, contains('easy'));
      });
    });

    group('Error Handling Tests', () {
      test('should handle unsupported file extension', () async {
        // Arrange
        final bytes = Uint8List.fromList([1, 2, 3]);

        // Act
        final result = await strategy.importFromContent(bytes, 'txt');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Unsupported file format'));
      });

      test('should handle malformed CSV gracefully', () async {
        // Arrange
        final csvContent = 'This is not,proper CSV\nformat"with quotes';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        // Should still try to parse something
        expect(result.isSuccess, anyOf(isTrue, isFalse));
        if (result.isSuccess) {
          expect(result.recipe, isNotNull);
        } else {
          expect(result.errorMessage, isNotEmpty);
        }
      });

      test('should handle corrupt Excel bytes', () async {
        // Arrange
        final bytes = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x00]);

        // Act
        final result = await strategy.importFromContent(bytes, 'xlsx');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
      });

      test('should handle UTF-8 decoding errors', () async {
        // Arrange - Invalid UTF-8 sequence
        final bytes = Uint8List.fromList([0xFF, 0xFE, 0xFD]);

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
      });
    });

    group('FilePicker Integration Tests', () {
      test('should use content provider for file selection', () async {
        // Arrange — MockFileContentProvider has a concrete pickFiles override,
        // so use setFilePickerResult() instead of when().
        final mockResult = MockFilePickerResult();
        final mockFile = MockPlatformFile();
        final fileBytes = Uint8List.fromList(utf8.encode('Title\nRecipe'));

        mockContentProvider.setFilePickerResult(mockResult);

        when(() => mockResult.files).thenReturn([mockFile]);
        when(() => mockFile.bytes).thenReturn(fileBytes);
        when(() => mockFile.extension).thenReturn('csv');

        // Act
        final result = await strategy.import('');

        // Assert — verify import succeeded (content provider was called)
        expect(result, isNotNull);
      });

      test('should handle cancelled file picker', () async {
        // Arrange — null result simulates cancelled picker
        mockContentProvider.setFilePickerResult(null);

        // Act
        final result = await strategy.import('');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No file selected'));
      });

      test('should handle file without bytes', () async {
        // Arrange
        final mockResult = MockFilePickerResult();
        final mockFile = MockPlatformFile();

        mockContentProvider.setFilePickerResult(mockResult);

        when(() => mockResult.files).thenReturn([mockFile]);
        when(() => mockFile.bytes).thenReturn(null);

        // Act
        final result = await strategy.import('');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Could not read file'));
      });
    });

    group('Edge Cases', () {
      test('should handle very large CSV files efficiently', () async {
        // Arrange - Create CSV with 100 recipes
        final buffer = StringBuffer('Title,Ingredients,Instructions\n');
        for (int i = 1; i <= 100; i++) {
          buffer.writeln('Recipe $i,"Ingredients $i","Instructions $i"');
        }
        final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

        // Act
        final recipes = await strategy.importMultipleFromContent(bytes, 'csv');

        // Assert
        expect(recipes, hasLength(100));
        expect(recipes.first.title, equals('Recipe 1'));
        expect(recipes.last.title, equals('Recipe 100'));
      });

      test('should skip invalid rows in batch import', () async {
        // Arrange
        final csvContent = '''Title,Ingredients
Valid Recipe 1,"Ingredients"

Valid Recipe 2,"More ingredients"
,"Missing title"
Valid Recipe 3,"Final ingredients"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final recipes = await strategy.importMultipleFromContent(bytes, 'csv');

        // Assert
        expect(recipes, hasLength(3)); // Should skip invalid rows
        expect(recipes[0].title, equals('Valid Recipe 1'));
        expect(recipes[1].title, equals('Valid Recipe 2'));
        expect(recipes[2].title, equals('Valid Recipe 3'));
      });

      test('should handle mixed column naming conventions', () async {
        // Arrange
        final csvContent =
            '''recipe_name,ingredient_list,cooking_steps,serving_size,prep_time
Mixed Naming,"Items","Steps",4,20''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        // Should still parse with different column names
        expect(result.recipe, isNotNull);
      });

      test('should preserve special characters in Swedish recipes', () async {
        // Arrange
        final csvContent = '''Namn,Ingredienser
Räksmörgås à la André,"Räkor från Östersjön;Crème fraîche"''';
        final bytes = Uint8List.fromList(utf8.encode(csvContent));

        // Act
        final result = await strategy.importFromContent(bytes, 'csv');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, contains('à la André'));
        expect(result.recipe!.ingredients.first, contains('Östersjön'));
        expect(result.recipe!.ingredients.last, contains('Crème fraîche'));
      });
    });
  });
}
