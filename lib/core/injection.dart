// lib/core/injection.dart

/// Dependency injection konfiguration för Butlery - RENSAD VERSION
library;

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== CORE SERVICES ====================
import '../services/recipe_service.dart';
import '../services/menu_service.dart';
import '../services/search_service.dart';
import '../services/persistence_service.dart';
import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';
import '../services/offline_service.dart';
import '../services/analytics_service.dart';
// ==================== REALTIME SERVICES ====================
import '../services/realtime/event_bus_service.dart';
import '../services/realtime/content_sharing_service.dart';
import '../services/realtime/realtime_event_handler.dart';

// ==================== UNIFIED SHOPPING SYSTEM ====================
import '../services/unified/unified_shopping_service.dart';

// ==================== SOCIAL SERVICES ====================
import '../services/user_service.dart';
import '../services/friends_service.dart';
import '../services/social_recipe_service.dart';
import '../services/friend_categories_service.dart';
import '../services/group_invitation_service.dart';

// ==================== CORE VIEWMODELS ====================
import '../viewmodels/recipe_list_viewmodel.dart';
import '../viewmodels/menu_viewmodel.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../viewmodels/text_import_viewmodel.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../viewmodels/url_import_viewmodel.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';

// ==================== UNIFIED SHOPPING VIEWMODELS ====================
import '../viewmodels/unified_shopping_viewmodel.dart';
import '../viewmodels/shopping_share_viewmodel.dart';

// ==================== REALTIME VIEWMODELS ====================
import '../viewmodels/realtime/recipe_realtime_viewmodel.dart';
import '../viewmodels/realtime/menu_realtime_viewmodel.dart';
import '../viewmodels/realtime/shopping_realtime_viewmodel.dart';

// ==================== SOCIAL VIEWMODELS ====================
import '../viewmodels/user_profile_viewmodel.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../viewmodels/shared_content_viewmodel.dart';
import '../viewmodels/create_shared_list_viewmodel.dart';
import '../viewmodels/add_members_to_group_viewmodel.dart';
import '../viewmodels/group_invitations_viewmodel.dart';
import '../viewmodels/create_group_viewmodel.dart';
import '../viewmodels/recipe_selection_viewmodel.dart';
import '../viewmodels/collaborative_shopping_viewmodel.dart';

// Models
import '../models/recipe.dart';
import '../models/user_profile.dart';

/// Service Locator instance
final GetIt sl = GetIt.instance;

/// Initialiserar alla dependencies
Future<void> initializeDependencies() async {
  debugPrint('🔄 Initialiserar dependency injection för Butlery...');

  try {
    // ==================== SHARED PREFERENCES (FÖRST AV ALLT!) ====================
    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(sharedPreferences);
    debugPrint('✅ SharedPreferences registrerad');

    // ==================== CORE SERVICES ====================
    sl.registerSingleton<AuthService>(AuthService());
    debugPrint('✅ AuthService registrerad');

    sl.registerSingleton<PersistenceService>(PersistenceService());
    debugPrint('✅ PersistenceService registrerad');

    // ==================== SOCIAL SERVICES (KORREKT ORDNING!) ====================
    sl.registerSingleton<UserService>(UserService());
    debugPrint('✅ UserService registrerad');

    sl.registerSingleton<FriendsService>(FriendsService());
    debugPrint('✅ FriendsService registrerad');

    sl.registerLazySingleton<FriendCategoriesService>(
      () => FriendCategoriesService(friendsService: sl<FriendsService>()),
    );
    debugPrint('✅ FriendCategoriesService registrerad');

    sl.registerLazySingleton<GroupInvitationService>(
      () => GroupInvitationService(
          categoriesService: sl<FriendCategoriesService>()),
    );
    debugPrint('✅ GroupInvitationService registrerad');

    // ==================== EXISTING SERVICES ====================
    sl.registerSingleton<RecipeService>(RecipeService());
    debugPrint('✅ RecipeService registrerad');

    sl.registerSingleton<MenuService>(MenuService());
    sl.registerSingleton<SearchService>(SearchService());
    sl.registerSingleton<ShareService>(ShareService());
    sl.registerSingleton<StorageService>(StorageService());
    sl.registerSingleton<ImagePickerService>(ImagePickerService());
    sl.registerSingleton<OfflineService>(OfflineService());
    sl.registerSingleton<AnalyticsService>(AnalyticsService());
    // Realtime event infrastructure
    sl.registerLazySingleton<EventBusService>(() => EventBusService());
    sl.registerLazySingleton<ContentSharingService>(
        () => ContentSharingService(eventBus: sl<EventBusService>()));
    sl.registerLazySingleton<RealtimeEventHandler>(
        () => RealtimeEventHandler(
              eventBus: sl<EventBusService>(),
              sharingService: sl<ContentSharingService>(),
            ));
    debugPrint('✅ Alla core services registrerade');

    // ==================== UNIFIED SHOPPING SYSTEM ====================
    sl.registerLazySingleton<UnifiedShoppingService>(
      () => UnifiedShoppingService(),
    );
    debugPrint('✅ UnifiedShoppingService registrerad');

    // ==================== SOCIAL SERVICES (EFTER ANDRA SERVICES) ====================
    sl.registerSingleton<SocialRecipeService>(
      SocialRecipeService(
        userService: sl<UserService>(),
        recipeService: sl<RecipeService>(),
      ),
    );
    debugPrint('✅ SocialRecipeService registrerad');

    // ==================== CORE VIEWMODELS ====================

    sl.registerFactory<RecipeListViewModel>(
      () => RecipeListViewModel(
        recipeService: sl<RecipeService>(),
        searchService: sl<SearchService>(),
      ),
    );

    sl.registerFactory<MenuViewModel>(
      () => MenuViewModel(
        recipeService: sl<RecipeService>(),
        menuService: sl<MenuService>(),
        socialService: sl<SocialRecipeService>(),
        userService: sl<UserService>(),
      ),
    );

    sl.registerFactory<RecipeFormViewModel>(
      () => RecipeFormViewModel(
        recipeService: sl<RecipeService>(),
        analyticsService: sl<AnalyticsService>(),
        storageService: sl<StorageService>(),
        imagePickerService: sl<ImagePickerService>(),
        authService: sl<AuthService>(),
      ),
    );

    // Import ViewModels
    sl.registerFactory<TextImportViewModel>(() => TextImportViewModel());
    sl.registerFactory<PhotoImportViewModel>(() => PhotoImportViewModel());
    sl.registerFactory<UrlImportViewModel>(() => UrlImportViewModel());
    sl.registerFactory<AuthViewModel>(() => AuthViewModel());

    sl.registerFactory<ArchiveImportViewModel>(
      () => ArchiveImportViewModel(
        recipeService: sl<RecipeService>(),
        searchService: sl<SearchService>(),
      ),
    );

    sl.registerFactoryParam<RecipeDetailViewModel, Recipe, void>(
      (recipe, _) => RecipeDetailViewModel(
        recipe: recipe,
        recipeService: sl<RecipeService>(),
        analyticsService: sl<AnalyticsService>(),
      ),
    );

    debugPrint('✅ Alla befintliga ViewModels registrerade');

    // ==================== UNIFIED SHOPPING VIEWMODELS ====================
    sl.registerFactory<UnifiedShoppingViewModel>(
      () => UnifiedShoppingViewModel(),
    );
    debugPrint('✅ UnifiedShoppingViewModel registrerad');

    sl.registerFactory<ShoppingShareViewModel>(
      () => ShoppingShareViewModel(
        socialRecipeService: sl<SocialRecipeService>(),
        friendsService: sl<FriendsService>(),
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

    // ==================== REALTIME VIEWMODELS ====================
    sl.registerFactory<RecipeRealtimeViewModel>(
      () => RecipeRealtimeViewModel(
        recipeService: sl<RecipeService>(),
      ),
    );

    sl.registerFactory<MenuRealtimeViewModel>(
      () => MenuRealtimeViewModel(
        recipeService: sl<RecipeService>(),
        menuService: sl<MenuService>(),
      ),
    );

    sl.registerFactory<ShoppingRealtimeViewModel>(
      () => ShoppingRealtimeViewModel(
        shoppingService: sl<UnifiedShoppingService>(),
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
        friendsService: sl<FriendsService>(),
        userService: sl<UserService>(),
        categoriesService: sl<FriendCategoriesService>(),
      ),
    );

    sl.registerFactoryParam<SocialRecipeViewModel, Recipe, void>(
      (recipe, _) => SocialRecipeViewModel(
        recipe: recipe,
        socialRecipeService: sl<SocialRecipeService>(),
        friendsService: sl<FriendsService>(),
        userService: sl<UserService>(),
      ),
    );

    sl.registerFactoryParam<RecipeSelectionViewModel, UserProfile, void>(
      (targetFriend, _) => RecipeSelectionViewModel(
        recipeService: sl<RecipeService>(),
        socialRecipeService: sl<SocialRecipeService>(),
        targetFriend: targetFriend,
      ),
    );

    sl.registerFactory<CreateGroupViewModel>(
      () => CreateGroupViewModel(
        categoriesService: sl<FriendCategoriesService>(),
        groupInvitationService: sl<GroupInvitationService>(),
      ),
    );

    sl.registerFactory<SharedContentViewModel>(
      () => SharedContentViewModel(
        socialRecipeService: sl<SocialRecipeService>(),
        userService: sl<UserService>(),
        friendsService: sl<FriendsService>(),
      ),
    );

    sl.registerFactory<CreateSharedListViewModel>(
      () => CreateSharedListViewModel(),
    );

    sl.registerFactoryParam<AddMembersToGroupViewModel, String, void>(
      (groupId, _) => AddMembersToGroupViewModel(
        groupId: groupId,
        friendsService: sl<FriendsService>(),
        categoriesService: sl<FriendCategoriesService>(),
        groupInvitationService: sl<GroupInvitationService>(),
      ),
    );

    sl.registerFactory<GroupInvitationsViewModel>(
      () => GroupInvitationsViewModel(
        categoriesService: sl<FriendCategoriesService>(),
        friendsService: sl<FriendsService>(),
        authService: sl<AuthService>(),
        groupInvitationService: sl<GroupInvitationService>(),
      ),
    );

    debugPrint('✅ Alla social ViewModels registrerade');

    // ==================== INITIALIZATION SEQUENCE ====================

    debugPrint('🔄 Initialiserar core services...');

    await sl<RecipeService>().initialize();
    debugPrint('✅ RecipeService initierad');

    await sl<OfflineService>().initialize();
    debugPrint('✅ OfflineService initierad');

    debugPrint('🔄 Initialiserar social services...');

    await sl<UserService>().initialize();
    debugPrint('✅ UserService initierad');

    await sl<FriendsService>().initialize();
    debugPrint('✅ FriendsService initierad');

    await sl<FriendCategoriesService>().initialize();
    debugPrint('✅ FriendCategoriesService initierad');

    await sl<GroupInvitationService>().initialize();
    debugPrint('✅ GroupInvitationService initierad');

    await sl<SocialRecipeService>().initialize();
    debugPrint('✅ SocialRecipeService initierad');

    // ==================== UNIFIED SHOPPING INITIALIZATION ====================

    debugPrint('🔄 Initialiserar unified shopping system...');

    await sl<UnifiedShoppingService>().initialize();
    debugPrint('✅ UnifiedShoppingService initierad');

    // ==================== VALIDATION ====================

    // Validera att alla kritiska services är registrerade
    sl<AuthService>();
    sl<RecipeService>();
    sl<UserService>();
    sl<FriendsService>();
    sl<SocialRecipeService>();
    sl<FriendCategoriesService>();
    sl<GroupInvitationService>();

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
    debugPrint('🚀 Dependency injection komplett - Butlery redo! 🛒✨');
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

/// Debug-funktion för att visa alla registrerade services
void debugPrintRegisteredServices() {
  debugPrint('📋 Registrerade Services:');
  debugPrint('  Core: AuthService, RecipeService, UserService');
  debugPrint('  Social: FriendsService, SocialRecipeService');
  debugPrint('  ✅ Shopping: UnifiedShoppingService (ENDAST UNIFIED)');
  debugPrint('  Invitations: GroupInvitationService');
  debugPrint('  ViewModels: Alla ViewModels inklusive unified shopping');
}
