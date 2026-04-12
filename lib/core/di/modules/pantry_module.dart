library;

import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/tagging_module.dart';

import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';

import 'package:butlery/services/pantry/pantry_service.dart';

class PantryModule implements DIModule {
  @override
  String get name => 'Pantry';

  @override
  List<Type> get dependencies => [CoreModule, TaggingModule];

  @override
  List<Type> get provides => [
        PantryRepository,
        PantryService,
      ];

  // Priority between TaggingModule (5) and ContentModule (10) so the
  // pantry is available to any downstream module that wants to surface
  // pantry data (recipe matching etc.).
  @override
  int get priority => 7;

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    container.registerLazySingleton<PantryService>(
      () => PantryService(
        pantryRepository: app<PantryRepository>(),
        ingredientRepository: app<IngredientRepository>(),
      ),
      dispose: (s) => s.dispose(),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      // PantryRepository is app-scoped — it takes an explicit userId on
      // every call so it doesn't need to be torn down on logout.
      container.registerLazySingleton<PantryRepository>(
        () => FirebasePantryRepository(),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure pantry services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // User-scoped service — only initialize if user session is active.
      if (container.isRegistered<PantryService>()) {
        await container<PantryService>().initialize();
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize pantry services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      final services = <String, dynamic>{
        'PantryRepository': container<PantryRepository>(),
      };

      if (container.isRegistered<PantryService>()) {
        services['PantryService'] = container<PantryService>();
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

/// Factory for creating [PantryModule] instances.
class PantryModuleFactory {
  static PantryModule create() => PantryModule();
}
