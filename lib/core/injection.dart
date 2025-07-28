// lib/core/injection.dart

/// Dependency injection konfiguration för Butlery - UPPDATERAD MED REALTIME SYNC
library;

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

// ==================== CORE SERVICES ====================
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/permission_service.dart';

import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_ratings_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import 'package:butlery/repositories/firebase/firebase_connectivity_repository.dart';
import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';

// ==================== REALTIME SERVICES (FAS 2 + 3) ====================
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/realtime/realtime_recipe_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';

// ==================== INVITATION SERVICES (FAS 2) ====================
// import '../services/invitations/group_invitation_expander.dart'; // Removed - no longer needed

// ==================== UNIFIED SYSTEMS ====================
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/import/import_manager.dart';

// ==================== SOCIAL SERVICES ====================
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/deep_link_service.dart';

// ==================== CORE VIEWMODELS ====================
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/unified_recipe_viewmodel.dart';

// ==================== UNIFIED SHOPPING VIEWMODELS ====================
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/shopping_share_viewmodel.dart';

// ==================== SOCIAL VIEWMODELS ====================
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/viewmodels/group_invitations_viewmodel.dart';
import 'package:butlery/viewmodels/create_group_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';

/// Service Locator instance
final GetIt sl = GetIt.instance;

/// Initialiserar alla dependencies
Future<void> initializeDependencies() async {
  if (kDebugMode) {
    debugPrint('🔄 Initialiserar dependency injection för Butlery...');
  }

  try {
    // ==================== SHARED PREFERENCES (FÖRST AV ALLT!) ====================
    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(sharedPreferences);
    if (kDebugMode) {
      debugPrint('✅ SharedPreferences registrerad');
    }

    // ==================== REPOSITORIES ====================
    sl.registerSingleton<AuthRepository>(FirebaseAuthRepository());
    sl.registerSingleton<RecipeRepository>(
      FirebaseRecipeRepository(authRepository: sl<AuthRepository>()),
    );
    if (kDebugMode) {
      debugPrint('✅ Repositories registrerade');
    }

    // ==================== CORE SERVICES ====================

    sl.registerSingleton<AuthService>(
      AuthService(authRepository: sl<AuthRepository>()),
    );
    if (kDebugMode) {
      debugPrint('✅ AuthService registrerad');
    }

    sl.registerSingleton<PersistenceService>(PersistenceService());
    if (kDebugMode) {
      debugPrint('✅ PersistenceService registrerad');
    }


    // ==================== REPOSITORIES ====================
    sl.registerSingleton<FirestoreRepository>(FirestoreRepository());
    if (kDebugMode) {
      debugPrint('✅ FirestoreRepository registrerad');
    }

    // TODO: Remove direct FirebaseFirestore registration - services should use repositories
    // sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);

    // ==================== REALTIME SERVICES (FAS 2 + 3) ====================
    sl.registerSingleton<RealtimeSyncService>(
      RealtimeSyncService(
        firestoreRepository: sl<FirestoreRepository>(),
        authRepository: sl<AuthRepository>(),
      ),
    );
    if (kDebugMode) {
      debugPrint('✅ RealtimeSyncService registrerad');
    }

    sl.registerLazySingleton<RealtimeMenuService>(
      () => RealtimeMenuService(
        syncService: sl<RealtimeSyncService>(),
        authService: sl<AuthService>(),
      ),
    );
    if (kDebugMode) {
      debugPrint('✅ RealtimeMenuService registrerad');
    }

    sl.registerLazySingleton<RealtimeRecipeService>(
      () => RealtimeRecipeService(
        syncService: sl<RealtimeSyncService>(),
        permissionService: sl<PermissionService>(),
      ),
    );
    if (kDebugMode) {
      debugPrint('✅ RealtimeRecipeService registrerad');
    }

    // ==================== SOCIAL SERVICES (KORREKT ORDNING!) ====================
    sl.registerSingleton<UserRepository>(
        FirebaseUserRepository(authRepository: sl<AuthRepository>()));
    sl.registerSingleton<UserService>(
      UserService(
        repository: sl<UserRepository>(),
        authRepository: sl<AuthRepository>(),
      ),
    );

    if (kDebugMode) {
      debugPrint('✅ UserService registrerad');
    }

    sl.registerSingleton<FriendsRepository>(
        FirebaseFriendsRepository(authRepository: sl<AuthRepository>()));
    if (kDebugMode) {
      debugPrint('✅ FriendsRepository registrerad');
    }

    // ==================== ADDITIONAL REPOSITORIES (EARLY REGISTRATION) ====================
    sl.registerSingleton<CommentsRepository>(
        FirebaseCommentsRepository(authRepository: sl<AuthRepository>()));
    
    sl.registerSingleton<RatingsRepository>(
        FirebaseRatingsRepository(authRepository: sl<AuthRepository>()));
    
    sl.registerSingleton<NotificationsRepository>(
        FirebaseNotificationsRepository(authRepository: sl<AuthRepository>()));
    
    sl.registerSingleton<SocialRecipeRepository>(
        FirebaseSocialRecipeRepository(authRepository: sl<AuthRepository>()));
    
    // New repositories for fixing direct Firebase access
    sl.registerSingleton<DeepLinkRepository>(
        FirebaseDeepLinkRepository(authRepository: sl<AuthRepository>()));
    
    sl.registerSingleton<ConnectivityRepository>(
        FirebaseConnectivityRepository(authRepository: sl<AuthRepository>()));
    
    sl.registerSingleton<SocialSharingRepository>(
        FirebaseSocialSharingRepository(authRepository: sl<AuthRepository>()));
    
    if (kDebugMode) {
      debugPrint('✅ Additional repositories registrerade');
    }

    // ==================== CONNECTIVITY SERVICE ====================
    sl.registerSingleton<ConnectivityMonitoringService>(
        ConnectivityMonitoringService(
            connectivityRepository: sl<ConnectivityRepository>()));
    if (kDebugMode) {
      debugPrint('✅ ConnectivityMonitoringService registrerad');
    }

    // ==================== INVITATION SERVICES (FAS 2) ====================

    // ==================== EXISTING SERVICES ====================

    // ==================== UNIFIED RECIPE SYSTEM (PHASE 5) ====================
    sl.registerSingleton<UnifiedRecipeService>(UnifiedRecipeService(
      // TODO: Migrate to use RecipeRepository instead of direct Firestore
      authRepository: sl<AuthRepository>() as FirebaseAuthRepository,
    ));
    if (kDebugMode) {
      debugPrint('✅ UnifiedRecipeService registrerad');
    }

    sl.registerLazySingleton<ImportManager>(
      () => ImportManager(sl<UnifiedRecipeService>().personal),
    );
    if (kDebugMode) {
      debugPrint('✅ ImportManager registrerad');
    }

    // ==================== UNIFIED FRIENDS SYSTEM (PHASE 5) ====================
    sl.registerSingleton<UnifiedFriendsService>(UnifiedFriendsService(
      firestoreRepository: sl<FirestoreRepository>(),
      authRepository: sl<AuthRepository>(),
    ));
    if (kDebugMode) {
      debugPrint('✅ UnifiedFriendsService registrerad');
    }

    sl.registerLazySingleton<SocialMenuOperations>(
      () => SocialMenuOperations(
        // TODO: Migrate to use MenuRepository instead of direct Firestore
        firestore: FirebaseFirestore.instance,
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );
    if (kDebugMode) {
      debugPrint('✅ SocialMenuOperations registrerad');
    }

    // ==================== UNIFIED SHOPPING SYSTEM ====================
    sl.registerLazySingleton<UnifiedShoppingService>(
      () => UnifiedShoppingService(
        firestoreRepository: sl<FirestoreRepository>(),
        authRepository: sl<AuthRepository>(),
      ),
    );
    if (kDebugMode) {
      debugPrint('✅ UnifiedShoppingService registrerad');
    }

    // ==================== PERMISSION SERVICE ====================
    sl.registerSingleton<PermissionService>(PermissionService(
      sl<AuthService>(),
      sl<UserService>(),
      sl<UnifiedRecipeService>(),
      sl<UnifiedShoppingService>(),
      sl<UnifiedFriendsService>(),
    ));
    if (kDebugMode) {
      debugPrint('✅ PermissionService registrerad');
    }

    sl.registerSingleton<MenuService>(MenuService());
    sl.registerSingleton<SearchService>(SearchService());
    sl.registerSingleton<ShareService>(ShareService());
    sl.registerSingleton<StorageService>(StorageService());
    sl.registerSingleton<ImagePickerService>(ImagePickerService());
    sl.registerSingleton<OfflineService>(
      OfflineService(
        firestoreRepository: sl<FirestoreRepository>(),
        authRepository: sl<AuthRepository>(),
      ),
    );
    sl.registerSingleton<CollaborativeRecipeRepository>(
      CollaborativeRecipeRepository(),
    );
    sl.registerSingleton<AnalyticsService>(AnalyticsService());
    if (kDebugMode) {
      debugPrint('✅ Alla core services registrerade');
    }

    // ==================== SOCIAL SERVICES (EFTER ANDRA SERVICES) ====================
    // Repositories already registered earlier

    sl.registerSingleton<SocialRecipeService>(SocialRecipeService(
      repository: sl<SocialRecipeRepository>(),
      userService: sl<UserService>(),
      recipeService: sl<UnifiedRecipeService>(),
      permissionService: sl<PermissionService>(),
    ));
    
    // DeepLinkService - uses repository instead of direct Firebase access
    sl.registerSingleton<DeepLinkService>(DeepLinkService(
      deepLinkRepository: sl<DeepLinkRepository>(),
    ));

    // ==================== CORE VIEWMODELS ====================

    sl.registerFactory<RecipeListViewModel>(
      () => RecipeListViewModel(
        recipeService: sl<UnifiedRecipeService>(),
        searchService: sl<SearchService>(),
      ),
    );

    sl.registerFactory<MenuViewModel>(
      () => MenuViewModel(
        recipeService: sl<UnifiedRecipeService>(),
        menuService: sl<MenuService>(),
      ),
    );

    sl.registerFactory<RecipeFormViewModel>(
      () => RecipeFormViewModel(
        recipeService: sl<UnifiedRecipeService>(),
        analyticsService: sl<AnalyticsService>(),
      ),
    );

    // Import ViewModels
    sl.registerFactory<TextImportViewModel>(
      () => TextImportViewModel(importManager: sl<ImportManager>()),
    );
    sl.registerFactory<PhotoImportViewModel>(
      () => PhotoImportViewModel(importManager: sl<ImportManager>()),
    );
    sl.registerFactory<UrlImportViewModel>(
      () => UrlImportViewModel(importManager: sl<ImportManager>()),
    );
    sl.registerFactory<AuthViewModel>(() => AuthViewModel());

    sl.registerFactory<ArchiveImportViewModel>(
      () => ArchiveImportViewModel(
        recipeService: sl<UnifiedRecipeService>(),
        searchService: sl<SearchService>(),
      ),
    );

    sl.registerFactoryParam<RecipeDetailViewModel, Recipe, void>(
      (recipe, _) => RecipeDetailViewModel(
        recipe: recipe,
        recipeService: sl<UnifiedRecipeService>(),
        analyticsService: sl<AnalyticsService>(),
      ),
    );

    // ==================== UNIFIED RECIPE VIEWMODELS (PHASE 5) ====================
    sl.registerFactory<UnifiedRecipeViewModel>(
      () => UnifiedRecipeViewModel(),
    );
    debugPrint('✅ UnifiedRecipeViewModel registrerad');

    debugPrint('✅ Alla befintliga ViewModels registrerade');

    // ==================== UNIFIED SHOPPING VIEWMODELS ====================
    sl.registerFactory<UnifiedShoppingViewModel>(
      () => UnifiedShoppingViewModel(),
    );
    debugPrint('✅ UnifiedShoppingViewModel registrerad');

    sl.registerFactory<ShoppingShareViewModel>(
      () => ShoppingShareViewModel(
        shoppingService: sl<UnifiedShoppingService>(),
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );
    debugPrint('✅ ShoppingShareViewModel registrerad');

    sl.registerFactoryParam<CollaborativeShoppingViewModel, String, void>(
      (listId, _) => CollaborativeShoppingViewModel(
        listId: listId,
        shoppingService: sl<UnifiedShoppingService>(),
        userService: sl<UserService>(),
      ),
    );

    // ==================== SOCIAL VIEWMODELS ====================

    sl.registerFactory<UserProfileViewModel>(
      () => UserProfileViewModel(
        sl<UserService>(),
        sl<StorageService>(),
        sl<ImagePickerService>(),
      ),
    );

    sl.registerLazySingleton<FriendsViewModel>(
      () => FriendsViewModel(
        friendsService: sl<UnifiedFriendsService>(),
        userService: sl<UserService>(),
      ),
    );

    sl.registerFactoryParam<SocialRecipeViewModel, Recipe, void>(
      (recipe, _) => SocialRecipeViewModel(
        recipe: recipe,
        recipeService: sl<UnifiedRecipeService>(),
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );

    sl.registerFactoryParam<RecipeSelectionViewModel, UserProfile, void>(
      (targetFriend, _) => RecipeSelectionViewModel(
        recipeService: sl<UnifiedRecipeService>(),
        targetFriend: targetFriend,
      ),
    );

    sl.registerFactory<CreateGroupViewModel>(
      () => CreateGroupViewModel(
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );

    sl.registerFactory<SharedContentViewModel>(
      () => SharedContentViewModel(
        socialRecipeService: sl<SocialRecipeService>(),
        friendsService: sl<UnifiedFriendsService>(),
        shoppingService: sl<UnifiedShoppingService>(),
      ),
    );

    sl.registerFactory<CreateSharedListViewModel>(
      () => CreateSharedListViewModel(),
    );

    sl.registerFactoryParam<AddMembersToGroupViewModel, String, void>(
      (groupId, _) => AddMembersToGroupViewModel(
        groupId: groupId,
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );

    sl.registerFactory<GroupInvitationsViewModel>(
      () => GroupInvitationsViewModel(
        friendsService: sl<UnifiedFriendsService>(),
      ),
    );

    sl.registerFactory<CollaborativeStatusViewModel>(
      () => CollaborativeStatusViewModel(),
    );

    sl.registerFactory<UniversalShareDialogViewModel>(
      () => UniversalShareDialogViewModel(
        socialRecipeService: sl<SocialRecipeService>(),
        shoppingService: sl<UnifiedShoppingService>(),
      ),
    );

    debugPrint('✅ Alla social ViewModels registrerade');

    // ==================== INITIALIZATION SEQUENCE ====================

    debugPrint('🔄 Initialiserar core services...');

    // Initialize OfflineService first (Hive dependency)
    await sl<OfflineService>().initialize();
    debugPrint('✅ OfflineService initierad');

    await sl<UnifiedRecipeService>().initialize();
    debugPrint('✅ UnifiedRecipeService initierad');

    // ==================== REALTIME SYNC INITIALIZATION (FAS 2) ====================
    debugPrint('🔄 Initialiserar RealtimeSyncService...');
    await sl<RealtimeSyncService>().initialize();
    debugPrint('✅ RealtimeSyncService initierad');

    debugPrint('🔄 Initialiserar social services...');

    await sl<UserService>().initialize();
    debugPrint('✅ UserService initierad');

    await sl<UnifiedFriendsService>().initialize();
    debugPrint('✅ UnifiedFriendsService initierad');

    await sl<SocialRecipeService>().initialize();
    debugPrint('✅ SocialRecipeService initierad');

    // ==================== UNIFIED SHOPPING INITIALIZATION ====================

    debugPrint('🔄 Initialiserar unified shopping system...');

    await sl<UnifiedShoppingService>().initialize();
    debugPrint('✅ UnifiedShoppingService initierad');

    // ==================== VALIDATION ====================

    // Validera att alla kritiska services är registrerade
    sl<AuthService>();
    sl<UnifiedRecipeService>();
    sl<RealtimeSyncService>(); // ✅ NYTT: Validera RealtimeSyncService
    sl<RealtimeRecipeService>(); // ✅ NYTT: Validera RealtimeRecipeService
    sl<RealtimeMenuService>(); // ✅ NYTT: Validera RealtimeMenuService
    sl<UserService>();
    sl<UnifiedFriendsService>();
    debugPrint('🔄 About to validate PermissionService...');
    try {
      sl<PermissionService>(); // ✅ VALIDERA: PermissionService
      debugPrint('✅ PermissionService validation successful');
    } catch (e) {
      debugPrint('❌ PermissionService validation failed: $e');
      rethrow;
    }
    sl<SocialRecipeService>();

    // Test ViewModels
    sl<RecipeListViewModel>();
    sl<FriendsViewModel>();
    sl<SharedContentViewModel>();
    sl<MenuViewModel>();
    sl<CreateSharedListViewModel>();
    sl<GroupInvitationsViewModel>();

    // Unified shopping system
    sl<UnifiedShoppingService>();
    sl<UnifiedShoppingViewModel>();

    debugPrint('✅ Alla kritiska services validerade');
    debugPrint(
        '🚀 Dependency injection komplett - Butlery med RealtimeSync redo! 🔄✨');
  } catch (e) {
    debugPrint('❌ Fel vid init av DI: $e');
    throw Exception('Kritiska services saknas: $e');
  }
}

// ==================== HELPER FUNCTIONS ====================

/// Hjälpfunktion för AddMembersToGroupViewModel med groupId
AddMembersToGroupViewModel getAddMembersToGroupViewModel(String groupId) {
  return sl<AddMembersToGroupViewModel>(param1: groupId);
}

/// Hjälpfunktion för att kontrollera unified shopping system
bool isUnifiedShoppingReady() {
  try {
    sl<UnifiedShoppingService>();
    sl<UnifiedShoppingViewModel>();
    return true;
  } catch (e) {
    debugPrint('⚠️ Unified shopping system inte redo: $e');
    return false;
  }
}

/// ✅ NYTT: Helper för att kontrollera RealtimeSyncService
bool isRealtimeSyncReady() {
  try {
    sl<RealtimeSyncService>();
    return true;
  } catch (e) {
    debugPrint('⚠️ RealtimeSyncService inte redo: $e');
    return false;
  }
}

/// Debug-funktion för att visa alla registrerade services
void debugPrintRegisteredServices() {
  debugPrint('📋 Registrerade Services:');
  debugPrint('  Core: AuthRepository, AuthService, RecipeService, UserService');
  debugPrint('  Social: UnifiedFriendsService, UnifiedRecipeService.social');
  debugPrint(
      '  ✅ Realtime: RealtimeSyncService, RealtimeRecipeService, RealtimeMenuService (FAS 2+3)');
  debugPrint('  ✅ Invitations: GroupInvitationExpander (FAS 2)');
  debugPrint('  ✅ Shopping: UnifiedShoppingService (ENDAST UNIFIED)');
  debugPrint('  Existing: GroupInvitationService');
  debugPrint('  ViewModels: Alla ViewModels inklusive unified shopping');
}
