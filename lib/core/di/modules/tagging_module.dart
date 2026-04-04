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

import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
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
        PersonalTagCrudService,
        PersonalTagRuleEvaluator,
        PersonalTagService,
        TagEditingService,
        TagResolutionService,
      ];

  @override
  int get priority => 5; // After Core (1), before Content (10)

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    container.registerLazySingleton<UserIngredientRepository>(
      () => FirebaseUserIngredientRepository(
        authRepository: app<AuthRepository>(),
      ),
      dispose: (s) {
        if (s is FirebaseUserIngredientRepository) s.clearAllCaches();
      },
    );

    // IngredientLookupService depends on UserIngredientRepository (user-scoped)
    // so it must also live in user scope to avoid GetIt resolution failures at boot.
    container.registerLazySingleton<IngredientLookupService>(
      () => IngredientLookupService(
        ingredientRepository: app<IngredientRepository>(),
        userIngredientRepository: container<UserIngredientRepository>(),
      ),
    );

    // TaggingService depends on IngredientLookupService + UserIngredientRepository
    container.registerLazySingleton<TaggingService>(
      () => TaggingService(
        lookupService: container<IngredientLookupService>(),
        tagConfigService: app<TagConfigService>(),
        userIngredientRepository: container<UserIngredientRepository>(),
        eventsTracker: app<TaggingEventsTracker>(),
      ),
    );

    // PersonalTagRuleEvaluator depends on IngredientLookupService (user-scoped)
    container.registerLazySingleton<PersonalTagRuleEvaluator>(
      () => PersonalTagRuleEvaluator(
        lookupService: container<IngredientLookupService>(),
      ),
    );

    container.registerLazySingleton<PersonalTagCrudService>(
      () => PersonalTagCrudService(
        tagRepository: app<FirebasePersonalTagRepository>(),
        groupRepository: app<FirebasePersonalTagGroupRepository>(),
      ),
    );

    container.registerLazySingleton<PersonalTagService>(
      () => PersonalTagService(
        crudService: container<PersonalTagCrudService>(),
        ruleEvaluator: container<PersonalTagRuleEvaluator>(),
        tagRepository: app<FirebasePersonalTagRepository>(),
        groupRepository: app<FirebasePersonalTagGroupRepository>(),
      ),
      dispose: (s) => s.resetForLogout(),
    );
  }

  @override
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

      // IngredientLookupService, TaggingService, PersonalTagRuleEvaluator,
      // UserIngredientRepository, PersonalTagCrudService, PersonalTagService:
      // registered in configureUserScope (depend on user-scoped deps)

      // Tagging analytics tracker (app-scoped, no user dep)
      container.registerLazySingleton<TaggingEventsTracker>(
        () => TaggingEventsTracker(container<AnalyticsRepository>()),
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

      // TaggingService, PersonalTagService etc. are user-scoped.
      // Only initialize them if user scope is active (persisted session).
      if (container.isRegistered<TaggingService>()) {
        final taggingService = container<TaggingService>();
        await taggingService.initialize();
      }

      if (container.isRegistered<PersonalTagService>()) {
        final personalTagService = container<PersonalTagService>();
        await personalTagService.initialize();
      }
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

      // App-scoped services (always available)
      final services = <String, dynamic>{
        'TagConfigService': container<TagConfigService>(),
        'IngredientRepository': container<IngredientRepository>(),
        'FirebasePersonalTagRepository':
            container<FirebasePersonalTagRepository>(),
        'FirebasePersonalTagGroupRepository':
            container<FirebasePersonalTagGroupRepository>(),
        'TagEditingService': container<TagEditingService>(),
        'TagResolutionService': container<TagResolutionService>(),
      };

      // User-scoped services (only available after login)
      if (container.isRegistered<UserIngredientRepository>()) {
        services['UserIngredientRepository'] =
            container<UserIngredientRepository>();
        services['IngredientLookupService'] =
            container<IngredientLookupService>();
        services['TaggingService'] = container<TaggingService>();
        services['PersonalTagCrudService'] =
            container<PersonalTagCrudService>();
        services['PersonalTagRuleEvaluator'] =
            container<PersonalTagRuleEvaluator>();
        services['PersonalTagService'] = container<PersonalTagService>();
      }

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
