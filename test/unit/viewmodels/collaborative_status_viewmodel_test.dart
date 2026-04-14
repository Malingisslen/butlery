import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';

// Local pure-Mock: centralized MockSocialRecipeService has concrete @overrides
// blocking when().
class _MockSocialRecipeService extends Mock implements SocialRecipeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSocialRecipeService mockSocial;
  late MockPermissionService mockPermission;
  late CollaborativeStatusViewModel viewModel;

  setUpAll(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    mockSocial = _MockSocialRecipeService();
    mockPermission = MockPermissionService();
    mockPermission.setPermissionState(
        currentUserId: 'test_user_id', isAuthenticated: true);
    TestServiceLocator.registerMock<PermissionService>(mockPermission);
    viewModel = CollaborativeStatusViewModel(socialRecipeService: mockSocial);
  });

  tearDown(() => viewModel.dispose());

  tearDownAll(() async => await TestServiceLocator.reset());

  // Helper to stub recipe-shared checks
  void stubRecipeShared({bool shared = true}) {
    when(() => mockSocial.isRecipeSharedByUser(any(), any()))
        .thenAnswer((_) async => shared);
    when(() => mockSocial.getRecipeParticipants(any()))
        .thenAnswer((_) async => []);
  }

  group('Initialization', () {
    test('should initialize with empty cache', () {
      expect(viewModel.currentUserId, equals('test_user_id'));
      expect(viewModel.debugInfo['totalCacheSize'], equals(0));
      expect(viewModel.debugInfo['activeChecks'], equals(0));
    });

    test('should handle null current user ID', () {
      mockPermission.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      final vm = CollaborativeStatusViewModel(socialRecipeService: mockSocial);
      expect(vm.currentUserId, isNull);
      vm.dispose();
    });
  });

  group('Recipe Metadata Analysis', () {
    test('should return false for null recipe metadata', () {
      final s = viewModel.getRecipeCollaborativeStatus('r1', null);
      expect(s.isCollaborative, isFalse);
    });

    test('should detect collaborative patterns in title', () {
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r1', RecipeFactory.build(title: '(Delad) Recipe'))
              .isCollaborative,
          isTrue);
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r2', RecipeFactory.build(title: '(Shared) Recipe'))
              .isCollaborative,
          isTrue);
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r3', RecipeFactory.build(title: 'Normal Recipe'))
              .isCollaborative,
          isFalse);
    });

    test('should detect collaborative patterns in description', () {
      for (final desc in [
        'Delat med vänner',
        'Shared with family',
        'Från "Annas kokbok"'
      ]) {
        expect(
            viewModel
                .getRecipeCollaborativeStatus(
                    'r_$desc', RecipeFactory.build(description: desc))
                .isCollaborative,
            isTrue,
            reason: 'Expected collaborative for description: $desc');
      }
    });

    test('should detect collaborative patterns in tags', () {
      final recipe = RecipeFactory.build(
          personalTagIds: ['vegetarisk', 'delad', 'middag']);
      expect(
          viewModel.getRecipeCollaborativeStatus('r1', recipe).isCollaborative,
          isTrue);
    });

    test('should detect collaborative patterns in source URL', () {
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r1',
                  RecipeFactory.build(
                      sourceUrl: 'https://x?shared_recipe_id=1'))
              .isCollaborative,
          isTrue);
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r2',
                  RecipeFactory.build(
                      sourceUrl: 'https://x?collaborative=true'))
              .isCollaborative,
          isTrue);
      expect(
          viewModel
              .getRecipeCollaborativeStatus(
                  'r3', RecipeFactory.build(sourceUrl: 'https://x/normal'))
              .isCollaborative,
          isFalse);
    });

    test('should support legacy boolean API', () {
      expect(
          viewModel.getRecipeCollaborativeStatusLegacy(
              'r1', RecipeFactory.build(title: '(Delad) Recipe')),
          isTrue);
    });
  });

  group('Async Recipe Status Check', () {
    test('should cache status after async check', () async {
      when(() => mockSocial.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getRecipeParticipants(any()))
          .thenAnswer((_) async => [
                UserProfile(
                    uid: 'u1',
                    displayName: 'User',
                    email: 'u@x.com',
                    joinedAt: DateTime.now(),
                    lastActiveAt: DateTime.now())
              ]);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      final cached = viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      expect(cached.isCollaborative, isTrue);
      expect(cached.participants.length, equals(1));
      expect(cached.isValid, isTrue);
    });

    test('should store error on async failure', () async {
      when(() => mockSocial.isRecipeSharedByUser(any(), any()))
          .thenThrow(Exception('Network error'));

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      final s = viewModel.getCachedStatus(
          'recipe_1', CollaborativeContentType.recipe);
      expect(s?.hasError, isTrue);
      expect(s?.error, contains('Network error'));
    });
  });

  group('Menu Status', () {
    test('should detect collaborative menu from recipe metadata', () {
      final data = {
        'Monday': [RecipeFactory.build(title: '(Delad) Pasta')],
        'Tuesday': [RecipeFactory.build(title: 'Normal')],
      };
      expect(viewModel.getMenuCollaborativeStatus('m1', data).isCollaborative,
          isTrue);
    });

    test('should detect collaborative menu from tag metadata', () {
      final data = {
        'Monday': [
          RecipeFactory.build(personalTagIds: ['importerat', 'lunch'])
        ]
      };
      expect(viewModel.getMenuCollaborativeStatus('m1', data).isCollaborative,
          isTrue);
    });

    test('should handle empty and null menu', () {
      expect(
          viewModel.getMenuCollaborativeStatus(
              'm1', <String, List<Recipe>>{}).isCollaborative,
          isFalse);
      expect(viewModel.getMenuCollaborativeStatus('m2', null).isCollaborative,
          isFalse);
    });

    test('should perform async menu check', () async {
      when(() => mockSocial.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getMenuCollaborativeStatus('menu_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockSocial.isMenuSharedByUser('menu_1', 'test_user_id'))
          .called(1);
    });

    test('should support legacy menu boolean API', () {
      final data = {
        'Monday': [RecipeFactory.build(title: '(Shared) Recipe')]
      };
      expect(viewModel.getMenuCollaborativeStatusLegacy('m1', data), isTrue);
    });
  });

  group('Shopping List Status', () {
    test('should return non-collaborative for uncached list', () {
      expect(
          viewModel
              .getShoppingListCollaborativeStatus('list_1')
              .isCollaborative,
          isFalse);
    });

    test('should perform async shopping list check', () async {
      when(() => mockSocial.isShoppingListSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getShoppingListParticipants(any()))
          .thenAnswer((_) async => [
                UserProfile(
                    uid: 'u1',
                    displayName: 'Friend',
                    email: 'f@x.com',
                    joinedAt: DateTime.now(),
                    lastActiveAt: DateTime.now())
              ]);

      viewModel.getShoppingListCollaborativeStatus('list_1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() =>
              mockSocial.isShoppingListSharedByUser('list_1', 'test_user_id'))
          .called(1);
      final c = viewModel.getCachedStatus(
          'list_1', CollaborativeContentType.shoppingList);
      expect(c?.isCollaborative, isTrue);
      expect(c?.participants.length, equals(1));
    });
  });

  group('Cache Management', () {
    test('should cache status with TTL', () async {
      stubRecipeShared();
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      final c = viewModel.getCachedStatus(
          'recipe_1', CollaborativeContentType.recipe);
      expect(c, isNotNull);
      expect(c?.isValid, isTrue);
      expect(c?.lastChecked, isNotNull);
    });

    test('should invalidate specific content', () async {
      stubRecipeShared();
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(
          viewModel.getCachedStatus(
              'recipe_1', CollaborativeContentType.recipe),
          isNotNull);

      viewModel.invalidateContent('recipe_1', CollaborativeContentType.recipe);

      expect(
          viewModel.getCachedStatus(
              'recipe_1', CollaborativeContentType.recipe),
          isNull);
    });

    test('should support legacy invalidate methods', () async {
      stubRecipeShared();
      when(() => mockSocial.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getMenuCollaborativeStatus('menu_1', null);
      await Future.delayed(const Duration(milliseconds: 200));

      viewModel.invalidateRecipeStatus('recipe_1');
      viewModel.invalidateMenuStatus('menu_1');

      expect(
          viewModel.getCachedStatus(
              'recipe_1', CollaborativeContentType.recipe),
          isNull);
      expect(viewModel.getCachedStatus('menu_1', CollaborativeContentType.menu),
          isNull);
    });

    test('should clear all cache', () async {
      stubRecipeShared();
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_2', null);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.debugInfo['totalCacheSize'], greaterThan(0));
      viewModel.clearAllCache();
      expect(viewModel.debugInfo['totalCacheSize'], equals(0));
    });

    test('should not check same content concurrently', () async {
      when(() => mockSocial.isRecipeSharedByUser(any(), any()))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });
      when(() => mockSocial.getRecipeParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 150));

      verify(() => mockSocial.isRecipeSharedByUser('recipe_1', any()))
          .called(1);
    });
  });

  group('Batch Operations', () {
    test('should batch check multiple content types', () async {
      stubRecipeShared();
      when(() => mockSocial.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockSocial.getMenuParticipants(any()))
          .thenAnswer((_) async => []);
      when(() => mockSocial.isShoppingListSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getShoppingListParticipants(any()))
          .thenAnswer((_) async => []);

      await viewModel.batchCheckContent(
        recipeIds: ['recipe_1', 'recipe_2'],
        menuIds: ['menu_1'],
        shoppingListIds: ['list_1', 'list_2'],
      );

      verify(() => mockSocial.isRecipeSharedByUser('recipe_1', any()))
          .called(1);
      verify(() => mockSocial.isRecipeSharedByUser('recipe_2', any()))
          .called(1);
      verify(() => mockSocial.isMenuSharedByUser('menu_1', any())).called(1);
      verify(() => mockSocial.isShoppingListSharedByUser('list_1', any()))
          .called(1);
      verify(() => mockSocial.isShoppingListSharedByUser('list_2', any()))
          .called(1);
    });

    test('should skip already cached items in batch', () async {
      when(() => mockSocial.isRecipeSharedByUser('recipe_1', any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getRecipeParticipants('recipe_1'))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      reset(mockSocial);
      stubRecipeShared(shared: false);

      await viewModel.batchCheckContent(recipeIds: ['recipe_1', 'recipe_2']);

      verifyNever(() => mockSocial.isRecipeSharedByUser('recipe_1', any()));
      verify(() => mockSocial.isRecipeSharedByUser('recipe_2', any()))
          .called(1);
    });

    test('should handle null user ID in batch check', () async {
      mockPermission.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      final vm = CollaborativeStatusViewModel(socialRecipeService: mockSocial);

      await vm.batchCheckContent(recipeIds: ['recipe_1']);
      verifyNever(() => mockSocial.isRecipeSharedByUser(any(), any()));
      vm.dispose();
    });
  });

  group('Debug Info', () {
    test('should provide comprehensive debug info', () async {
      stubRecipeShared();
      when(() => mockSocial.isMenuSharedByUser(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockSocial.getMenuParticipants(any()))
          .thenAnswer((_) async => []);

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      viewModel.getRecipeCollaborativeStatus('recipe_2', null);
      viewModel.getMenuCollaborativeStatus('menu_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      final info = viewModel.debugInfo;
      expect(info['totalCacheSize'], equals(3));
      expect(info['activeChecks'], equals(0));
      expect(info['currentUserId'], equals('test_user_id'));
      expect(info['cacheByType']['recipe'], equals(2));
      expect(info['cacheByType']['menu'], equals(1));
      expect(info['cacheByType']['shoppingList'], equals(0));
      expect(info['cacheTtlMinutes'], equals(5));
    });
  });

  group('Error Handling', () {
    test('should handle null user ID gracefully', () {
      mockPermission.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      final vm = CollaborativeStatusViewModel(socialRecipeService: mockSocial);
      final s = vm.getRecipeCollaborativeStatus('recipe_1', null);
      expect(s.isCollaborative, isFalse);
      vm.dispose();
    });

    test('should store error on async failure', () async {
      when(() => mockSocial.isRecipeSharedByUser(any(), any()))
          .thenThrow(Exception('Service error'));

      viewModel.getRecipeCollaborativeStatus('recipe_1', null);
      await Future.delayed(const Duration(milliseconds: 100));

      final s = viewModel.getCachedStatus(
          'recipe_1', CollaborativeContentType.recipe);
      expect(s?.hasError, isTrue);
      expect(s?.error, contains('Service error'));
      expect(s?.isCollaborative, isFalse);
    });
  });

  group('Disposal', () {
    test('should clear cache on dispose', () {
      final vm = CollaborativeStatusViewModel(socialRecipeService: mockSocial);
      vm.getRecipeCollaborativeStatus('recipe_1', null);
      vm.dispose();
      expect(vm.debugInfo['totalCacheSize'], equals(0));
    });
  });
}
