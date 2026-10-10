/// BUT-907: the trash's DI registrations, called from `ContentModule`.
library;

import 'package:get_it/get_it.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_trash_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/trash/trash_restore.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

abstract final class TrashRegistrations {
  static void register(GetIt container) {
    container.registerLazySingleton<TrashRepository>(
      () => FirebaseTrashRepository(
        authRepository: container<AuthRepository>(),
      ),
    );

    // The restore's collaborators are user-scoped or registered by later
    // modules, so they are looked up when a restore runs.
    container.registerLazySingleton<TrashService>(
      () => TrashService(
        repository: container<TrashRepository>(),
        restorer: TrashRestore(
          repository: container<TrashRepository>(),
          userRepository: ServiceLocator.tryGet<UserRepository>,
          taggingService: ServiceLocator.tryGet<TaggingService>,
          hasUnsentWrite: (recipeId, userId) async =>
              await ServiceLocator.tryGet<OfflineService>()
                  ?.hasUnsentRecipeWrite(recipeId, userId) ??
              false,
          adoptRecipe: (recipe) async =>
              ServiceLocator.tryGet<UnifiedRecipeService>()
                  ?.adoptRestoredRecipe(recipe),
        ),
      ),
      dispose: (s) => s.dispose(),
    );
  }
}
