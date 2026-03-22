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

import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_ingredient_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_personal_tag_repository.dart';

import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
import 'package:butlery/services/tagging/personal_tag_sharing_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/tagging/tag_resolution_service.dart';
import 'package:butlery/services/tagging/tagging_events_tracker.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';

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
        TaggingEventsTracker,
        TaggingService,
        FirebasePersonalTagRepository,
        FirebasePersonalTagGroupRepository,
        FirebaseSharedPersonalTagRepository,
        PersonalTagCrudService,
        PersonalTagRuleEvaluator,
        PersonalTagSharingService,
        PersonalTagService,
        TagEditingService,
        TagResolutionService,
      ];

  @override
  int get priority => 25; // After Core (1), before Content (10) is also valid

  @override
  @override
  Future<void> configureUserScope(GetIt container) async {}

  Future<void> configure(GetIt container) async {
    try {
      // Tag configuration service with Firebase + SharedPreferences caching
      container.registerLazySingleton<TagConfigService>(
        () => TagConfigService(
          firestore: container<FirestoreRepository>().firestore,
        ),
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

      // Tagging analytics tracker
      container.registerLazySingleton<TaggingEventsTracker>(
        () => TaggingEventsTracker(container<AnalyticsRepository>()),
      );

      // Main tagging service orchestrator
      container.registerLazySingleton<TaggingService>(
        () => TaggingService(
          lookupService: container<IngredientLookupService>(),
          tagConfigService: container<TagConfigService>(),
          userIngredientRepository: container<UserIngredientRepository>(),
          eventsTracker: container<TaggingEventsTracker>(),
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

      // Shared personal tag repository for cross-user tag sharing
      container.registerLazySingleton<FirebaseSharedPersonalTagRepository>(
        () => FirebaseSharedPersonalTagRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Tag editing service for user-driven tag overrides
      container.registerLazySingleton<TagEditingService>(
        () => TagEditingService(),
      );

      // Personal tag sub-services (registered before facade)
      container.registerLazySingleton<PersonalTagCrudService>(
        () => PersonalTagCrudService(
          tagRepository: container<FirebasePersonalTagRepository>(),
          groupRepository: container<FirebasePersonalTagGroupRepository>(),
        ),
      );

      container.registerLazySingleton<PersonalTagRuleEvaluator>(
        () => PersonalTagRuleEvaluator(
          lookupService: container<IngredientLookupService>(),
        ),
      );

      container.registerLazySingleton<PersonalTagSharingService>(
        () => PersonalTagSharingService(
          tagRepository: container<FirebasePersonalTagRepository>(),
        ),
      );

      // Personal tag facade - delegates to sub-services
      container.registerLazySingleton<PersonalTagService>(
        () => PersonalTagService(
          crudService: container<PersonalTagCrudService>(),
          ruleEvaluator: container<PersonalTagRuleEvaluator>(),
          sharingService: container<PersonalTagSharingService>(),
          tagRepository: container<FirebasePersonalTagRepository>(),
          groupRepository: container<FirebasePersonalTagGroupRepository>(),
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
        'FirebaseSharedPersonalTagRepository':
            container<FirebaseSharedPersonalTagRepository>(),
        'PersonalTagCrudService': container<PersonalTagCrudService>(),
        'PersonalTagRuleEvaluator': container<PersonalTagRuleEvaluator>(),
        'PersonalTagSharingService': container<PersonalTagSharingService>(),
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
