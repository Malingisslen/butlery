// lib/core/injection.dart

/// Dependency injection konfiguration för Butlery med Social Platform
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

// ==================== NYA SOCIAL SERVICES ====================
import '../services/user_service.dart';
import '../services/friends_service.dart';
import '../services/social_recipe_service.dart';

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

// ==================== NYA SOCIAL VIEWMODELS ====================
import '../viewmodels/user_profile_viewmodel.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../viewmodels/shared_content_viewmodel.dart';

// Models
import '../models/recipe.dart';

/// Service Locator instance
final GetIt sl = GetIt.instance;

/// Initialiserar alla dependencies - FIXAD REGISTRERINGSORDNING
Future<void> initializeDependencies() async {
  debugPrint('🔄 Initialiserar dependency injection...');

  // ==================== CORE SERVICES (FÖRST) ====================

  // AuthService - REGISTRERAS FÖRST (behövs för användarspecifik data)
  sl.registerSingleton<AuthService>(AuthService());
  debugPrint('✅ AuthService registrerad');

  // PersistenceService - för lokal datalagring
  sl.registerSingleton<PersistenceService>(PersistenceService());
  debugPrint('✅ PersistenceService registrerad');

  // ==================== SOCIAL SERVICES (REGISTRERAS TIDIGT) ====================

  // UserService - Hanterar användarprofilsn (måste komma före FriendsService)
  sl.registerSingleton<UserService>(UserService());
  debugPrint('✅ UserService registrerad');

  // FriendsService - Hanterar vänskaper (ingen dependency injection behövs)
  sl.registerSingleton<FriendsService>(FriendsService());
  debugPrint('✅ FriendsService registrerad');

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

  // ==================== SOCIAL SERVICES (BEHÖVER ANDRA SERVICES) ====================

  // SocialRecipeService - Behöver UserService och RecipeService
  sl.registerSingleton<SocialRecipeService>(
    SocialRecipeService(
      userService: sl<UserService>(),
      recipeService: sl<RecipeService>(),
    ),
  );
  debugPrint('✅ SocialRecipeService registrerad');

  // ==================== BEFINTLIGA VIEWMODELS ====================

  // ViewModels - Factory (ny instans för varje view)
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
    ),
  );

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

  // ==================== NYA SOCIAL VIEWMODELS ====================

  // UserProfileViewModel - för profil-redigering
  sl.registerFactory<UserProfileViewModel>(
    () => UserProfileViewModel(
      sl<UserService>(),
      sl<StorageService>(),
      sl<ImagePickerService>(),
    ),
  );

  // FriendsViewModel - för vänhantering
  sl.registerFactory<FriendsViewModel>(
    () => FriendsViewModel(
      friendsService: sl<FriendsService>(),
      userService: sl<UserService>(),
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

  // 🔧 FIXAD: SharedContentViewModel registreras EFTER alla dependencies
  sl.registerFactory<SharedContentViewModel>(
    () => SharedContentViewModel(
      socialRecipeService: sl<SocialRecipeService>(),
      userService: sl<UserService>(),
    ),
  );
  debugPrint('✅ SharedContentViewModel registrerad (efter dependencies)');

  debugPrint('✅ Alla social ViewModels registrerade');

  // ==================== INITIALIZATION SEQUENCE ====================

  try {
    // 1. Initiera core services som HAR initialize() metoder
    debugPrint('🔄 Initialiserar core services...');

    await sl<RecipeService>().initialize();
    debugPrint('✅ RecipeService initierad');

    await sl<OfflineService>().initialize();
    debugPrint('✅ OfflineService initierad');

    // 🔧 KRITISK FIX: SocialRecipeService initialize() anropas här
    await sl<SocialRecipeService>().initialize();
    debugPrint('✅ SocialRecipeService initierad');

    await sl<FriendsService>().initialize();
    debugPrint('✅ FriendsService initierad');

    // 2. Social services initialiseras automatiskt när de används först
    debugPrint('✅ Social services redo att användas');

    debugPrint('🎉 Alla services initierade framgångsrikt!');
  } catch (e) {
    debugPrint('❌ Fel vid service-initialisering: $e');
    // Fortsätt ändå - låt appen köra med begränsad funktionalitet
  }

  // ==================== MANUAL SOCIAL INITIALIZATION ====================

  // Initiera UserService manuellt när auth state är klar
  try {
    final userService = sl<UserService>();
    await userService.initialize();
    debugPrint('✅ UserService manuellt initierad');
  } catch (e) {
    debugPrint('⚠️ UserService initialization fel: $e');
    // Fortsätt ändå
  }

  // ==================== VALIDATION ====================

  // Validera att alla kritiska services är registrerade
  try {
    sl<AuthService>();
    sl<RecipeService>();
    sl<UserService>();
    sl<FriendsService>();
    sl<SocialRecipeService>();
    sl<SharedContentViewModel>(); // 🔧 TILLAGT: Validera SharedContentViewModel
    debugPrint('✅ Alla kritiska services validerade');
  } catch (e) {
    debugPrint('❌ Service validation fel: $e');
    throw Exception('Kritiska services saknas: $e');
  }

  debugPrint(
    '🚀 Dependency injection komplett - appen redo för social features!',
  );
}
