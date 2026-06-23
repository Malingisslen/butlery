import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';

// Local pure mock — the centralized MockUnifiedRecipeService has concrete
// @override methods (e.g. createRecipe(Recipe)) that clash with mocktail's
// when() for the named-parameter PersonalRecipeDelegate.createRecipe signature.
class MockPersonalRecipeDelegate extends Mock
    implements PersonalRecipeDelegate {}

void main() {
  group('PersonalRecipeOperations', () {
    late PersonalRecipeOperations operations;
    late MockPersonalRecipeDelegate mockDelegate;
    late Recipe testRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeBuilder().build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockDelegate = MockPersonalRecipeDelegate();

      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Swedish Meatballs')
          .withDescription('Traditional Swedish meatballs')
          .build();

      operations = PersonalRecipeOperations(mockDelegate);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with parent service', () {
        expect(operations, isNotNull);
      });
    });

    group('Recipe CRUD Operations', () {
      test('should add unified recipe successfully', () async {
        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => 'new-recipe-id');

        final result = await operations.addUnifiedRecipe(testRecipe);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('successfully'));
        verify(
          () => mockDelegate.createRecipe(
            title: testRecipe.title,
            description: testRecipe.description,
            ingredients: testRecipe.ingredients,
            instructions: testRecipe.instructions,
            imageUrls: testRecipe.imageUrls,
            mealType: testRecipe.mealType,
            portions: testRecipe.portions,
            timeMinutes: testRecipe.timeMinutes,
            rating: testRecipe.rating,
            personalTagIds: testRecipe.personalTagIds,
            sourceUrl: testRecipe.sourceUrl,
          ),
        ).called(1);
      });

      test('should handle add recipe failure', () async {
        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => null);

        final result = await operations.addUnifiedRecipe(testRecipe);

        // BUT-968: when createRecipe returns null (non-exception failure
        // path), the message is the localized "could not add" string, not
        // the raw "Failed: ..." that used to leak. Assert the contract,
        // not the literal English text — the locale could change.
        expect(result.isSuccess, isFalse);
        expect(result.message, isNotNull);
        expect(result.message, isNotEmpty);
        expect(result.message, isNot(contains('Exception')));
      });

      test('should update unified recipe successfully', () async {
        when(
          () => mockDelegate.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        final result = await operations.updateUnifiedRecipe(testRecipe);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('successfully'));
        verify(() => mockDelegate.updateRecipe(testRecipe)).called(1);
      });

      test('should handle update recipe failure', () async {
        when(
          () => mockDelegate.updateRecipe(any()),
        ).thenAnswer((_) async => false);

        final result = await operations.updateUnifiedRecipe(testRecipe);

        // BUT-968: failure message is the localized "could not update"
        // fallback, not the raw exception text. Assert the contract.
        expect(result.isSuccess, isFalse);
        expect(result.message, isNotNull);
        expect(result.message, isNotEmpty);
        expect(result.message, isNot(contains('Exception')));
      });

      test('should delete recipe', () async {
        when(
          () => mockDelegate.deleteRecipe(any()),
        ).thenAnswer((_) async => true);

        final result = await operations.deleteRecipe('recipe-123');

        expect(result, isTrue);
        verify(() => mockDelegate.deleteRecipe('recipe-123')).called(1);
      });
    });

    group('Batch Operations', () {
      test('should add multiple recipes successfully', () async {
        final recipes = [
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
          RecipeBuilder().withTitle('Recipe 3').build(),
        ];

        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => 'new-id');

        final result = await operations.addMultipleUnifiedRecipes(recipes);

        // Production returns '3 recipes imported' (English hardcoded)
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('3 recipes imported'));
        verify(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).called(3);
      });

      test('should handle partial batch success', () async {
        final recipes = [
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
          RecipeBuilder().withTitle('Recipe 3').build(),
        ];

        var callCount = 0;
        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return callCount <= 2 ? 'new-id' : null;
        });

        final result = await operations.addMultipleUnifiedRecipes(recipes);

        // Production returns '2/3 recipes imported...'
        expect(result.isSuccess, isTrue);
        expect(result.message, contains('2/3 recipes imported'));
      });

      test('should handle complete batch failure', () async {
        final recipes = [
          RecipeBuilder().withTitle('Recipe 1').build(),
          RecipeBuilder().withTitle('Recipe 2').build(),
        ];

        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => null);

        final result = await operations.addMultipleUnifiedRecipes(recipes);

        // Production uses AppLocale.current.errorCouldNotImportRecipes
        // Default locale is Swedish: 'Kunde inte importera recept'
        expect(result.isSuccess, isFalse);
        expect(result.message, contains('Kunde inte importera recept'));
      });
    });

    group('Content Management', () {
      test('should update recipe content', () async {
        when(
          () => mockDelegate.updateRecipeContent(
            recipeId: any(named: 'recipeId'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => true);

        final result = await operations.updateRecipeContent(
          recipeId: 'recipe-123',
          title: 'Updated Title',
          description: 'Updated Description',
        );

        expect(result, isTrue);
        verify(
          () => mockDelegate.updateRecipeContent(
            recipeId: 'recipe-123',
            title: 'Updated Title',
            description: 'Updated Description',
          ),
        ).called(1);
      });

      test('should add ingredient', () async {
        when(
          () => mockDelegate.addIngredient(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.addIngredient(
          'recipe-123',
          '2 dl mjölk',
        );

        expect(result, isTrue);
        verify(
          () => mockDelegate.addIngredient('recipe-123', '2 dl mjölk'),
        ).called(1);
      });

      test('should update ingredient', () async {
        when(
          () => mockDelegate.updateIngredient(any(), any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.updateIngredient(
          'recipe-123',
          0,
          '3 dl mjölk',
        );

        expect(result, isTrue);
        verify(
          () => mockDelegate.updateIngredient('recipe-123', 0, '3 dl mjölk'),
        ).called(1);
      });

      test('should remove ingredient', () async {
        when(
          () => mockDelegate.removeIngredient(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.removeIngredient('recipe-123', 0);

        expect(result, isTrue);
        verify(() => mockDelegate.removeIngredient('recipe-123', 0)).called(1);
      });

      test('should add instruction', () async {
        when(
          () => mockDelegate.addInstruction(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.addInstruction(
          'recipe-123',
          'Värm ugnen till 200°C',
        );

        expect(result, isTrue);
        verify(
          () => mockDelegate.addInstruction(
            'recipe-123',
            'Värm ugnen till 200°C',
          ),
        ).called(1);
      });

      test('should update instruction', () async {
        when(
          () => mockDelegate.updateInstruction(any(), any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.updateInstruction(
          'recipe-123',
          0,
          'Värm ugnen till 225°C',
        );

        expect(result, isTrue);
        verify(
          () => mockDelegate.updateInstruction(
            'recipe-123',
            0,
            'Värm ugnen till 225°C',
          ),
        ).called(1);
      });

      test('should remove instruction', () async {
        when(
          () => mockDelegate.removeInstruction(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await operations.removeInstruction('recipe-123', 0);

        expect(result, isTrue);
        verify(() => mockDelegate.removeInstruction('recipe-123', 0)).called(1);
      });
    });

    group('Recipe Lifecycle', () {
      test('should mark recipe as cooked', () async {
        when(
          () => mockDelegate.markAsCooked(any()),
        ).thenAnswer((_) async => true);

        final result = await operations.markAsCooked('recipe-123');

        expect(result, isTrue);
        verify(() => mockDelegate.markAsCooked('recipe-123')).called(1);
      });
    });

    group('Legacy Compatibility', () {
      test('should add legacy recipe', () async {
        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => 'new-recipe-id');

        final result = await operations.addLegacyRecipe(testRecipe);

        expect(result.isSuccess, isTrue);
        verify(
          () => mockDelegate.createRecipe(
            title: testRecipe.title,
            description: testRecipe.description,
            ingredients: testRecipe.ingredients,
            instructions: testRecipe.instructions,
            imageUrls: testRecipe.imageUrls,
            mealType: testRecipe.mealType,
            portions: testRecipe.portions,
            timeMinutes: testRecipe.timeMinutes,
            rating: testRecipe.rating,
            personalTagIds: testRecipe.personalTagIds,
            sourceUrl: testRecipe.sourceUrl,
          ),
        ).called(1);
      });

      test('should update legacy recipe', () async {
        when(
          () => mockDelegate.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        final result = await operations.updateLegacyRecipe(testRecipe);

        expect(result.isSuccess, isTrue);
        verify(() => mockDelegate.updateRecipe(testRecipe)).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle empty batch import', () async {
        final result = await operations.addMultipleUnifiedRecipes([]);

        // Production: all success path with 0 recipes -> '0 recipes imported'
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('0 recipes imported'));
      });

      test('should handle recipe with minimal data', () async {
        final minimalRecipe = RecipeBuilder()
            .withTitle('Simple Recipe')
            .withDescription('')
            .withIngredients([])
            .withInstructions([])
            .build();

        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => 'recipe-id');

        final result = await operations.addUnifiedRecipe(minimalRecipe);

        expect(result.isSuccess, isTrue);
      });

      test('should handle special characters in recipe content', () async {
        final specialRecipe = RecipeBuilder()
            .withTitle('Räksmörgås & lax')
            .withDescription('En "klassisk" rätt med <special> tecken')
            .withIngredients(['100g räkor & lax', '1 msk "majonnäs"'])
            .build();

        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenAnswer((_) async => 'recipe-id');

        final result = await operations.addUnifiedRecipe(specialRecipe);

        expect(result.isSuccess, isTrue);
      });

      test('should handle add recipe exception', () async {
        when(
          () => mockDelegate.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ),
        ).thenThrow(Exception('Database error'));

        final result = await operations.addUnifiedRecipe(testRecipe);

        // BUT-968 contract: raw exception text MUST NOT leak to the user.
        // Previously this test asserted `contains('Database error')` —
        // the new mapFirebaseErrorMessage helper returns the localized
        // fallback ("Could not add the recipe.") for non-FirebaseException
        // throwables. The negated assertion locks the contract: if anyone
        // bypasses the mapper and surfaces raw `e.toString()` again, this
        // test breaks.
        expect(result.isSuccess, isFalse);
        expect(result.message, isNotNull);
        expect(result.message, isNotEmpty);
        expect(result.message, isNot(contains('Database error')));
        expect(result.message, isNot(contains('Exception')));
      });
    });
  });
}
