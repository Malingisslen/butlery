/// Tagging module for automatic recipe tag generation.
///
/// This module handles ingredient lookup and tag generation:
/// - Ingredient database access (Firebase Firestore)
/// - User-defined ingredient overrides
/// - 4-phase tag generation system
/// - Allergen and dietary status calculation
///
/// Depends on Core Module for Firestore and Auth access.
library;

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/modules/core_module.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';

import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/tagging/tag_resolution_service.dart';

// Re-export RetaggingScheduler for app-level integration
// Note: RetaggingScheduler requires callback functions for recipes,
// so it must be instantiated at the app level, not in DI
export 'package:butlery/services/tagging/retagging_scheduler.dart';

/// Tagging module providing automatic recipe tagging services.
///
/// Registers:
/// - [TagConfigService] - Firebase-backed tag configuration with caching
/// - [IngredientRepository] - Global ingredient database access
/// - [UserIngredientRepository] - User-defined ingredient overrides
/// - [IngredientLookupService] - Ingredient matching and lookup
/// - [TaggingService] - Main tagging orchestrator
/// - [FirebasePersonalTagRepository] - User-defined personal tags
/// - [FirebasePersonalTagGroupRepository] - Personal tag groups/folders
/// - [PersonalTagService] - Personal tag management and rule evaluation
class TaggingModule implements DIModule {
  @override
  String get name => 'Tagging';

  @override
  List<Type> get dependencies => [CoreModule];

  @override
  List<Type> get provides => [
        TagConfigService,
        IngredientRepository,
        UserIngredientRepository,
        IngredientLookupService,
        TaggingService,
        FirebasePersonalTagRepository,
        FirebasePersonalTagGroupRepository,
        PersonalTagService,
        TagEditingService,
        TagResolutionService,
      ];

  @override
  int get priority => 25; // After Core (1), before Content (10) is also valid

  @override
  Future<void> configure(GetIt container) async {
    try {
      // Tag configuration service with Firebase + SharedPreferences caching
      container.registerLazySingleton<TagConfigService>(
        () => TagConfigService(),
      );

      // Global ingredient repository with in-memory caching
      container.registerLazySingleton<IngredientRepository>(
        () => FirebaseIngredientRepository(),
      );

      // User-scoped ingredient repository for custom ingredients
      container.registerLazySingleton<UserIngredientRepository>(
        () => FirebaseUserIngredientRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Ingredient lookup service for matching recipe ingredients
      container.registerLazySingleton<IngredientLookupService>(
        () => IngredientLookupService(
          ingredientRepository: container<IngredientRepository>(),
          userIngredientRepository: container<UserIngredientRepository>(),
        ),
      );

      // Main tagging service orchestrator
      container.registerLazySingleton<TaggingService>(
        () => TaggingService(
          lookupService: container<IngredientLookupService>(),
          tagConfigService: container<TagConfigService>(),
          userIngredientRepository: container<UserIngredientRepository>(),
        ),
      );

      // Personal tag repository for user-defined tags
      container.registerLazySingleton<FirebasePersonalTagRepository>(
        () => FirebasePersonalTagRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Personal tag group repository for organizing tags
      container.registerLazySingleton<FirebasePersonalTagGroupRepository>(
        () => FirebasePersonalTagGroupRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Tag editing service for user-driven tag overrides
      container.registerLazySingleton<TagEditingService>(
        () => TagEditingService(),
      );

      // Personal tag service for tag management and rule evaluation
      container.registerLazySingleton<PersonalTagService>(
        () => PersonalTagService(
          tagRepository: container<FirebasePersonalTagRepository>(),
          groupRepository: container<FirebasePersonalTagGroupRepository>(),
          lookupService: container<IngredientLookupService>(),
        ),
      );
      // Tag resolution service - unified tag data for recipes
      container.registerLazySingleton<TagResolutionService>(
        () => TagResolutionService(
          tagEditingService: container<TagEditingService>(),
        ),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure tagging services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // Initialize TagConfigService first (loads tag configs from Firebase)
      final tagConfigService = container<TagConfigService>();
      await tagConfigService.initialize();

      // Initialize TaggingService (which initializes IngredientLookupService)
      final taggingService = container<TaggingService>();
      await taggingService.initialize();

      // Initialize PersonalTagService
      final personalTagService = container<PersonalTagService>();
      await personalTagService.initialize();
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize tagging services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      final services = <String, dynamic>{
        'TagConfigService': container<TagConfigService>(),
        'IngredientRepository': container<IngredientRepository>(),
        'UserIngredientRepository': container<UserIngredientRepository>(),
        'IngredientLookupService': container<IngredientLookupService>(),
        'TaggingService': container<TaggingService>(),
        'FirebasePersonalTagRepository':
            container<FirebasePersonalTagRepository>(),
        'FirebasePersonalTagGroupRepository':
            container<FirebasePersonalTagGroupRepository>(),
        'PersonalTagService': container<PersonalTagService>(),
        'TagEditingService': container<TagEditingService>(),
        'TagResolutionService': container<TagResolutionService>(),
      };

      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) return false;
        }

        if (service == null) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Factory for creating TaggingModule instances.
class TaggingModuleFactory {
  static TaggingModule create() => TaggingModule();
}
