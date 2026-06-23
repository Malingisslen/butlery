// test/unit/viewmodels/personal_recipe_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mock — centralized MockPersonalRecipeOperations has concrete @overrides
// that break mocktail when() stubs
class _MockPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PersonalRecipeViewModel viewModel;
  late MockUnifiedRecipeService mockService;
  late _MockPersonalOps mockPersonalOps;

  const testUserId = 'user-123';
  const testRecipeId = 'recipe-1';

  final testRecipe = RecipeFactory.build(
    id: testRecipeId,
    title: 'Kottbullar',
    description: 'Svenska kottbullar',
    createdBy: testUserId,
    type: RecipeType.personal,
    ingredients: ['500g kottfars', '1 dl strobrod', '1 agg'],
    instructions: ['Blanda', 'Forma', 'Stek'],
    personalTagIds: ['svensk', 'middag'],
    mealType: 'Middag',
    portions: 4,
    timeMinutes: 30,
  );

  final sharedRecipe = RecipeFactory.build(
    id: 'shared-1',
    title: 'Shared Recipe',
    createdBy: 'other-user',
    type: RecipeType.shared,
  );

  setUpAll(() {
    final container = DIContainer();
    ServiceLocator.initialize(container);
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(RecipeOperationResult.success());
  });

  setUp(() {
    final getIt = GetIt.instance;

    mockService = MockUnifiedRecipeService();
    mockPersonalOps = _MockPersonalOps();

    mockService.setRecipeState(
      recipes: [testRecipe, sharedRecipe],
      currentUserId: testUserId,
      currentUserDisplayName: 'Test User',
      isInitialized: true,
      personalOperations: mockPersonalOps,
    );

    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }
    getIt.registerSingleton<UnifiedRecipeService>(mockService);

    // Default stubs for personal operations
    when(
      () => mockPersonalOps.createRecipe(
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

    when(
      () => mockPersonalOps.updateRecipe(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.deleteRecipe(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.updateRecipeContent(
        recipeId: any(named: 'recipeId'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        mealType: any(named: 'mealType'),
        portions: any(named: 'portions'),
        timeMinutes: any(named: 'timeMinutes'),
        rating: any(named: 'rating'),
        personalTagIds: any(named: 'personalTagIds'),
        sourceUrl: any(named: 'sourceUrl'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.addIngredient(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.updateIngredient(any(), any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.removeIngredient(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.addInstruction(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.updateInstruction(any(), any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.removeInstruction(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.markAsCooked(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPersonalOps.addLegacyRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('ok'));
    when(
      () => mockPersonalOps.updateLegacyRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('ok'));

    viewModel = PersonalRecipeViewModel();
  });

  tearDown(() {
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UnifiedRecipeService>()) {
      getIt.unregister<UnifiedRecipeService>();
    }
  });

  group('Read Operations', () {
    test('personalRecipes returns only personal type', () {
      expect(viewModel.personalRecipes, hasLength(1));
      expect(viewModel.personalRecipes.first.id, testRecipeId);
    });

    test('hasPersonalRecipes reflects list state', () {
      expect(viewModel.hasPersonalRecipes, isTrue);
    });

    test('personalRecipeCount matches list length', () {
      expect(viewModel.personalRecipeCount, 1);
    });

    test('getPersonalRecipeById finds existing recipe', () {
      final recipe = viewModel.getPersonalRecipeById(testRecipeId);
      expect(recipe, isNotNull);
      expect(recipe!.title, 'Kottbullar');
    });

    test('getPersonalRecipeById returns null for missing id', () {
      expect(viewModel.getPersonalRecipeById('nonexistent'), isNull);
    });

    test('getPersonalRecipesByMealType filters correctly', () {
      final recipes = viewModel.getPersonalRecipesByMealType('Middag');
      expect(recipes, hasLength(1));
    });

    test('getPersonalRecipesByTag filters by tag', () {
      final recipes = viewModel.getPersonalRecipesByTag('svensk');
      expect(recipes, hasLength(1));
    });

    test('currentUserId comes from service', () {
      expect(viewModel.currentUserId, testUserId);
    });

    test('currentUserDisplayName comes from service', () {
      expect(viewModel.currentUserDisplayName, 'Test User');
    });
  });

  group('Search', () {
    test('searchPersonalRecipes matches title', () {
      final results = viewModel.searchPersonalRecipes('Kott');
      expect(results, hasLength(1));
    });

    test('searchPersonalRecipes matches ingredient', () {
      final results = viewModel.searchPersonalRecipes('kottfars');
      expect(results, hasLength(1));
    });

    test('searchPersonalRecipes matches instruction', () {
      final results = viewModel.searchPersonalRecipes('Forma');
      expect(results, hasLength(1));
    });

    test('searchPersonalRecipes matches tag', () {
      final results = viewModel.searchPersonalRecipes('middag');
      expect(results, hasLength(1));
    });

    test('searchPersonalRecipes returns all for empty query', () {
      final results = viewModel.searchPersonalRecipes('');
      expect(results, hasLength(1));
    });

    test('searchPersonalRecipes returns empty for no match', () {
      final results = viewModel.searchPersonalRecipes('pizza');
      expect(results, isEmpty);
    });
  });

  group('Statistics', () {
    test('getPersonalMealTypeCounts groups correctly', () {
      final counts = viewModel.getPersonalMealTypeCounts();
      expect(counts['Middag'], 1);
    });

    test('getPersonalTagCounts groups correctly', () {
      final counts = viewModel.getPersonalTagCounts();
      expect(counts['svensk'], 1);
      expect(counts['middag'], 1);
    });
  });

  group('Create Operations', () {
    test('createPersonalRecipe calls service and returns true', () async {
      final result = await viewModel.createPersonalRecipe(name: 'Pannkakor');
      expect(result, isTrue);
      verify(
        () => mockPersonalOps.createRecipe(
          title: 'Pannkakor',
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
      ).called(1);
    });

    test('createPersonalRecipe rejects empty name', () async {
      final result = await viewModel.createPersonalRecipe(name: '');
      expect(result, isFalse);
      verifyNever(
        () => mockPersonalOps.createRecipe(
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
      );
    });

    test(
      'createPersonalRecipe returns false when service returns null',
      () async {
        when(
          () => mockPersonalOps.createRecipe(
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

        final result = await viewModel.createPersonalRecipe(name: 'Test');
        expect(result, isFalse);
      },
    );
  });

  group('Update Operations', () {
    test('updatePersonalRecipe delegates to service', () async {
      final result = await viewModel.updatePersonalRecipe(testRecipe);
      expect(result, isTrue);
      verify(() => mockPersonalOps.updateRecipe(testRecipe)).called(1);
    });

    test('updatePersonalRecipe rejects non-personal recipe', () async {
      final result = await viewModel.updatePersonalRecipe(sharedRecipe);
      expect(result, isFalse);
    });

    test('updateRecipeContent delegates to service', () async {
      final result = await viewModel.updateRecipeContent(
        recipeId: testRecipeId,
        name: 'New Title',
      );
      expect(result, isTrue);
    });

    test('updateRecipeContent rejects empty recipeId', () async {
      final result = await viewModel.updateRecipeContent(recipeId: '');
      expect(result, isFalse);
    });

    test('updateRecipeContent rejects non-personal recipe', () async {
      final result = await viewModel.updateRecipeContent(recipeId: 'shared-1');
      // shared-1 is not in personalRecipes, so getPersonalRecipeById returns null
      expect(result, isFalse);
    });
  });

  group('Delete Operations', () {
    test('deletePersonalRecipe delegates to service', () async {
      final result = await viewModel.deletePersonalRecipe(testRecipeId);
      expect(result, isTrue);
      verify(() => mockPersonalOps.deleteRecipe(testRecipeId)).called(1);
    });

    test('deletePersonalRecipe rejects empty id', () async {
      final result = await viewModel.deletePersonalRecipe('');
      expect(result, isFalse);
    });

    test('deletePersonalRecipe rejects non-personal recipe', () async {
      // shared-1 is not in personalRecipes
      final result = await viewModel.deletePersonalRecipe('shared-1');
      expect(result, isFalse);
    });
  });

  group('Ingredient Operations', () {
    test('addIngredient delegates to service', () async {
      final result = await viewModel.addIngredient(testRecipeId, '1 dl mjolk');
      expect(result, isTrue);
      verify(
        () => mockPersonalOps.addIngredient(testRecipeId, '1 dl mjolk'),
      ).called(1);
    });

    test('addIngredient rejects empty ingredient', () async {
      final result = await viewModel.addIngredient(testRecipeId, '');
      expect(result, isFalse);
    });

    test('updateIngredient delegates to service', () async {
      final result = await viewModel.updateIngredient(
        testRecipeId,
        0,
        '2 dl mjolk',
      );
      expect(result, isTrue);
    });

    test('removeIngredient delegates to service', () async {
      final result = await viewModel.removeIngredient(testRecipeId, 0);
      expect(result, isTrue);
    });
  });

  group('Instruction Operations', () {
    test('addInstruction delegates to service', () async {
      final result = await viewModel.addInstruction(
        testRecipeId,
        'Servera varmt',
      );
      expect(result, isTrue);
    });

    test('addInstruction rejects empty instruction', () async {
      final result = await viewModel.addInstruction(testRecipeId, '');
      expect(result, isFalse);
    });

    test('updateInstruction delegates to service', () async {
      final result = await viewModel.updateInstruction(
        testRecipeId,
        0,
        'Steg 1 ny',
      );
      expect(result, isTrue);
    });

    test('removeInstruction delegates to service', () async {
      final result = await viewModel.removeInstruction(testRecipeId, 0);
      expect(result, isTrue);
    });
  });

  group('Mark as Cooked', () {
    test('markAsCooked delegates to service', () async {
      final result = await viewModel.markAsCooked(testRecipeId);
      expect(result, isTrue);
      verify(() => mockPersonalOps.markAsCooked(testRecipeId)).called(1);
    });

    test('markAsCooked rejects empty id', () async {
      final result = await viewModel.markAsCooked('');
      expect(result, isFalse);
    });
  });

  group('Legacy Operations', () {
    test('addLegacyRecipe succeeds for personal recipe', () async {
      final result = await viewModel.addLegacyRecipe(testRecipe);
      expect(result.isSuccess, isTrue);
    });

    test('addLegacyRecipe fails for non-personal recipe', () async {
      final result = await viewModel.addLegacyRecipe(sharedRecipe);
      expect(result.isSuccess, isFalse);
    });

    test('updateLegacyRecipe succeeds for personal recipe', () async {
      final result = await viewModel.updateLegacyRecipe(testRecipe);
      expect(result.isSuccess, isTrue);
    });

    test('updateLegacyRecipe fails for non-personal recipe', () async {
      final result = await viewModel.updateLegacyRecipe(sharedRecipe);
      expect(result.isSuccess, isFalse);
    });
  });

  group('Error Handling', () {
    test('createPersonalRecipe handles service exception gracefully', () async {
      when(
        () => mockPersonalOps.createRecipe(
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
      ).thenThrow(Exception('Network error'));

      final result = await viewModel.createPersonalRecipe(name: 'Test');
      // safeExecute catches and returns defaultValue (false)
      expect(result, isFalse);
    });

    test('deletePersonalRecipe handles service returning false', () async {
      when(
        () => mockPersonalOps.deleteRecipe(any()),
      ).thenAnswer((_) async => false);
      final result = await viewModel.deletePersonalRecipe(testRecipeId);
      expect(result, isFalse);
    });
  });

  group('Empty State', () {
    test('empty recipe list reports correctly', () {
      mockService.setRecipeState(
        recipes: [],
        currentUserId: testUserId,
        isInitialized: true,
      );

      expect(viewModel.hasPersonalRecipes, isFalse);
      expect(viewModel.personalRecipeCount, 0);
      expect(viewModel.personalRecipes, isEmpty);
    });
  });
}
