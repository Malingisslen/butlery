/// Collaboration module for real-time services and collaborative features.
///
/// This module handles all collaborative functionality including:
/// - Real-time synchronization services
/// - Collaborative recipe editing
/// - Collaborative menu planning
/// - Unified shopping list management
/// - Permission validation system
/// - Real-time conflict resolution
///
/// Depends on Core, Content, and Social modules for foundational services.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Dependencies from Core Module
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/auth_service.dart';

// Dependencies from Content Module
import 'package:butlery/services/unified/unified_recipe_service.dart';

// Dependencies from Social Module
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

// Collaboration services
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/realtime/realtime_recipe_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';

// Import dependency modules
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';

/// Collaboration module providing real-time collaborative services.
///
/// This module handles all collaborative functionality and depends on
/// Core, Content, and Social modules. It provides:
/// - Real-time synchronization for collaborative editing
/// - Collaborative recipe editing with conflict resolution
/// - Collaborative menu planning and sharing
/// - Unified shopping list management with real-time updates
/// - Comprehensive permission validation system
/// - Real-time conflict resolution and merging
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
    PermissionService,
  ];

  @override
  int get priority => 40; // After Core (1), Content (10), Social (20), Messaging (30)

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [CollaborationModule] Configuring collaboration services...');
    }

    try {
      // ==================== REALTIME SYNC FOUNDATION ====================
      
      // RealtimeSyncService - enables collaborative editing of recipes and menus
      container.registerSingleton<RealtimeSyncService>(
        RealtimeSyncService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] RealtimeSyncService registered');
      }

      // ==================== COLLABORATIVE SERVICES ====================
      
      // RealtimeMenuService - collaborative meal planning
      container.registerLazySingleton<RealtimeMenuService>(
        () => RealtimeMenuService(
          syncService: container<RealtimeSyncService>(),
          authService: container<AuthService>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] RealtimeMenuService registered');
      }

      // ==================== UNIFIED SHOPPING SYSTEM ====================
      
      // UnifiedShoppingService - collaborative shopping lists
      container.registerLazySingleton<UnifiedShoppingService>(
        () => UnifiedShoppingService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] UnifiedShoppingService registered');
      }

      // ==================== PERMISSION SYSTEM ====================
      
      // PermissionService - comprehensive authorization system
      // Note: This depends on services from multiple modules, registered as lazy singleton
      container.registerLazySingleton<PermissionService>(
        () => PermissionService(
          container<AuthService>(),
          container<UserService>(),
          container<UnifiedRecipeService>(),
          container<UnifiedShoppingService>(),
          container<UnifiedFriendsService>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] PermissionService registered');
      }

      // ==================== REALTIME RECIPE SERVICE ====================
      
      // RealtimeRecipeService - collaborative recipe editing
      // Note: This depends on PermissionService, so it's registered as lazy singleton
      container.registerLazySingleton<RealtimeRecipeService>(
        () => RealtimeRecipeService(
          syncService: container<RealtimeSyncService>(),
          permissionService: container<PermissionService>(),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] RealtimeRecipeService registered');
      }

      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] All collaboration services configured');
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
    if (kDebugMode) {
      debugPrint('⚡ [CollaborationModule] Initializing collaboration services...');
    }

    try {
      final container = GetIt.instance;

      // Initialize RealtimeSyncService
      final realtimeSyncService = container<RealtimeSyncService>();
      await realtimeSyncService.initialize();
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] RealtimeSyncService initialized');
      }

      // Initialize UnifiedShoppingService
      final shoppingService = container<UnifiedShoppingService>();
      await shoppingService.initialize();
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] UnifiedShoppingService initialized');
      }

      // Validate other services are accessible (lazy singletons will be created on first access)
      final permissionService = container<PermissionService>();
      permissionService.toString(); // Basic validation - this creates the lazy singleton
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] PermissionService validated');
      }

      // Validate realtime services
      final realtimeMenuService = container<RealtimeMenuService>();
      realtimeMenuService.toString(); // Basic validation
      
      final realtimeRecipeService = container<RealtimeRecipeService>();
      realtimeRecipeService.toString(); // Basic validation
      
      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] Realtime services validated');
      }

      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] All collaboration services initialized');
      }
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

      // Check that all collaboration services are registered and accessible
      final services = <String, dynamic>{
        'RealtimeSyncService': container<RealtimeSyncService>(),
        'UnifiedShoppingService': container<UnifiedShoppingService>(),
        'PermissionService': container<PermissionService>(),
      };

      // Note: Lazy singletons will be created when accessed for health check
      try {
        services['RealtimeMenuService'] = container<RealtimeMenuService>();
        services['RealtimeRecipeService'] = container<RealtimeRecipeService>();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [CollaborationModule] Could not access lazy singletons: $e');
        }
      }

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;
        
        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint('❌ [CollaborationModule] Health check failed for ${entry.key}');
            }
            return false;
          }
        }
        
        // Basic validation - service is not null
        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [CollaborationModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [CollaborationModule] Health check passed for all services');
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

/// Collaboration module factory for easy instantiation.
class CollaborationModuleFactory {
  /// Create a new CollaborationModule instance.
  static CollaborationModule create() => CollaborationModule();
  
  /// Create CollaborationModule with custom configuration.
  static CollaborationModule createWithConfig({
    bool enableRealtimeSync = true,
    bool enableCollaborativeRecipes = true,
    bool enableCollaborativeMenus = true,
    bool enableCollaborativeShopping = true,
    bool enablePermissionValidation = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return CollaborationModule();
  }
}