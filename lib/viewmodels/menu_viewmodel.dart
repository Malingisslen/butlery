// lib/viewmodels/menu_viewmodel_new.dart
// ✅ INTEGRERAD med social import support

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

// Focused modules
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/viewmodels/menu/menu_social_manager.dart';

/// Clean facade for menu viewmodel using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - MenuStateManager: State management and notifications
/// - MenuGenerator: AI-powered menu generation
/// - MenuStorage: Local storage operations
/// - MenuSocialManager: Social sharing and importing
///
/// ❌ DOES NOT CONTAIN: Complex business logic, direct service implementations
class MenuViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  
  // Focused modules
  late final MenuStateManager _stateManager;
  late final MenuGenerator _generator;
  late final MenuStorage _storage;
  late final MenuSocialManager _socialManager;

  MenuViewModel({
    UnifiedRecipeService? recipeService,
    MenuService? menuService,
  })  : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
        _menuService = menuService ?? ServiceLocator.get<MenuService>() {
    
    // Initialize focused modules
    _stateManager = MenuStateManager();
    _generator = MenuGenerator(
      menuService: _menuService,
      recipeService: _recipeService,
    );
    _storage = MenuStorage();
    _socialManager = MenuSocialManager(
      socialMenuOps: ServiceLocator.get<SocialMenuOperations>(),
    );

    // Forward state manager notifications
    _stateManager.addListener(() => notifyListeners());

    // Listen to recipe service changes
    _recipeService.addListener(_onRecipesChanged);

    // Load all menus at startup
    _loadAllMenus();
  }

  // ===== STATE GETTERS (DELEGATE TO STATE_MANAGER) =====
  
  Map<String, List<Recipe>> get menu => _stateManager.menu;
  bool get isGenerating => _stateManager.isGenerating;
  String? get error => _stateManager.error;
  bool get hasError => _stateManager.hasError;
  bool get hasMenu => _stateManager.hasMenu;
  String get lastPrompt => _stateManager.lastPrompt;
  List<SavedMenuInfo> get savedMenus => _stateManager.savedMenus;
  int get totalRecipeCount => _stateManager.totalRecipeCount;

  List<Recipe> get availableRecipes => _generator.availableRecipes;
  bool get hasAvailableRecipes => _generator.hasAvailableRecipes;

  // ===== MENU GENERATION (DELEGATE TO GENERATOR) =====

  Future<void> generateMenu(String prompt) async {
    if (!_stateManager.validatePrompt(prompt)) {
      _stateManager.setError('Ange vad du vill ha för meny');
      return;
    }

    _stateManager.setGenerating(true);
    _stateManager.setLastPrompt(prompt.trim());

    try {
      final generatedMenu = await _generator.generateMenuFromPrompt(prompt.trim());
      _stateManager.setMenu(generatedMenu);
      _stateManager.clearErrorAfterSuccess();
    } catch (e) {
      _stateManager.handleOperationError('Meny-generering misslyckades', e);
    } finally {
      _stateManager.setGenerating(false);
    }
  }

  Future<void> regenerateSection(String section) async {
    if (!hasMenu) return;

    _stateManager.setGenerating(true);

    try {
      final newRecipes = await _generator.regenerateMenuSection(section, menu);
      
      if (newRecipes != null) {
        _stateManager.updateMenuSection(section, newRecipes);
        _stateManager.clearErrorAfterSuccess();
      }
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte uppdatera $section', e);
    } finally {
      _stateManager.setGenerating(false);
    }
  }

  void clearMenu() => _stateManager.clearMenu();
  void clearError() => _stateManager.clearError();

  // ===== MENU STORAGE (DELEGATE TO STORAGE) =====

  Future<bool> saveMenuWithNameAndComment(
    String menuName,
    String comment, {
    bool shareWithFriends = false,
    List<String>? selectedFriendIds,
    String? shareMessage,
  }) async {
    if (!_stateManager.validateMenuForSaving()) {
      _stateManager.setError('Ingen meny att spara');
      return false;
    }

    if (!_storage.validateMenuName(menuName)) {
      _stateManager.setError('Ange ett namn för menyn');
      return false;
    }

    try {
      // Save locally first
      await _storage.saveMenuLocally(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
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

          if (!shareSuccess) {
            _stateManager.setError('Meny sparad, men kunde inte dela med vänner');
          }
        } catch (e) {
          _stateManager.setError('Meny sparad, men kunde inte dela med vänner: $e');
        }
      }

      // Refresh saved menus list
      await _loadAllMenus();
      return true;
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte spara meny', e);
      return false;
    }
  }

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
      final importedMenuData = await _socialManager.loadImportedMenuData(menuKey);
      if (importedMenuData != null) {
        _stateManager.loadMenuFromData(
          menu: importedMenuData.menu,
          lastPrompt: importedMenuData.lastPrompt,
        );
        return true;
      }

      _stateManager.setError('Menyn kunde inte hittas');
      return false;
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte ladda meny', e);
      return false;
    }
  }

  Future<bool> deleteSavedMenu(String menuKey) async {
    try {
      final success = await _storage.deleteMenuByKey(menuKey);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte ta bort meny', e);
      return false;
    }
  }

  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      return await _storage.markMenuAsModified(menuKey);
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte markera meny som modifierad', e);
      return false;
    }
  }

  // ===== SOCIAL FEATURES (DELEGATE TO SOCIAL_MANAGER) =====

  Future<List<Map<String, dynamic>>> getAvailableSharedMenus() async {
    try {
      return await _socialManager.getAvailableSharedMenus();
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte hämta delade menyer', e);
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      final success = await _socialManager.importSharedMenu(sharedMenuId);
      if (success) {
        await _loadAllMenus();
      }
      return success;
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte importera meny', e);
      return false;
    }
  }

  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    await _socialManager.markSharedMenuAsViewed(sharedMenuId);
  }

  Future<Map<String, dynamic>> getSharingStats() async {
    return await _socialManager.getSharingStats();
  }

  /// Refresh saved menus list
  Future<void> refreshSavedMenus() async {
    await _loadAllMenus();
  }

  // ===== INTERNAL METHODS =====

  void _onRecipesChanged() {
    notifyListeners();
  }

  Future<void> _loadAllMenus() async {
    try {
      final localMenus = await _storage.loadLocalMenus();
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
          '✅ Alla menyer laddade: ${localMenus.length} lokala, ${importedMenus.length} importerade');
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av menyer: $e');
    }
  }

  @override
  void dispose() {
    _stateManager.dispose();
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}