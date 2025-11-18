library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/firebase/firebase_connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';

import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';

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
        UnifiedFriendsService,
        CommentsRepository,
        RatingsRepository,
        SocialRecipeRepository,
        SocialRecipeService,
        DeepLinkRepository,
        DeepLinkService,
        ConnectivityRepository,
        ConnectivityMonitoringService,
        SocialSharingRepository,
        SocialMenuOperations,
        GroupSharedContentService,
        // Social coordinators for shared content (Issue #014)
        SocialRecipeCoordinator,
        SocialMenuCoordinator,
        SocialShoppingCoordinator,
      ];

  @override
  int get priority => 20;

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [SocialModule] Configuring social services...');
    }

    try {
      container.registerSingleton<UserRepository>(
        FirebaseUserRepository(authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<UserService>(
        UserService(
          repository: container<UserRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerSingleton<FriendsRepository>(
        FirebaseFriendsRepository(authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<UnifiedFriendsService>(
        UnifiedFriendsService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerSingleton<CommentsRepository>(
        FirebaseCommentsRepository(authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<RatingsRepository>(
        FirebaseRatingsRepository(authRepository: container<AuthRepository>()),
      );

      // ==================== SOCIAL RECIPE SYSTEM ====================

      // Social recipe repository
      container.registerSingleton<SocialRecipeRepository>(
        FirebaseSocialRecipeRepository(
            authRepository: container<AuthRepository>()),
      );

      // Phase 1 shared content repositories (Issue #014)
      container.registerSingleton<FirebaseSharedRecipeRepository>(
        FirebaseSharedRecipeRepository(
            authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<FirebaseSharedMenuRepository>(
        FirebaseSharedMenuRepository(
            authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<FirebaseSharedShoppingRepository>(
        FirebaseSharedShoppingRepository(
            authRepository: container<AuthRepository>()),
      );

      // Note: SocialRecipeService registration is deferred to lazy singleton
      // because it depends on services from other modules that may not be available yet
      container.registerLazySingleton<SocialRecipeService>(
        () => SocialRecipeService(
          repository: container<SocialRecipeRepository>(),
          userService: container<UserService>(),
          recipeService: container<UnifiedRecipeService>(),
          permissionService: container<PermissionService>(),
          sharedRecipeRepository: container<FirebaseSharedRecipeRepository>(),
          sharedMenuRepository: container<FirebaseSharedMenuRepository>(),
          shoppingService: container<UnifiedShoppingService>(),
        ),
      );

      // ==================== SOCIAL COORDINATORS (ISSUE #014) ====================

      // Social coordinators for shared content operations
      // These provide facade coordination for social recipe/menu/shopping features
      container.registerLazySingleton<SocialRecipeCoordinator>(
        () {
          final authRepo = container<AuthRepository>();
          final userService = container<UserService>();
          final recipeService = container<UnifiedRecipeService>();

          return SocialRecipeCoordinator(
            cacheHelper: container<JsonCacheHelper>(),
            getCurrentUserId: () => authRepo.currentUserId,
            getCurrentUserDisplayName: () =>
                userService.currentUserProfile?.displayName ?? 'Unknown User',
            setError: (error) =>
                AppLogger.error('SocialRecipeCoordinator error: $error'),
            notifyListeners: () {}, // Coordinators are services, not ViewModels
            getRecipe: (id) async => recipeService.getRecipeById(id),
            saveRecipe: (recipe) async {
              return await recipeService.updateRecipe(recipe);
            },
          );
        },
      );

      container.registerLazySingleton<SocialMenuCoordinator>(
        () {
          final authRepo = container<AuthRepository>();
          final userService = container<UserService>();

          return SocialMenuCoordinator(
            getCurrentUserId: () => authRepo.currentUserId,
            getCurrentUserDisplayName: () =>
                userService.currentUserProfile?.displayName ?? 'Unknown User',
            setError: (error) =>
                AppLogger.error('SocialMenuCoordinator error: $error'),
            notifyListeners: () {}, // Coordinators are services, not ViewModels
            getMenu: (id) async {
              // FIXME(social-menu-api): Implement when UnifiedMenuService has getById
              AppLogger.warning(
                  'SocialMenuCoordinator.getMenu not yet implemented');
              return null;
            },
            saveMenu: (menu) async {
              // FIXME(social-menu-api): Implement when UnifiedMenuService has save method
              AppLogger.warning(
                  'SocialMenuCoordinator.saveMenu not yet implemented');
              return null;
            },
            cacheHelper: container<JsonCacheHelper>(),
          );
        },
      );

      container.registerLazySingleton<SocialShoppingCoordinator>(
        () {
          final authRepo = container<AuthRepository>();
          final userService = container<UserService>();

          return SocialShoppingCoordinator(
            getCurrentUserId: () => authRepo.currentUserId,
            getCurrentUserDisplayName: () =>
                userService.currentUserProfile?.displayName ?? 'Unknown User',
            setError: (error) =>
                AppLogger.error('SocialShoppingCoordinator error: $error'),
            notifyListeners: () {}, // Coordinators are services, not ViewModels
            getShoppingList: (id) async {
              // FIXME(social-shopping-api): Implement when UnifiedShoppingService has getById
              AppLogger.warning(
                  'SocialShoppingCoordinator.getShoppingList not yet implemented');
              return null;
            },
            saveShoppingList: (list) async {
              // FIXME(social-shopping-api): Implement when UnifiedShoppingService has save method
              AppLogger.warning(
                  'SocialShoppingCoordinator.saveShoppingList not yet implemented');
              return null;
            },
            cacheHelper: container<JsonCacheHelper>(),
          );
        },
      );

      // ==================== SHARING AND CONNECTIVITY ====================

      // Deep link repository and service
      container.registerSingleton<DeepLinkRepository>(
        FirebaseDeepLinkRepository(authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<DeepLinkService>(DeepLinkService(
        deepLinkRepository: container<DeepLinkRepository>(),
      ));

      // Connectivity repository and monitoring service
      container.registerSingleton<ConnectivityRepository>(
        FirebaseConnectivityRepository(
            authRepository: container<AuthRepository>()),
      );

      container.registerSingleton<ConnectivityMonitoringService>(
        ConnectivityMonitoringService(
          connectivityRepository: container<ConnectivityRepository>(),
        ),
      );

      // Social sharing repository
      container.registerSingleton<SocialSharingRepository>(
        FirebaseSocialSharingRepository(
            authRepository: container<AuthRepository>()),
      );

      // ==================== SOCIAL OPERATIONS ====================

      // Note: SocialMenuOperations depends on services that may not be available yet
      // We'll register it as lazy singleton to defer creation
      container.registerLazySingleton<SocialMenuOperations>(
        () => SocialMenuOperations(
          firestore: container<FirestoreRepository>().firestore,
          friendsService: container<UnifiedFriendsService>(),
        ),
      );

      // Group shared content service for displaying shared content in groups
      container.registerLazySingleton<GroupSharedContentService>(
        () => GroupSharedContentService(
          firestore: container<FirestoreRepository>().firestore,
          permissionService: container<PermissionService>(),
        ),
      );

      if (kDebugMode) {
        debugPrint(
            '✅ [SocialModule] Configured 16 services (Users, Friends, Social recipes, Comments, Ratings, Group content, Social coordinators)');
      }
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

      // Initialize UserService
      final userService = container<UserService>();
      await userService.initialize();

      // Initialize Enhanced UnifiedFriendsService
      final friendsService = container<UnifiedFriendsService>();
      await friendsService.initialize();

      // Validate other services are accessible
      final services = [
        container<DeepLinkService>(),
        container<ConnectivityMonitoringService>(),
      ];

      for (final service in services) {
        // Basic validation - service is accessible
        service.toString();
      }
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

      // Check that all social services are registered and accessible
      final services = <String, dynamic>{
        'UserRepository': container<UserRepository>(),
        'UserService': container<UserService>(),
        'FriendsRepository': container<FriendsRepository>(),
        'UnifiedFriendsService': container<UnifiedFriendsService>(),
        'CommentsRepository': container<CommentsRepository>(),
        'RatingsRepository': container<RatingsRepository>(),
        'SocialRecipeRepository': container<SocialRecipeRepository>(),
        'DeepLinkRepository': container<DeepLinkRepository>(),
        'DeepLinkService': container<DeepLinkService>(),
        'ConnectivityRepository': container<ConnectivityRepository>(),
        'ConnectivityMonitoringService':
            container<ConnectivityMonitoringService>(),
        'SocialSharingRepository': container<SocialSharingRepository>(),
        'GroupSharedContentService': container<GroupSharedContentService>(),
      };

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint(
                  '❌ [SocialModule] Health check failed for ${entry.key}');
            }
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [SocialModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SocialModule] Health check failed: $e');
      }
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
