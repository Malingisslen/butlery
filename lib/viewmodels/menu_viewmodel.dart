/// Comprehensive menu ViewModel providing advanced meal planning and menu management for Flutter applications.
///
/// This module implements sophisticated menu management following Single Responsibility Principle,
/// handling all aspects of menu presentation layer including AI-powered generation, social sharing, storage coordination,
/// and comprehensive state management. It provides complete meal planning infrastructure while
/// maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles menu presentation layer concerns through focused module delegation:
/// - **Menu Generation Excellence**: AI-powered menu generation with prompt-based meal planning and section regeneration
/// - **Social Integration Intelligence**: Comprehensive social sharing, importing, and collaborative menu management
/// - **Storage Coordination**: Advanced local storage with menu persistence, retrieval, and modification tracking
/// - **State Management**: Sophisticated reactive state management with error handling and notification coordination
/// - **Module Architecture**: Clean facade pattern delegating to specialized modules for focused responsibility
///
/// **What This Module Does NOT Handle:**
/// - Complex business logic implementation (handled by specialized modules: MenuGenerator, MenuStorage, etc.)
/// - Direct service implementations (handled by UnifiedRecipeService, MenuService, and SocialMenuOperations)
/// - UI rendering and widget creation (handled by MenuView and meal planning UI components)
/// - Data persistence logic (handled by MenuStorage module and underlying storage services)
///
/// **Menu ViewModel Architecture:**
/// - **MenuStateManager**: Reactive state management and UI notification coordination
/// - **MenuGenerator**: AI-powered menu generation and section regeneration capabilities
/// - **MenuStorage**: Local menu persistence, retrieval, and modification tracking
/// - **MenuSocialManager**: Social sharing, importing, and collaborative menu features
/// - **Clean Facade Pattern**: Unified API delegating to focused modules for maintainable architecture
///
/// **Usage Examples:**
/// ```dart
/// // Initialize menu ViewModel with service dependencies
/// final menuViewModel = MenuViewModel(
///   recipeService: unifiedRecipeService,
///   menuService: menuService,
/// );
/// 
/// // AI-powered menu generation with Swedish prompts
/// await menuViewModel.generateMenu('Vegetarisk veckomeny för familj med barn');
/// 
/// // Regenerate specific menu sections
/// await menuViewModel.regenerateSection('Middag');
/// 
/// // Save menu with social sharing
/// final saved = await menuViewModel.saveMenuWithNameAndComment(
///   'Vegetarisk Veckomeny',
///   'Hälsosam och barnvänlig meny',
///   shareWithFriends: true,
///   selectedFriendIds: ['friend1', 'friend2'],
///   shareMessage: 'Kolla in denna fantastiska vegetariska meny!',
/// );
/// 
/// // Load saved menu
/// await menuViewModel.loadSavedMenu('menu_key_123');
/// 
/// // Social menu operations
/// final sharedMenus = await menuViewModel.getAvailableSharedMenus();
/// await menuViewModel.importSharedMenu('shared_menu_id');
/// 
/// // Reactive state monitoring
/// if (menuViewModel.isGenerating) {
///   // Show generation progress
/// } else if (menuViewModel.hasMenu) {
///   // Display generated menu
/// }
/// ```

// lib/viewmodels/menu_viewmodel.dart

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

/// Comprehensive menu ViewModel providing advanced meal planning and menu management through focused module architecture.
///
/// Serves as a clean facade coordinating specialized modules for menu operations, providing unified API
/// for AI-powered menu generation, social sharing, storage management, and reactive state coordination
/// while maintaining clean MVVM architecture separation between menu business logic and UI presentation concerns.
class MenuViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final MenuService _menuService;
  
  // ===== FOCUSED MODULE ARCHITECTURE =====
  
  /// State management module for reactive UI coordination and error handling.
  late final MenuStateManager _stateManager;
  
  /// AI-powered menu generation module for prompt-based meal planning.
  late final MenuGenerator _generator;
  
  /// Local storage module for menu persistence and retrieval operations.
  late final MenuStorage _storage;
  
  /// Social features module for sharing, importing, and collaborative menu management.
  late final MenuSocialManager _socialManager;

  /// Initializes menu ViewModel with comprehensive module coordination and service integration.
  /// 
  /// [recipeService] Optional UnifiedRecipeService instance for dependency injection
  /// [menuService] Optional MenuService instance for dependency injection
  /// 
  /// Establishes focused module architecture with specialized components for menu management,
  /// sets up reactive state coordination, and initializes menu data loading for complete
  /// meal planning functionality with clean separation of concerns.
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

  // ===== REACTIVE STATE ACCESSORS (DELEGATE TO SPECIALIZED MODULES) =====
  
  /// Current generated menu organized by categories for UI display and meal planning.
  /// 
  /// Delegates to MenuStateManager for reactive menu state access enabling
  /// UI components to display categorized recipes and meal planning information.
  Map<String, List<Recipe>> get menu => _stateManager.menu;
  
  /// Menu generation operation state for UI progress indication and interaction control.
  /// 
  /// Provides real-time generation status for loading indicators and user interaction
  /// management during AI-powered menu generation and section regeneration operations.
  bool get isGenerating => _stateManager.isGenerating;
  
  /// Current error message for user feedback and error state management.
  /// 
  /// Delegates to MenuStateManager for centralized error handling with localized
  /// Swedish error messages for comprehensive user feedback and error recovery.
  String? get error => _stateManager.error;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Provides boolean error state check for UI error display decisions
  /// and error state management throughout menu operations.
  bool get hasError => _stateManager.hasError;
  
  /// Menu existence indicator for UI conditional display and feature enabling.
  /// 
  /// Indicates whether a generated menu is available for display and operations,
  /// enabling UI conditional rendering and menu-dependent feature activation.
  bool get hasMenu => _stateManager.hasMenu;
  
  /// Last generation prompt for regeneration and context display.
  /// 
  /// Provides access to the last AI generation prompt for UI display
  /// and menu regeneration operations with user context preservation.
  String get lastPrompt => _stateManager.lastPrompt;
  
  /// Saved menus list for UI display and menu selection functionality.
  /// 
  /// Delegates to MenuStateManager for comprehensive saved menu information
  /// including local and imported menus for complete menu management.
  List<SavedMenuInfo> get savedMenus => _stateManager.savedMenus;
  
  /// Total recipe count across all menu categories for statistics and UI display.
  /// 
  /// Provides aggregate recipe count for menu statistics display
  /// and meal planning information presentation to users.
  int get totalRecipeCount => _stateManager.totalRecipeCount;

  /// Available recipes for menu generation from recipe service integration.
  /// 
  /// Delegates to MenuGenerator for recipe availability information
  /// enabling menu generation capability assessment and user guidance.
  List<Recipe> get availableRecipes => _generator.availableRecipes;
  
  /// Recipe availability indicator for menu generation capability assessment.
  /// 
  /// Indicates whether sufficient recipes are available for menu generation,
  /// enabling UI conditional display and generation feature availability.
  bool get hasAvailableRecipes => _generator.hasAvailableRecipes;

  // ===== AI-POWERED MENU GENERATION OPERATIONS =====

  /// Generates complete menu from AI prompt with comprehensive state management and error handling.
  /// 
  /// [prompt] Swedish language prompt describing desired menu characteristics
  /// 
  /// Performs AI-powered menu generation through MenuGenerator module with complete
  /// state coordination, progress tracking, and error handling. Validates prompt,
  /// manages generation state, and updates menu with generated recipes organized by categories.
  /// 
  /// **Generation Process:**
  /// - Prompt validation with Swedish localized error feedback
  /// - Generation state management with UI progress indication
  /// - AI-powered recipe selection and categorization
  /// - Menu state update with generated content
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await menuViewModel.generateMenu(
  ///   'Vegetarisk veckomeny för familj med barn som gillar pasta',
  /// );
  /// ```
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

  /// Regenerates specific menu section with AI-powered recipe replacement and state coordination.
  /// 
  /// [section] Menu category to regenerate (e.g., 'Middag', 'Lunch', 'Frukost')
  /// 
  /// Performs targeted menu section regeneration through MenuGenerator with existing menu context,
  /// maintaining other sections while replacing specified category with new AI-generated recipes.
  /// Includes comprehensive error handling and state management for seamless user experience.
  /// 
  /// **Regeneration Process:**
  /// - Menu existence validation before operation
  /// - Section-specific AI generation with context preservation
  /// - Targeted menu section update with new recipes
  /// - State coordination and error handling
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await menuViewModel.regenerateSection('Middag');
  /// ```
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

  /// Clears current menu state for new generation or menu reset operations.
  /// 
  /// Delegates to MenuStateManager for complete menu state cleanup
  /// enabling fresh menu generation and state reset functionality.
  void clearMenu() => _stateManager.clearMenu();
  
  /// Clears current error state for error recovery and clean state management.
  /// 
  /// Delegates to MenuStateManager for error state cleanup enabling
  /// error recovery and clean user experience after error resolution.
  void clearError() => _stateManager.clearError();

  // ===== COMPREHENSIVE MENU STORAGE OPERATIONS =====

  /// Saves menu with comprehensive metadata and optional social sharing coordination.
  /// 
  /// [menuName] Display name for saved menu identification
  /// [comment] User comment describing menu characteristics
  /// [shareWithFriends] Whether to share menu with selected friends
  /// [selectedFriendIds] List of friend user IDs for sharing
  /// [shareMessage] Optional custom message for social sharing
  /// 
  /// Returns true if save operation succeeds, false if validation fails or save errors occur.
  /// Performs complete menu save flow including validation, local storage, social sharing coordination,
  /// and saved menus list refresh for comprehensive menu persistence management.
  /// 
  /// **Save Process:**
  /// - Menu and name validation with Swedish localized feedback
  /// - Local menu storage with metadata and recipe content
  /// - Optional social sharing with friend coordination
  /// - Saved menus list refresh for UI synchronization
  /// 
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

  /// Loads saved menu with comprehensive source detection and state coordination.
  /// 
  /// [menuKey] Unique identifier for saved menu retrieval
  /// 
  /// Returns true if menu loads successfully, false if menu not found or load errors occur.
  /// Performs intelligent menu loading attempting local storage first, then imported menus,
  /// with automatic state management and error handling for seamless menu retrieval.
  /// 
  /// **Load Process:**
  /// - Local storage menu retrieval attempt
  /// - Imported menu fallback for social menu access
  /// - Menu state coordination with recipe and prompt data
  /// - Error handling with Swedish localized feedback
  /// 
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

  /// Deletes saved menu with automatic list refresh and comprehensive error handling.
  /// 
  /// [menuKey] Unique identifier for menu deletion
  /// 
  /// Returns true if deletion succeeds, false if operation fails.
  /// Performs menu deletion through MenuStorage with automatic saved menus list refresh
  /// for immediate UI synchronization and comprehensive error handling.
  /// 
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
      _stateManager.handleOperationError('Kunde inte ta bort meny', e);
      return false;
    }
  }

  /// Marks menu as modified for change tracking and version management.
  /// 
  /// [menuKey] Unique identifier for menu modification marking
  /// 
  /// Returns true if marking succeeds, false if operation fails.
  /// Delegates to MenuStorage for modification tracking enabling
  /// menu version management and change detection capabilities.
  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      return await _storage.markMenuAsModified(menuKey);
    } catch (e) {
      _stateManager.handleOperationError('Kunde inte markera meny som modifierad', e);
      return false;
    }
  }

  // ===== COMPREHENSIVE SOCIAL MENU FEATURES =====

  /// Retrieves available shared menus from social network with comprehensive error handling.
  /// 
  /// Returns list of shared menu metadata for social menu discovery and import functionality.
  /// Delegates to MenuSocialManager for social menu retrieval with automatic error handling
  /// and empty list fallback for robust social feature integration.
  /// 
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
      _stateManager.handleOperationError('Kunde inte hämta delade menyer', e);
      return <Map<String, dynamic>>[];
    }
  }

  /// Imports shared menu with automatic list refresh and comprehensive state management.
  /// 
  /// [sharedMenuId] Unique identifier for shared menu import
  /// 
  /// Returns true if import succeeds, false if operation fails.
  /// Performs shared menu import through MenuSocialManager with automatic saved menus refresh
  /// for immediate UI synchronization and comprehensive error handling with Swedish feedback.
  /// 
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
      _stateManager.handleOperationError('Kunde inte importera meny', e);
      return false;
    }
  }

  /// Marks shared menu as viewed for social engagement tracking and notification management.
  /// 
  /// [sharedMenuId] Unique identifier for shared menu view tracking
  /// 
  /// Delegates to MenuSocialManager for view tracking enabling social engagement metrics
  /// and notification management for shared menu interactions.
  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    await _socialManager.markSharedMenuAsViewed(sharedMenuId);
  }

  /// Retrieves comprehensive sharing statistics for social engagement insights.
  /// 
  /// Returns sharing statistics data for social engagement analysis and user insights.
  /// Delegates to MenuSocialManager for comprehensive sharing metrics including
  /// share counts, view statistics, and engagement data for social feature optimization.
  Future<Map<String, dynamic>> getSharingStats() async {
    return await _socialManager.getSharingStats();
  }

  /// Refreshes saved menus list for UI synchronization and data consistency.
  /// 
  /// Reloads complete saved menus list including local and imported menus
  /// with sorting and organization for UI display and menu management operations.
  Future<void> refreshSavedMenus() async {
    await _loadAllMenus();
  }

  // ===== INTERNAL COORDINATION METHODS =====

  /// Handles reactive updates from recipe service changes with automatic UI synchronization.
  /// 
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// all recipe availability changes are immediately reflected in menu generation capabilities
  /// for consistent user experience and real-time recipe status updates.
  void _onRecipesChanged() {
    notifyListeners();
  }

  /// Loads all saved menus with comprehensive organization and intelligent sorting.
  /// 
  /// Performs complete menu loading from both local storage and social imports
  /// with intelligent sorting prioritizing user-owned menus and chronological organization.
  /// Includes comprehensive error handling and success logging for menu management operations.
  /// 
  /// **Loading Process:**
  /// - Local menus retrieval from MenuStorage
  /// - Imported menus retrieval from MenuSocialManager
  /// - Intelligent sorting with ownership priority and date organization
  /// - State management update with organized menu list
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

  /// Performs comprehensive ViewModel disposal with module cleanup and memory management.
  /// 
  /// Disposes all focused modules, removes service listeners, and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic menu management scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _stateManager.dispose();
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}