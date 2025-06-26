// lib/core/injection.dart
// ✅ KOMPLETT FIXAD VERSION - Nu med GroupInvitationService

/// Dependency injection konfiguration för Butlery med Social Shopping Platform
library;

import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';

// ==================== BEFINTLIGA IMPORTS ====================
import '../services/recipe_service.dart';
import '../services/menu_service.dart';
import '../services/search_service.dart';
import '../services/shopping_list_service.dart';
import '../services/persistence_service.dart';
import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';
import '../services/offline_service.dart';
import '../services/analytics_service.dart';

// ==================== SOCIAL SERVICES ====================
import '../services/user_service.dart';
import '../services/friends_service.dart';
import '../services/social_recipe_service.dart';
import '../services/friend_categories_service.dart';
import '../services/social_shopping_service.dart';
import '../services/group_invitation_service.dart'; // ✅ NYTT: GroupInvitationService import

// ==================== BEFINTLIGA VIEWMODELS ====================
import '../viewmodels/recipe_list_viewmodel.dart';
import '../viewmodels/menu_viewmodel.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../viewmodels/text_import_viewmodel.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../viewmodels/url_import_viewmodel.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';

// ==================== SOCIAL VIEWMODELS ====================
import '../viewmodels/user_profile_viewmodel.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../viewmodels/shared_content_viewmodel.dart';
import '../viewmodels/collaborative_shopping_viewmodel.dart';
import '../viewmodels/create_shared_list_viewmodel.dart';
import '../viewmodels/add_members_to_group_viewmodel.dart';
import '../viewmodels/group_invitations_viewmodel.dart';
import '../viewmodels/create_group_viewmodel.dart';

// Models
import '../models/recipe.dart';

/// Service Locator instance
final GetIt sl = GetIt.instance;

/// Initialiserar alla dependencies - KOMPLETT SOCIAL SHOPPING
Future<void> initializeDependencies() async {
  debugPrint('🔄 Initialiserar dependency injection för Social Shopping...');

  // ==================== CORE SERVICES (FÖRST) ====================

  // AuthService - REGISTRERAS FÖRST (behövs för användarspecifik data)
  sl.registerSingleton<AuthService>(AuthService());
  debugPrint('✅ AuthService registrerad');

  // PersistenceService - för lokal datalagring
  sl.registerSingleton<PersistenceService>(PersistenceService());
  debugPrint('✅ PersistenceService registrerad');

  // ==================== SOCIAL SERVICES (KORREKT ORDNING!) ====================

  // UserService - Hanterar användarprofilsn (måste komma före FriendsService)
  sl.registerSingleton<UserService>(UserService());
  debugPrint('✅ UserService registrerad');

  // FriendsService - Hanterar vänskaper (ingen dependency injection behövs)
  sl.registerSingleton<FriendsService>(FriendsService());
  debugPrint('✅ FriendsService registrerad');

  // ✅ FIXAT: FriendCategoriesService - Behöver FriendsService
  sl.registerLazySingleton<FriendCategoriesService>(
    () => FriendCategoriesService(friendsService: sl<FriendsService>()),
  );
  debugPrint('✅ FriendCategoriesService registrerad');

  // ✅ NYTT: GroupInvitationService - Behöver FriendCategoriesService
  sl.registerLazySingleton<GroupInvitationService>(
    () => GroupInvitationService(
        categoriesService: sl<FriendCategoriesService>()),
  );
  debugPrint('✅ GroupInvitationService registrerad');

  // ==================== EXISTING SERVICES ====================

  // RecipeService - FIRESTORE VERSION!
  sl.registerSingleton<RecipeService>(RecipeService());
  debugPrint('✅ RecipeService registrerad');

  // Andra befintliga services
  sl.registerSingleton<MenuService>(MenuService());
  sl.registerSingleton<SearchService>(SearchService());
  sl.registerSingleton<ShoppingListService>(ShoppingListService());
  sl.registerSingleton<ShareService>(ShareService());
  sl.registerSingleton<StorageService>(StorageService());
  sl.registerSingleton<ImagePickerService>(ImagePickerService());
  sl.registerSingleton<OfflineService>(OfflineService());
  sl.registerSingleton<AnalyticsService>(AnalyticsService());
  debugPrint('✅ Alla core services registrerade');

  // ==================== SOCIAL SERVICES (EFTER ANDRA SERVICES) ====================

  // SocialRecipeService - Behöver UserService och RecipeService
  sl.registerSingleton<SocialRecipeService>(
    SocialRecipeService(
      userService: sl<UserService>(),
      recipeService: sl<RecipeService>(),
    ),
  );
  debugPrint('✅ SocialRecipeService registrerad');

  // SocialShoppingService - Behöver flera dependencies
  sl.registerSingleton<SocialShoppingService>(
    SocialShoppingService(
      userService: sl<UserService>(),
      categoriesService: sl<FriendCategoriesService>(),
      basicShoppingService: sl<ShoppingListService>(),
    ),
  );
  debugPrint('✅ SocialShoppingService registrerad');

  // ==================== BEFINTLIGA VIEWMODELS ====================

  // ✅ FIXAT: RecipeListViewModel - Factory (ny instans för varje view)
  sl.registerFactory<RecipeListViewModel>(
    () => RecipeListViewModel(
      recipeService: sl<RecipeService>(),
      searchService: sl<SearchService>(),
    ),
  );

  // MenuViewModel med alla nya dependencies inklusive social shopping
  sl.registerFactory<MenuViewModel>(
    () => MenuViewModel(
      recipeService: sl<RecipeService>(),
      menuService: sl<MenuService>(),
      socialService: sl<SocialRecipeService>(),
      userService: sl<UserService>(),
    ),
  );

  // ShoppingListViewModel - behåller original konstruktor
  sl.registerFactory<ShoppingListViewModel>(
    () => ShoppingListViewModel(
      shoppingListService: sl<ShoppingListService>(),
      shareService: sl<ShareService>(),
    ),
  );

  // RecipeFormViewModel med dependencies
  sl.registerFactory<RecipeFormViewModel>(
    () => RecipeFormViewModel(
      recipeService: sl<RecipeService>(),
      analyticsService: sl<AnalyticsService>(),
      storageService: sl<StorageService>(),
      imagePickerService: sl<ImagePickerService>(),
      authService: sl<AuthService>(),
    ),
  );

  // Import ViewModels - inga konstruktor-dependencies
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

  // RecipeDetailViewModel - fixad med korrekta parameters
  sl.registerFactoryParam<RecipeDetailViewModel, Recipe, void>(
    (recipe, _) => RecipeDetailViewModel(
      recipe: recipe,
      recipeService: sl<RecipeService>(),
      analyticsService: sl<AnalyticsService>(),
    ),
  );

  debugPrint('✅ Alla befintliga ViewModels registrerade');

  // ==================== SOCIAL VIEWMODELS ====================

  // UserProfileViewModel - för profil-redigering
  sl.registerFactory<UserProfileViewModel>(
    () => UserProfileViewModel(
      sl<UserService>(),
      sl<StorageService>(),
      sl<ImagePickerService>(),
    ),
  );

  // ✅ MVVM: FriendsViewModel som PERSISTENT SINGLETON (aldrig disposed)
  // VIKTIGT: Denna rad ska ERSÄTTA den befintliga FriendsViewModel-registreringen
  sl.registerLazySingleton<FriendsViewModel>(
    () => FriendsViewModel(
      friendsService: sl<FriendsService>(),
      userService: sl<UserService>(),
      categoriesService: sl<FriendCategoriesService>(),
    ),
  );

  // SocialRecipeViewModel - för receptdelning och kommentarer
  sl.registerFactoryParam<SocialRecipeViewModel, Recipe, void>(
    (recipe, _) => SocialRecipeViewModel(
      recipe: recipe,
      socialRecipeService: sl<SocialRecipeService>(),
      friendsService: sl<FriendsService>(),
      userService: sl<UserService>(),
    ),
  );

// ViewModels
  sl.registerFactory<CreateGroupViewModel>(
    () => CreateGroupViewModel(
      categoriesService: sl<FriendCategoriesService>(),
      groupInvitationService: sl<GroupInvitationService>(),
    ),
  );

  // SharedContentViewModel
  sl.registerFactory<SharedContentViewModel>(
    () => SharedContentViewModel(
      socialRecipeService: sl<SocialRecipeService>(),
      userService: sl<UserService>(),
    ),
  );

  // CollaborativeShoppingViewModel - Factory med traditionell constructor injection
  sl.registerFactory<CollaborativeShoppingViewModel>(
    () => CollaborativeShoppingViewModel(
      socialShoppingService: sl<SocialShoppingService>(),
      userService: sl<UserService>(),
      listId: '', // Kommer att sättas vid användning
    ),
  );

  // CreateSharedListViewModel - för att skapa delade listor
  sl.registerFactory<CreateSharedListViewModel>(
    () => CreateSharedListViewModel(),
  );

  // ✅ FIXAT: AddMembersToGroupViewModel - Nu med GroupInvitationService
  sl.registerFactoryParam<AddMembersToGroupViewModel, String, void>(
    (groupId, _) => AddMembersToGroupViewModel(
      groupId: groupId,
      friendsService: sl<FriendsService>(),
      categoriesService: sl<FriendCategoriesService>(),
      groupInvitationService: sl<
          GroupInvitationService>(), // ✅ NYTT: Lagt till GroupInvitationService
    ),
  );

  // ✅ FIXAT: GroupInvitationsViewModel - Nu med GroupInvitationService dependency
  sl.registerFactory<GroupInvitationsViewModel>(
    () => GroupInvitationsViewModel(
      categoriesService: sl<FriendCategoriesService>(),
      friendsService: sl<FriendsService>(),
      authService: sl<AuthService>(),
      groupInvitationService: sl<
          GroupInvitationService>(), // ✅ NYTT: Lagt till GroupInvitationService
    ),
  );

  debugPrint('✅ GroupInvitationsViewModel registrerad');
  debugPrint('✅ Alla social ViewModels registrerade');

  // ==================== INITIALIZATION SEQUENCE ====================

  try {
    // 1. Initiera core services som HAR initialize() metoder
    debugPrint('🔄 Initialiserar core services...');

    await sl<RecipeService>().initialize();
    debugPrint('✅ RecipeService initierad');

    await sl<OfflineService>().initialize();
    debugPrint('✅ OfflineService initierad');

    // 2. Social services initialization (KORREKT ORDNING!)
    debugPrint('🔄 Initialiserar social services...');

    await sl<UserService>().initialize();
    debugPrint('✅ UserService initierad');

    await sl<FriendsService>().initialize();
    debugPrint('✅ FriendsService initierad');

    await sl<FriendCategoriesService>().initialize();
    debugPrint('✅ FriendCategoriesService initierad');

    // ✅ NYTT: Initiera GroupInvitationService
    await sl<GroupInvitationService>().initialize();
    debugPrint('✅ GroupInvitationService initierad');

    await sl<SocialRecipeService>().initialize();
    debugPrint('✅ SocialRecipeService initierad');

    await sl<SocialShoppingService>().initialize();
    debugPrint('✅ SocialShoppingService initierad');

    debugPrint('🎉 Alla services initierade framgångsrikt!');
  } catch (e) {
    debugPrint('❌ Fel vid service-initialisering: $e');
    // Fortsätt ändå - låt appen köra med begränsad funktionalitet
  }

  // ==================== VALIDATION ====================

  // Validera att alla kritiska services är registrerade
  try {
    // Core services
    sl<AuthService>();
    sl<RecipeService>();
    sl<UserService>();
    sl<FriendsService>();
    sl<SocialRecipeService>();

    // Social shopping services
    sl<FriendCategoriesService>();
    sl<SocialShoppingService>();
    sl<GroupInvitationService>(); // ✅ NYTT: Validera GroupInvitationService

    // ✅ ViewModels - Testa att de kan skapas
    sl<RecipeListViewModel>(); // ✅ NU FINNS DENNA!
    sl<FriendsViewModel>(); // ✅ NU FUNGERAR DENNA!
    sl<SharedContentViewModel>();
    sl<MenuViewModel>();
    sl<ShoppingListViewModel>();
    sl<CreateSharedListViewModel>();
    sl<GroupInvitationsViewModel>(); // ✅ Testa att den kan skapas

    debugPrint(
        '✅ Alla kritiska services validerade inklusive gruppinbjudningar');
  } catch (e) {
    debugPrint('❌ Service validation fel: $e');
    debugPrint('❌ Fel vid init av DI: $e');
    throw Exception('Kritiska services saknas: $e');
  }

  debugPrint(
    '🚀 Dependency injection komplett - Social Shopping Platform med gruppinbjudningar redo! 🛒✨',
  );
}

/// Hjälpfunktion för att hämta CollaborativeShoppingViewModel med listId
CollaborativeShoppingViewModel getCollaborativeShoppingViewModel(
    String listId) {
  return CollaborativeShoppingViewModel(
    socialShoppingService: sl<SocialShoppingService>(),
    userService: sl<UserService>(),
    listId: listId,
  );
}

/// ✅ NYTT: Hjälpfunktion för AddMembersToGroupViewModel med groupId
AddMembersToGroupViewModel getAddMembersToGroupViewModel(String groupId) {
  return sl<AddMembersToGroupViewModel>(param1: groupId);
}

/// Hjälpfunktion för att kontrollera om alla social shopping services är redo
bool isSocialShoppingReady() {
  try {
    sl<SocialShoppingService>();
    sl<FriendCategoriesService>();
    sl<UserService>();
    sl<FriendsService>();
    sl<GroupInvitationService>(); // ✅ NYTT: Kontrollera GroupInvitationService
    return true;
  } catch (e) {
    debugPrint('⚠️ Social shopping services inte redo: $e');
    return false;
  }
}

/// Debug-funktion för att visa alla registrerade services
void debugPrintRegisteredServices() {
  debugPrint('📋 Registrerade Services:');
  debugPrint('  Core: AuthService, RecipeService, UserService');
  debugPrint('  Social: FriendsService, SocialRecipeService');
  debugPrint('  Shopping: FriendCategoriesService, SocialShoppingService');
  debugPrint('  Invitations: GroupInvitationService'); // ✅ NYTT
  debugPrint('  ViewModels: Alla ViewModels inklusive gruppinbjudningar');
}
