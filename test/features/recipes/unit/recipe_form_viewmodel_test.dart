/// Comprehensive unit tests for RecipeFormViewModel following TDD and BDD patterns.
///
/// This test suite validates all aspects of recipe form management including form state,
/// validation, save operations, collaborative editing, image management, and permission control
/// using Mocktail and comprehensive test scenarios following Given-When-Then structure.

import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

import '../../../helpers/test_service_locator.dart';

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  group('RecipeFormViewModel', () {
    late RecipeFormViewModel sut; // System Under Test
    late MockUnifiedRecipeService mockRecipeService;
    late MockAnalyticsService mockAnalyticsService;

    setUp(() {
      // ServiceLocator is already initialized by configureTests()
      mockRecipeService = TestServiceLocator.mockRecipeService;
      mockAnalyticsService = TestServiceLocator.mockAnalyticsService;

      sut = RecipeFormViewModel(
        recipeService: mockRecipeService,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() {
      sut.dispose();
      // Cleanup is handled by configureTests()
    });

    group('initialization', () {
      test('should initialize with default values for new recipe', () {
        // Then
        expect(sut.title, equals(''));
        expect(sut.description, equals(''));
        expect(sut.mealType, equals('Middag'));
        expect(sut.portions, isNull);
        expect(sut.timeMinutes, isNull);
        expect(sut.rating, isNull);
        expect(sut.imageUrls, isEmpty);
        expect(sut.sourceUrl, isNull);
        expect(sut.ingredients, isEmpty);
        expect(sut.instructions, isEmpty);
        expect(sut.tags, isEmpty);
        expect(sut.isEditing, isFalse);
        expect(sut.originalRecipe, isNull);
        expect(sut.hasUnsavedChanges, isFalse);
      });

      test('should initialize with existing recipe data for editing', () {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe(
          title: 'Existing Recipe',
          description: 'Existing description',
          ingredients: ['Existing ingredient'],
          instructions: ['Existing instruction'],
        );

        // When
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        // Then
        expect(sut.title, equals('Existing Recipe'));
        expect(sut.description, equals('Existing description'));
        expect(sut.ingredients, contains('Existing ingredient'));
        expect(sut.instructions, contains('Existing instruction'));
        expect(sut.isEditing, isTrue);
        expect(sut.originalRecipe, equals(existingRecipe));
      });

      test('should initialize as template', () {
        // Given
        final templateRecipe = TestServiceLocator.createTestRecipe();

        // When
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: templateRecipe,
          isTemplate: true,
        );

        // Then
        expect(
            sut.isEditing, isFalse); // Template should not be in editing mode
        expect(sut.originalRecipe, equals(templateRecipe));
      });
    });

    group('form state management', () {
      test('should update title', () {
        // Given
        const newTitle = 'Updated Recipe Title';

        // When
        sut.setTitle(newTitle);

        // Then
        expect(sut.title, equals(newTitle));
      });

      test('should update description', () {
        // Given
        const newDescription = 'Updated recipe description';

        // When
        sut.setDescription(newDescription);

        // Then
        expect(sut.description, equals(newDescription));
      });

      test('should update meal type', () {
        // Given
        const newMealType = 'Frukost';

        // When
        sut.setMealType(newMealType);

        // Then
        expect(sut.mealType, equals(newMealType));
      });

      test('should update portions', () {
        // Given
        const newPortions = 6;

        // When
        sut.setPortions(newPortions);

        // Then
        expect(sut.portions, equals(newPortions));
      });

      test('should update time minutes', () {
        // Given
        const newTimeMinutes = 45;

        // When
        sut.setTimeMinutes(newTimeMinutes);

        // Then
        expect(sut.timeMinutes, equals(newTimeMinutes));
      });

      test('should update rating', () {
        // Given
        const newRating = 4.5;

        // When
        sut.setRating(newRating);

        // Then
        expect(sut.rating, equals(newRating));
      });

      test('should update source URL', () {
        // Given
        const newSourceUrl = 'https://example.com/recipe';

        // When
        sut.setSourceUrl(newSourceUrl);

        // Then
        expect(sut.sourceUrl, equals(newSourceUrl));
      });
    });

    group('dynamic list management', () {
      test('should add ingredient', () {
        // Given
        expect(sut.ingredients, isEmpty);

        // When
        sut.addIngredient();

        // Then
        expect(sut.ingredients, hasLength(1));
        expect(sut.ingredients[0], equals(''));
      });

      test('should update ingredient', () {
        // Given
        sut.addIngredient();
        const ingredientText = 'Tomatoes';

        // When
        sut.updateIngredient(0, ingredientText);

        // Then
        expect(sut.ingredients[0], equals(ingredientText));
      });

      test('should remove ingredient', () {
        // Given
        sut.addIngredient();
        sut.addIngredient();
        expect(sut.ingredients, hasLength(2));

        // When
        sut.removeIngredient(0);

        // Then
        expect(sut.ingredients, hasLength(1));
      });

      test('should add instruction', () {
        // Given
        expect(sut.instructions, isEmpty);

        // When
        sut.addInstruction();

        // Then
        expect(sut.instructions, hasLength(1));
        expect(sut.instructions[0], equals(''));
      });

      test('should update instruction', () {
        // Given
        sut.addInstruction();
        const instructionText = 'Chop the tomatoes';

        // When
        sut.updateInstruction(0, instructionText);

        // Then
        expect(sut.instructions[0], equals(instructionText));
      });

      test('should remove instruction', () {
        // Given
        sut.addInstruction();
        sut.addInstruction();
        expect(sut.instructions, hasLength(2));

        // When
        sut.removeInstruction(0);

        // Then
        expect(sut.instructions, hasLength(1));
      });

      test('should add tag', () {
        // Given
        expect(sut.tags, isEmpty);

        // When
        sut.addTag();

        // Then
        expect(sut.tags, hasLength(1));
        expect(sut.tags[0], equals(''));
      });

      test('should update tag', () {
        // Given
        sut.addTag();
        const tagText = 'vegetarian';

        // When
        sut.updateTag(0, tagText);

        // Then
        expect(sut.tags[0], equals(tagText));
      });

      test('should remove tag', () {
        // Given
        sut.addTag();
        sut.addTag();
        expect(sut.tags, hasLength(2));

        // When
        sut.removeTag(0);

        // Then
        expect(sut.tags, hasLength(1));
      });
    });

    group('form validation', () {
      test('should be invalid with empty title', () {
        // Given
        sut.setTitle('');
        sut.setDescription('Valid description');

        // Then
        expect(sut.isValid, isFalse);
      });

      test('should be valid with required fields filled', () {
        // Given
        sut.setTitle('Valid Title');
        sut.setDescription('Valid description');

        // Then
        expect(sut.isValid, isTrue);
      });
    });

    group('unsaved changes detection', () {
      test('should detect changes in editing mode', () {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe(
          title: 'Original Title',
          description: 'Original description',
        );

        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        // When
        sut.setTitle('Modified Title');

        // Then
        expect(sut.hasUnsavedChanges, isTrue);
      });

      test('should not detect changes for new recipes', () {
        // Given - new recipe (no original recipe)
        sut.setTitle('Some Title');
        sut.setDescription('Some description');

        // Then
        expect(sut.hasUnsavedChanges, isFalse);
      });

      test('should not detect changes when fields match original', () {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe(
          title: 'Original Title',
          description: 'Original description',
        );

        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        // Then (no changes made)
        expect(sut.hasUnsavedChanges, isFalse);
      });
    });

    group('save operations', () {
      test('should save new recipe successfully', () async {
        // Given
        sut.setTitle('New Recipe');
        sut.setDescription('New description');

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.success('Recipe created'));

        // When
        final result = await sut.saveRecipe();

        // Then
        expect(result, isNotNull);
        expect(result!.core.title, equals('New Recipe'));
        verify(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .called(1);
      });

      test('should update existing recipe successfully', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        sut.setTitle('Updated Recipe');

        when(() => mockRecipeService.personal.updateUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.success('Recipe updated'));

        // When
        final result = await sut.saveRecipe();

        // Then
        expect(result, isNotNull);
        expect(result!.core.title, equals('Updated Recipe'));
        verify(() => mockRecipeService.personal.updateUnifiedRecipe(any()))
            .called(1);
      });

      test('should handle save failures gracefully', () async {
        // Given
        sut.setTitle('Recipe Title');
        sut.setDescription('Recipe description');

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.failure('Save failed'));

        // When
        final result = await sut.saveRecipe();

        // Then
        expect(result, isNull);
        expect(sut.hasError, isTrue);
        expect(sut.error, contains('Failed to create recipe'));
      });

      test('should not save invalid form', () async {
        // Given
        sut.setTitle(''); // Invalid - empty title
        sut.setDescription('Description');

        // When
        final result = await sut.saveRecipe();

        // Then
        expect(result, isNull);
        expect(sut.hasError, isTrue);
        expect(sut.error, equals('Fyll i alla obligatoriska fält'));
        verifyNever(() => mockRecipeService.personal.addUnifiedRecipe(any()));
      });

      test('should set saving state during save operation', () async {
        // Given
        sut.setTitle('Recipe Title');
        sut.setDescription('Recipe description');
        expect(sut.isSaving, isFalse);

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer((_) async {
          // During save operation, should be saving
          expect(sut.isSaving, isTrue);
          return RecipeOperationResult.success('Saved');
        });

        // When
        final result = await sut.saveRecipe();

        // Then
        expect(result, isNotNull);
        expect(sut.isSaving, isFalse); // Should reset after save
      });
    });

    group('fork operations', () {
      test('should fork recipe successfully', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.success('Recipe forked'));

        // When
        final result = await sut.forkRecipe();

        // Then
        expect(result, isNotNull);
        verify(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .called(1);
      });

      test('should handle fork failure', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.failure('Fork failed'));

        // When
        final result = await sut.forkRecipe();

        // Then
        expect(result, isNull);
        expect(sut.hasError, isTrue);
      });

      test('should not fork without original recipe', () async {
        // Given - new recipe (no original recipe)

        // When
        final result = await sut.forkRecipe();

        // Then
        expect(result, isNull);
        expect(sut.hasError, isTrue);
        expect(sut.error, equals('Inget recept att forka'));
      });

      test('should set forking state during fork operation', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );
        expect(sut.isForking, isFalse);

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer((_) async {
          // During fork operation, should be forking
          expect(sut.isForking, isTrue);
          return RecipeOperationResult.success('Forked');
        });

        // When
        final result = await sut.forkRecipe();

        // Then
        expect(result, isNotNull);
        expect(sut.isForking, isFalse); // Should reset after fork
      });
    });

    group('delete operations', () {
      test('should delete recipe successfully', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        when(() => mockRecipeService.deleteRecipe(any()))
            .thenAnswer((_) async => true);

        // When
        final result = await sut.deleteRecipe();

        // Then
        expect(result, isTrue);
        verify(() => mockRecipeService.deleteRecipe(existingRecipe.id))
            .called(1);
      });

      test('should not delete without original recipe', () async {
        // Given - new recipe (no original recipe)

        // When
        final result = await sut.deleteRecipe();

        // Then
        expect(result, isFalse);
        expect(sut.hasError, isTrue);
        expect(sut.error, equals('Inget recept att ta bort'));
      });

      test('should handle delete failures', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        when(() => mockRecipeService.deleteRecipe(any()))
            .thenThrow(Exception('Delete failed'));

        // When
        final result = await sut.deleteRecipe();

        // Then
        expect(result, isFalse);
        expect(sut.hasError, isTrue);
        expect(sut.error, equals('Kunde inte ta bort recept'));
      });
    });

    group('error handling', () {
      test('should clear error state', () {
        // Given - set error state first
        sut.setTitle(''); // This should cause validation error
        expect(sut.hasError, isTrue);

        // When
        // Simulate clearing error through some operation
        sut.setTitle('Valid Title');
        sut.setDescription('Valid Description');

        // Then
        expect(sut.hasError, isFalse);
      });
    });

    group('backward compatibility', () {
      test('should support saveFork operation', () async {
        // Given
        final existingRecipe = TestServiceLocator.createTestRecipe();
        sut = RecipeFormViewModel(
          recipeService: mockRecipeService,
          initialRecipe: existingRecipe,
        );

        when(() => mockRecipeService.personal.addUnifiedRecipe(any()))
            .thenAnswer(
                (_) async => RecipeOperationResult.success('Recipe forked'));

        // When
        final result = await sut.saveFork();

        // Then
        expect(result, isNotNull);
      });

      test('should support setPortionsFromDouble', () {
        // Given
        const doubleValue = 4.0;

        // When
        sut.setPortionsFromDouble(doubleValue);

        // Then
        expect(sut.portions, equals(4));
      });

      test('should support setTimeMinutesFromDouble', () {
        // Given
        const doubleValue = 30.0;

        // When
        sut.setTimeMinutesFromDouble(doubleValue);

        // Then
        expect(sut.timeMinutes, equals(30));
      });
    });
  });
}
