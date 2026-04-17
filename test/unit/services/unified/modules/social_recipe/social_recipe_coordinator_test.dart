// Unit tests for SocialRecipeCoordinator
//
// Tests creation, membership, sharing, permissions, queries, and
// validation. Requires production ServiceLocator bridge because the
// constructor calls ServiceLocator.get() for FirebaseSharedRecipeRepository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';

class _MockSharedRecipeRepo extends Mock
    implements FirebaseSharedRecipeRepository {}

void main() {
  group('SocialRecipeCoordinator', () {
    late SocialRecipeCoordinator coordinator;
    late FakeJsonCacheHelper mockCacheHelper;
    late MockRecipeServiceAdapter mockServiceAdapter;
    late _MockSharedRecipeRepo mockSharedRecipeRepo;
    late Map<String, Recipe> testRecipesMap;
    late String currentUserId;
    late String currentUserDisplayName;
    late int notifyCount;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      notifyCount = 0;
      testRecipesMap = {};

      mockCacheHelper = FakeJsonCacheHelper();
      mockServiceAdapter = MockRecipeServiceAdapter();
      mockSharedRecipeRepo = _MockSharedRecipeRepo();

      // Register the shared recipe repo in GetIt so the coordinator finds it
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FirebaseSharedRecipeRepository>()) {
        getIt.unregister<FirebaseSharedRecipeRepository>();
      }
      getIt.registerSingleton<FirebaseSharedRecipeRepository>(
          mockSharedRecipeRepo);

      // Build test recipes
      final recipe1 = Recipe(
        core: RecipeCore(
          id: 'recipe-1',
          title: 'Collaborative Recipe',
          description: 'Test',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Lunch',
          createdBy: currentUserId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: currentUserId,
          ownerDisplayName: currentUserDisplayName,
          memberPermissions: {
            currentUserId: ResourcePermission.admin,
            'user-2': ResourcePermission.editor,
            'user-3': ResourcePermission.viewer,
          },
        ),
      );

      final recipe2 = RecipeFactory.buildPersonal(
        id: 'recipe-2',
        title: 'Personal Recipe',
        createdBy: currentUserId,
      );

      testRecipesMap['recipe-1'] = recipe1;
      testRecipesMap['recipe-2'] = recipe2;

      coordinator = SocialRecipeCoordinator(
        getCacheHelper: () => mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) {},
        notifyListeners: () => notifyCount++,
        getRecipe: (id) async => testRecipesMap[id],
        saveRecipe: (recipe) async {
          testRecipesMap[recipe.id] = recipe;
          return true;
        },
        serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
      );
    });

    tearDown(() async {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FirebaseSharedRecipeRepository>()) {
        getIt.unregister<FirebaseSharedRecipeRepository>();
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with correct service name', () {
        expect(coordinator.serviceName, equals('SocialRecipeCoordinator'));
      });
    });

    group('Validation', () {
      test('should validate valid collaborative recipe data', () {
        final valid = coordinator.validateCollaborativeRecipeData(
          title: 'Familjerätt',
          ingredients: ['potatis', 'lök'],
          instructions: ['Skala', 'Koka'],
        );
        expect(valid, isTrue);
      });

      test('should reject empty title', () {
        final valid = coordinator.validateCollaborativeRecipeData(
          title: '',
          ingredients: ['potatis'],
          instructions: ['Koka'],
        );
        expect(valid, isFalse);
      });

      test('should reject empty ingredients', () {
        final valid = coordinator.validateCollaborativeRecipeData(
          title: 'Test',
          ingredients: [],
          instructions: ['Koka'],
        );
        expect(valid, isFalse);
      });

      test('should reject empty instructions', () {
        final valid = coordinator.validateCollaborativeRecipeData(
          title: 'Test',
          ingredients: ['potatis'],
          instructions: [],
        );
        expect(valid, isFalse);
      });
    });

    group('Result Helpers', () {
      test('should create success result', () {
        final result = coordinator.createSuccessResult('OK');
        expect(result.isSuccess, isTrue);
      });

      test('should create failure result', () {
        final result = coordinator.createFailureResult('Error');
        expect(result.isSuccess, isFalse);
      });
    });

    group('Status Cache', () {
      test('should default dismissed to false', () {
        expect(coordinator.isRecipeDismissed('unknown'), isFalse);
      });

      test('should default viewed to false', () {
        expect(coordinator.isRecipeViewed('unknown'), isFalse);
      });

      test('should default imported to false', () {
        expect(coordinator.isRecipeImported('unknown'), isFalse);
      });

      test('should update viewed status cache directly', () {
        coordinator.setViewedStatus('recipe-1', true);
        expect(coordinator.isRecipeViewed('recipe-1'), isTrue);
      });
    });

    group('Dismiss Shared Recipe', () {
      test('should dismiss shared recipe', () async {
        when(() => mockSharedRecipeRepo.markAsDismissed(any(), any()))
            .thenAnswer((_) async {});

        final result = await coordinator.dismissSharedRecipe('shared-1');
        expect(result, isTrue);
        verify(() =>
                mockSharedRecipeRepo.markAsDismissed('shared-1', currentUserId))
            .called(1);
      });

      test('should fail dismiss when not authenticated', () async {
        // Replace coordinator with unauthenticated one
        final unauthCoordinator = SocialRecipeCoordinator(
          getCacheHelper: () => mockCacheHelper,
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          setError: (error) {},
          notifyListeners: () {},
          getRecipe: (id) async => null,
          saveRecipe: (recipe) async => false,
          serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
        );

        final result = await unauthCoordinator.dismissSharedRecipe('shared-1');
        expect(result, isFalse);
      });
    });

    group('Mark As Viewed', () {
      test('should mark recipe as viewed', () async {
        when(() => mockSharedRecipeRepo.markAsViewed(any(), any()))
            .thenAnswer((_) async {});

        final result = await coordinator.markRecipeAsViewed('shared-1');
        expect(result, isTrue);
      });

      test('should fail when not authenticated', () async {
        final unauthCoordinator = SocialRecipeCoordinator(
          getCacheHelper: () => mockCacheHelper,
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => null,
          setError: (error) {},
          notifyListeners: () {},
          getRecipe: (id) async => null,
          saveRecipe: (recipe) async => false,
          serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
        );

        final result = await unauthCoordinator.markRecipeAsViewed('shared-1');
        expect(result, isFalse);
      });
    });

    group('Get Shared Recipes', () {
      test('should get shared recipes for user', () async {
        when(() => mockSharedRecipeRepo.getSharedRecipesForUser(any()))
            .thenAnswer((_) async => []);

        final recipes = await coordinator.getSharedRecipesForUser('user-1');
        expect(recipes, isEmpty);
      });

      test('should handle repository error gracefully', () async {
        when(() => mockSharedRecipeRepo.getSharedRecipesForUser(any()))
            .thenThrow(Exception('Network error'));

        final recipes = await coordinator.getSharedRecipesForUser('user-1');
        expect(recipes, isEmpty);
      });
    });

    group('Get Shared Recipe By ID', () {
      test('should return null for non-existent shared recipe', () async {
        when(() => mockSharedRecipeRepo.getSharedRecipe(any()))
            .thenAnswer((_) async => null);

        final recipe = await coordinator.getSharedRecipeById('nonexistent');
        expect(recipe, isNull);
      });
    });

    group('Notification Placeholders', () {
      test('should send collaboration invitations without error', () async {
        await coordinator.sendCollaborationInvitations('recipe-1', ['user-2']);
        // Placeholder method — just logs, no error
      });

      test('should send member addition notification without error', () async {
        await coordinator.sendMemberAdditionNotification('recipe-1', 'user-2');
      });

      test('should send sharing notifications without error', () async {
        await coordinator
            .sendRecipeSharingNotifications('recipe-1', ['user-2', 'user-3']);
      });
    });
  });
}
