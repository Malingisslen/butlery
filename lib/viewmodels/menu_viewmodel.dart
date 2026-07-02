/// Menu ViewModel for AI meal planning, social sharing, and storage with modular architecture.
/// ```dart
/// final vm = MenuViewModel(); await vm.generateMenu('Veckomeny');

// lib/viewmodels/menu_viewmodel.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/household_service.dart';

// Focused modules
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/viewmodels/menu/menu_social_manager.dart';

/// Menu ViewModel with focused modules for generation, storage, and social sharing (MVVM).
class MenuViewModel extends BaseViewModel {
  StreamSubscription? _recipeServiceSubscription;
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  final AnalyticsService _analyticsService;

  // Local disposal flag, kept alongside BaseViewModel's own guard. It is set at
  // the very START of dispose() (before super.dispose()) so the module/stream
  // callbacks below (_onStateChanged, _onRecipesChanged) are already inert
  // during teardown, before the base flag flips. BaseViewModel.isDisposed only
  // becomes true inside super.dispose() at the end, which would be too late for
  // this VM's own guarded callbacks.
  bool _isDisposed = false;

  // Modules
  late final MenuStateManager _stateManager;
  late final MenuGenerator _generator;
  late final MenuStorage _storage;
  late final MenuSocialManager _socialManager;
  late final VoidCallback _onStateChanged;
  MenuViewModel({
    UnifiedRecipeService? recipeService,
    MenuService? menuService,
    AnalyticsService? analyticsService,
  }) : _recipeService =
           recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
       _menuService = menuService ?? ServiceLocator.get<MenuService>(),
       _analyticsService =
           analyticsService ?? ServiceLocator.get<AnalyticsService>() {
    // Initialize focused modules
    _stateManager = MenuStateManager();
    _generator = MenuGenerator(
      menuService: _menuService,
      recipeService: _recipeService,
      userService: ServiceLocator.get<UserService>(),
      // BUT-1318: reuse the registered plan service to down-weight recipes
      // used in the last 1-2 weeks. tryGet keeps construction safe in tests
      // that don't register it (recent-use dedup is simply skipped then).
      weeklyMenuPlanService: ServiceLocator.tryGet<WeeklyMenuPlanService>(),
      // BUT-1317 (safety): personal weekly-menu generation must respect the
      // user's tracked allergens/dietary prefs by default, mirroring the group
      // flow. Filtering reads userService.allergenPreferences and honors
      // includeUnknownInMenu; the household toggle and prompt-inline
      // constraints still layer on top.
      filterByAllergens: true,
      filterByDietary: true,
    );
    _storage = MenuStorage();
    _socialManager = MenuSocialManager(
      socialMenuOps: ServiceLocator.get<SocialMenuOperations>(),
    );

    // Forward state manager notifications
    _onStateChanged = () {
      if (!_isDisposed) notifyListeners();
    };
    _stateManager.addListener(_onStateChanged);

    // Listen to recipe service changes
    _recipeServiceSubscription = _recipeService.stateStream.listen(
      (_) => _onRecipesChanged(),
    );

    // Load all menus at startup
    _loadAllMenus();
  }

  // Getters
  Map<String, List<Recipe>> get menu => _stateManager.menu;
  bool get isGenerating => _stateManager.isGenerating;
  // Error state is owned by _stateManager, NOT BaseViewModel's own _error store.
  // These getters (and clearError below) override the base to read _stateManager.
  // Consequence: the INHERITED setError/setLoading/reset write BaseViewModel's
  // inert _error/_isLoading, which nothing here reads — so route menu errors
  // through _stateManager.setError, never the inherited setError, and don't wrap
  // menu ops in executeAsync (its catch calls the inherited setError → a silent,
  // never-displayed error). Cross-cutting cleanup for the delegate-pattern VMs
  // tracked in BUT-1462.
  @override
  String? get error => _stateManager.error;
  @override
  bool get hasError => _stateManager.hasError;
  bool get hasMenu => _stateManager.hasMenu;
  String get lastPrompt => _stateManager.lastPrompt;
  List<SavedMenuInfo> get savedMenus => _stateManager.savedMenus;
  int get totalRecipeCount => _stateManager.totalRecipeCount;
  List<Recipe> get availableRecipes => _generator.availableRecipes;
  bool get hasAvailableRecipes => _generator.hasAvailableRecipes;

  /// Whether the user has a household group configured.
  bool get hasHousehold {
    final service = ServiceLocator.tryGet<HouseholdService>();
    return service?.hasHousehold ?? false;
  }

  /// Whether menu generation should use household allergens.
  bool get useHouseholdAllergens => _generator.useHouseholdAllergens;
  set useHouseholdAllergens(bool value) {
    _generator.useHouseholdAllergens = value;
    notifyListeners();
  }

  /// Generates menu from AI prompt
  /// - Menu state update with generated content
  /// **Usage Example:**
  /// ```dart
  /// await menuViewModel.generateMenu(
  ///   'Vegetarisk veckomeny för familj med barn som gillar pasta',
  /// );
  /// ```
  Future<void> generateMenu(String prompt) async {
    if (!_stateManager.validatePrompt(prompt)) {
      _stateManager.setError(AppLocale.current.errorEnterMenuDescription);
      return;
    }

    _stateManager.setGenerating(true);
    _stateManager.setLastPrompt(prompt.trim());

    // Track menu generation started
    await _analyticsService.logMenuGenerationStarted(
      promptLength: prompt.trim().length,
    );

    final startTime = clock.now();

    try {
      final generatedMenu = await _generator.generateMenuFromPrompt(
        prompt.trim(),
      );
      _stateManager.setMenu(generatedMenu);
      _stateManager.clearErrorAfterSuccess();

      // Track menu generation success
      final generationTime = clock.now().difference(startTime).inMilliseconds;
      await _analyticsService.logMenuGenerated(
        recipeCount: totalRecipeCount,
        method: 'ai_prompt',
      );

      // Also log the time taken if it was slow
      if (generationTime > 10000) {
        // More than 10 seconds
        await _analyticsService.logSlowOperation(
          operationName: 'menu_generation',
          durationMs: generationTime,
          thresholdMs: 10000,
        );
      }
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorImportFailed,
        e,
      );

      // Track menu generation failure — log generic code, not full exception
      await _analyticsService.logMenuGenerationFailed(
        errorCode: 'menu_generation_error',
        errorMessage: 'menu_generation_failed',
      );
    } finally {
      _stateManager.setGenerating(false);
    }
  }

  /// Regenerates specific menu section with AI-powered recipe replacement and state coordination.
  /// Re-rolls one section using the original prompt constraints.
  Future<void> regenerateSection(String section) async {
    if (!hasMenu) return;

    _stateManager.setGenerating(true);

    try {
      final newRecipes = await _generator.regenerateMenuSection(
        section,
        menu,
        originalPrompt: _stateManager.lastPrompt.isNotEmpty
            ? _stateManager.lastPrompt
            : null,
      );

      if (newRecipes != null) {
        _stateManager.updateMenuSection(section, newRecipes);
        _stateManager.clearErrorAfterSuccess();
      }
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotUpdate(section),
        e,
      );
    } finally {
      _stateManager.setGenerating(false);
    }
  }

  /// Swaps a single recipe with the best-scoring alternative.
  /// Returns a [SwapResult] with the replacement and alternatives count.
  /// When no replacement is found, [SwapResult.recipe] is null and
  /// [SwapResult.exhaustedMessage] contains an informative message.
  Future<SwapResult> swapRecipe(Recipe recipe, String category) async {
    if (!hasMenu) {
      return SwapResult(
        recipe: null,
        alternativesRemaining: 0,
        exhaustedMessage: AppLocale.current.errorNoMoreRecipesForSwap,
      );
    }

    final result = _generator.swapSingleRecipe(recipe, category, menu);
    if (result.recipe == null) {
      _stateManager.setError(
        result.exhaustedMessage ?? AppLocale.current.errorNoMoreRecipesForSwap,
      );
      return result;
    }

    // Update the menu with the swapped recipe
    final updatedRecipes = List<Recipe>.from(menu[category] ?? []);
    final index = updatedRecipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      updatedRecipes[index] = result.recipe!;
      _stateManager.updateMenuSection(category, updatedRecipes);
    }

    return result;
  }

  /// BUT-1241: parsed constraint trace for the last generation prompt, used
  /// to thread day pins ("tacofredag") and the extraction-chip strip into
  /// the calendar distribution. Re-parses on demand — the parser is
  /// deterministic and lexicon-cached, so this costs no LLM call and stays
  /// consistent with what generation saw.
  Future<ParsedMenuRequest?> parsedRequestForLastPrompt() async {
    final prompt = lastPrompt;
    if (prompt.isEmpty) return null;
    try {
      return await _menuService.parsePrompt(prompt);
    } catch (e) {
      AppLogger.error('Could not re-parse menu prompt', e);
      return null;
    }
  }

  /// Clears current menu state for new generation or menu reset operations.
  /// Delegates to MenuStateManager for complete menu state cleanup
  /// enabling fresh menu generation and state reset functionality.
  void clearMenu() => _stateManager.clearMenu();

  /// Clears current error state for error recovery and clean state management.
  /// Delegates to MenuStateManager for error state cleanup enabling
  /// error recovery and clean user experience after error resolution.
  @override
  void clearError() => _stateManager.clearError();

  /// Loads menu content from a SharedMenu for viewing/editing.
  /// Used when navigating to VeckomenyView with a shared menu from social features.
  void loadFromSharedMenu(SharedMenu sharedMenu) {
    _stateManager.setMenu(sharedMenu.menuSnapshot);
    AppLogger.info('Loaded shared menu: ${sharedMenu.menuTitle}');
  }

  /// Saves menu with comprehensive metadata and optional social sharing coordination.
  /// [menuName] Display name for saved menu identification
  /// [comment] User comment describing menu characteristics
  /// [shareWithFriends] Whether to share menu with selected friends
  /// [selectedFriendIds] List of friend user IDs for sharing
  /// [shareMessage] Optional custom message for social sharing
  /// Returns true if save operation succeeds, false if validation fails or save errors occur.
  /// Performs complete menu save flow including validation, local storage, social sharing coordination,
  /// and saved menus list refresh for comprehensive menu persistence management.
  /// **Save Process:**
  /// - Menu and name validation with Swedish localized feedback
  /// - Local menu storage with metadata and recipe content
  /// - Optional social sharing with friend coordination
  /// - Saved menus list refresh for UI synchronization
  /// **Usage Example:**
  /// ```dart
  /// final saved = await menuViewModel.saveMenuWithNameAndComment(
  ///   'Familjevänlig Veckomeny',
  ///   'Näringsrik meny som barnen älskar',
  ///   shareWithFriends: true,
  ///   selectedFriendIds: ['friend1', 'friend2'],
  ///   shareMessage: 'Perfekt meny för familjer!',
  /// );
  /// ```
  Future<bool> saveMenuWithNameAndComment(
    String menuName,
    String comment, {
    bool shareWithFriends = false,
    List<String>? selectedFriendIds,
    String? shareMessage,
  }) async {
    final l = AppLocale.current;
    if (!_stateManager.validateMenuForSaving()) {
      _stateManager.setError(l.errorNoMenuToSave);
      return false;
    }

    if (!_storage.validateMenuName(menuName)) {
      _stateManager.setError(l.errorEnterMenuName);
      return false;
    }

    try {
      // Save to Firestore
      final menuId = await _storage.saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
      );

      // Track menu saved analytics
      await _analyticsService.logMenuSaved(
        menuId: menuId,
        recipeCount: totalRecipeCount,
        isShared: shareWithFriends && (selectedFriendIds?.isNotEmpty ?? false),
      );

      // First-meal-plan milestone fires at most once per user (BUT-576).
      final userService = ServiceLocator.tryGet<UserService>();
      await _analyticsService.menu.logFirstMealPlanIfMilestone(
        userId: userService?.currentUserId,
        recipeCountInPlan: totalRecipeCount,
        joinedAt: userService?.currentUserProfile?.joinedAt,
      );

      // Handle social sharing if requested
      if (shareWithFriends &&
          selectedFriendIds != null &&
          selectedFriendIds.isNotEmpty) {
        try {
          final shareSuccess = await _socialManager.shareMenuWithFriends(
            menu: menu,
            friendUserIds: selectedFriendIds,
            menuName: menuName,
            shareMessage: shareMessage,
          );

          if (shareSuccess) {
            // Track menu shared analytics
            await _analyticsService.logMenuShared(
              menuId: menuId,
              recipientCount: selectedFriendIds.length,
              shareMethod: 'social',
            );
          } else {
            _stateManager.setError(AppLocale.current.errorSomeSharesFailed);
          }
        } catch (e) {
          _stateManager.setError(AppLocale.current.errorSomeSharesFailed);
        }
      }

      // Refresh saved menus list
      await _loadAllMenus();
      return true;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotSaveRecipe,
        e,
      );
      return false;
    }
  }

  /// Loads saved menu with comprehensive source detection and state coordination.
  /// [menuKey] Unique identifier for saved menu retrieval
  /// Returns true if menu loads successfully, false if menu not found or load errors occur.
  /// Performs intelligent menu loading attempting local storage first, then imported menus,
  /// with automatic state management and error handling for seamless menu retrieval.
  /// **Load Process:**
  /// - Local storage menu retrieval attempt
  /// - Imported menu fallback for social menu access
  /// - Menu state coordination with recipe and prompt data
  /// - Error handling with Swedish localized feedback
  /// **Usage Example:**
  /// ```dart
  /// final loaded = await menuViewModel.loadSavedMenu('menu_key_123');
  /// if (loaded) {
  ///   // Menu loaded successfully, update UI
  /// } else {
  ///   // Handle load failure
  /// }
  /// ```
  Future<bool> loadSavedMenu(String menuKey) async {
    try {
      // Try loading from local storage first
      final localMenuData = await _storage.loadMenuByKey(menuKey);
      if (localMenuData != null) {
        _stateManager.loadMenuFromData(
          menu: localMenuData.menu,
          lastPrompt: localMenuData.lastPrompt,
        );
        return true;
      }

      // Try loading from imported menus
      final importedMenuData = await _socialManager.loadImportedMenuData(
        menuKey,
      );
      if (importedMenuData != null) {
        _stateManager.loadMenuFromData(
          menu: importedMenuData.menu,
          lastPrompt: importedMenuData.lastPrompt,
        );
        return true;
      }

      _stateManager.setError(AppLocale.current.errorMenuNotFound);
      return false;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotLoad('meny'),
        e,
      );
      return false;
    }
  }

  /// Deletes saved menu with automatic list refresh and comprehensive error handling.
  /// [menuKey] Unique identifier for menu deletion
  /// Returns true if deletion succeeds, false if operation fails.
  /// Performs menu deletion through MenuStorage with automatic saved menus list refresh
  /// for immediate UI synchronization and comprehensive error handling.
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await menuViewModel.deleteSavedMenu('menu_key_123');
  /// ```
  Future<bool> deleteSavedMenu(String menuKey) async {
    try {
      final success = await _storage.deleteMenuByKey(menuKey);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotDelete('meny'),
        e,
      );
      return false;
    }
  }

  /// Marks menu as modified for change tracking and version management.
  /// [menuKey] Unique identifier for menu modification marking
  /// Returns true if marking succeeds, false if operation fails.
  /// Delegates to MenuStorage for modification tracking enabling
  /// menu version management and change detection capabilities.
  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      return await _storage.markMenuAsModified(menuKey);
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotUpdate('meny'),
        e,
      );
      return false;
    }
  }

  /// Retrieves available shared menus from social network with comprehensive error handling.
  /// Returns list of shared menu metadata for social menu discovery and import functionality.
  /// Delegates to MenuSocialManager for social menu retrieval with automatic error handling
  /// and empty list fallback for robust social feature integration.
  /// **Usage Example:**
  /// ```dart
  /// final sharedMenus = await menuViewModel.getAvailableSharedMenus();
  /// for (final menuData in sharedMenus) {
  ///   // Display shared menu information
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getAvailableSharedMenus() async {
    try {
      return await _socialManager.getAvailableSharedMenus();
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotLoad('delade menyer'),
        e,
      );
      return <Map<String, dynamic>>[];
    }
  }

  /// Imports shared menu with automatic list refresh and comprehensive state management.
  /// [sharedMenuId] Unique identifier for shared menu import
  /// Returns true if import succeeds, false if operation fails.
  /// Performs shared menu import through MenuSocialManager with automatic saved menus refresh
  /// for immediate UI synchronization and comprehensive error handling with Swedish feedback.
  /// **Usage Example:**
  /// ```dart
  /// final imported = await menuViewModel.importSharedMenu('shared_menu_123');
  /// if (imported) {
  ///   // Menu imported successfully, update UI
  /// }
  /// ```
  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      final success = await _socialManager.importSharedMenu(sharedMenuId);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError(
        AppLocale.current.errorCouldNotImportRecipes,
        e,
      );
      return false;
    }
  }

  /// Marks shared menu as viewed for social engagement tracking and notification management.
  /// [sharedMenuId] Unique identifier for shared menu view tracking
  /// Delegates to MenuSocialManager for view tracking enabling social engagement metrics
  /// and notification management for shared menu interactions.
  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    await _socialManager.markSharedMenuAsViewed(sharedMenuId);
  }

  /// Retrieves comprehensive sharing statistics for social engagement insights.
  /// Returns sharing statistics data for social engagement analysis and user insights.
  /// Delegates to MenuSocialManager for comprehensive sharing metrics including
  /// share counts, view statistics, and engagement data for social feature optimization.
  Future<Map<String, dynamic>> getSharingStats() async {
    return await _socialManager.getSharingStats();
  }

  /// Refreshes saved menus list for UI synchronization and data consistency.
  /// Reloads complete saved menus list including local and imported menus
  /// with sorting and organization for UI display and menu management operations.
  Future<void> refreshSavedMenus() async {
    await _loadAllMenus();
  }

  /// Handles reactive updates from recipe service changes with automatic UI synchronization.
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// all recipe availability changes are immediately reflected in menu generation capabilities
  /// for consistent user experience and real-time recipe status updates.
  void _onRecipesChanged() {
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Loads all saved menus with comprehensive organization and intelligent sorting.
  /// Performs complete menu loading from both local storage and social imports
  /// with intelligent sorting prioritizing user-owned menus and chronological organization.
  /// Includes comprehensive error handling and success logging for menu management operations.
  /// **Loading Process:**
  /// - Local menus retrieval from MenuStorage
  /// - Imported menus retrieval from MenuSocialManager
  /// - Intelligent sorting with ownership priority and date organization
  /// - State management update with organized menu list
  Future<void> _loadAllMenus() async {
    try {
      final localMenus = await _storage.loadUserMenus();
      final importedMenus = await _socialManager.loadImportedMenus();

      // Combine and sort menus
      final allMenus = <SavedMenuInfo>[...localMenus, ...importedMenus];
      allMenus.sort((a, b) {
        // Own menus first
        if (a.isOwned && !b.isOwned) return -1;
        if (!a.isOwned && b.isOwned) return 1;

        // Within same type, sort by date (newest first)
        return b.savedDate.compareTo(a.savedDate);
      });

      _stateManager.setSavedMenus(allMenus);

      AppLogger.success(
        '✅ Alla menyer laddade: ${localMenus.length} lokala, ${importedMenus.length} importerade',
      );
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av menyer: $e');
    }
  }

  /// Performs comprehensive ViewModel disposal with module cleanup and memory management.
  /// Disposes all focused modules, removes service listeners, and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic menu management scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _isDisposed = true;
    _stateManager.removeListener(_onStateChanged);
    _stateManager.dispose();
    _recipeServiceSubscription?.cancel();
    super.dispose();
  }
}
