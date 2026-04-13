// Unit tests for SocialRecipeModule
//
// Tests the facade that delegates to SocialRecipeCoordinator.
// Requires production ServiceLocator bridge because the coordinator
// constructor calls ServiceLocator.get() for FirebaseSharedRecipeRepository
// and _createDefaultServiceAdapter() calls ServiceLocator.get() for
// repository types.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/services/unified/modules/social_recipe_module.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';

class _MockSharedRecipeRepo extends Mock
    implements FirebaseSharedRecipeRepository {}

void main() {
  group('SocialRecipeModule', () {
    late SocialRecipeModule module;
    late MockJsonCacheHelper mockCacheHelper;
    late MockRecipeServiceAdapter mockServiceAdapter;
    late _MockSharedRecipeRepo mockSharedRecipeRepo;
    late Map<String, Recipe> recipeDatabase;

    String? currentUserId;
    String? currentUserDisplayName;
    int notifyListenersCalled = 0;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(ResourcePermission.viewer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockCacheHelper = MockJsonCacheHelper();
      mockServiceAdapter = MockRecipeServiceAdapter();
      mockSharedRecipeRepo = _MockSharedRecipeRepo();

      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      notifyListenersCalled = 0;
      recipeDatabase = {};

      // Register shared recipe repo in GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FirebaseSharedRecipeRepository>()) {
        getIt.unregister<FirebaseSharedRecipeRepository>();
      }
      getIt.registerSingleton<FirebaseSharedRecipeRepository>(
          mockSharedRecipeRepo);

      // Build test recipes
      final testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        createdBy: 'test-user-123',
      );

      final collaborativeRecipe = Recipe.collaborative(
        title: 'Familjerecept',
        description: 'Shared family recipe',
        ingredients: ['ingredient 1'],
        instructions: ['step 1'],
        mealType: 'Dinner',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'friend-1': ResourcePermission.editor,
          'friend-2': ResourcePermission.viewer,
        },
      );

      recipeDatabase['test-recipe-1'] = testRecipe;
      recipeDatabase[collaborativeRecipe.id] = collaborativeRecipe;

      module = SocialRecipeModule(
        getCacheHelper: () => mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) {},
        notifyListeners: () => notifyListenersCalled++,
        getRecipe: (id) async => recipeDatabase[id],
        saveRecipe: (recipe) async {
          recipeDatabase[recipe.id] = recipe;
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
        expect(module.serviceName, equals('SocialRecipeModule'));
      });
    });

    group('Validation', () {
      test('should validate valid collaborative recipe data', () {
        final valid = module.validateCollaborativeRecipeData(
          title: 'Familjerätt',
          ingredients: ['potatis', 'lök'],
          instructions: ['Skala', 'Koka'],
        );
        expect(valid, isTrue);
      });

      test('should reject empty title', () {
        final valid = module.validateCollaborativeRecipeData(
          title: '',
          ingredients: ['potatis'],
          instructions: ['Koka'],
        );
        expect(valid, isFalse);
      });

      test('should reject empty ingredients', () {
        final valid = module.validateCollaborativeRecipeData(
          title: 'Test',
          ingredients: [],
          instructions: ['Koka'],
        );
        expect(valid, isFalse);
      });

      test('should reject empty instructions', () {
        final valid = module.validateCollaborativeRecipeData(
          title: 'Test',
          ingredients: ['potatis'],
          instructions: [],
        );
        expect(valid, isFalse);
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

    group('Permission Checks', () {
      test('should check canViewRecipe without error', () async {
        // Permission service delegates to getRecipe which we control
        final result =
            await module.canViewRecipe('test-recipe-1', 'test-user-123');
        expect(result, isA<bool>());
      });

      test('should check canEditRecipe without error', () async {
        final result =
            await module.canEditRecipe('test-recipe-1', 'test-user-123');
        expect(result, isA<bool>());
      });

      test('should check canManageRecipeMembers without error', () async {
        final result = await module.canManageRecipeMembers(
            'test-recipe-1', 'test-user-123');
        expect(result, isA<bool>());
      });

      test('should get user permission for recipe', () async {
        final permission = await module.getUserPermissionForRecipe(
            'test-recipe-1', 'test-user-123');
        // May be null for personal recipes that don't have member permissions
        expect(permission, isA<ResourcePermission?>());
      });
    });

    group('Sharing', () {
      test('should unshare recipe', () async {
        final result = await module.unshareRecipe('test-recipe-1');
        expect(result, isA<bool>());
      });
    });

    group('Notification Helpers', () {
      test('should send collaboration invitations without error', () async {
        await module.sendCollaborationInvitations('test-recipe-1', ['user-2']);
      });

      test('should send member addition notification without error', () async {
        await module.sendMemberAdditionNotification('test-recipe-1', 'user-2');
      });

      test('should send sharing notifications without error', () async {
        await module.sendRecipeSharingNotifications(
            'test-recipe-1', ['user-2', 'user-3']);
      });
    });
  });
}
