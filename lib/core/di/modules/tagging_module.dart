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

import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

/// Tagging module providing automatic recipe tagging services.
///
/// Registers:
/// - [IngredientRepository] - Global ingredient database access
/// - [UserIngredientRepository] - User-defined ingredient overrides
/// - [IngredientLookupService] - Ingredient matching and lookup
/// - [TaggingService] - Main tagging orchestrator
class TaggingModule implements DIModule {
  @override
  String get name => 'Tagging';

  @override
  List<Type> get dependencies => [CoreModule];

  @override
  List<Type> get provides => [
        IngredientRepository,
        UserIngredientRepository,
        IngredientLookupService,
        TaggingService,
      ];

  @override
  int get priority => 25; // After Core (1), before Content (10) is also valid

  @override
  Future<void> configure(GetIt container) async {
    try {
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
          userIngredientRepository: container<UserIngredientRepository>(),
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

      // Initialize TaggingService (which initializes IngredientLookupService)
      final taggingService = container<TaggingService>();
      await taggingService.initialize();
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
        'IngredientRepository': container<IngredientRepository>(),
        'UserIngredientRepository': container<UserIngredientRepository>(),
        'IngredientLookupService': container<IngredientLookupService>(),
        'TaggingService': container<TaggingService>(),
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
