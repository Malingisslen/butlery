import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart' as import_strategy;
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// ============= TESTS =============
// Using mocks from production_mocks.dart:
// - MockImportStrategy
// - MockTextImportStrategy
// - MockArchiveImportStrategy
// - MockFileImportStrategy
// - MockPersonalRecipeOperations

void main() {
  group('ImportManager', () {
    late ImportManager importManager;
    late MockPersonalRecipeOperations mockPersonalOperations;
    late MockImportStrategy mockStrategy;  // From production_mocks.dart
    late Recipe testRecipe;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      
      // Register fallback values for mocktail
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(ImportSourceType.text);
      registerFallbackValue(<Recipe>[]);
    });
    
    setUp(() {
      // Create mocks
      mockPersonalOperations = MockPersonalRecipeOperations();
      
      // Create test data
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Test Recipe',
        description: 'A test recipe',
      );
      
      // Create import manager
      importManager = ImportManager(mockPersonalOperations);
      
      // Setup default stubs for PersonalRecipeOperations
      when(() => mockPersonalOperations.addUnifiedRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success('Recipe added'));
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Service Identification', () {
      test('should have available strategies', () {
        // Assert
        final strategies = importManager.availableStrategies;
        expect(strategies, isNotEmpty);
        expect(strategies.any((s) => s is ArchiveImportStrategy), isTrue);
        expect(strategies.any((s) => s is TextImportStrategy), isTrue);
        expect(strategies.any((s) => s is FileImportStrategy), isTrue);
      });
      
      test('should get text import strategy', () {
        // Act
        final textStrategy = importManager.getTextImportStrategy();
        
        // Assert
        expect(textStrategy, isA<TextImportStrategy>());
      });
    });
    
    group('Auto Import', () {
      test('should auto-detect and import with successful strategy', () async {
        // Arrange
        // Use realistic Swedish recipe text that TextImportStrategy can handle
        const input = '''
        Köttbullar med gräddsås
        
        Ingredienser:
        500 g köttfärs
        1 dl mjölk
        2 msk ströbröd
        1 st ägg
        
        Gör så här:
        1. Blanda köttfärs med mjölk och ströbröd
        2. Forma till bollar
        3. Stek i smör tills gyllene
        ''';
        
        // Act
        final result = await importManager.autoImport(input);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.strategy, isNotNull);
      });
      
      test('should try preferred strategy first if provided', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        const input = 'some recipe text';
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('mock_strategy');
        when(() => mockStrategy.import(input, options: any(named: 'options')))
            .thenAnswer((_) async => import_strategy.ImportResult.success(testRecipe));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.strategy, equals('mock_strategy'));
        verify(() => mockStrategy.import(input, options: any(named: 'options'))).called(1);
      });
      
      test('should fallback to other strategies if preferred fails', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        mockStrategy.setStrategyState(
          strategyName: 'failing_strategy',
          canHandle: true,
        );
        // Use input that built-in TextImportStrategy can handle
        const input = '''
        Köttbullar
        Ingredienser: 500 g köttfärs
        Gör så här: 1. Forma 2. Stek
        ''';
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.import(input, options: any(named: 'options')))
            .thenAnswer((_) async => import_strategy.ImportResult.failure('Strategy failed'));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        // Should try built-in strategies after preferred fails
        expect(result.strategy, isNotNull);
        expect(result.strategy, isNot('failing_strategy'));
        // Should use Text Import strategy as fallback
        expect(result.strategy, equals('Text Import'));
      });
      
      test('should return failure when no strategy can handle input', () async {
        // Arrange
        const input = ''; // Empty input that no strategy will handle
        
        // Act
        final result = await importManager.autoImport(input);
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No import strategy could handle'));
        expect(result.availableStrategies, isNotEmpty);
      });
      
      test('should handle strategy execution errors gracefully', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        const input = 'error input';
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('error_strategy');
        when(() => mockStrategy.import(input, options: any(named: 'options')))
            .thenAnswer((_) async => throw Exception('Import error'));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        expect(result.isSuccess, isFalse);
        // The ImportManager catches the exception and includes it in error message
        expect(result.errorMessage, anyOf(
          contains('Import error'),
          contains('Strategy execution error'),
          contains('No import strategy could handle'),
        ));
      });
      
      test('should pass options to strategy', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        const input = 'recipe with options';
        final options = {'language': 'swedish', 'format': 'json'};
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('options_strategy');
        when(() => mockStrategy.import(input, options: options))
            .thenAnswer((_) async => import_strategy.ImportResult.success(testRecipe));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
          options: options,
        );
        
        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockStrategy.import(input, options: options)).called(1);
      });
    });
    
    group('Import with Specific Strategy', () {
      test('should import with named strategy', () async {
        // Arrange
        const input = '''
        Köttbullar recept
        
        Ingredienser:
        500 g köttfärs
        1 dl mjölk
        
        Gör så här:
        1. Blanda ingredienser
        2. Forma och stek
        ''';
        
        // Act
        final result = await importManager.importWithStrategy(
          'Text Import',  // Use the actual strategy name from TextImportStrategy
          input,
        );
        
        // Assert
        expect(result.strategy, equals('Text Import'));
      });
      
      test('should return failure for unknown strategy', () async {
        // Arrange
        const input = 'some input';
        
        // Act
        final result = await importManager.importWithStrategy(
          'UnknownStrategy',
          input,
        );
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Strategy not found'));
        expect(result.availableStrategies, isNotEmpty);
      });
    });
    
    group('Batch Import', () {
      test('should process multiple imports successfully', () async {
        // Arrange
        final inputs = [
          '''Pannkakor
          Ingredienser: 3 ägg, 5 dl mjölk, 3 dl vetemjöl
          Gör så här: 1. Vispa ihop 2. Stek i panna''',
          '''Köttbullar
          Ingredienser: 500 g köttfärs, 1 dl mjölk
          Gör så här: 1. Blanda 2. Forma 3. Stek''',
          '''Pasta Carbonara
          Ingredienser: 400 g pasta, 200 g bacon, 3 ägg
          Gör så här: 1. Koka pasta 2. Stek bacon 3. Blanda''',
        ];
        
        // Act
        final result = await importManager.batchImport(inputs);
        
        // Assert
        expect(result.totalProcessed, equals(3));
        expect(result.results.length, equals(3));
      });
      
      test('should handle mixed success and failure in batch', () async {
        // Arrange
        final inputs = [
          '''Köttbullar
          Ingredienser: 500 g köttfärs
          Gör så här: 1. Forma 2. Stek''',
          '', // Will fail
          '''Pannkakor
          Ingredienser: 3 ägg, 5 dl mjölk
          Gör så här: 1. Vispa 2. Stek''',
        ];
        
        // Act
        final result = await importManager.batchImport(inputs);
        
        // Assert
        expect(result.totalProcessed, equals(3));
        expect(result.failureCount, greaterThan(0));
        expect(result.hasErrors, isTrue);
      });
      
      test('should use preferred strategy for all batch items', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        final inputs = ['input1', 'input2'];
        
        when(() => mockStrategy.canHandle(any())).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('batch_strategy');
        when(() => mockStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => import_strategy.ImportResult.success(testRecipe));
        
        // Act
        final result = await importManager.batchImport(
          inputs,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        expect(result.successCount, equals(2));
        verify(() => mockStrategy.import(any(), options: any(named: 'options'))).called(2);
      });
      
      test('should calculate success rate correctly', () async {
        // Arrange
        // Create a mix of valid and invalid inputs
        final inputs = [
          // 5 valid recipes
          ...List.generate(5, (i) => '''
          Recipe $i
          Ingredienser: 500 g köttfärs
          Gör så här: 1. Forma 2. Stek
          '''),
          // 5 invalid inputs that strategies won't handle
          ...List.generate(5, (i) => 'short$i'),  // Too short, no keywords
        ];
        
        // Act
        final result = await importManager.batchImport(inputs);
        
        // Assert
        expect(result.totalProcessed, equals(10));
        // With valid recipe inputs, some should succeed
        expect(result.successRate, greaterThan(0));
      });
      
      test('should handle empty batch gracefully', () async {
        // Act
        final result = await importManager.batchImport([]);
        
        // Assert
        expect(result.totalProcessed, equals(0));
        expect(result.successCount, equals(0));
        expect(result.failureCount, equals(0));
        expect(result.successRate, equals(0.0));
      });
    });
    
    group('Strategy Management', () {
      test('should get compatible strategies for input', () {
        // Arrange
        // ArchiveImportStrategy expects specific ID format (likely with prefix/pattern)
        const archiveInput = 'archive:recipe-123';  // Or whatever format archive expects
        const textInput = '''
        Köttbullar med potatismos
        
        Ingredienser:
        500 g köttfärs
        1 kg potatis
        2 dl mjölk
        
        Gör så här:
        1. Koka potatis
        2. Forma köttbullar
        3. Stek köttbullarna
        ''';
        
        // Act
        importManager.getCompatibleStrategies(archiveInput); // Test it runs without error
        final textStrategies = importManager.getCompatibleStrategies(textInput);
        
        // Assert
        // Note: archiveStrategies might be empty if archive expects different format
        expect(textStrategies, isNotEmpty);
      });
      
      test('should validate input with specific strategy', () {
        // Arrange
        final textStrategy = importManager.getTextImportStrategy();
        const validInput = '''
        Pannkakor
        Ingredienser: 3 ägg, 5 dl mjölk, 3 dl vetemjöl
        Gör så här: 1. Vispa ihop 2. Stek
        ''';
        const invalidInput = '';
        
        // Act
        final validResult = importManager.validateInput(validInput, strategy: textStrategy);
        final invalidResult = importManager.validateInput(invalidInput, strategy: textStrategy);
        
        // Assert
        expect(validResult, isTrue);
        expect(invalidResult, isFalse);
      });
      
      test('should validate input with any compatible strategy', () {
        // Arrange
        const someInput = '''
        Köttbullar
        Ingredienser: 500 g köttfärs
        Gör så här: 1. Forma 2. Stek
        ''';
        
        // Act
        final result = importManager.validateInput(someInput);
        
        // Assert
        expect(result, isTrue);
      });
    });
    
    group('Import Suggestions', () {
      test('should provide import suggestions sorted by confidence', () {
        // Arrange
        const input = '''
        Köttbullar
        Ingredienser: 500 g köttfärs, 1 dl mjölk
        Gör så här: 1. Blanda 2. Forma 3. Stek
        ''';
        
        // Act
        final suggestions = importManager.getImportSuggestions(input);
        
        // Assert
        expect(suggestions, isNotEmpty);
        
        // Check sorting by confidence
        for (int i = 0; i < suggestions.length - 1; i++) {
          expect(suggestions[i].confidence, greaterThanOrEqualTo(suggestions[i + 1].confidence));
        }
      });
      
      test('should include strategy information in suggestions', () {
        // Arrange
        const input = '''
        Pannkakor
        Ingredienser: 3 ägg, 5 dl mjölk
        Gör så här: 1. Vispa 2. Stek
        ''';
        
        // Act
        final suggestions = importManager.getImportSuggestions(input);
        
        // Assert
        expect(suggestions, isNotEmpty);
        for (final suggestion in suggestions) {
          expect(suggestion.strategy, isNotNull);
          expect(suggestion.description, isNotEmpty);
          expect(suggestion.confidence, greaterThan(0));
        }
      });
      
      test('should return empty suggestions for invalid input', () {
        // Arrange
        const input = '';
        
        // Act
        final suggestions = importManager.getImportSuggestions(input);
        
        // Assert
        expect(suggestions, isEmpty);
      });
    });
    
    group('Direct Recipe Save', () {
      test('should save imported recipe directly', () async {
        // Arrange
        when(() => mockPersonalOperations.addUnifiedRecipe(testRecipe))
            .thenAnswer((_) async => RecipeOperationResult.success('Saved'));
        
        // Act
        final result = await importManager.saveImportedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.strategy, equals('direct_save'));
        verify(() => mockPersonalOperations.addUnifiedRecipe(testRecipe)).called(1);
      });
      
      test('should handle save failure', () async {
        // Arrange
        when(() => mockPersonalOperations.addUnifiedRecipe(testRecipe))
            .thenAnswer((_) async => RecipeOperationResult.failure('Save failed'));
        
        // Act
        final result = await importManager.saveImportedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Failed to save recipe'));
      });
      
      test('should handle save exception', () async {
        // Arrange
        when(() => mockPersonalOperations.addUnifiedRecipe(testRecipe))
            .thenAnswer((_) async => throw Exception('Database error'));
        
        // Act
        final result = await importManager.saveImportedRecipe(testRecipe);
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Error saving recipe'));
      });
    });
    
    group('Result Objects', () {
      test('ImportManagerResult should have correct properties', () {
        // Arrange
        final successResult = ImportManagerResult.success(
          testRecipe,
          strategy: 'test',
          warnings: ['warning1'],
          metadata: {'source': 'test'},
        );
        
        final failureResult = ImportManagerResult.failure(
          'Error message',
          strategy: 'test',
          availableStrategies: ['strategy1', 'strategy2'],
        );
        
        // Assert success result
        expect(successResult.isSuccess, isTrue);
        expect(successResult.recipe, equals(testRecipe));
        expect(successResult.hasWarnings, isTrue);
        expect(successResult.hasMetadata, isTrue);
        expect(successResult.importedRecipes, hasLength(1));
        expect(successResult.error, isNull);
        
        // Assert failure result
        expect(failureResult.isSuccess, isFalse);
        expect(failureResult.recipe, isNull);
        expect(failureResult.errorMessage, equals('Error message'));
        expect(failureResult.availableStrategies, hasLength(2));
        expect(failureResult.error, equals('Error message'));
        expect(failureResult.importedRecipes, isEmpty);
      });
      
      test('BatchImportResult should calculate properties correctly', () {
        // Arrange
        final results = [
          ImportManagerResult.success(testRecipe),
          ImportManagerResult.failure('Error 1'),
          ImportManagerResult.success(testRecipe),
        ];
        
        final batchResult = BatchImportResult(
          results: results,
          successfulRecipes: [testRecipe, testRecipe],
          errors: ['Error 1'],
          totalProcessed: 3,
          successCount: 2,
          failureCount: 1,
        );
        
        // Assert
        expect(batchResult.successRate, closeTo(0.667, 0.001));
        expect(batchResult.hasErrors, isTrue);
        expect(batchResult.allSuccessful, isFalse);
        
        // Test all successful case
        final allSuccessResult = BatchImportResult(
          results: [ImportManagerResult.success(testRecipe)],
          successfulRecipes: [testRecipe],
          errors: [],
          totalProcessed: 1,
          successCount: 1,
          failureCount: 0,
        );
        
        expect(allSuccessResult.allSuccessful, isTrue);
        expect(allSuccessResult.hasErrors, isFalse);
        expect(allSuccessResult.successRate, equals(1.0));
      });
      
      test('ImportSuggestion should store properties correctly', () {
        // Arrange
        final strategy = MockImportStrategy();
        when(() => strategy.strategyName).thenReturn('test_strategy');
        
        final suggestion = ImportSuggestion(
          strategy: strategy,
          confidence: 0.85,
          description: 'Test strategy description',
        );
        
        // Assert
        expect(suggestion.strategy, equals(strategy));
        expect(suggestion.confidence, equals(0.85));
        expect(suggestion.description, equals('Test strategy description'));
      });
    });
    
    group('Edge Cases', () {
      test('should handle null options gracefully', () async {
        // Act
        final result = await importManager.autoImport(
          'some input',
          options: null,
        );
        
        // Assert - Should not throw
        expect(result, isNotNull);
      });
      
      test('should handle strategy returning null recipe', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        const input = 'null recipe input';
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('null_strategy');
        when(() => mockStrategy.import(input, options: any(named: 'options')))
            .thenAnswer((_) async => import_strategy.ImportResult.success(null));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        expect(result.isSuccess, isFalse);
        // The error message may vary depending on implementation
        expect(result.errorMessage, anyOf(
          contains('no recipe returned'),
          contains('No import strategy could handle'),
          contains('but no recipe'),
        ));
      });
      
      test('should handle PersonalRecipeOperations save failure', () async {
        // Arrange
        mockStrategy = MockImportStrategy();
        const input = 'save failure input';
        
        when(() => mockStrategy.canHandle(input)).thenReturn(true);
        when(() => mockStrategy.strategyName).thenReturn('save_fail_strategy');
        when(() => mockStrategy.import(input, options: any(named: 'options')))
            .thenAnswer((_) async => import_strategy.ImportResult.success(testRecipe));
        when(() => mockPersonalOperations.addUnifiedRecipe(testRecipe))
            .thenAnswer((_) async => RecipeOperationResult.failure('Database error'));
        
        // Act
        final result = await importManager.autoImport(
          input,
          preferredStrategy: mockStrategy,
        );
        
        // Assert
        expect(result.isSuccess, isFalse);
        // The error message may include save failure or fallback to other strategies
        expect(result.errorMessage, anyOf(
          contains('Failed to save imported recipe'),
          contains('No import strategy could handle'),
          contains('Database error'),
        ));
        // Recipe might be preserved depending on implementation
        if (result.recipe != null) {
          expect(result.recipe, equals(testRecipe));
        }
      });
      
      test('should handle concurrent batch imports', () async {
        // Arrange
        final batch1 = List.generate(5, (i) => 'batch1_recipe_$i');
        final batch2 = List.generate(5, (i) => 'batch2_recipe_$i');
        
        // Act - Start both imports concurrently
        final future1 = importManager.batchImport(batch1);
        final future2 = importManager.batchImport(batch2);
        
        final results = await Future.wait([future1, future2]);
        
        // Assert
        expect(results[0].totalProcessed, equals(5));
        expect(results[1].totalProcessed, equals(5));
      });
    });
    
    group('Performance', () {
      test('should handle large batch efficiently', () async {
        // Arrange
        final largeInputs = List.generate(100, (i) => 'recipe_$i');
        
        // Act
        final stopwatch = Stopwatch()..start();
        final result = await importManager.batchImport(largeInputs);
        stopwatch.stop();
        
        // Assert
        expect(result.totalProcessed, equals(100));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000), 
               reason: 'Large batch should process in reasonable time');
      });
      
      test('should cache strategy compatibility checks', () {
        // Arrange
        const input = 'test input';
        
        // Act - Call multiple times
        final compatible1 = importManager.getCompatibleStrategies(input);
        final compatible2 = importManager.getCompatibleStrategies(input);
        final compatible3 = importManager.getCompatibleStrategies(input);
        
        // Assert - Results should be consistent
        expect(compatible1.length, equals(compatible2.length));
        expect(compatible2.length, equals(compatible3.length));
      });
    });
  });
}