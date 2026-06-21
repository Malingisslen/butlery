/// Intent-driven unit tests for [UnifiedRecipeService.fetchFriendRecipe].
///
/// Behaviours pinned:
/// 1. Cache-hit: returns the locally-cached recipe without calling the repo.
/// 2. Cache-miss: delegates to repository.readSharedRecipe and returns result.
/// 3. Repo-null: when repository returns null, returns null.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_presence_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/core/cache/cache_dao_interface.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/rate_limiting/rate_limiter.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// ---------------------------------------------------------------------------
// Local mocks not already in production_mocks
// ---------------------------------------------------------------------------

class _MockFirebaseRecipePresenceRepository extends Mock
    implements FirebaseRecipePresenceRepository {}

class _MockFirebaseSharedRecipeRepository extends Mock
    implements FirebaseSharedRecipeRepository {}

class _MockOfflineService extends Mock implements OfflineService {}

class _MockTaggingService extends Mock implements TaggingService {}

class _MockPersonalTagService extends Mock implements PersonalTagService {}

class _MockStorageService extends Mock implements StorageService {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockCacheDao extends Mock implements CacheDao {}

// ---------------------------------------------------------------------------
// Thin fake subclass that exposes a cache-injection point for testing.
//
// [_recipeById] is private on [UnifiedRecipeService]. Rather than drive a
// full initialize() cycle (which requires live auth + Firestore), we subclass
// and override [getRecipeById] to check an injected map first, then fall
// through to the real implementation. This lets us test the cache-hit branch
// without touching service internals.
// ---------------------------------------------------------------------------

class _FakeUnifiedRecipeService extends UnifiedRecipeService {
  _FakeUnifiedRecipeService({
    required super.authRepository,
    required super.recipeRepository,
    required super.commentsRepository,
    required super.ratingsRepository,
    required super.notificationsRepository,
    required super.firestoreRepository,
  });

  final Map<String, Recipe> _injectedCache = {};

  /// Seed a recipe into the fake cache so [fetchFriendRecipe] sees a cache-hit.
  void seedCache(String id, Recipe recipe) => _injectedCache[id] = recipe;

  @override
  Recipe? getRecipeById(String id) =>
      _injectedCache[id] ?? super.getRecipeById(id);
}

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
  });

  group('UnifiedRecipeService.fetchFriendRecipe', () {
    late _FakeUnifiedRecipeService service;
    late mocks.MockFirebaseAuthRepository mockAuthRepository;
    late mocks.MockRecipeRepository mockRecipeRepository;
    late mocks.MockCommentsRepository mockCommentsRepository;
    late mocks.MockRatingsRepository mockRatingsRepository;
    late mocks.MockNotificationsRepository mockNotificationsRepository;
    late mocks.FakeFirestoreRepository mockFirestoreRepository;
    late mocks.MockCollaborativeRecipeRepository mockCollaborativeRepository;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      RateLimiter().reset();
      await TestServiceLocator.initialize();

      mockAuthRepository = mocks.MockFirebaseAuthRepository();
      mockRecipeRepository = mocks.MockRecipeRepository();
      mockCommentsRepository = mocks.MockCommentsRepository();
      mockRatingsRepository = mocks.MockRatingsRepository();
      mockNotificationsRepository = mocks.MockNotificationsRepository();
      mockFirestoreRepository = mocks.FakeFirestoreRepository();
      mockCollaborativeRepository = mocks.MockCollaborativeRecipeRepository();

      final mockUser = MockFactory.createMockUser(uid: 'test_user_123');
      mockAuthRepository.setAuthState(
        user: mockUser as User?,
        userId: 'test_user_123',
      );
      when(() => mockAuthRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(mockUser as User?));
      when(
        () => mockRecipeRepository.subscribeToUserRecipes(
          any(),
          any(),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((_) => Stream.empty().listen((_) {}));

      TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepository);
      TestServiceLocator.registerMock<CommentsRepository>(
          mockCommentsRepository);
      TestServiceLocator.registerMock<RatingsRepository>(mockRatingsRepository);
      TestServiceLocator.registerMock<NotificationsRepository>(
          mockNotificationsRepository);
      TestServiceLocator.registerMock<FirestoreRepository>(
          mockFirestoreRepository);
      TestServiceLocator.registerMock<CollaborativeRecipeRepository>(
          mockCollaborativeRepository);
      TestServiceLocator.registerMock<FirebaseRecipePresenceRepository>(
          _MockFirebaseRecipePresenceRepository());
      TestServiceLocator.registerMock<FirebaseSharedRecipeRepository>(
          _MockFirebaseSharedRecipeRepository());
      TestServiceLocator.registerMock<UserRepository>(_MockUserRepository());

      final mockCacheDao = _MockCacheDao();
      final mockAppDatabase = _MockAppDatabase();
      when(() => mockAppDatabase.cacheDao).thenReturn(mockCacheDao);
      final mockOfflineService = _MockOfflineService();
      when(() => mockOfflineService.database).thenReturn(mockAppDatabase);
      TestServiceLocator.registerMock<OfflineService>(mockOfflineService);
      TestServiceLocator.registerMock<TaggingService>(_MockTaggingService());
      TestServiceLocator.registerMock<PersonalTagService>(
          _MockPersonalTagService());
      TestServiceLocator.registerMock<StorageService>(_MockStorageService());

      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(mocks.MockDIContainer());

      service = _FakeUnifiedRecipeService(
        authRepository: mockAuthRepository,
        recipeRepository: mockRecipeRepository,
        commentsRepository: mockCommentsRepository,
        ratingsRepository: mockRatingsRepository,
        notificationsRepository: mockNotificationsRepository,
        firestoreRepository: mockFirestoreRepository,
      );
    });

    tearDown(() async {
      try {
        service.dispose();
      } catch (_) {}
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // -------------------------------------------------------------------------
    // 1. Cache-hit: returns cached recipe, does NOT call repository.
    // -------------------------------------------------------------------------
    test(
        'returns locally-cached recipe and does not call the repository '
        'when the recipe is already in the cache', () async {
      const ownerId = 'friend-uid';
      const recipeId = 'recipe-abc';
      final cachedRecipe = RecipeFactory.build(id: recipeId);

      service.seedCache(recipeId, cachedRecipe);

      final result = await service.fetchFriendRecipe(
        ownerId: ownerId,
        recipeId: recipeId,
      );

      expect(result, equals(cachedRecipe));
      verifyNever(
        () => mockRecipeRepository.readSharedRecipe(
          ownerId: any(named: 'ownerId'),
          recipeId: any(named: 'recipeId'),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 2. Cache-miss: delegates to repository and returns its result.
    // -------------------------------------------------------------------------
    test(
        'calls repository.readSharedRecipe with correct ids and returns its '
        'result when the recipe is not in the local cache', () async {
      const ownerId = 'friend-uid';
      const recipeId = 'recipe-xyz';
      final repoRecipe = RecipeFactory.build(id: recipeId);

      when(
        () => mockRecipeRepository.readSharedRecipe(
          ownerId: ownerId,
          recipeId: recipeId,
        ),
      ).thenAnswer((_) async => repoRecipe);

      final result = await service.fetchFriendRecipe(
        ownerId: ownerId,
        recipeId: recipeId,
      );

      expect(result, equals(repoRecipe));
      verify(
        () => mockRecipeRepository.readSharedRecipe(
          ownerId: ownerId,
          recipeId: recipeId,
        ),
      ).called(1);
    });

    // -------------------------------------------------------------------------
    // 3. Repo-null: repository returns null → fetchFriendRecipe returns null.
    // -------------------------------------------------------------------------
    test(
        'returns null when the repository returns null '
        '(recipe not found or not visible to the current user)', () async {
      const ownerId = 'friend-uid';
      const recipeId = 'recipe-missing';

      when(
        () => mockRecipeRepository.readSharedRecipe(
          ownerId: ownerId,
          recipeId: recipeId,
        ),
      ).thenAnswer((_) async => null);

      final result = await service.fetchFriendRecipe(
        ownerId: ownerId,
        recipeId: recipeId,
      );

      expect(result, isNull);
    });
  });
}
