// test/unit/viewmodels/collaborative_status_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSocialRecipeService mockSocialRecipeService;
  late MockPermissionService mockPermissionService;
  late CollaborativeStatusViewModel viewModel;

  setUp(() async {
    await TestServiceLocator.initialize();

    mockSocialRecipeService = MockSocialRecipeService();
    mockPermissionService = MockPermissionService();

    // Setup default permission service behavior using state configuration
    mockPermissionService.setPermissionState(
      currentUserId: 'test_user_id',
      isAuthenticated: true,
    );

    // Register mocks
    TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

    viewModel = CollaborativeStatusViewModel(
      socialRecipeService: mockSocialRecipeService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  group('CollaborativeStatusViewModel - Initialization', () {
    test('should initialize with empty cache', () {
      expect(viewModel.currentUserId, equals('test_user_id'));
      expect(viewModel.debugInfo['totalCacheSize'], equals(0));
      expect(viewModel.debugInfo['activeChecks'], equals(0));
    });

    test('should handle null current user ID', () {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );

      final viewModelWithoutUser = CollaborativeStatusViewModel(
        socialRecipeService: mockSocialRecipeService,
      );

      expect(viewModelWithoutUser.currentUserId, isNull);

      viewModelWithoutUser.dispose();
    });
  });

  group('CollaborativeStatusViewModel - Recipe Status', () {
    test('should return loading status for uncached recipe', () {
      final status = viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      expect(status.isLoading, isTrue);
      expect(status.isCollaborative, isFalse);
      expect(status.hasError, isFalse);
    });

    test('should return cached status if available', () async {
      // First call triggers async check
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => [
                UserProfile(
                  uid: 'user_1',
                  displayName: 'Test User',
                  email: 'test@example.com',
                  joinedAt: DateTime.now(),
                  lastActiveAt: DateTime.now(),
                ),
              ]);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      // Wait for async operation
      await Future.delayed(Duration(milliseconds: 100));

      // Second call should return cached
      final cachedStatus =
          viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      expect(cachedStatus.isCollaborative, isTrue);
      expect(cachedStatus.participants.length, equals(1));
      expect(cachedStatus.isValid, isTrue);
    });

    test('should analyze recipe metadata for collaborative indicators', () {
      final collaborativeRecipe = RecipeFactory.build(
        title: '(Delad) Pasta Carbonara',
        description: 'Delat med familjen',
        sourceUrl: 'https://example.com?shared_recipe_id=123',
      );

      final status = viewModel.getRecipeCollaborativeStatus(
        'recipe_1',
        collaborativeRecipe,
      );

      // Should return true based on metadata analysis
      expect(status.isCollaborative, isTrue);
    });

    test('should detect collaborative patterns in title', () {
      final recipe1 = RecipeFactory.build(title: '(Delad) Recipe');
      final recipe2 = RecipeFactory.build(title: '(Shared) Recipe');
      final recipe3 = RecipeFactory.build(title: 'Normal Recipe');

      expect(
        viewModel.getRecipeCollaborativeStatus('r1', recipe1).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r2', recipe2).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r3', recipe3).isCollaborative,
        isFalse,
      );
    });

    test('should detect collaborative patterns in description', () {
      final recipe1 = RecipeFactory.build(
        description: 'Delat med vänner',
      );
      final recipe2 = RecipeFactory.build(
        description: 'Shared with family',
      );
      final recipe3 = RecipeFactory.build(
        description: 'Från "Annas kokbok"',
      );

      expect(
        viewModel.getRecipeCollaborativeStatus('r1', recipe1).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r2', recipe2).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r3', recipe3).isCollaborative,
        isTrue,
      );
    });

    test('should detect collaborative patterns in tags', () {
      final recipe = RecipeFactory.build(
        tags: ['vegetarisk', 'delad', 'middag'],
      );

      expect(
        viewModel.getRecipeCollaborativeStatus('r1', recipe).isCollaborative,
        isTrue,
      );
    });

    test('should detect collaborative patterns in source URL', () {
      final recipe1 = RecipeFactory.build(
        sourceUrl: 'https://example.com?shared_recipe_id=123',
      );
      final recipe2 = RecipeFactory.build(
        sourceUrl: 'https://example.com?collaborative=true',
      );
      final recipe3 = RecipeFactory.build(
        sourceUrl: 'https://example.com/normal-recipe',
      );

      expect(
        viewModel.getRecipeCollaborativeStatus('r1', recipe1).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r2', recipe2).isCollaborative,
        isTrue,
      );
      expect(
        viewModel.getRecipeCollaborativeStatus('r3', recipe3).isCollaborative,
        isFalse,
      );
    });

    test('should handle async check error', () async {
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenThrow(Exception('Network error'));

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      // Wait for async operation
      await Future.delayed(Duration(milliseconds: 100));

      final status = viewModel.getCachedStatus(
        'recipe_1',
        CollaborativeContentType.recipe,
      );

      expect(status?.hasError, isTrue);
      expect(status?.error, contains('Network error'));
    });

    test('should support legacy boolean API', () {
      final recipe = RecipeFactory.build(
        title: '(Delad) Recipe',
      );

      final isCollaborative = viewModel.getRecipeCollaborativeStatusLegacy(
        'recipe_1',
        recipe,
      );

      expect(isCollaborative, isTrue);
    });
  });

  group('CollaborativeStatusViewModel - Menu Status', () {
    test('should check menu collaborative status', () {
      final menuData = {
        'Monday': [
          RecipeFactory.build(title: '(Delad) Pasta'),
        ],
        'Tuesday': [
          RecipeFactory.build(title: 'Normal Recipe'),
        ],
      };

      final status = viewModel.getMenuCollaborativeStatus('menu_1', menuData);

      expect(status.isCollaborative, isTrue);
    });

    test('should detect collaborative menu from recipe metadata', () {
      final menuData = {
        'Monday': [
          RecipeFactory.build(
            tags: ['importerat', 'lunch'],
          ),
        ],
      };

      final status = viewModel.getMenuCollaborativeStatus('menu_1', menuData);

      expect(status.isCollaborative, isTrue);
    });

    test('should handle empty menu', () {
      final menuData = <String, List<Recipe>>{};

      final status = viewModel.getMenuCollaborativeStatus('menu_1', menuData);

      expect(status.isCollaborative, isFalse);
    });

    test('should handle null menu', () {
      final status = viewModel.getMenuCollaborativeStatus('menu_1', null);

      expect(status.isCollaborative, isFalse);
    });

    test('should perform async menu check', () async {
      when(() => mockSocialRecipeService.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getMenuCollaborativeStatus('menu_1', null);

      // Wait for async operation
      await Future.delayed(Duration(milliseconds: 100));

      verify(() => mockSocialRecipeService.isMenuSharedByUser(
          'menu_1', 'test_user_id')).called(1);
    });

    test('should support legacy menu boolean API', () {
      final menuData = {
        'Monday': [
          RecipeFactory.build(title: '(Shared) Recipe'),
        ],
      };

      final isCollaborative = viewModel.getMenuCollaborativeStatusLegacy(
        'menu_1',
        menuData,
      );

      expect(isCollaborative, isTrue);
    });
  });

  group('CollaborativeStatusViewModel - Shopping List Status', () {
    test('should check shopping list collaborative status', () {
      final status = viewModel.getShoppingListCollaborativeStatus('list_1');

      expect(status.isLoading, isTrue);
      expect(status.isCollaborative, isFalse);
    });

    test('should perform async shopping list check', () async {
      when(() =>
              mockSocialRecipeService.isShoppingListSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getShoppingListParticipants(any()))
          .thenAnswer((_) async => [
                UserProfile(
                  uid: 'user_1',
                  displayName: 'Friend 1',
                  email: 'friend@example.com',
                  joinedAt: DateTime.now(),
                  lastActiveAt: DateTime.now(),
                ),
              ]);

      viewModel.getShoppingListCollaborativeStatus('list_1');

      // Wait for async operation
      await Future.delayed(Duration(milliseconds: 100));

      verify(() => mockSocialRecipeService.isShoppingListSharedByUser(
            'list_1',
            'test_user_id',
          )).called(1);

      final cachedStatus = viewModel.getCachedStatus(
        'list_1',
        CollaborativeContentType.shoppingList,
      );

      expect(cachedStatus?.isCollaborative, isTrue);
      expect(cachedStatus?.participants.length, equals(1));
    });
  });

  group('CollaborativeStatusViewModel - Cache Management', () {
    test('should cache status with TTL', () async {
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      await Future.delayed(Duration(milliseconds: 100));

      final cached = viewModel.getCachedStatus(
        'recipe_1',
        CollaborativeContentType.recipe,
      );

      expect(cached, isNotNull);
      expect(cached?.isValid, isTrue);
      expect(cached?.lastChecked, isNotNull);
    });

    test('should invalidate specific content', () async {
      // Add to cache
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      await Future.delayed(Duration(milliseconds: 100));

      // Verify cached
      expect(
        viewModel.getCachedStatus('recipe_1', CollaborativeContentType.recipe),
        isNotNull,
      );

      // Invalidate
      viewModel.invalidateContent('recipe_1', CollaborativeContentType.recipe);

      // Verify removed
      expect(
        viewModel.getCachedStatus('recipe_1', CollaborativeContentType.recipe),
        isNull,
      );
    });

    test('should support legacy invalidate methods', () async {
      // Add to cache
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);
      when(() => mockSocialRecipeService.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getMenuCollaborativeStatus('menu_1', null);

      await Future.delayed(Duration(milliseconds: 200));

      // Invalidate using legacy methods
      viewModel.invalidateRecipeStatus('recipe_1');
      viewModel.invalidateMenuStatus('menu_1');

      // Verify removed
      expect(
        viewModel.getCachedStatus('recipe_1', CollaborativeContentType.recipe),
        isNull,
      );
      expect(
        viewModel.getCachedStatus('menu_1', CollaborativeContentType.menu),
        isNull,
      );
    });

    test('should clear all cache', () async {
      // Add multiple items to cache
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_2', null);

      await Future.delayed(Duration(milliseconds: 100));

      expect(viewModel.debugInfo['totalCacheSize'], greaterThan(0));

      viewModel.clearAllCache();

      expect(viewModel.debugInfo['totalCacheSize'], equals(0));
    });

    test('should not check same content multiple times concurrently', () async {
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 50));
        return true;
      });
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      // Trigger multiple checks for same recipe
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      await Future.delayed(Duration(milliseconds: 100));

      // Should only call service once
      verify(() =>
              mockSocialRecipeService.isRecipeSharedByUser('recipe_1', any()))
          .called(1);
    });
  });

  group('CollaborativeStatusViewModel - Batch Operations', () {
    test('should batch check multiple content types', () async {
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);
      when(() => mockSocialRecipeService.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockSocialRecipeService.getMenuParticipants(any()))
          .thenAnswer((_) async => []);
      when(() =>
              mockSocialRecipeService.isShoppingListSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getShoppingListParticipants(any()))
          .thenAnswer((_) async => []);

      await viewModel.batchCheckContent(
        recipeIds: ['recipe_1', 'recipe_2'],
        menuIds: ['menu_1'],
        shoppingListIds: ['list_1', 'list_2'],
      );

      // Verify all checks were made
      verify(() =>
              mockSocialRecipeService.isRecipeSharedByUser('recipe_1', any()))
          .called(1);
      verify(() =>
              mockSocialRecipeService.isRecipeSharedByUser('recipe_2', any()))
          .called(1);
      verify(() => mockSocialRecipeService.isMenuSharedByUser('menu_1', any()))
          .called(1);
      verify(() => mockSocialRecipeService.isShoppingListSharedByUser(
          'list_1', any())).called(1);
      verify(() => mockSocialRecipeService.isShoppingListSharedByUser(
          'list_2', any())).called(1);
    });

    test('should skip already cached items in batch check', () async {
      // Pre-cache some items
      when(() =>
              mockSocialRecipeService.isRecipeSharedByUser('recipe_1', any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants('recipe_1'))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(Duration(milliseconds: 100));

      // Reset mock to track new calls
      reset(mockSocialRecipeService);
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      // Batch check including cached item
      await viewModel.batchCheckContent(
        recipeIds: ['recipe_1', 'recipe_2'], // recipe_1 is cached
      );

      // Should only check uncached item
      verifyNever(() =>
          mockSocialRecipeService.isRecipeSharedByUser('recipe_1', any()));
      verify(() =>
              mockSocialRecipeService.isRecipeSharedByUser('recipe_2', any()))
          .called(1);
    });

    test('should handle null user ID in batch check', () async {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );

      final viewModelNoUser = CollaborativeStatusViewModel(
        socialRecipeService: mockSocialRecipeService,
      );

      await viewModelNoUser.batchCheckContent(
        recipeIds: ['recipe_1'],
      );

      // Should not make any service calls
      verifyNever(
          () => mockSocialRecipeService.isRecipeSharedByUser(any(), any()));

      viewModelNoUser.dispose();
    });
  });

  group('CollaborativeStatusViewModel - Debug Info', () {
    test('should provide comprehensive debug info', () async {
      // Add items to cache
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);
      when(() => mockSocialRecipeService.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocialRecipeService.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_2', null);
      viewModel.getMenuCollaborativeStatus('menu_1', null);

      await Future.delayed(Duration(milliseconds: 100));

      final debugInfo = viewModel.debugInfo;

      expect(debugInfo['totalCacheSize'], equals(3));
      expect(debugInfo['activeChecks'], equals(0));
      expect(debugInfo['currentUserId'], equals('test_user_id'));
      expect(debugInfo['cacheByType'], isA<Map<String, dynamic>>());
      expect(debugInfo['cacheByType']['recipe'], equals(2));
      expect(debugInfo['cacheByType']['menu'], equals(1));
      expect(debugInfo['cacheByType']['shoppingList'], equals(0));
      expect(debugInfo['cacheTtlMinutes'], equals(5));
    });
  });

  group('CollaborativeStatusViewModel - Error Handling', () {
    test('should handle null user ID gracefully', () {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );

      final viewModelNoUser = CollaborativeStatusViewModel(
        socialRecipeService: mockSocialRecipeService,
      );

      // Should not crash and return fallback status
      final status = viewModelNoUser.getRecipeCollaborativeStatus(
        'recipe_1',
        null,
      );

      expect(status.isCollaborative, isFalse);

      viewModelNoUser.dispose();
    });

    test('should store error in status on async failure', () async {
      when(() => mockSocialRecipeService.isRecipeSharedByUser(any(), any()))
          .thenThrow(Exception('Service error'));

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);

      await Future.delayed(Duration(milliseconds: 100));

      final status = viewModel.getCachedStatus(
        'recipe_1',
        CollaborativeContentType.recipe,
      );

      expect(status?.hasError, isTrue);
      expect(status?.error, contains('Service error'));
      expect(status?.isCollaborative, isFalse);
    });
  });

  group('CollaborativeStatusViewModel - Disposal', () {
    test('should clear cache on dispose', () {
      final disposableViewModel = CollaborativeStatusViewModel(
        socialRecipeService: mockSocialRecipeService,
      );

      // Add to cache
      disposableViewModel.getRecipeCollaborativeStatus('recipe_1', null);

      disposableViewModel.dispose();

      // Cache should be cleared
      expect(disposableViewModel.debugInfo['totalCacheSize'], equals(0));
    });
  });
}
