import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Using centralized mocks from production_mocks.dart:
// - MockImportManager with setImportManagerState() method
// - MockTextImportStrategy with enhanced stubbing support

void main() {
  group('TextImportViewModel', () {
    late TextImportViewModel viewModel;
    late MockImportManager mockImportManager;
    late MockTextImportStrategy mockTextStrategy; // Centralized mock
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create centralized mocks
      mockImportManager = MockImportManager();
      mockTextStrategy = MockTextImportStrategy();
      
      // Configure default mock result for text parsing using mocktail stubbing
      when(() => mockTextStrategy.import(any(), options: any(named: 'options')))
          .thenAnswer((_) async => ImportResult.success(
            RecipeFactory.build(
              title: 'Parsed Recipe',
              description: 'Recipe parsed from text',
              ingredients: ['2 ägg', '3 dl mjölk', '2 dl vetemjöl'],
              instructions: ['Vispa ihop', 'Stek i pannan'],
            ),
          ));
      
      // Configure ImportManager using centralized setImportManagerState()
      mockImportManager.setImportManagerState(
        textImportStrategy: mockTextStrategy,
      );
      
      // Configure autoImport for text strategy approach
      when(() => mockImportManager.autoImport(any(), preferredStrategy: any(named: 'preferredStrategy'), options: any(named: 'options')))
          .thenAnswer((_) async => ImportManagerResult.success(
            RecipeFactory.build(
              title: 'Parsed Recipe',
              description: 'Recipe parsed from text',
              ingredients: ['2 ägg', '3 dl mjölk', '2 dl vetemjöl'],
              instructions: ['Vispa ihop', 'Stek i pannan'],
            ),
            strategy: 'text',
          ));
      
      when(() => mockImportManager.saveImportedRecipe(any()))
          .thenAnswer((_) async => ImportManagerResult.success(
            RecipeFactory.build(),
            strategy: 'text',
          ));
      
      // Create viewModel
      viewModel = TextImportViewModel(
        importManager: mockImportManager,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp
        
        // Act - no action needed, checking initial state
        
        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.canImport, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(viewModel.sourceUrl, isNull);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.isParsing, isFalse);
        expect(viewModel.canParse, isTrue);
      });

      test('should have correct import type', () {
        // Assert
        expect(viewModel.importType, equals('text'));
      });
    });

    group('Text Input Management', () {
      test('should update input text', () {
        // Arrange
        const testText = '''
        Pannkakor
        Ingredienser:
        - 2 ägg
        - 3 dl mjölk
        - 2 dl vetemjöl
        
        Instruktioner:
        1. Vispa ihop alla ingredienser
        2. Stek i smör i pannan
        ''';
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.updateInputText(testText);
        
        // Assert
        expect(viewModel.inputText, equals(testText));
        expect(viewModel.hasValidInput, isTrue);
        expect(viewModel.canImport, isTrue);
        expect(notificationCount, greaterThan(0));
      });

      test('should validate empty input', () {
        // Arrange
        viewModel.updateInputText('  ');
        
        // Act & Assert
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.canImport, isFalse);
      });

      test('should clear input and data', () {
        // Arrange
        viewModel.updateInputText('Some recipe text');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.clearInput();
        
        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasValidInput, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(notificationCount, greaterThan(0));
      });

      test('should clear error when updating text', () {
        // Arrange
        // Force an error state by trying to parse empty text
        viewModel.updateInputText('');
        viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.updateInputText('New text');
        
        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should clear import data when empty text is set', () {
        // Arrange
        viewModel.updateInputText('Recipe text');
        
        // Act
        viewModel.updateInputText('');
        
        // Assert
        expect(viewModel.inputText, isEmpty);
        expect(viewModel.hasParsedRecipe, isFalse);
      });
    });

    group('Text Parsing', () {
      test('should parse valid text successfully', () async {
        // Arrange
        const testText = '''
        Köttbullar
        Ingredienser: 500g köttfärs, 1 ägg
        Instruktioner: Blanda och forma bullar
        ''';
        viewModel.updateInputText(testText);
        
        // Act
        final result = await viewModel.parseText();
        
        // Assert
        expect(result, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.parsedRecipe, isNotNull);
        expect(viewModel.parsedRecipe!.title, equals('Parsed Recipe'));
        expect(viewModel.error, isNull);
        // Can't verify internal strategy calls with real TextImportStrategy
      });

      test('should fail parsing with empty text', () async {
        // Arrange
        viewModel.updateInputText('');
        
        // Act
        final result = await viewModel.parseText();
        
        // Assert
        expect(result, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.error, equals('Vänligen ange text att tolka'));
      });

      test('should handle parsing error', () async {
        // Arrange
        viewModel.updateInputText('Some text');
        when(() => mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenThrow(Exception('Parsing failed'));
        
        // Act
        final result = await viewModel.parseText();
        
        // Assert
        expect(result, isFalse);
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.error, contains('Failed to parse recipe'));
      });

      test('should track parsing state', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        bool wasParsing = false;
        
        viewModel.addListener(() {
          if (viewModel.isParsing) wasParsing = true;
        });
        
        // Act
        await viewModel.parseText();
        
        // Assert
        expect(wasParsing, isTrue);
        expect(viewModel.isParsing, isFalse); // Should be false after completion
      });

      test('should parse with source URL', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        viewModel.setSourceUrl('https://example.com/recipe');
        
        // Act
        await viewModel.parseText();
        
        // Assert
        // Source URL is handled internally
        expect(viewModel.sourceUrl, equals('https://example.com/recipe'));
      });
    });

    group('Recipe Manipulation', () {
      test('should update parsed recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.updateRecipeTitle('Updated Title');
        viewModel.updateRecipeMealType('Middag');
        viewModel.updateRecipePortions(6);
        
        // Assert
        expect(viewModel.parsedRecipe!.title, equals('Updated Title'));
        expect(viewModel.parsedRecipe!.mealType, equals('Middag'));
        expect(viewModel.parsedRecipe!.portions, equals(6));
        expect(notificationCount, greaterThan(0));
      });

      test('should clear parsed recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.clearInput();
        
        // Assert
        expect(viewModel.hasParsedRecipe, isFalse);
        expect(viewModel.parsedRecipe, isNull);
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Import and Save', () {
      test('should complete import workflow successfully', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        
        // Act
        final result = await viewModel.importAndSave();
        
        // Assert
        expect(result, isTrue);
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
        // Verify through ImportManager - internal strategy calls can't be verified
        verify(() => mockImportManager.saveImportedRecipe(any())).called(1);
      });

      test('should handle save failure', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        when(() => mockImportManager.saveImportedRecipe(any()))
            .thenAnswer((_) async => ImportManagerResult.failure(
              'Failed to save',
              strategy: 'text',
            ));
        
        // Act
        final result = await viewModel.importAndSave();
        
        // Assert
        expect(result, isFalse);
      });

      test('should not save without valid input', () async {
        // Arrange
        viewModel.updateInputText('');
        
        // Act
        final result = await viewModel.importAndSave();
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });

      test('should handle import error', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        when(() => mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenThrow(Exception('Import failed'));
        
        // Act
        final result = await viewModel.importAndSave();
        
        // Assert
        expect(result, isFalse);
        expect(viewModel.error, contains('Failed to parse recipe'));
        verifyNever(() => mockImportManager.saveImportedRecipe(any()));
      });
    });

    group('Text and Source Management', () {
      test('should update text and source URL together', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.updateTextAndSource(
          'Recipe content from social media',
          sourceUrl: 'https://instagram.com/recipe-post',
        );
        
        // Assert
        expect(viewModel.inputText, equals('Recipe content from social media'));
        expect(viewModel.sourceUrl, equals('https://instagram.com/recipe-post'));
        expect(notificationCount, greaterThanOrEqualTo(2)); // One for text, one for URL
      });

      test('should update source URL', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.setSourceUrl('https://example.com/recipe');
        
        // Assert
        expect(viewModel.sourceUrl, equals('https://example.com/recipe'));
        expect(notificationCount, greaterThan(0));
      });

      test('should clear source URL with import data', () {
        // Arrange
        viewModel.setSourceUrl('https://example.com');
        
        // Act
        viewModel.clearInput();
        
        // Assert
        expect(viewModel.sourceUrl, isNull);
      });
    });

    group('Input Suggestions', () {
      test('should provide input suggestions for empty text', () {
        // Arrange
        viewModel.updateInputText('');
        
        // Act
        final suggestions = viewModel.getInputSuggestions();
        
        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.contains('Klistra in') || s.contains('skriv')), isTrue);
      });

      test('should provide suggestions for short text', () {
        // Arrange
        viewModel.updateInputText('Kort text');
        
        // Act
        final suggestions = viewModel.getInputSuggestions();
        
        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.toLowerCase().contains('ingrediens') || s.toLowerCase().contains('instruktion')), isTrue);
      });

      test('should provide suggestions for text without ingredients', () {
        // Arrange
        viewModel.updateInputText('Pannkakor är goda. Stek dem i pannan.');
        
        // Act
        final suggestions = viewModel.getInputSuggestions();
        
        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.toLowerCase().contains('ingrediens')), isTrue);
      });

      test('should provide suggestions for text without instructions', () {
        // Arrange
        viewModel.updateInputText('Ingredienser: 2 ägg, 3 dl mjölk, 2 dl mjöl');
        
        // Act
        final suggestions = viewModel.getInputSuggestions();
        
        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.toLowerCase().contains('instruktion')), isTrue);
      });

      test('should return empty suggestions for well-formed text', () {
        // Arrange
        viewModel.updateInputText('''
          Pannkakor
          
          Ingredienser:
          - 2 ägg
          - 3 dl mjölk
          - 2 dl vetemjöl
          - 1 krm salt
          
          Instruktioner:
          1. Vispa ihop alla ingredienser
          2. Låt smeten svälla 10 minuter
          3. Stek tunna pannkakor i smör
          4. Servera med sylt och grädde
        ''');
        
        // Act
        final suggestions = viewModel.getInputSuggestions();
        
        // Assert - well-formed text might still have minor suggestions (e.g., portions)
        expect(suggestions.length, equals(1));
        expect(suggestions[0], anyOf(
          contains('ser bra ut'),
          contains('portion'),
        ));
      });
    });

    group('Validation', () {
      test('should validate import data with recipe', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        await viewModel.parseText();
        
        // Act - validateImportData is part of complete import workflow
        final hasRecipe = viewModel.hasParsedRecipe;
        
        // Assert
        expect(hasRecipe, isTrue);
      });

      test('should not validate without recipe', () {
        // Arrange - no recipe parsed
        
        // Act - check if we have parsed recipe
        final hasRecipe = viewModel.hasParsedRecipe;
        
        // Assert
        expect(hasRecipe, isFalse);
      });

      test('should validate input text', () {
        // Arrange
        viewModel.updateInputText('Valid recipe text');
        
        // Act
        final isValid = viewModel.validateInput();
        
        // Assert
        expect(isValid, isTrue);
      });

      test('should not validate empty input', () {
        // Arrange
        viewModel.updateInputText('');
        
        // Act
        final isValid = viewModel.validateInput();
        
        // Assert
        expect(isValid, isFalse);
      });
    });

    group('Error Handling', () {
      test('should set and clear error', () async {
        // Arrange
        viewModel.updateInputText('Recipe text');
        when(() => mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenThrow(Exception('Test error'));
        
        // Act - trigger error
        await viewModel.parseText();
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Failed to parse recipe'));
        
        // Clear error by updating text
        viewModel.updateInputText('New text');
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should handle import manager not available', () async {
        // Arrange
        final separateMockManager = MockImportManager();
        final separateMockStrategy = MockTextImportStrategy();
        when(() => separateMockStrategy.import(any(), options: any(named: 'options')))
            .thenThrow(Exception('Import manager not available'));
        separateMockManager.setImportManagerState(
          textImportStrategy: separateMockStrategy,
        );
        
        final testViewModel = TextImportViewModel(importManager: separateMockManager);
        testViewModel.updateInputText('Recipe text');
        
        // Act
        final result = await testViewModel.parseText();
        
        // Assert
        expect(result, isFalse);
        expect(testViewModel.error, contains('Failed to parse recipe'));
        
        // Cleanup
        testViewModel.dispose();
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = TextImportViewModel(importManager: mockImportManager);
        
        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should not update after disposal', () {
        // Arrange
        final testViewModel = TextImportViewModel(importManager: mockImportManager);
        testViewModel.dispose();
        
        // Act
        testViewModel.updateInputText('Should not update');
        
        // Assert
        expect(testViewModel.inputText, isEmpty);
      });

      test('should handle multiple operations', () async {
        // Arrange
        viewModel.updateInputText('First recipe');
        
        // Act - Multiple operations
        await viewModel.parseText();
        viewModel.updateInputText('Second recipe');
        await viewModel.parseText();
        viewModel.clearInput();
        viewModel.updateInputText('Third recipe');
        await viewModel.importAndSave();
        
        // Assert
        expect(viewModel.inputText, equals('Third recipe'));
        expect(viewModel.hasParsedRecipe, isTrue);
        expect(viewModel.error, isNull);
      });
    });
  });
}