/// Collaboration module for real-time services and collaborative features.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/repositories/firebase/firebase_menu_collaboration_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/realtime/realtime_recipe_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';

/// Provides real-time collaborative services for recipes, menus, and shopping lists.
class CollaborationModule implements DIModule {
  @override
  String get name => 'Collaboration';

  @override
  List<Type> get dependencies => [CoreModule, ContentModule, SocialModule];

  @override
  List<Type> get provides => [
        RealtimeSyncService,
        RealtimeRecipeService,
        RealtimeMenuService,
        UnifiedShoppingService,
        MenuCollaborationRepository,
      ];

  @override
  int get priority =>
      40; // After Core (1), Content (10), Social (20), Messaging (30)

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint(
        '🔧 [CollaborationModule] Configuring collaboration services...',
      );
    }

    try {
      container.registerSingleton<RealtimeSyncService>(
        RealtimeSyncService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<MenuCollaborationRepository>(
        () => FirebaseMenuCollaborationRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<RealtimeMenuService>(
        () => RealtimeMenuService(
          syncService: container<RealtimeSyncService>(),
          authService: container<AuthService>(),
        ),
      );

      container.registerLazySingleton<ShoppingRepository>(
        () => FirebaseShoppingRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<UnifiedShoppingService>(
        () => UnifiedShoppingService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
          shoppingRepository: container<ShoppingRepository>(),
        ),
      );

      container.registerLazySingleton<RealtimeRecipeService>(
        () => RealtimeRecipeService(
          syncService: container<RealtimeSyncService>(),
          permissionService: container<PermissionService>(),
        ),
      );

      if (kDebugMode) {
        debugPrint(
          '✅ [CollaborationModule] Configured 6 services (Realtime sync, Shopping, Shared shopping, Permissions)',
        );
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure collaboration services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      final realtimeSyncService = container<RealtimeSyncService>();
      await realtimeSyncService.initialize();

      final shoppingService = container<UnifiedShoppingService>();
      await shoppingService.initialize();

      final permissionService = container<PermissionService>();
      permissionService.toString();

      final realtimeMenuService = container<RealtimeMenuService>();
      realtimeMenuService.toString();

      final realtimeRecipeService = container<RealtimeRecipeService>();
      realtimeRecipeService.toString();
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize collaboration services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      final services = <String, dynamic>{
        'RealtimeSyncService': container<RealtimeSyncService>(),
        'UnifiedShoppingService': container<UnifiedShoppingService>(),
        'PermissionService': container<PermissionService>(),
      };

      try {
        services['RealtimeMenuService'] = container<RealtimeMenuService>();
        services['RealtimeRecipeService'] = container<RealtimeRecipeService>();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [CollaborationModule] Could not access lazy singletons: $e',
          );
        }
      }

      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint(
                '❌ [CollaborationModule] Health check failed for ${entry.key}',
              );
            }
            return false;
          }
        }

        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [CollaborationModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CollaborationModule] Health check failed: $e');
      }
      return false;
    }
  }
}

class CollaborationModuleFactory {
  static CollaborationModule create() => CollaborationModule();

  static CollaborationModule createWithConfig({
    bool enableRealtimeSync = true,
    bool enableCollaborativeRecipes = true,
    bool enableCollaborativeMenus = true,
    bool enableCollaborativeShopping = true,
    bool enablePermissionValidation = true,
  }) {
    return CollaborationModule();
  }
}
