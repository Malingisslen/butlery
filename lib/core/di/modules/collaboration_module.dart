/// Collaboration module for real-time services and collaborative features.
library;

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
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/repositories/firebase/firebase_category_preferences_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_presence_repository.dart';
import 'package:butlery/services/unified/operations/shopping/shopping_presence_module.dart';
import 'package:butlery/repositories/firebase/firebase_cooking_session_repository.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';
import 'package:butlery/repositories/firebase/firebase_overwritten_version_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/repositories/interfaces/recipe_suggestion_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_suggestion_repository.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/realtime/realtime_recipe_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';
import 'package:butlery/repositories/firebase/firebase_menu_voting_repository.dart';
import 'package:butlery/services/menu_voting_service.dart';

/// Provides real-time collaborative services for recipes, menus, and shopping lists.
class CollaborationModule implements DIModule {
  @override
  String get name => 'Collaboration';

  @override
  List<Type> get dependencies => [CoreModule, ContentModule, SocialModule];

  @override
  List<Type> get provides => [
    RealtimeSyncService,
    // P5-U26b: overwritten versions kept 30 days behind "Återställ".
    OverwrittenVersionRepository,
    OverwrittenVersionService,
    // P5-U27b: suggestions to someone else's shared recipe, kept 7 days.
    RecipeSuggestionRepository,
    RecipeSuggestionService,
    RealtimeRecipeService,
    RealtimeMenuService,
    UnifiedShoppingService,
    MenuCollaborationRepository,
    ShoppingRepository,
    CategoryPreferencesRepository,
    MenuVotingRepository,
    MenuVotingService,
    // BUT-238: collaborative shopping presence
    FirebaseShoppingPresenceRepository,
    ShoppingPresenceModule,
    // BUT-408: live cooking session presence ("Erik lagar just nu")
    FirebaseCookingSessionRepository,
    CookingSessionModule,
  ];

  @override
  int get priority => 40; // After Core (1), Content (10), Social (20), Messaging (30)

  @override
  Future<void> configureUserScope(GetIt container) async {
    final app = GetIt.instance;

    // P5-U26b: the user's own overwritten versions (users/{uid}/
    // overwritten_versions), kept by RealtimeSyncService when a save loses.
    container.registerLazySingleton<OverwrittenVersionRepository>(
      () => FirebaseOverwrittenVersionRepository(
        authRepository: app<AuthRepository>(),
      ),
    );

    // P5-U27b: suggestions to someone else's shared recipe
    // (recipe_suggestions), stored by RealtimeSyncService when a non-owner's
    // edit meets the owner's.
    container.registerLazySingleton<RecipeSuggestionRepository>(
      () => FirebaseRecipeSuggestionRepository(
        authRepository: app<AuthRepository>(),
      ),
    );

    // The owner's own library recipe, read and written the way the owner's
    // own editor does it (RecipePersistenceManager.saveRecipe), so a write
    // goes through the offline queue where there is one. Resolved at call
    // time, so the content module's registration order does not matter.
    Future<Recipe?> readOwnRecipe(String id) async =>
        container.isRegistered<UnifiedRecipeService>()
        ? container<UnifiedRecipeService>().getRecipeById(id)
        : null;
    Future<void> writeOwnRecipe(Recipe recipe) async {
      final recipes = container<UnifiedRecipeService>();
      final result = await recipes.personal.updateUnifiedRecipe(recipe);
      if (!result.isSuccess) {
        throw StateError(result.message ?? 'recipe update failed');
      }
    }

    container.registerLazySingleton<RealtimeSyncService>(
      () => RealtimeSyncService(
        firestoreRepository: app<FirestoreRepository>(),
        authRepository: app<AuthRepository>(),
        overwrittenVersions: container<OverwrittenVersionRepository>(),
        suggestions: container<RecipeSuggestionRepository>(),
        // P6-U08b: conflict notices wait for the offline queue to empty
        // (produktregler.md:189).
        queueSettled: () => SyncQueueSource.resolve().watchSettled(),
        // BUT-2213: "Behåll min version" on a queued recipe edit.
        writeOwnRecipe: writeOwnRecipe,
      ),
    );

    // Q6-08 = A: a suggestion is taken into the owner's own library recipe.
    container.registerLazySingleton<RecipeSuggestionService>(
      () => RecipeSuggestionService(
        repository: container<RecipeSuggestionRepository>(),
        syncService: container<RealtimeSyncService>(),
        readOwnRecipe: readOwnRecipe,
        writeOwnRecipe: writeOwnRecipe,
        // The suggester's view of their own suggestion reads the owner's
        // recipe through the member's read path (recipe-shared-read-rules).
        readSharedRecipe: ({required ownerId, required recipeId}) async =>
            container.isRegistered<UnifiedRecipeService>()
            ? container<UnifiedRecipeService>().fetchFriendRecipe(
                ownerId: ownerId,
                recipeId: recipeId,
              )
            : null,
      ),
    );

    container.registerLazySingleton<OverwrittenVersionService>(
      () => OverwrittenVersionService(
        repository: container<OverwrittenVersionRepository>(),
        syncService: container<RealtimeSyncService>(),
        // BUT-2213: a kept recipe version comes back through the recipe.
        readOwnRecipe: readOwnRecipe,
        writeOwnRecipe: writeOwnRecipe,
      ),
    );

    container.registerLazySingleton<MenuVotingRepository>(
      () => FirebaseMenuVotingRepository(
        authRepository: app<AuthRepository>(),
      ),
    );

    container.registerLazySingleton<MenuVotingService>(
      () => MenuVotingService(),
    );

    container.registerLazySingleton<UnifiedShoppingService>(
      () => UnifiedShoppingService(
        firestoreRepository: app<FirestoreRepository>(),
        authRepository: app<AuthRepository>(),
        shoppingRepository: app<ShoppingRepository>(),
      ),
      dispose: (s) => s.resetForLogout(),
    );

    // BUT-238: shopping presence repository + module. Registered as the
    // interface type so tests / alt implementations can swap in cleanly.
    container.registerLazySingleton<FirebaseShoppingPresenceRepository>(
      () => FirebaseShoppingPresenceRepository(
        firestoreRepository: app<FirestoreRepository>(),
      ),
    );
    container.registerLazySingleton<ShoppingPresenceModule>(
      () => FirebaseShoppingPresenceModule(
        repository: container<FirebaseShoppingPresenceRepository>(),
      ),
      dispose: (m) => m.dispose(),
    );

    // BUT-408: cooking session presence repository + module. Registered as
    // the interface type so tests/alt implementations can swap in cleanly.
    // RTDB rather than Firestore — we need onDisconnect() for cleanup.
    container.registerLazySingleton<FirebaseCookingSessionRepository>(
      () => FirebaseCookingSessionRepository(
        database: FirebaseDatabase.instance,
      ),
    );
    container.registerLazySingleton<CookingSessionModule>(
      () => FirebaseCookingSessionModule(
        repository: container<FirebaseCookingSessionRepository>(),
      ),
      dispose: (m) => m.dispose(),
    );

    container.registerLazySingleton<RealtimeMenuService>(
      () => RealtimeMenuService(
        syncService: container<RealtimeSyncService>(),
        authService: app<AuthService>(),
      ),
    );

    container.registerLazySingleton<RealtimeRecipeService>(
      () => RealtimeRecipeService(
        syncService: container<RealtimeSyncService>(),
        permissionService: app<PermissionService>(),
      ),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      container.registerLazySingleton<MenuCollaborationRepository>(
        () => FirebaseMenuCollaborationRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<ShoppingRepository>(
        () => FirebaseShoppingRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      container.registerLazySingleton<CategoryPreferencesRepository>(
        () => FirebaseCategoryPreferencesRepository(
          authRepository: container<AuthRepository>(),
        ),
      );
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

      // RealtimeSyncService, UnifiedShoppingService, RealtimeMenuService,
      // RealtimeRecipeService are user-scoped — initialized on login, not here

      // Validate app-scoped services
      container<PermissionService>();
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

      // App-scoped services (always available)
      final services = <String, dynamic>{
        'PermissionService': container<PermissionService>(),
      };

      // User-scoped services (only after login)
      if (container.isRegistered<RealtimeSyncService>()) {
        services['RealtimeSyncService'] = container<RealtimeSyncService>();
      }
      if (container.isRegistered<UnifiedShoppingService>()) {
        services['UnifiedShoppingService'] =
            container<UnifiedShoppingService>();
      }
      if (container.isRegistered<RealtimeMenuService>()) {
        services['RealtimeMenuService'] = container<RealtimeMenuService>();
      }
      if (container.isRegistered<RealtimeRecipeService>()) {
        services['RealtimeRecipeService'] = container<RealtimeRecipeService>();
      }

      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            return false;
          }
        }

        if (service == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
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
