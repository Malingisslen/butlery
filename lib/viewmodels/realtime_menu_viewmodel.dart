/// Comprehensive real-time menu collaboration ViewModel providing advanced collaborative menu management for Flutter applications.
///
/// This module implements sophisticated real-time collaborative menu functionality following Single Responsibility Principle,
/// specializing in multi-user menu collaboration, recipe management, participant coordination, and real-time synchronization.
/// It provides complete collaborative menu infrastructure while maintaining clean separation from UI rendering,
/// menu data persistence, and complex collaborative business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles real-time collaborative menu presentation layer concerns:
/// - **Real-Time Collaboration Intelligence**: Advanced multi-user menu collaboration with live synchronization and conflict resolution
/// - **Recipe Management System**: Sophisticated recipe operations with optimistic updates and category coordination
/// - **Participant Management Excellence**: Comprehensive participant tracking with permission system and presence coordination
/// - **Connection Management**: Advanced connection monitoring with offline handling and synchronization recovery
/// - **Swedish Localization Excellence**: Complete Swedish language support for collaborative operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by real-time menu views and presentation components)
/// - Menu data persistence and storage (handled by RealtimeMenuService and underlying data repositories)
/// - Complex collaborative infrastructure (handled by real-time services and synchronization systems)
/// - Recipe business logic implementation (handled by recipe services and business logic layer)
///
/// **Real-Time Menu ViewModel Architecture:**
/// - **Focused Module Pattern**: Clean delegation to specialized modules for maintainable and scalable functionality
/// - **RealtimeMenuState**: Core state management with status tracking and error coordination
/// - **RealtimeStreamManager**: Real-time streaming with connection management and automatic reconnection
/// - **RealtimeMenuOperations**: Recipe operations with optimistic updates and conflict resolution
/// - **RealtimeParticipantManager**: Participant management with permission system and presence tracking
///
/// **Usage Examples:**
/// ```dart
/// // Initialize real-time menu ViewModel with service integration
/// final realtimeMenuViewModel = RealtimeMenuViewModel(
///   menuService: ServiceLocator.get<RealtimeMenuService>(),
///   syncService: ServiceLocator.get<RealtimeSyncService>(),
///   authService: ServiceLocator.get<AuthService>(),
/// );
/// 
/// // Start collaborative menu session with real-time synchronization
/// await realtimeMenuViewModel.startWatching('menu_123');
/// 
/// // Recipe management operations with optimistic updates
/// await realtimeMenuViewModel.addRecipeToCategory(
///   categoryName: 'Huvudrätter',
///   recipe: vegetarianPastaRecipe,
/// );
/// 
/// await realtimeMenuViewModel.moveRecipeBetweenCategories(
///   fromCategory: 'Förslag',
///   fromIndex: 0,
///   toCategory: 'Middag',
///   toIndex: 2,
/// );
/// 
/// await realtimeMenuViewModel.reorderRecipeInCategory(
///   categoryName: 'Huvudrätter',
///   fromIndex: 0,
///   toIndex: 3,
/// );
/// 
/// // Category management with regeneration
/// await realtimeMenuViewModel.clearCategory('Förslag');
/// await realtimeMenuViewModel.regenerateCategory('Huvudrätter');
/// 
/// // Participant management with permission control
/// await realtimeMenuViewModel.addParticipant(
///   userId: 'user_456',
///   userDisplayName: 'Anna Svensson',
///   permission: ResourcePermission.editor,
/// );
/// 
/// await realtimeMenuViewModel.removeParticipant('user_789');
/// 
/// // Real-time state monitoring
/// if (realtimeMenuViewModel.isLoading) {
///   // Show loading indicator
/// } else if (realtimeMenuViewModel.errorMessage != null) {
///   // Display error message
/// } else if (realtimeMenuViewModel.hasUnsavedChanges) {
///   // Show unsaved changes indicator
/// }
/// 
/// // Connection status monitoring
/// if (!realtimeMenuViewModel.isOnline) {
///   // Show offline indicator
///   final status = realtimeMenuViewModel.connectionStatusDescription;
///   final emoji = realtimeMenuViewModel.connectionStatusEmoji;
/// }
/// 
/// // Permission checking and UI control
/// if (realtimeMenuViewModel.canEdit) {
///   // Enable editing controls
/// } else if (realtimeMenuViewModel.canManageParticipants) {
///   // Show participant management options
/// }
/// 
/// // Participant presence tracking
/// final activeCount = realtimeMenuViewModel.activeParticipantCount;
/// final activities = realtimeMenuViewModel.participantActivities;
/// final onlineUsers = realtimeMenuViewModel.onlineParticipants;
/// 
/// // Category selection and recipe access
/// realtimeMenuViewModel.selectCategory('Huvudrätter');
/// final categoryRecipes = realtimeMenuViewModel.selectedCategoryRecipes;
/// final menuWithChanges = realtimeMenuViewModel.menuWithOptimisticChanges;
/// 
/// // UI state management
/// realtimeMenuViewModel.toggleParticipants(); // Show/hide participant panel
/// realtimeMenuViewModel.clearError(); // Clear error state
/// realtimeMenuViewModel.refreshConnection(); // Force connection check
/// 
/// // Menu lifecycle management
/// final personalCopy = realtimeMenuViewModel.createPersonalCopy();
/// await realtimeMenuViewModel.deleteMenu(); // Delete if owner
/// await realtimeMenuViewModel.stopWatching(); // Stop collaboration
/// ```

// lib/viewmodels/realtime_menu_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';

// Focused modules for clean architecture separation
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_state.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_stream_manager.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_operations.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_participant_manager.dart';

/// Comprehensive real-time menu collaboration ViewModel providing advanced collaborative menu management through focused module architecture.
///
/// Manages real-time collaborative menu state enabling multi-user menu collaboration with recipe management, participant coordination,
/// permission system, and real-time synchronization while maintaining clean MVVM architecture separation between
/// collaborative menu business logic and UI presentation concerns through focused module delegation.
///
/// **Core Responsibilities:**
/// - Real-time collaborative menu coordination with live synchronization and multi-user conflict resolution
/// - Advanced recipe management operations with optimistic updates and category coordination
/// - Comprehensive participant management with permission system and real-time presence tracking
/// - Connection monitoring with offline handling and automatic synchronization recovery
/// - Swedish localized error messages and user feedback coordination throughout collaborative operations
///
/// **Focused Module Architecture:**
/// This ViewModel delegates responsibilities to specialized modules for maintainable and scalable functionality:
/// - **RealtimeMenuState**: Core state management, status tracking, and error coordination
/// - **RealtimeStreamManager**: Real-time streaming, connection management, and automatic reconnection
/// - **RealtimeMenuOperations**: Recipe operations, optimistic updates, and conflict resolution
/// - **RealtimeParticipantManager**: Participant management, permission system, and presence tracking
class RealtimeMenuViewModel extends ChangeNotifier {
  final RealtimeMenuService _menuService;

  // ===== FOCUSED MODULE ARCHITECTURE =====

  /// Core state management module for menu state coordination and status tracking.
  /// 
  /// Handles collaborative menu state management including loading states, error coordination,
  /// category selection, and UI state management throughout real-time collaboration sessions.
  late final RealtimeMenuState _state;
  
  /// Real-time streaming management module for connection coordination and live updates.
  /// 
  /// Manages real-time menu streaming including connection establishment, automatic reconnection,
  /// stream lifecycle management, and real-time update coordination throughout collaborative sessions.
  late final RealtimeStreamManager _streamManager;
  
  /// Recipe operations management module for collaborative recipe coordination and optimistic updates.
  /// 
  /// Handles recipe management operations including category operations, recipe manipulation,
  /// optimistic updates, and conflict resolution throughout collaborative menu editing.
  late final RealtimeMenuOperations _operations;
  
  /// Participant management module for collaborative user coordination and permission control.
  /// 
  /// Manages participant tracking including user presence monitoring, permission management,
  /// participant coordination, and collaborative access control throughout menu sessions.
  late final RealtimeParticipantManager _participantManager;

  // ===== LEGACY COMPATIBILITY MANAGERS =====

  /// Optimistic update manager for immediate UI feedback and conflict resolution.
  /// 
  /// Provides optimistic update functionality for immediate user feedback while waiting
  /// for real-time synchronization confirmation throughout collaborative operations.
  late final OptimisticUpdateManager _optimisticManager;
  
  /// Participant tracker for real-time presence monitoring and activity coordination.
  /// 
  /// Tracks participant activity including presence status, activity monitoring,
  /// and collaborative user coordination throughout real-time menu sessions.
  late final ParticipantTracker _participantTracker;
  
  /// Connection monitor for network status tracking and offline handling.
  /// 
  /// Monitors network connectivity including connection status tracking, offline detection,
  /// and connection recovery coordination throughout collaborative sessions.
  late final ConnectionMonitor _connectionMonitor;

  /// Initializes real-time menu ViewModel with comprehensive service integration and focused module architecture.
  /// 
  /// [menuService] RealtimeMenuService instance for collaborative menu operations and real-time coordination
  /// [syncService] RealtimeSyncService instance for synchronization management and connection coordination
  /// [authService] AuthService instance for user authentication and permission management
  /// 
  /// Establishes collaborative menu infrastructure with service integration and focused module delegation,
  /// enabling comprehensive real-time menu functionality with participant management, recipe operations,
  /// and synchronization coordination through clean architecture separation and unified state management.
  /// 
  /// **Initialization Process:**
  /// 1. **Legacy Manager Setup**: Initialize compatibility managers for optimistic updates and tracking
  /// 2. **Focused Module Integration**: Initialize specialized modules for state, streaming, operations, and participants
  /// 3. **Event Handler Configuration**: Establish event handlers for real-time updates and state transitions
  /// 4. **Service Integration**: Connect menu service with listener setup and initialization coordination
  /// 5. **State Synchronization**: Configure state notification forwarding and UI update coordination
  /// 
  /// **Architecture Benefits:**
  /// - Clean separation of concerns through focused module delegation
  /// - Maintainable and testable collaborative functionality
  /// - Scalable real-time menu management with modular design
  /// - Comprehensive error handling and state management coordination
  RealtimeMenuViewModel({
    required RealtimeMenuService menuService,
    required RealtimeSyncService syncService,
    required AuthService authService,
  }) : _menuService = menuService {
    
    // Initialize legacy compatibility managers for optimistic updates and tracking
    _optimisticManager = OptimisticUpdateManager(onUpdated: notifyListeners);
    _participantTracker = ParticipantTracker(onUpdated: notifyListeners);
    _connectionMonitor = ConnectionMonitor(
      syncService: syncService,
      onConnectionChanged: _onConnectionChanged,
    );

    // Initialize focused modules with service integration and event coordination
    _state = RealtimeMenuState();
    
    _streamManager = RealtimeStreamManager(
      menuService: _menuService,
      onMenuUpdated: _onMenuUpdated,
      onMenuError: _onMenuError,
      onStreamStarted: () => _state.transitionToWatching(),
      onStreamStopped: () => _state.setStatus(RealtimeMenuStatus.idle),
    );
    
    _operations = RealtimeMenuOperations(
      menuService: _menuService,
      optimisticManager: _optimisticManager,
    );
    
    _participantManager = RealtimeParticipantManager(
      menuService: _menuService,
      participantTracker: _participantTracker,
    );

    // Configure state notification forwarding for UI synchronization
    _state.addListener(() => notifyListeners());

    _initialize();
  }

  // ===== COLLABORATIVE MENU STATE ACCESSORS =====

  /// Current collaborative menu for real-time editing and participant coordination.
  /// 
  /// Provides access to active collaborative menu enabling recipe management,
  /// participant coordination, and real-time synchronization throughout collaborative sessions.
  RealtimeMenu? get currentMenu => _state.currentMenu;
  
  /// Real-time menu status for connection monitoring and state management coordination.
  /// 
  /// Indicates current collaborative session status including loading, watching, offline,
  /// and error states for comprehensive UI state management and user feedback.
  RealtimeMenuStatus get status => _state.status;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout collaborative menu operations and real-time functionality.
  String? get errorMessage => _state.errorMessage;
  
  /// Selected category for focused recipe display and management coordination.
  /// 
  /// Provides current category selection enabling focused recipe display
  /// and category-specific operations throughout collaborative menu editing.
  String? get selectedCategory => _state.selectedCategory;
  
  /// Participant panel visibility for UI state management and social coordination.
  /// 
  /// Indicates whether participant panel is visible enabling UI layout management
  /// and participant visibility control throughout collaborative sessions.
  bool get showParticipants => _state.showParticipants;
  
  /// Loading state for UI progress indication during collaborative operations.
  /// 
  /// Indicates active loading operations for progress display and interaction
  /// control during menu initialization and collaborative synchronization.
  bool get isLoading => _state.isLoading;
  
  /// Unsaved changes indicator for data protection and user feedback.
  /// 
  /// Indicates presence of optimistic updates pending synchronization enabling
  /// unsaved changes warnings and data protection throughout collaborative editing.
  bool get hasUnsavedChanges => _operations.hasOptimisticChanges;
  
  /// Available menu categories for recipe organization and navigation coordination.
  /// 
  /// Provides complete list of menu categories enabling category navigation,
  /// recipe organization, and menu structure display throughout collaborative functionality.
  List<String> get categories => _state.categories;

  // ===== CONNECTION STATUS ACCESSORS =====

  /// Network connectivity status for offline handling and connection monitoring.
  /// 
  /// Indicates current network connectivity enabling offline mode handling
  /// and connection status feedback throughout collaborative sessions.
  bool get isOnline => _connectionMonitor.isOnline;
  
  /// Connection status description for user feedback and network state display.
  /// 
  /// Provides detailed connection status information enabling user feedback
  /// and network connectivity awareness throughout collaborative functionality.
  String get connectionStatusDescription => _connectionMonitor.statusDescription;
  
  /// Connection status emoji for visual feedback and enhanced user experience.
  /// 
  /// Provides visual connection status indicators enabling enhanced UI feedback
  /// and user-friendly connection status display throughout collaborative sessions.
  String get connectionStatusEmoji => _connectionMonitor.statusEmoji;

  // ===== PERMISSION SYSTEM ACCESSORS =====

  /// Current authenticated user ID for permission validation and ownership tracking.
  /// 
  /// Provides current user identification enabling permission checking,
  /// ownership validation, and user-specific functionality throughout collaborative operations.
  String? get currentUserId => _participantManager.currentUserId;
  
  /// Edit permission for recipe modification and content management functionality.
  /// 
  /// Indicates whether current user has edit permission for collaborative menu modification
  /// enabling recipe editing controls and content management capabilities.
  bool get canEdit => currentMenu != null && _participantManager.canEdit(currentMenu!.id);
  
  /// Participant management permission for collaborative administration and member control.
  /// 
  /// Indicates whether current user has participant management permission enabling
  /// member invitation, removal, and collaborative administration functionality.
  bool get canManageParticipants => currentMenu != null && 
      _participantManager.canManageParticipants(currentMenu!.id);

  // ===== PARTICIPANT TRACKING ACCESSORS =====

  /// Active participant count for social awareness and collaboration indication.
  /// 
  /// Provides count of currently active participants enabling social presence display
  /// and collaborative awareness throughout real-time menu sessions.
  int get activeParticipantCount => _participantManager.activeParticipantCount;
  
  /// Participant activities for detailed presence tracking and collaborative coordination.
  /// 
  /// Provides comprehensive participant activity information enabling detailed presence display
  /// and collaborative awareness with activity tracking throughout collaborative sessions.
  List<ParticipantActivity> get participantActivities => _participantManager.participantActivities;
  
  /// Online participants for real-time presence indication and social coordination.
  /// 
  /// Provides list of currently online participants enabling real-time presence display
  /// and social awareness throughout collaborative menu functionality.
  List<String> get onlineParticipants => _participantManager.onlineParticipants;

  // Recipe getters with optimistic updates
  List<Recipe> get selectedCategoryRecipes {
    if (selectedCategory == null) return [];
    
    final baseRecipes = _state.selectedCategoryRecipes;
    return _operations.getRecipesForCategory(selectedCategory!, baseRecipes);
  }

  Map<String, List<Recipe>> get menuWithOptimisticChanges {
    if (currentMenu == null) return {};
    return _operations.applyOptimisticChanges(currentMenu!.menuSnapshot);
  }

  // ===== CORE OPERATIONS (DELEGATE TO STREAM_MANAGER) =====

  Future<void> startWatching(String menuId) async {
    _state.transitionToLoading();
    _state.clearError();

    try {
      await _streamManager.startWatching(menuId);
    } catch (e) {
      _state.transitionToError('Kunde inte starta watching: $e');
      AppLogger.error('❌ Failed to start watching', e);
    }
  }

  Future<void> stopWatching() async {
    await _streamManager.stopWatching();
    _state.resetState();
    AppLogger.info('🛑 Watching stopped');
  }

  // ===== MENU OPERATIONS (DELEGATE TO OPERATIONS) =====

  Future<void> addRecipeToCategory({
    required String categoryName,
    required Recipe recipe,
  }) async {
    if (!_canPerformUpdate()) return;

    try {
      await _operations.addRecipeToCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        recipe: recipe,
      );
    } catch (e) {
      _state.setError('Kunde inte lägga till recept: $e');
    }
  }

  Future<void> removeRecipeFromCategory({
    required String categoryName,
    required int recipeIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes = currentMenu?.getRecipesForCategory(categoryName) ?? [];
    
    try {
      await _operations.removeRecipeFromCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte ta bort recept: $e');
    }
  }

  Future<void> moveRecipeBetweenCategories({
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final fromRecipes = currentMenu?.getRecipesForCategory(fromCategory) ?? [];
    final toRecipes = currentMenu?.getRecipesForCategory(toCategory) ?? [];

    try {
      await _operations.moveRecipeBetweenCategories(
        menuId: currentMenu!.id,
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        fromRecipes: fromRecipes,
        toRecipes: toRecipes,
        toIndex: toIndex,
      );
    } catch (e) {
      _state.setError('Kunde inte flytta recept: $e');
    }
  }

  Future<void> reorderRecipeInCategory({
    required String categoryName,
    required int fromIndex,
    required int toIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes = currentMenu?.getRecipesForCategory(categoryName) ?? [];

    try {
      await _operations.reorderRecipesInCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        fromIndex: fromIndex,
        toIndex: toIndex,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte ändra ordning på recept: $e');
    }
  }

  Future<void> clearCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes = currentMenu?.getRecipesForCategory(categoryName) ?? [];

    try {
      await _operations.clearCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte rensa kategori: $e');
    }
  }

  Future<void> regenerateCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    _state.transitionToUpdating();

    try {
      await _operations.regenerateCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
      );
    } catch (e) {
      _state.setError('Kunde inte regenerera kategori: $e');
    } finally {
      if (_state.status == RealtimeMenuStatus.updating) {
        _state.transitionToWatching();
      }
    }
  }

  // ===== PARTICIPANT OPERATIONS (DELEGATE TO PARTICIPANT_MANAGER) =====

  Future<void> addParticipant({
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return;
    }

    try {
      await _participantManager.addParticipant(
        menuId: currentMenu!.id,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      );
    } catch (e) {
      _state.setError('Kunde inte lägga till deltagare: $e');
    }
  }

  Future<void> removeParticipant(String userId) async {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return;
    }

    try {
      await _participantManager.removeParticipant(
        menuId: currentMenu!.id,
        userId: userId,
      );
    } catch (e) {
      _state.setError('Kunde inte ta bort deltagare: $e');
    }
  }

  // ===== UI STATE MANAGEMENT (DELEGATE TO STATE) =====

  void selectCategory(String? categoryName) => _state.selectCategory(categoryName);
  void toggleParticipants() => _state.toggleParticipants();
  void clearError() => _state.clearError();
  void refreshConnection() => _connectionMonitor.forceConnectionCheck();

  // ===== UTILITY METHODS =====

  Map<String, List<Recipe>>? createPersonalCopy() {
    if (currentMenu == null) return null;
    return _menuService.createPersonalCopy(currentMenu!);
  }

  Future<void> deleteMenu() async {
    if (currentMenu == null || !canManageParticipants) return;

    try {
      await _menuService.deleteRealtimeMenu(currentMenu!.id);
      await stopWatching();
      AppLogger.success('✅ Meny borttagen');
    } catch (e) {
      _state.setError('Kunde inte ta bort meny: $e');
    }
  }

  Future<void> updateBasicInfo({
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    String? originalPrompt,
  }) async {
    if (!_canPerformUpdate()) return;

    _state.transitionToUpdating();

    try {
      await _menuService.updateBasicInfo(
        resourceId: currentMenu!.id,
        menuTitle: menuTitle,
        createdForDate: createdForDate,
        menuNotes: menuNotes,
        originalPrompt: originalPrompt,
      );
      AppLogger.success('✅ Menyinfo uppdaterad');
    } catch (e) {
      _state.setError('Kunde inte uppdatera menyinfo: $e');
    } finally {
      if (_state.status == RealtimeMenuStatus.updating) {
        _state.transitionToWatching();
      }
    }
  }

  // ===== INTERNAL METHODS =====

  void _initialize() {
    _menuService.addListener(_onServiceStateChanged);
  }

  void _onServiceStateChanged() {
    final error = _menuService.lastError;
    if (error != null) {
      _state.setError('Menu service fel: ${error.message}');
    }
  }

  void _onConnectionChanged(bool isOnline) {
    if (!isOnline && _state.status == RealtimeMenuStatus.watching) {
      _state.transitionToOffline();
    } else if (isOnline && _state.status == RealtimeMenuStatus.offline) {
      _state.transitionToWatching();
    }
    notifyListeners();
  }

  void _onMenuUpdated(RealtimeMenu menu) {
    _state.setCurrentMenu(menu);
    
    // Clear optimistic changes when real update arrives
    _operations.clearOptimisticChanges();
    _participantManager.updateFromMenu(menu);

    if (_state.status != RealtimeMenuStatus.watching) {
      _state.transitionToWatching();
    }

    AppLogger.info('📥 Menu updated: ${menu.menuTitle}');
  }

  void _onMenuError(dynamic error) {
    _state.transitionToError('Real-time fel: $error');
    AppLogger.error('❌ Menu watching error', error);
  }

  bool _canPerformUpdate() {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return false;
    }

    if (!canEdit) {
      _state.setError('Ingen redigeringsbehörighet');
      return false;
    }

    if (!isOnline) {
      _state.setError('Ingen internetanslutning');
      return false;
    }

    return true;
  }

  // ===== DISPOSE =====

  @override
  void dispose() {
    AppLogger.info('🗑️ RealtimeMenuViewModel disposing...');

    _streamManager.dispose();
    _menuService.removeListener(_onServiceStateChanged);

    // Dispose focused modules
    _state.dispose();

    // Dispose legacy managers
    _optimisticManager.dispose();
    _participantManager.dispose();
    _connectionMonitor.dispose();

    super.dispose();
  }
}