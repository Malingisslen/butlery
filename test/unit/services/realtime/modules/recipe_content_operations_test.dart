import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/realtime/modules/recipe_content_operations.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/builders/realtime_recipe_builder.dart';

void main() {
  group('RecipeContentOperations', () {
    late RealtimeRecipeBuilder realtimeRecipeBuilder;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      realtimeRecipeBuilder = RealtimeRecipeBuilder();
    });

    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Basic Info Updates', () {
      test('should update recipe title', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act
        final updated = RecipeContentOperations.updateBasicInfo(
          recipe,
          title: 'Ny recepttitel',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.title, 'Ny recepttitel');
        expect(identical(recipe, updated), false); // New instance
      });

      test('should update recipe description', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act
        final updated = RecipeContentOperations.updateBasicInfo(
          recipe,
          description: 'En detaljerad beskrivning av receptet',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.description,
            'En detaljerad beskrivning av receptet');
      });

      test('should update meal type', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act
        final updated = RecipeContentOperations.updateBasicInfo(
          recipe,
          mealType: 'Frukost',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.mealType, 'Frukost');
      });

      test('should update cooking time', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act
        final updated = RecipeContentOperations.updateBasicInfo(
          recipe,
          timeMinutes: 45,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.timeMinutes, 45);
      });

      test('should validate immutability', () {
        // Arrange
        final original = realtimeRecipeBuilder.withTitle('Original').build();

        // Act
        final updated = RecipeContentOperations.updateBasicInfo(
          original,
          title: 'Updated',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert - Check properties match, not object identity
        expect(original.recipe.title, 'Original'); // Original unchanged
        expect(updated.recipe.title, 'Updated'); // New object has update
        expect(identical(original, updated), false); // Different objects
      });
    });

    group('Ingredient Operations', () {
      test('should add ingredient to recipe', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withIngredients(['Ingredient 1']).build();

        // Act
        final updated = RecipeContentOperations.addIngredient(
          recipe,
          ingredient: 'Ingredient 2',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.ingredients.length, 2);
        expect(updated.recipe.ingredients.last, 'Ingredient 2');
      });

      test('should remove ingredient by index', () {
        // Arrange
        final recipe = realtimeRecipeBuilder
            .withIngredients(['First', 'Second', 'Third']).build();

        // Act
        final updated = RecipeContentOperations.removeIngredient(
          recipe,
          index: 1,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.ingredients.length, 2);
        expect(updated.recipe.ingredients, ['First', 'Third']);
      });

      test('should update all ingredients', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withIngredients(['Old 1', 'Old 2']).build();
        final newIngredients = ['New 1', 'New 2', 'New 3'];

        // Act
        final updated = RecipeContentOperations.updateIngredients(
          recipe,
          ingredients: newIngredients,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.ingredients, newIngredients);
        expect(updated.recipe.ingredients.length, 3);
      });

      test('should handle empty ingredient list', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withIngredients(['Something']).build();

        // Act & Assert - Should throw error for empty ingredients
        expect(
          () => RecipeContentOperations.updateIngredients(
            recipe,
            ingredients: [],
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should support Swedish ingredients', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();
        final swedishIngredients = [
          '500g köttfärs',
          '1 ägg',
          '1 dl ströbröd',
          'Lingonsylt för servering',
        ];

        // Act
        final updated = RecipeContentOperations.updateIngredients(
          recipe,
          ingredients: swedishIngredients,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.ingredients, swedishIngredients);
        expect(updated.recipe.ingredients.first, contains('köttfärs'));
      });

      test('should validate index when removing ingredient', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withIngredients(['Only one']).build();

        // Act & Assert
        expect(
          () => RecipeContentOperations.removeIngredient(
            recipe,
            index: 5, // Out of bounds
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });
    });

    group('Instruction Operations', () {
      test('should add instruction to recipe', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withInstructions(['Step 1']).build();

        // Act
        final updated = RecipeContentOperations.addInstruction(
          recipe,
          instruction: 'Step 2',
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.instructions.length, 2);
        expect(updated.recipe.instructions.last, 'Step 2');
      });

      test('should remove instruction by index', () {
        // Arrange
        final recipe = realtimeRecipeBuilder
            .withInstructions(['Step 1', 'Step 2', 'Step 3']).build();

        // Act
        final updated = RecipeContentOperations.removeInstruction(
          recipe,
          index: 0,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.instructions.length, 2);
        expect(updated.recipe.instructions.first, 'Step 2');
      });

      test('should update all instructions', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();
        final newInstructions = [
          'Förbered ingredienser',
          'Blanda allt',
          'Koka i 20 minuter',
          'Servera varmt',
        ];

        // Act
        final updated = RecipeContentOperations.updateInstructions(
          recipe,
          instructions: newInstructions,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.instructions, newInstructions);
        expect(updated.recipe.instructions.length, 4);
      });

      test('should handle reordering instructions', () {
        // Arrange
        final recipe = realtimeRecipeBuilder
            .withInstructions(['A', 'B', 'C', 'D']).build();

        // Act - Simulate reordering
        final reordered = ['D', 'A', 'C', 'B'];
        final updated = RecipeContentOperations.updateInstructions(
          recipe,
          instructions: reordered,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.instructions, reordered);
      });

      test('should handle empty instruction list', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withInstructions(['Something']).build();

        // Act & Assert - Should throw error for empty instructions
        expect(
          () => RecipeContentOperations.updateInstructions(
            recipe,
            instructions: [],
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should support multi-line instructions', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();
        final multiLineInstruction = '''
Blanda köttfärs, ägg och ströbröd.
Låt stå i 10 minuter.
Forma till köttbullar.''';

        // Act
        final updated = RecipeContentOperations.addInstruction(
          recipe,
          instruction: multiLineInstruction,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.instructions.last, contains('köttfärs'));
        expect(updated.recipe.instructions.last, contains('\n'));
      });
    });

    group('Image Operations', () {
      test('should add image URL to recipe', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();
        const imageUrl = 'https://example.com/recipe.jpg';

        // Act
        final updated = RecipeContentOperations.addImage(
          recipe,
          imageUrl: imageUrl,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.imageUrls, contains(imageUrl));
      });

      test('should remove image by index', () {
        // Arrange
        final recipe = realtimeRecipeBuilder
            .withImages(['img1.jpg', 'img2.jpg', 'img3.jpg']).build();

        // Act
        final updated = RecipeContentOperations.removeImage(
          recipe,
          index: 1,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.imageUrls.length, 2);
        expect(updated.recipe.imageUrls, ['img1.jpg', 'img3.jpg']);
      });

      test('should update all images', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.withImages(['old1.jpg', 'old2.jpg']).build();
        final newImages = ['new1.jpg', 'new2.jpg', 'new3.jpg'];

        // Act
        final updated = RecipeContentOperations.updateImages(
          recipe,
          imageUrls: newImages,
          editedBy: 'test_user',
          editedByDisplayName: 'Test User',
        );

        // Assert
        expect(updated.recipe.imageUrls, newImages);
      });

      test('should validate URL format', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act & Assert - Invalid URL should throw
        expect(
          () => RecipeContentOperations.addImage(
            recipe,
            imageUrl: 'not-a-valid-url',
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should enforce maximum image limit of 5', () {
        // Arrange
        final images = List.generate(5, (i) => 'https://example.com/img$i.jpg');
        final recipe = realtimeRecipeBuilder.withImages(images).build();

        // Act & Assert - Should prevent adding more than 5 images
        expect(
          () => RecipeContentOperations.addImage(
            recipe,
            imageUrl: 'https://example.com/extra.jpg',
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });
    });

    group('Validation & Utilities', () {
      test('should check recipe completeness', () {
        // Arrange
        final complete =
            realtimeRecipeBuilder.asCollaborativeSwedishDinner().build();
        final incomplete = realtimeRecipeBuilder.asIncompleteRecipe().build();

        // Act & Assert
        expect(RecipeContentOperations.isRecipeComplete(complete), true);
        expect(RecipeContentOperations.isRecipeComplete(incomplete), false);
      });

      test('should validate recipe content', () {
        // Arrange
        final valid =
            realtimeRecipeBuilder.asCollaborativeSwedishDinner().build();
        final invalid = realtimeRecipeBuilder
            .withTitle('') // Empty title
            .build();

        // Act & Assert
        expect(RecipeContentOperations.validateRecipeContent(valid), isEmpty);
        final errors = RecipeContentOperations.validateRecipeContent(invalid);
        expect(errors, isNotEmpty);
        expect(
          errors.any((error) =>
              error.contains('titel') || error.contains('Recepttitel')),
          true,
          reason: 'Should contain Swedish error message about title',
        );
      });

      test('should calculate complexity score for simple recipe', () {
        // Arrange
        final simple = realtimeRecipeBuilder
            .withIngredients(['Ingredient 1', 'Ingredient 2'])
            .withInstructions(['Step 1', 'Step 2'])
            .withTimeMinutes(15)
            .build();

        // Act
        final score = RecipeContentOperations.getComplexityScore(simple);

        // Assert
        expect(score, lessThanOrEqualTo(2)); // Simple recipe
      });

      test('should calculate complexity score for complex recipe', () {
        // Arrange
        final complex = realtimeRecipeBuilder.asComplexRecipe().build();

        // Act
        final score = RecipeContentOperations.getComplexityScore(complex);

        // Assert
        expect(score, greaterThanOrEqualTo(4)); // Complex recipe
      });

      test('should create personal copy of recipe', () {
        // Arrange
        final original = realtimeRecipeBuilder
            .withId('original_id')
            .withOwner('original_owner', 'Original Owner')
            .asCollaborativeSwedishDinner()
            .build();
        const newUserId = 'new_user_123';

        // Act
        final copy = RecipeContentOperations.createPersonalCopy(
          original,
          newOwnerId: newUserId,
        );

        // Assert - Personal copy has different ID and owner
        expect(copy.id, isNot(original.recipe.id));
        expect(copy.createdBy, newUserId);
        expect(copy.title,
            'Kopia av ${original.recipe.title}'); // Title gets "Kopia av " prefix
      });

      test('should generate content summary', () {
        // Arrange
        final recipe =
            realtimeRecipeBuilder.asCollaborativeSwedishDinner().build();

        // Act
        final summary = RecipeContentOperations.getContentSummary(recipe);

        // Assert
        expect(summary, contains('ingredienser'));
        expect(summary, contains('steg'));
        expect(summary, contains('min')); // Uses 'min' not 'minuter'
      });

      test('should handle minimal recipe edge case', () {
        // Arrange
        final minimal = realtimeRecipeBuilder.asMinimalRecipe().build();

        // Act
        final complete = RecipeContentOperations.isRecipeComplete(minimal);
        final score = RecipeContentOperations.getComplexityScore(minimal);
        final summary = RecipeContentOperations.getContentSummary(minimal);

        // Assert
        expect(complete, true); // Has minimum requirements
        expect(score, 1); // Lowest complexity
        expect(summary, isNotEmpty);
      });

      test('should validate content with Swedish characters', () {
        // Arrange
        final swedishRecipe = realtimeRecipeBuilder
            .withTitle('Köttbullar med gräddsås')
            .withIngredients(['Köttfärs', 'Ägg', 'Mjölk']).withInstructions(
                ['Värm ugnen', 'Blanda köttfärsen']).build();

        // Act
        final errors =
            RecipeContentOperations.validateRecipeContent(swedishRecipe);

        // Assert
        expect(errors, isEmpty); // Swedish characters are valid
      });
    });

    group('Error Handling', () {
      test('should handle negative index for removal', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.withIngredients(['Item']).build();

        // Act & Assert
        expect(
          () => RecipeContentOperations.removeIngredient(
            recipe,
            index: -1,
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should handle empty title validation', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act & Assert
        expect(
          () => RecipeContentOperations.updateBasicInfo(
            recipe,
            title: '',
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should handle invalid time values', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act & Assert
        expect(
          () => RecipeContentOperations.updateBasicInfo(
            recipe,
            timeMinutes: -10,
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should throw error for empty title', () {
        // Arrange
        final recipe = realtimeRecipeBuilder.build();

        // Act & Assert - Production throws for empty title
        expect(
          () => RecipeContentOperations.updateBasicInfo(
            recipe,
            title: '',
            editedBy: 'test_user',
            editedByDisplayName: 'Test User',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });
    });
  });
}
