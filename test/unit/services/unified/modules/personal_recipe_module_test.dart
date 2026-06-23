/// Unit tests for PersonalRecipeModule
///
/// Tests validation, auth guards, cache loading, repository access,
/// and sync status. FakeJsonCacheHelper and MockRecipeServiceAdapter
/// have concrete @override methods, so we use their built-in behavior
/// instead of when() stubs. MockRecipeRepository has no concrete
/// overrides and IS stubbable with when().
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/modules/personal_recipe_module.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('PersonalRecipeModule', () {
    late PersonalRecipeModule module;
    late MockRecipeRepository mockRepository;
    late MockUserRepository mockUserRepository;
    late FakeJsonCacheHelper mockCacheHelper;
    late MockRecipeServiceAdapter mockServiceAdapter;
    late Recipe testRecipe;

    String? currentUserId;
    String? currentUserDisplayName;
    String? lastError;
    int notifyListenersCalled = 0;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockRepository = MockRecipeRepository();
      mockUserRepository = MockUserRepository();
      mockCacheHelper = FakeJsonCacheHelper();
      mockServiceAdapter = MockRecipeServiceAdapter();

      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      lastError = null;
      notifyListenersCalled = 0;

      module = PersonalRecipeModule(
        recipeRepository: mockRepository,
        userRepository: mockUserRepository,
        getCacheHelper: () => mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) => lastError = error,
        notifyListeners: () => notifyListenersCalled++,
        getServiceAdapter: () => mockServiceAdapter,
      );

      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
        createdBy: 'test-user-123',
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Validation', () {
      test('should validate valid recipe data', () {
        final isValid = module.validateRecipeData(
          title: 'Köttbullar',
          ingredients: ['500g köttfärs'],
          instructions: ['Blanda allt'],
        );
        expect(isValid, isTrue);
        expect(lastError, isNull);
      });

      test('should reject empty title', () {
        final isValid = module.validateRecipeData(
          title: '  ',
          ingredients: ['ingredient'],
          instructions: ['step'],
        );
        expect(isValid, isFalse);
        expect(lastError, isNotNull);
      });

      test('should reject empty ingredients', () {
        final isValid = module.validateRecipeData(
          title: 'Test',
          ingredients: [],
          instructions: ['step'],
        );
        expect(isValid, isFalse);
        expect(lastError, isNotNull);
      });

      test('should reject empty instructions', () {
        final isValid = module.validateRecipeData(
          title: 'Test',
          ingredients: ['ingredient'],
          instructions: [],
        );
        expect(isValid, isFalse);
        expect(lastError, isNotNull);
      });
    });

    group('Ownership', () {
      test('should detect own recipe', () {
        expect(module.isOwnRecipe(testRecipe), isTrue);
      });

      test('should detect other users recipe', () {
        final otherRecipe = RecipeFactory.build(createdBy: 'other-user');
        expect(module.isOwnRecipe(otherRecipe), isFalse);
      });

      test('should return false when not authenticated', () {
        currentUserId = null;
        expect(module.isOwnRecipe(testRecipe), isFalse);
      });
    });

    group('Auth Guards', () {
      test('should fail creation when not authenticated', () async {
        currentUserId = null;
        final result = await module.createPersonalRecipe(
          title: 'Test',
          ingredients: ['test'],
          instructions: ['test'],
        );
        expect(result, isNull);
        expect(lastError, isNotNull);
      });

      test('should fail creation with empty title', () async {
        final result = await module.createPersonalRecipe(
          title: '',
          ingredients: ['test'],
          instructions: ['test'],
        );
        expect(result, isNull);
        expect(lastError, isNotNull);
      });

      test('should fail update when not authenticated', () async {
        currentUserId = null;
        final result = await module.updatePersonalRecipe(testRecipe);
        expect(result, isFalse);
        expect(lastError, isNotNull);
      });

      test('should fail update for non-personal recipe', () async {
        final collaborative = Recipe.collaborative(
          title: 'Shared',
          description: 'desc',
          ingredients: ['a'],
          instructions: ['b'],
          mealType: 'Lunch',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        );
        final result = await module.updatePersonalRecipe(collaborative);
        expect(result, isFalse);
        expect(lastError, isNotNull);
      });

      test('should fail delete when not authenticated', () async {
        currentUserId = null;
        final result = await module.deletePersonalRecipe('recipe-1');
        expect(result, isFalse);
        expect(lastError, isNotNull);
      });

      test('should fail content ops when not authenticated', () async {
        currentUserId = null;
        expect(await module.addIngredient('r1', 'test'), isFalse);
        expect(await module.updateIngredient('r1', 0, 'test'), isFalse);
        expect(await module.removeIngredient('r1', 0), isFalse);
        expect(await module.addInstruction('r1', 'test'), isFalse);
        expect(await module.updateInstruction('r1', 0, 'test'), isFalse);
        expect(await module.removeInstruction('r1', 0), isFalse);
        expect(await module.markRecipeAsCooked('r1'), isFalse);
      });
    });

    group('Content Operations (authenticated)', () {
      test('should add ingredient', () async {
        final result = await module.addIngredient('r1', '2 dl mjölk');
        expect(result, isTrue);
      });

      test('should update ingredient', () async {
        final result = await module.updateIngredient('r1', 0, '600g köttfärs');
        expect(result, isTrue);
      });

      test('should remove ingredient', () async {
        final result = await module.removeIngredient('r1', 1);
        expect(result, isTrue);
      });

      test('should add instruction', () async {
        final result = await module.addInstruction('r1', 'Servera');
        expect(result, isTrue);
      });

      test('should mark recipe as cooked', () async {
        final result = await module.markRecipeAsCooked('r1');
        expect(result, isTrue);
      });
    });

    group('Cache Loading', () {
      test('should load cached personal recipes owned by user', () async {
        // Pre-populate cache with the mock's concrete behavior
        mockCacheHelper.setCacheState(
          cache: {'test-recipe-1': testRecipe.toJson()},
        );

        final recipes = await module.loadCachedPersonalRecipes();
        expect(recipes, hasLength(1));
        expect(recipes.first.id, equals('test-recipe-1'));
      });

      test('should skip recipes not owned by current user', () async {
        final otherRecipe = RecipeFactory.build(
          id: 'other-recipe',
          createdBy: 'other-user-456',
        );
        mockCacheHelper.setCacheState(
          cache: {'other-recipe': otherRecipe.toJson()},
        );

        final recipes = await module.loadCachedPersonalRecipes();
        expect(recipes, isEmpty);
      });

      test('should return empty list when cache is empty', () async {
        final recipes = await module.loadCachedPersonalRecipes();
        expect(recipes, isEmpty);
      });
    });

    group('Repository Operations', () {
      test('should get personal recipes stream', () {
        when(
          () => mockRepository.watchRecipes(any()),
        ).thenAnswer((_) => Stream.value([]));

        final stream = module.getPersonalRecipesStream();
        expect(stream, isNotNull);
        verify(() => mockRepository.watchRecipes('test-user-123')).called(1);
      });

      test('should return null stream when not authenticated', () {
        currentUserId = null;
        final stream = module.getPersonalRecipesStream();
        expect(stream, isNull);
      });

      test('should get personal recipes list', () async {
        when(
          () => mockRepository.fetchUserRecipes(any()),
        ).thenAnswer((_) async => [testRecipe]);

        final recipes = await module.getPersonalRecipesList();
        expect(recipes, isNotNull);
        expect(recipes!.length, equals(1));
      });

      test('should return null list when not authenticated', () async {
        currentUserId = null;
        final recipes = await module.getPersonalRecipesList();
        expect(recipes, isNull);
      });

      test('should handle repository fetch errors', () async {
        when(
          () => mockRepository.fetchUserRecipes(any()),
        ).thenThrow(Exception('Fetch error'));

        final recipes = await module.getPersonalRecipesList();
        expect(recipes, isNull);
      });
    });

    group('Sync Status', () {
      test('should default to synced for unknown recipe', () {
        expect(
          module.getSyncStatus('unknown'),
          equals(RecipeSyncStatus.synced),
        );
      });

      test('should return null lastSyncedAt for never-synced recipe', () {
        expect(module.getLastSyncedAt('unknown'), isNull);
      });

      test('should report not fresh for never-synced recipe', () {
        expect(module.isSyncFresh('unknown'), isFalse);
      });
    });

    group('Import', () {
      test('should fail import when not authenticated', () async {
        currentUserId = null;
        final ids = await module.importRecipesFromData([testRecipe.toJson()]);
        expect(ids, isEmpty);
        expect(lastError, isNotNull);
      });

      test('should return empty list for empty input', () async {
        final ids = await module.importRecipesFromData([]);
        expect(ids, isEmpty);
      });

      test('should import valid recipe data', () async {
        // MockRecipeServiceAdapter.createRecipe returns 'mock-recipe-<id>'
        final ids = await module.importRecipesFromData([testRecipe.toJson()]);
        expect(ids, hasLength(1));
        expect(notifyListenersCalled, equals(1));
      });
    });

    group('Export', () {
      test('should export cached personal recipes', () async {
        mockCacheHelper.setCacheState(
          cache: {'test-recipe-1': testRecipe.toJson()},
        );

        final exportData = await module.exportPersonalRecipes();
        expect(exportData, hasLength(1));
      });

      test('should return empty list when no recipes cached', () async {
        final exportData = await module.exportPersonalRecipes();
        expect(exportData, isEmpty);
      });
    });

    group('Result Helpers', () {
      test('should create success result', () {
        final result = module.createSuccessResult('OK');
        expect(result.isSuccess, isTrue);
      });

      test('should create failure result', () {
        final result = module.createFailureResult('Error');
        expect(result.isSuccess, isFalse);
      });
    });
  });
}
