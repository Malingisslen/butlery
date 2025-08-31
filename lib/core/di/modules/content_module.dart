/// Content module for recipe and menu management services.
///
/// This module handles all content-related functionality including:
/// - Recipe management and operations
/// - Menu planning and organization
/// - Import functionality (text, photo, URL, archive)
/// - Search and discovery services
/// - Storage and file management
/// - Image handling services
///
/// Depends on Core Module for authentication and database access.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Dependencies from Core Module
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

// Recipe repositories and interfaces
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';

// Storage repository
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';

// Social repositories (for UnifiedRecipeService dependencies)
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

// Content services
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/services/backup_service.dart';

// Import core module for dependencies
import 'package:butlery/core/di/modules/core_module.dart';

/// Content module providing recipe and menu management services.
///
/// This module handles all content-related functionality and depends on
/// the Core Module for foundational services. It provides:
/// - Recipe management through UnifiedRecipeService
/// - Import functionality for various content types
/// - Menu planning and organization
/// - Search and discovery capabilities
/// - Storage and file management
/// - Offline content synchronization
class ContentModule implements DIModule {
  @override
  String get name => 'Content';

  @override
  List<Type> get dependencies => [CoreModule]; // Depends on Core Module

  @override
  List<Type> get provides => [
    RecipeRepository,
    UnifiedRecipeService,
    UnifiedMenuService,
    ImportManager,
    MenuService,
    SearchService,
    ShareService,
    StorageRepository,
    StorageService,
    ImagePickerService,
    OfflineService,
    CollaborativeRecipeRepository,
    RecommendationService,
    BackupService,
  ];

  @override
  int get priority => 10; // After Core Module (priority 1)

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [ContentModule] Configuring content services...');
    }

    try {
      // ==================== RECIPE REPOSITORIES ====================
      
      // Recipe repository - depends on Auth from Core Module
      container.registerSingleton<RecipeRepository>(
        FirebaseRecipeRepository(authRepository: container<AuthRepository>()),
      );

      // Collaborative recipe repository
      container.registerSingleton<CollaborativeRecipeRepository>(
        CollaborativeRecipeRepository(),
      );

      // ==================== UNIFIED RECIPE SYSTEM ====================
      
      // UnifiedRecipeService - core recipe management
      // Note: We use lazy singleton to ensure social dependencies are available
      container.registerLazySingleton<UnifiedRecipeService>(() => UnifiedRecipeService(
        // Using FirestoreRepository for standardized Firestore access
        firestore: container<FirestoreRepository>().firestore,
        authRepository: container<AuthRepository>() as FirebaseAuthRepository,
        // Include social dependencies if available (from SocialModule)
        ratingsRepository: container.isRegistered<RatingsRepository>() 
            ? container<RatingsRepository>() 
            : null,
        firestoreRepository: container.isRegistered<FirestoreRepository>()
            ? container<FirestoreRepository>()
            : null,
      ));

      // Import manager for various content import methods
      container.registerLazySingleton<ImportManager>(
        () => ImportManager(container<UnifiedRecipeService>().personal),
      );

      // ==================== CONTENT SERVICES ====================

      // Menu service for meal planning
      container.registerSingleton<MenuService>(MenuService());

      // Unified menu service for collaborative menu planning
      container.registerSingleton<UnifiedMenuService>(UnifiedMenuService(
        firestore: container<FirestoreRepository>().firestore,
      ));

      // Search service for content discovery
      container.registerSingleton<SearchService>(SearchService());

      // Share service for content sharing
      container.registerSingleton<ShareService>(ShareService());

      // Storage repository for storage operations
      container.registerSingleton<StorageRepository>(
        FirebaseStorageRepository(),
      );

      // Storage service for file management
      container.registerSingleton<StorageService>(
        StorageService(repository: container<StorageRepository>()),
      );

      // Image picker service for photo handling
      container.registerSingleton<ImagePickerService>(ImagePickerService());

      // Offline service for content synchronization
      container.registerSingleton<OfflineService>(
        OfflineService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      // Recommendation service for AI-powered content recommendations
      container.registerSingleton<RecommendationService>(RecommendationService());

      // Backup service for recipe data export and import
      container.registerSingleton<BackupService>(BackupService());

      if (kDebugMode) {
        debugPrint('✅ [ContentModule] Configured 13 services (Recipes, Menus, Import, Storage, Offline, Backup)');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure content services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // Initialize UnifiedRecipeService
      final unifiedRecipeService = container<UnifiedRecipeService>();
      await unifiedRecipeService.initialize();

      // Initialize UnifiedMenuService
      final unifiedMenuService = container<UnifiedMenuService>();
      await unifiedMenuService.initialize();

      // Initialize OfflineService (Hive dependency)
      final offlineService = container<OfflineService>();
      await offlineService.initialize();

      // Validate other services are accessible (no explicit initialization needed)
      final services = [
        container<MenuService>(),
        container<SearchService>(),
        container<ShareService>(),
        container<StorageService>(),
        container<ImagePickerService>(),
        container<BackupService>(),
      ];

      for (final service in services) {
        // Basic validation - service is accessible
        service.toString();
      }

    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize content services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Check that all content services are registered and accessible
      final services = <String, dynamic>{
        'RecipeRepository': container<RecipeRepository>(),
        'UnifiedRecipeService': container<UnifiedRecipeService>(),
        'ImportManager': container<ImportManager>(),
        'MenuService': container<MenuService>(),
        'SearchService': container<SearchService>(),
        'ShareService': container<ShareService>(),
        'StorageService': container<StorageService>(),
        'ImagePickerService': container<ImagePickerService>(),
        'OfflineService': container<OfflineService>(),
        'CollaborativeRecipeRepository': container<CollaborativeRecipeRepository>(),
        'RecommendationService': container<RecommendationService>(),
        'BackupService': container<BackupService>(),
      };

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;
        
        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint('❌ [ContentModule] Health check failed for ${entry.key}');
            }
            return false;
          }
        }
        
        // Basic validation - service is not null
        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [ContentModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContentModule] Health check failed: $e');
      }
      return false;
    }
  }
}

/// Content module factory for easy instantiation.
class ContentModuleFactory {
  /// Create a new ContentModule instance.
  static ContentModule create() => ContentModule();
  
  /// Create ContentModule with custom configuration.
  static ContentModule createWithConfig({
    bool enableOfflineSync = true,
    bool enableCollaboration = true,
    bool enableImport = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return ContentModule();
  }
}