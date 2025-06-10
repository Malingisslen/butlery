// lib/core/injection.dart

import 'package:get_it/get_it.dart';
import '../services/recipe_service.dart';
import '../services/menu_service.dart';
import '../services/search_service.dart';
import '../services/shopping_list_service.dart';
import '../viewmodels/recipe_list_viewmodel.dart';
import '../viewmodels/menu_viewmodel.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../viewmodels/text_import_viewmodel.dart';
import '../viewmodels/archive_import_viewmodel.dart';
import '../viewmodels/photo_import_viewmodel.dart';
import '../viewmodels/url_import_viewmodel.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../models/recipe.dart';

/// Service Locator instance
final GetIt sl = GetIt.instance;

/// Initialiserar alla dependencies
Future<void> initializeDependencies() async {
  // Services - Singletons (samma instans överallt)
  sl.registerSingleton<RecipeService>(RecipeService());
  sl.registerSingleton<MenuService>(MenuService());
  sl.registerSingleton<SearchService>(SearchService());
  sl.registerSingleton<ShoppingListService>(ShoppingListService());

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
    () => ShoppingListViewModel(shoppingListService: sl<ShoppingListService>()),
  );

  sl.registerFactory<RecipeFormViewModel>(
    () => RecipeFormViewModel(recipeService: sl<RecipeService>()),
  );

  sl.registerFactory<TextImportViewModel>(() => TextImportViewModel());

  sl.registerFactory<ArchiveImportViewModel>(
    () => ArchiveImportViewModel(
      recipeService: sl<RecipeService>(),
      searchService: sl<SearchService>(),
    ),
  );

  sl.registerFactory<PhotoImportViewModel>(() => PhotoImportViewModel());

  sl.registerFactory<UrlImportViewModel>(() => UrlImportViewModel());

  // RecipeDetailViewModel behöver recipe som parameter
  sl.registerFactoryParam<RecipeDetailViewModel, Recipe, void>(
    (recipe, _) => RecipeDetailViewModel(
      recipe: recipe,
      recipeService: sl<RecipeService>(),
    ),
  );

  // Initiera RecipeService direkt
  await sl<RecipeService>().initialize();
}

/// Återställ dependencies (för testing)
Future<void> resetDependencies() async {
  await sl.reset();
  await initializeDependencies();
}
