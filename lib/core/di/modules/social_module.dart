library;

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_ownership_resolver.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/firebase/firebase_connectivity_repository.dart';

import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/repositories/interfaces/group_shared_content_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_shared_content_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/firebase_cook_snap_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';

import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_activity_event_repository.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/services/social/ping_service.dart';

import 'package:butlery/repositories/firebase/firebase_report_repository.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

class SocialModule implements DIModule {
  @override
  String get name => 'Social';

  @override
  List<Type> get dependencies => [CoreModule, ContentModule];

  @override
  List<Type> get provides => [
    UserRepository,
    UserService,
    FriendsRepository,
    FirebaseSocialRequestRepository,
    UnifiedFriendsService,
    CommentsRepository,
    RatingsRepository,
    SocialRecipeService,
    DeepLinkRepository,
    DeepLinkService,
    ConnectivityRepository,
    ConnectivityMonitoringService,
    SocialMenuOperations,
    GroupSharedContentRepository,
    GroupSharedContentService,
    // Social coordinators for shared content (Issue #014)
    SocialRecipeCoordinator,
    SocialMenuCoordinator,
    SocialShoppingCoordinator,
    CookSnapRepository,
    CookSnapService,
    ActivityEventRepository,
    ActivityFeedService,
    // BUT-407: group-scoped nudge primitive.
    PingService,
    FirebaseReportRepository,
    ReportService,
    ContentFilterService,
    FirebaseBlockRepository,
    BlockedUserFilter,
    HouseholdService,
    HouseholdRepository,
  ];

  @override
  int get priority => 20;

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    // UserService is in app scope (needed by AuthWrapper before login)

    container.registerLazySingleton<UnifiedFriendsService>(
      () => UnifiedFriendsService(
        firestoreRepository: app<FirestoreRepository>(),
        authRepository: app<AuthRepository>(),
      ),
      dispose: (s) => s.dispose(),
    );

    container.registerLazySingleton<HouseholdService>(
      () => HouseholdService(),
    );

    container.registerLazySingleton<HouseholdRepository>(
      () => FirebaseHouseholdRepository(
        authRepository: container<AuthRepository>(),
      ),
    );

    container.registerLazySingleton<SocialRecipeService>(
      () => SocialRecipeService(
        userService: container<UserService>(),
        recipeService: container<UnifiedRecipeService>(),
        permissionService: app<PermissionService>(),
        sharedRecipeRepository: app<FirebaseSharedRecipeRepository>(),
        sharedMenuRepository: app<FirebaseSharedMenuRepository>(),
        socialRequestRepository: app<FirebaseSocialRequestRepository>(),
      ),
    );

    container.registerLazySingleton<SocialRecipeCoordinator>(() {
      final authRepo = app<AuthRepository>();
      final userService = container<UserService>();
      final recipeService = container<UnifiedRecipeService>();
      return SocialRecipeCoordinator(
        getCacheHelper: () => app<JsonCacheHelper>(),
        getCurrentUserId: () => authRepo.currentUserId,
        getCurrentUserDisplayName: () =>
            userService.currentUserProfile?.displayName ??
            AppLocale.current.displayUnknownUser,
        setError: (error) =>
            AppLogger.error('SocialRecipeCoordinator error: $error'),
        notifyListeners: () {},
        getRecipe: (id) async => recipeService.getRecipeById(id),
        saveRecipe: (recipe) async =>
            await recipeService.saveRecipeForSocialModule(recipe),
      );
    });

    container.registerLazySingleton<SocialMenuCoordinator>(() {
      final authRepo = app<AuthRepository>();
      final userService = container<UserService>();
      final menuService = container<UnifiedMenuService>();
      final firestoreRepo = app<FirestoreRepository>();
      return SocialMenuCoordinator(
        getCurrentUserId: () => authRepo.currentUserId,
        getCurrentUserDisplayName: () =>
            userService.currentUserProfile?.displayName ??
            AppLocale.current.displayUnknownUser,
        setError: (error) =>
            AppLogger.error('SocialMenuCoordinator error: $error'),
        notifyListeners: () {},
        getMenu: (id) async => menuService.getMenuById(id)?.menuSnapshot,
        saveMenu: (Map<String, List<Recipe>> menu) async {
          try {
            final userId = authRepo.currentUserId;
            final displayName =
                userService.currentUserProfile?.displayName ??
                AppLocale.current.displayUnknownUser;
            if (userId == null) return null;
            final sharedMenu = SharedMenu.create(
              sharedByUserId: userId,
              sharedByDisplayName: displayName,
              sharedToUserIds: [],
              shareMessage: null,
              menuTitle: 'Importerad meny',
              menuSnapshot: menu,
            );
            final menuData = sharedMenu.toFirestore();
            final docRef = await firestoreRepo.firestore
                .collection(FirestoreCollections.menus)
                .add(menuData);
            return docRef.id;
          } catch (e) {
            AppLogger.error('Failed to save imported menu: $e');
            return null;
          }
        },
        cacheHelper: app<JsonCacheHelper>(),
      );
    });

    container.registerLazySingleton<SocialShoppingCoordinator>(() {
      final authRepo = app<AuthRepository>();
      final userService = container<UserService>();
      final shoppingService = container<UnifiedShoppingService>();
      return SocialShoppingCoordinator(
        getCurrentUserId: () => authRepo.currentUserId,
        getCurrentUserDisplayName: () =>
            userService.currentUserProfile?.displayName ??
            AppLocale.current.displayUnknownUser,
        setError: (error) =>
            AppLogger.error('SocialShoppingCoordinator error: $error'),
        notifyListeners: () {},
        getShoppingList: (id) async =>
            shoppingService.lists.where((l) => l.id == id).firstOrNull,
        saveShoppingList: (list) async {
          AppLogger.warning(
            'SocialShoppingCoordinator.saveShoppingList called unexpectedly',
          );
          return null;
        },
        cacheHelper: app<JsonCacheHelper>(),
      );
    });

    container.registerLazySingleton<SocialMenuOperations>(
      () => SocialMenuOperations(
        firestore: app<FirestoreRepository>().firestore,
        friendsService: container<UnifiedFriendsService>(),
      ),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      container.registerLazySingleton<UserRepository>(
        () =>
            FirebaseUserRepository(authRepository: container<AuthRepository>()),
      );

      // UserService in app scope — needed by AuthWrapper before login
      container.registerLazySingleton<UserService>(
        () => UserService(
          repository: container<UserRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      // UnifiedFriendsService, SocialRecipeService,
      // coordinators, SocialMenuOperations: registered in configureUserScope

      container.registerLazySingleton<FriendsRepository>(
        () => FirebaseFriendsRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<FirebaseBlockRepository>(
        () => FirebaseBlockRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // BUT-544: shared block-aware filter for comment + chat read paths.
      // Singleton so the streamed cache is shared across both surfaces.
      container.registerLazySingleton<BlockedUserFilter>(
        () => BlockedUserFilter(
          blockRepository: container<FirebaseBlockRepository>(),
        ),
        dispose: (f) => f.dispose(),
      );

      container.registerLazySingleton<CommentsRepository>(
        () => FirebaseCommentsRepository(
          authRepository: container<AuthRepository>(),
          recipeAccessValidator: (recipeId, userId) async {
            try {
              final coordinator = container<SocialRecipeCoordinator>();
              return await coordinator.canViewRecipe(recipeId, userId);
            } catch (_) {
              return false;
            }
          },
          // BUT-458: production wiring of the ownership resolver. The
          // recipe service is user-scoped (registered post-login in
          // `configureUserScope`), so we resolve it lazily on each call
          // — pre-login attempts return null and the comment writes
          // without denorm fields (rules degrade to author-only read).
          recipeOwnershipResolver: (recipeId) async {
            try {
              if (!container.isRegistered<UnifiedRecipeService>()) {
                return null;
              }
              final recipeService = container<UnifiedRecipeService>();
              final resolver = FirebaseRecipeOwnershipResolver(
                getRecipe: (id) async => recipeService.getRecipeById(id),
              );
              return await resolver.resolve(recipeId);
            } catch (_) {
              return null;
            }
          },
        ),
      );

      container.registerLazySingleton<RatingsRepository>(
        () => FirebaseRatingsRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Phase 1 shared content repositories (Issue #014)
      container.registerLazySingleton<FirebaseSharedRecipeRepository>(
        () => FirebaseSharedRecipeRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<FirebaseSharedMenuRepository>(
        () => FirebaseSharedMenuRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<FirebaseSharedShoppingRepository>(
        () => FirebaseSharedShoppingRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Recipe-share requests reuse the unified social_requests collection.
      // SocialRecipeService injects this for the "ask a friend for a recipe"
      // + accept flow (idempotent recipeShareRequest writes).
      container.registerLazySingleton<FirebaseSocialRequestRepository>(
        () => FirebaseSocialRequestRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // CookSnap repository and service
      container.registerLazySingleton<CookSnapRepository>(
        () => FirebaseCookSnapRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<CookSnapService>(
        () => CookSnapService(
          repository: container<CookSnapRepository>(),
          friendsRepository: container<FriendsRepository>(),
        ),
      );

      // Activity feed repository and service
      container.registerLazySingleton<ActivityEventRepository>(
        () => FirebaseActivityEventRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<ActivityFeedService>(
        () => ActivityFeedService(
          repository: container<ActivityEventRepository>(),
        ),
      );

      // BUT-407: ping primitive service. Registered in the shared container
      // (not user-scoped) because it reads PermissionService + UnifiedFriendsService
      // lazily — both are already wired by the time the first ping flies.
      container.registerLazySingleton<PingService>(
        () => PingService(
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      // Content reporting repository and service
      container.registerLazySingleton<FirebaseReportRepository>(
        () => FirebaseReportRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<ReportService>(
        () => ReportService(
          reportRepository: container<FirebaseReportRepository>(),
          authRepository: container<AuthRepository>(),
          firestoreRepository: container<FirestoreRepository>(),
        ),
      );

      container.registerLazySingleton<ContentFilterService>(
        () => ContentFilterService(),
      );

      // Deep link repository and service
      container.registerLazySingleton<DeepLinkRepository>(
        () => FirebaseDeepLinkRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<DeepLinkService>(
        () => DeepLinkService(
          deepLinkRepository: container<DeepLinkRepository>(),
        ),
      );

      // Connectivity repository and monitoring service
      container.registerLazySingleton<ConnectivityRepository>(
        () => FirebaseConnectivityRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<ConnectivityMonitoringService>(
        () => ConnectivityMonitoringService(
          container<ConnectivityRepository>(),
        ),
      );

      // Group shared content service for displaying shared content in groups
      container.registerLazySingleton<GroupSharedContentRepository>(
        () => FirebaseGroupSharedContentRepository(
          firestore: container<FirestoreRepository>().firestore,
        ),
      );
      container.registerLazySingleton<GroupSharedContentService>(
        () => GroupSharedContentService(
          repository: container<GroupSharedContentRepository>(),
          permissionService: container<PermissionService>(),
        ),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure social services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // Validate app-scoped services are accessible
      container<DeepLinkService>();
      container<ConnectivityMonitoringService>();

      // UserService is app-scoped — initialize it so it subscribes to auth
      // state and loads the profile. Without this, returning users with
      // persisted Firebase sessions get a permanent spinner (BUG-043).
      await container<UserService>().initialize();
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize social services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // App-scoped services (always available)
      final services = <String, dynamic>{
        'UserRepository': container<UserRepository>(),
        'UserService': container<UserService>(),
        'FriendsRepository': container<FriendsRepository>(),
        'CommentsRepository': container<CommentsRepository>(),
        'RatingsRepository': container<RatingsRepository>(),
        'DeepLinkRepository': container<DeepLinkRepository>(),
        'DeepLinkService': container<DeepLinkService>(),
        'ConnectivityRepository': container<ConnectivityRepository>(),
        'ConnectivityMonitoringService':
            container<ConnectivityMonitoringService>(),
        'GroupSharedContentService': container<GroupSharedContentService>(),
      };

      // User-scoped services (only after login)
      if (container.isRegistered<UnifiedFriendsService>()) {
        services['UnifiedFriendsService'] = container<UnifiedFriendsService>();
      }

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Social module factory for easy instantiation.
class SocialModuleFactory {
  /// Create a new SocialModule instance.
  static SocialModule create() => SocialModule();

  /// Create SocialModule with custom configuration.
  static SocialModule createWithConfig({
    bool enableSocialSharing = true,
    bool enableComments = true,
    bool enableRatings = true,
    bool enableDeepLinks = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return SocialModule();
  }
}
