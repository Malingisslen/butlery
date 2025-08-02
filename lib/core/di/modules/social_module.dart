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
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/firebase/firebase_connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';

import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service_enhanced.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';

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
    UnifiedFriendsServiceEnhanced,
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
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] User services registered');
      }

      container.registerSingleton<FriendsRepository>(
        FirebaseFriendsRepository(authRepository: container<AuthRepository>()),
      );
      
      container.registerSingleton<UnifiedFriendsServiceEnhanced>(
        UnifiedFriendsServiceEnhanced(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Friends services registered');
      }

      container.registerSingleton<CommentsRepository>(
        FirebaseCommentsRepository(authRepository: container<AuthRepository>()),
      );
      
      container.registerSingleton<RatingsRepository>(
        FirebaseRatingsRepository(authRepository: container<AuthRepository>()),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Interaction repositories registered');
      }

      // ==================== SOCIAL RECIPE SYSTEM ====================
      
      // Social recipe repository
      container.registerSingleton<SocialRecipeRepository>(
        FirebaseSocialRecipeRepository(authRepository: container<AuthRepository>()),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Social recipe repository registered');
      }

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
        FirebaseConnectivityRepository(authRepository: container<AuthRepository>()),
      );
      
      container.registerSingleton<ConnectivityMonitoringService>(
        ConnectivityMonitoringService(
          connectivityRepository: container<ConnectivityRepository>(),
        ),
      );
      
      // Social sharing repository
      container.registerSingleton<SocialSharingRepository>(
        FirebaseSocialSharingRepository(authRepository: container<AuthRepository>()),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Sharing and connectivity services registered');
      }

      // ==================== SOCIAL OPERATIONS ====================
      
      // Note: SocialMenuOperations depends on services that may not be available yet
      // We'll register it as lazy singleton to defer creation
      container.registerLazySingleton<SocialMenuOperations>(
        () => SocialMenuOperations(
          firestore: container<FirestoreRepository>().firestore,
          friendsService: container<UnifiedFriendsServiceEnhanced>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Social operations registered');
      }

      if (kDebugMode) {
        debugPrint('✅ [SocialModule] All social services configured');
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
    if (kDebugMode) {
      debugPrint('⚡ [SocialModule] Initializing social services...');
    }

    try {
      final container = GetIt.instance;

      // Initialize UserService
      final userService = container<UserService>();
      await userService.initialize();
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] UserService initialized');
      }

      // Initialize Enhanced UnifiedFriendsService
      final friendsService = container<UnifiedFriendsServiceEnhanced>();
      await friendsService.initialize();
      
      if (kDebugMode) {
        debugPrint('✅ [SocialModule] UnifiedFriendsService initialized');
      }

      // Validate other services are accessible
      final services = [
        container<DeepLinkService>(),
        container<ConnectivityMonitoringService>(),
      ];

      for (final service in services) {
        // Basic validation - service is accessible
        service.toString();
      }

      if (kDebugMode) {
        debugPrint('✅ [SocialModule] All social services validated');
      }

      if (kDebugMode) {
        debugPrint('✅ [SocialModule] All social services initialized');
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
        'UnifiedFriendsServiceEnhanced': container<UnifiedFriendsServiceEnhanced>(),
        'CommentsRepository': container<CommentsRepository>(),
        'RatingsRepository': container<RatingsRepository>(),
        'SocialRecipeRepository': container<SocialRecipeRepository>(),
        'DeepLinkRepository': container<DeepLinkRepository>(),
        'DeepLinkService': container<DeepLinkService>(),
        'ConnectivityRepository': container<ConnectivityRepository>(),
        'ConnectivityMonitoringService': container<ConnectivityMonitoringService>(),
        'SocialSharingRepository': container<SocialSharingRepository>(),
      };

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;
        
        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint('❌ [SocialModule] Health check failed for ${entry.key}');
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

      if (kDebugMode) {
        debugPrint('✅ [SocialModule] Health check passed for all services');
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