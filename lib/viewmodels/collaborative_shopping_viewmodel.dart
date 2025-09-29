/// Comprehensive collaborative shopping ViewModel providing advanced real-time shopping coordination for Flutter applications.
///
/// This module implements sophisticated collaborative shopping functionality following Single Responsibility Principle,
/// providing complete real-time shopping list management including item synchronization, collaborative editing,
/// permission management, and progress tracking. It enables multiple users to collaborate on shopping lists
/// with real-time updates and comprehensive state management.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles collaborative shopping presentation layer concerns:
/// - **Real-Time Shopping Coordination**: Advanced collaborative shopping list management with real-time item synchronization
/// - **Item Management Excellence**: Complete shopping item operations including adding, editing, completion tracking, and state management
/// - **Permission System Integration**: Comprehensive permission validation ensuring proper access control and collaboration security
/// - **Progress Tracking Intelligence**: Advanced completion tracking with progress visualization and status management
/// - **Activity Monitoring Features**: Real-time activity tracking enabling collaboration awareness and coordination
///
/// **What This Module Does NOT Handle:**
/// - Direct shopping data persistence (handled by UnifiedShoppingService and shopping data repositories)
/// - UI rendering and widget creation (handled by collaborative shopping views and presentation components)
/// - Complex business logic implementation (handled by shopping services and underlying business layer)
/// - Real-time synchronization infrastructure (handled by real-time services and synchronization systems)
///
/// **Collaborative Shopping ViewModel Features:**
/// - **Multi-User Shopping Lists**: Complete collaborative shopping list management with real-time synchronization
/// - **Item Coordination System**: Advanced shopping item management with collaborative editing and state synchronization
/// - **Permission Management**: Comprehensive access control ensuring proper collaboration permissions and security
/// - **Progress Visualization**: Real-time completion tracking with progress indicators and status management
/// - **Swedish Localization**: Complete Swedish language support for shopping coordination and user feedback
///
/// **Usage Examples:**
/// ```dart
/// // Initialize collaborative shopping ViewModel with list ID
/// final collaborativeShoppingViewModel = CollaborativeShoppingViewModel(
///   listId: 'shared_shopping_list_123',
///   shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
/// );
/// 
/// // Shopping list management and item operations
/// await collaborativeShoppingViewModel.addItem('Mjölk 1L');
/// await collaborativeShoppingViewModel.toggleItemCompletion('item_123');
/// final completion = collaborativeShoppingViewModel.completionPercentage;
/// 
/// // Real-time state monitoring
/// if (collaborativeShoppingViewModel.hasData) {
///   final listTitle = collaborativeShoppingViewModel.listTitle;
///   final activeItems = collaborativeShoppingViewModel.activeItems;
///   final completedItems = collaborativeShoppingViewModel.completedItemsList;
/// }
/// 
/// // Permission validation and access control
/// if (collaborativeShoppingViewModel.canEdit) {
///   // User can edit shopping list
/// } else if (collaborativeShoppingViewModel.canView) {
///   // User can view but not edit
/// }
/// 
/// // Progress tracking and status management
/// final statusText = collaborativeShoppingViewModel.statusText;
/// final statusColor = collaborativeShoppingViewModel.getStatusColor();
/// final progressColor = collaborativeShoppingViewModel.getProgressColor();
/// 
/// // Activity monitoring and collaboration awareness
/// final activitySummary = collaborativeShoppingViewModel.activitySummary;
/// final memberCount = collaborativeShoppingViewModel.memberCountText;
/// 
/// // Item display and interaction helpers
/// for (final item in activeItems) {
///   final subtitle = collaborativeShoppingViewModel.getItemSubtitle(item);
///   final trailingWidgets = collaborativeShoppingViewModel.getItemTrailingWidgets(item);
/// }
/// 
/// // List refresh and synchronization
/// await collaborativeShoppingViewModel.refresh();
/// ```

// lib/viewmodels/collaborative_shopping_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';

/// Comprehensive collaborative shopping ViewModel providing advanced real-time shopping coordination through service integration.
///
/// Manages collaborative shopping lists enabling multiple users to coordinate shopping activities with real-time synchronization,
/// item management, permission validation, and progress tracking while maintaining clean MVVM architecture separation
/// between collaborative shopping business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Real-time collaborative shopping list management and item synchronization
/// - Shopping item operations including adding, editing, and completion tracking
/// - Permission validation ensuring proper access control and collaboration security
/// - Progress tracking with completion percentage and status visualization
/// - Activity monitoring enabling collaboration awareness and real-time updates
class CollaborativeShoppingViewModel extends ChangeNotifier 
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;
  
  /// Unique identifier for the collaborative shopping list being managed.
  /// 
  /// Stores the shopping list ID for service operations and state management
  /// throughout the collaborative shopping session.
  final String listId;

  // ===== COLLABORATIVE SHOPPING STATE =====

  /// Current collaborative shopping list data for display and interaction management.
  /// 
  /// Stores the loaded shopping list with items, members, and metadata
  /// for comprehensive collaborative shopping functionality.
  UnifiedShoppingList? _currentList;

  /// Item addition operation state for UI progress indication during collaborative operations.
  /// 
  /// Indicates active item addition for loading indicators and interaction
  /// control during collaborative shopping item management.
  bool _isAddingItem = false;

  /// Last activity description for collaboration awareness and real-time coordination.
  /// 
  /// Stores recent collaborative activity description enabling collaboration
  /// awareness and activity tracking throughout shopping sessions.
  String _lastActivity = '';
  
  /// Last activity timestamp for collaboration timing and activity coordination.
  /// 
  /// Tracks when last collaborative activity occurred enabling time-based
  /// activity display and collaboration coordination.
  DateTime _lastActivityTime = DateTime.now();

  /// Initializes collaborative shopping ViewModel with comprehensive service integration and real-time preparation.
  /// 
  /// [listId] Unique identifier for the collaborative shopping list to manage
  /// [shoppingService] UnifiedShoppingService instance for shopping operations (optional, uses service locator if not provided)
  /// [userService] UserService instance for user management (optional, currently unused but available for future features)
  /// 
  /// Establishes collaborative shopping infrastructure with service integration, enabling comprehensive
  /// real-time shopping functionality with unified state management, permission validation, and activity tracking.
  /// 
  /// **Initialization Process:**
  /// - UnifiedShoppingService integration for shopping operations
  /// - List ID assignment for targeted shopping list management
  /// - Automatic list loading and state preparation
  /// - Real-time activity tracking initialization
  CollaborativeShoppingViewModel({
    required this.listId,
    UnifiedShoppingService? shoppingService,
    UserService? userService,
  }) : _shoppingService = shoppingService ?? ServiceLocator.get<UnifiedShoppingService>() {
    _initialize();
  }

  // ===== STATE ACCESSORS =====

  /// Current collaborative shopping list for display and interaction coordination.
  /// 
  /// Provides access to loaded shopping list data enabling UI rendering
  /// and collaborative shopping functionality with comprehensive list management.
  UnifiedShoppingList? get currentList => _currentList;
  
  /// Item addition operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether item addition operation is in progress for loading indicators
  /// and user interaction management during collaborative shopping operations.
  bool get isAddingItem => _isAddingItem;
  
  /// Shopping list data availability indicator for conditional UI rendering and state management.
  /// 
  /// Indicates whether shopping list data has been successfully loaded
  /// for UI state management and collaborative shopping functionality enablement.
  bool get hasData => _currentList != null;

  // ===== LIST PROPERTIES =====

  /// Shopping list title for display and identification with loading state handling.
  /// 
  /// Provides list title with fallback loading text ensuring consistent
  /// UI display during collaborative shopping list loading operations.
  String get listTitle => _currentList?.name ?? 'Laddar...';
  
  /// Shopping list description for additional context and information display.
  /// 
  /// Provides optional list description enabling enhanced list information
  /// and context display throughout collaborative shopping sessions.
  String get listDescription => _currentList?.description ?? '';
  
  /// Description availability indicator for conditional UI element rendering.
  /// 
  /// Indicates whether list description is available for UI conditional
  /// rendering and enhanced list information display coordination.
  bool get hasDescription => listDescription.isNotEmpty;

  // ===== PERMISSION SYSTEM =====

  /// Edit permission indicator for collaborative shopping list modification operations.
  /// 
  /// Indicates whether current user has edit permissions for collaborative shopping list
  /// enabling proper access control and collaborative security management.
  /// 
  /// **SECURITY**: Now implements proper permission validation!
  bool get canEdit {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canEditShoppingList(listId);
  }
  
  /// View permission indicator for collaborative shopping list access and display.
  /// 
  /// Indicates whether current user has view permissions for collaborative shopping list
  /// enabling proper access control and collaborative security management.
  /// 
  /// **SECURITY**: Now implements proper permission validation!
  bool get canView {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canViewShoppingList(listId);
  }
  
  /// Validates edit permissions for specific shopping list with comprehensive access control.
  /// 
  /// [listId] Shopping list identifier for permission validation
  /// 
  /// Returns true if user has edit permissions, false otherwise.
  /// Performs permission validation ensuring proper collaborative security
  /// and access control throughout shopping list operations.
  /// 
  /// **SECURITY**: Now implements proper permission validation!
  bool canEditShoppingList(String listId) {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canEditShoppingList(listId);
  }
  
  /// Validates view permissions for specific shopping list with comprehensive access control.
  /// 
  /// [listId] Shopping list identifier for permission validation
  /// 
  /// Returns true if user has view permissions, false otherwise.
  /// Performs permission validation ensuring proper collaborative security
  /// and access control throughout shopping list operations.
  /// 
  /// **SECURITY**: Now implements proper permission validation!
  bool canViewShoppingList(String listId) {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canViewShoppingList(listId);
  }

  // ===== PROGRESS TRACKING =====

  /// Total shopping items count for progress calculation and status display.
  /// 
  /// Provides total number of items in collaborative shopping list
  /// enabling progress tracking and completion percentage calculations.
  int get totalItems => _currentList?.totalItems ?? 0;
  
  /// Completed shopping items count for progress tracking and visualization.
  /// 
  /// Provides number of purchased/completed items in collaborative shopping list
  /// enabling progress visualization and completion status management.
  int get completedItems => _currentList?.boughtItems ?? 0;
  
  /// Completed items count alias for consistent API and progress display.
  /// 
  /// Provides alternative accessor for completed items count ensuring
  /// consistent API usage throughout collaborative shopping functionality.
  int get completedItemsCount => completedItems;
  
  /// Shopping list completion percentage for progress visualization and status tracking.
  /// 
  /// Calculates completion percentage based on purchased vs total items
  /// enabling progress bars, status indicators, and completion visualization.
  double get completionPercentage =>
      totalItems > 0 ? (completedItems.toDouble() / totalItems.toDouble()) * 100.0 : 0.0;

  // ===== ITEM COLLECTIONS =====

  /// Active shopping items collection for display and interaction management.
  /// 
  /// Filters shopping list items to show only non-purchased items
  /// enabling focused shopping experience and active item management.
  List<UnifiedShoppingItem> get activeItems =>
      _currentList?.items.where((item) => !item.bought).toList() ?? [];

  /// Completed shopping items collection for progress display and history tracking.
  /// 
  /// Filters shopping list items to show only purchased items
  /// enabling completion tracking and shopping history display.
  List<UnifiedShoppingItem> get completedItemsList =>
      _currentList?.items.where((item) => item.bought).toList() ?? [];

  // ===== STATUS AND METADATA =====

  /// Shopping list status text with Swedish localization and comprehensive state representation.
  /// 
  /// Provides human-readable status text based on list state including loading,
  /// empty, completed, and active states with Swedish localized descriptions.
  String get statusText {
    if (!hasData) return 'Laddar...';
    if (totalItems == 0) return 'Tom lista';
    if (completedItems == totalItems) return 'Klar';
    return 'Pågående';
  }

  /// Collaborative member count text with Swedish localization and grammatical correctness.
  /// 
  /// Provides formatted member count text with proper Swedish grammar
  /// enabling collaboration awareness and member status display.
  String get memberCountText {
    final count = _currentList?.memberCount ?? 0;
    return '$count ${count == 1 ? 'medlem' : 'medlemmar'}';
  }

  /// Recent activity summary with time formatting and collaboration awareness display.
  /// 
  /// Provides formatted activity summary including last action and timing
  /// enabling collaboration awareness and real-time activity tracking.
  String get activitySummary {
    if (_lastActivity.isEmpty) return 'Ingen aktivitet';
    final timeAgo = _getTimeAgo(_lastActivityTime);
    return '$_lastActivity $timeAgo';
  }

  // ===== INITIALIZATION OPERATIONS =====

  /// Initializes collaborative shopping ViewModel with comprehensive list loading and state preparation.
  /// 
  /// Performs initial setup including list loading, state preparation, and error handling
  /// with async operation coordination ensuring proper collaborative shopping initialization.
  /// 
  /// **Initialization Process:**
  /// - Async operation wrapper for loading state management
  /// - Shopping list loading with comprehensive error handling
  /// - State coordination and UI notification preparation
  Future<void> _initialize() async {
    await executeAsync(() async {
      await _loadList();
    });
  }

  /// Loads collaborative shopping list with comprehensive error handling and state management.
  /// 
  /// Performs shopping list loading from UnifiedShoppingService with list identification,
  /// data validation, and state coordination ensuring proper collaborative shopping list access.
  /// 
  /// **List Loading Process:**
  /// - List identification through UnifiedShoppingService lists collection
  /// - Data validation ensuring list availability and access
  /// - State update with loaded list data and activity tracking
  /// - Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Throws**: Exception if list loading fails or list is not found.
  Future<void> _loadList() async {
    try {
      AppLogger.info('📋 Laddar kollaborativ lista: $listId');

      // Hitta listan i unified service lists
      final targetList = _shoppingService.lists
          .cast<UnifiedShoppingList?>()
          .firstWhere((list) => list?.id == listId, orElse: () => null);

      if (targetList != null) {
        _currentList = targetList;
        _updateActivity('Lista laddad', DateTime.now());
        AppLogger.success('✅ Kollaborativ lista laddad: ${targetList.name}');
      } else {
        AppLogger.error('❌ Kollaborativ lista inte hittad: $listId');
        throw Exception('Lista hittades inte');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av kollaborativ lista', e);
      throw Exception('Kunde inte ladda lista: $e');
    }
  }

  // ===== PUBLIC OPERATIONS =====

  /// Refreshes collaborative shopping list with comprehensive synchronization and state coordination.
  /// 
  /// Performs complete list refresh including data reloading, state synchronization,
  /// and UI coordination ensuring up-to-date collaborative shopping list display.
  /// 
  /// **Refresh Process:**
  /// - Async operation wrapper for loading state management
  /// - Complete list data reloading from service
  /// - State synchronization and UI notification coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await collaborativeShoppingViewModel.refresh();
  /// // List data is now synchronized with latest changes
  /// ```
  Future<void> refresh() async {
    await executeAsync(() async {
      await _loadList();
    });
  }

  /// Adds shopping item to collaborative list with comprehensive validation and synchronization.
  /// 
  /// [itemName] Name of shopping item to add to collaborative list
  /// 
  /// Returns true if item addition succeeds, false if validation fails or operation errors occur.
  /// Performs item addition with permission validation, service integration, state synchronization,
  /// and activity tracking ensuring proper collaborative shopping item management.
  /// 
  /// **Item Addition Process:**
  /// - Input validation and permission checking
  /// - Item addition through UnifiedShoppingService
  /// - State synchronization and list refresh
  /// - Activity tracking and collaboration awareness updates
  /// - Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final success = await collaborativeShoppingViewModel.addItem('Mjölk 1L');
  /// if (success) {
  ///   // Item successfully added to collaborative list
  /// }
  /// ```
  Future<bool> addItem(String itemName) async {
    if (itemName.trim().isEmpty || !canEdit) return false;

    _setAddingItem(true);

    try {
      AppLogger.info('➕ Lägger till artikel: $itemName');

      // Använd unified service för att lägga till artikel
      final success = await _shoppingService.addItemToActiveList(
        name: itemName.trim(),
        amount: 1.0, // Default amount
        unit: '', // Default unit
        category: 'Övrigt', // Default category
      );

      if (success) {
        await _loadList(); // Uppdatera lokal state
        _updateActivity('La till "$itemName"', DateTime.now());
        AppLogger.success('✅ Artikel tillagd: $itemName');
        return true;
      } else {
        setError('Kunde inte lägga till artikel');
        AppLogger.error('❌ Kunde inte lägga till artikel: $itemName');
        return false;
      }
    } catch (e) {
      setError('Fel vid tillägg av artikel: $e');
      AppLogger.error('❌ Exception vid tillägg av artikel', e);
      return false;
    } finally {
      _setAddingItem(false);
    }
  }

  /// Toggles shopping item completion status with comprehensive synchronization and activity tracking.
  /// 
  /// [itemId] Unique identifier of shopping item to toggle completion status
  /// 
  /// Returns true if status toggle succeeds, false if permission denied or operation fails.
  /// Performs completion status toggle with permission validation, service integration,
  /// state synchronization, and activity tracking ensuring proper collaborative shopping coordination.
  /// 
  /// **Status Toggle Process:**
  /// - Permission validation ensuring user can modify item status
  /// - Item identification and current status determination
  /// - Status toggle through UnifiedShoppingService
  /// - State synchronization and list refresh
  /// - Activity tracking with appropriate completion/incomplete messaging
  /// - Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final success = await collaborativeShoppingViewModel.toggleItemCompletion('item_123');
  /// if (success) {
  ///   // Item status successfully toggled in collaborative list
  /// }
  /// ```
  Future<bool> toggleItemCompletion(String itemId) async {
    // ULTRATHINK FIX: Use canEdit for edit operations, not canView
    if (!canEdit) return false;

    try {
      AppLogger.info('🔄 Växlar artikel status: $itemId');

      // Hitta artikeln lokalt
      final item = _currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return false;

      // Använd unified service
      final success = await _shoppingService.toggleItemBought(itemId);

      if (success) {
        await _loadList(); // Uppdatera lokal state
        _updateActivity(
          item.bought ? 'Markerade som klar' : 'Markerade som ej klar',
          DateTime.now(),
        );
        AppLogger.success('✅ Artikel status växlad: $itemId');
        return true;
      } else {
        setError('Kunde inte uppdatera artikel');
        AppLogger.error('❌ Kunde inte växla artikel status: $itemId');
        return false;
      }
    } catch (e) {
      setError('Fel vid uppdatering: $e');
      AppLogger.error('❌ Exception vid växling av artikel status', e);
      return false;
    }
  }

  // ===== UI DISPLAY HELPERS =====

  /// Gets status color based on shopping list state with comprehensive color coordination.
  /// 
  /// Returns appropriate color for current shopping list status enabling consistent
  /// status visualization and color-coded progress indication throughout UI components.
  /// 
  /// **Status Color Mapping:**
  /// - 'Klar' (Complete): Success green color
  /// - 'Pågående' (Active): Warning orange color
  /// - 'Tom lista' (Empty): Medium text gray color
  /// - Loading/Default: Medium text gray color
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final statusColor = collaborativeShoppingViewModel.getStatusColor();
  /// // Use color for status indicators and text styling
  /// ```
  Color getStatusColor() {
    if (!hasData) return AppColors.textMedium;

    switch (statusText) {
      case 'Klar':
        return AppColors.success;
      case 'Pågående':
        return AppColors.warning;
      case 'Tom lista':
        return AppColors.textMedium;
      default:
        return AppColors.textMedium;
    }
  }

  /// Gets progress color based on completion percentage with dynamic color progression.
  /// 
  /// Returns appropriate color for current completion percentage enabling dynamic
  /// progress visualization and color-coded completion indication in progress bars.
  /// 
  /// **Progress Color Mapping:**
  /// - 100% completion: Success green color (fully complete)
  /// - >50% completion: Warning orange color (majority complete)
  /// - ≤50% completion: Primary blue color (getting started)
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final progressColor = collaborativeShoppingViewModel.getProgressColor();
  /// // Use color for progress bars and completion indicators
  /// ```
  Color getProgressColor() {
    if (completionPercentage == 100) return AppColors.success;
    if (completionPercentage > 50) return AppColors.warning;
    return AppColors.primaryBlue;
  }

  /// Generates comprehensive item subtitle with quantity, category, and status information.
  /// 
  /// [item] Shopping item for subtitle generation with detailed information display
  /// 
  /// Returns formatted subtitle string or null if no additional information available.
  /// Creates informative subtitle including quantity, unit, category, and purchase status
  /// with Swedish localization and proper formatting for enhanced item display.
  /// 
  /// **Subtitle Components:**
  /// - Quantity and unit information (when available)
  /// - Category information (excluding default 'Övrigt')
  /// - Purchase status indicator for completed items
  /// - Formatted with bullet separators for readability
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final subtitle = collaborativeShoppingViewModel.getItemSubtitle(item);
  /// if (subtitle != null) {
  ///   // Display subtitle with additional item information
  /// }
  /// ```
  String? getItemSubtitle(UnifiedShoppingItem item) {
    final parts = <String>[];

    // Kvantitet och enhet
    if (item.amount > 1 || item.unit.isNotEmpty) {
      final quantityText = item.amount > 1 ? '${item.amount}' : '';
      final unitText = item.unit.isNotEmpty ? item.unit : '';
      if (quantityText.isNotEmpty || unitText.isNotEmpty) {
        parts.add('$quantityText $unitText'.trim());
      }
    }

    // Kategori
    if (item.category.isNotEmpty && item.category != 'Övrigt') {
      parts.add(item.category);
    }

    // Status info för köpta artiklar
    if (item.bought) {
      parts.add('✓ Inhandlad');
    }

    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  /// Generates trailing widgets for shopping item display with extensible widget architecture.
  /// 
  /// [item] Shopping item for trailing widget generation and interaction options
  /// 
  /// Returns list of widgets for item trailing display including action buttons and status indicators.
  /// Provides extensible architecture for additional item interactions and display options
  /// with future support for edit, delete, and additional collaborative features.
  /// 
  /// **Current Implementation**: Simple implementation with expansion capability for future features.
  /// **Future Enhancements**: Edit buttons, quantity adjusters, category selectors, member indicators.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final trailingWidgets = collaborativeShoppingViewModel.getItemTrailingWidgets(item);
  /// // Use widgets in ListTile trailing or Row widgets
  /// ```
  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) {
    // Enkel implementation - kan utökas med fler widgets
    return [];
  }

  // ===== PRIVATE HELPER OPERATIONS =====

  /// Sets item addition state with comprehensive UI notification and state coordination.
  /// 
  /// [adding] Item addition state for UI progress indication and interaction control
  /// 
  /// Updates item addition state with immediate UI notification enabling
  /// responsive item addition progress indication and user interaction management.
  void _setAddingItem(bool adding) {
    _isAddingItem = adding;
    notifyListeners();
  }

  /// Clears error state with comprehensive state cleanup and UI coordination.
  /// 
  /// Performs error state cleanup with immediate UI notification enabling
  /// proper error recovery and user interaction restoration.
  /// 
  /// **Override Implementation**: Implements StateNotifierMixin error clearing interface.
  @override
  void clearError() {
    setError('');
  }

  /// Updates collaborative activity tracking with comprehensive activity coordination.
  /// 
  /// [activity] Activity description for collaboration awareness and tracking
  /// [time] Activity timestamp for timing coordination and display
  /// 
  /// Records collaborative activity with timestamp enabling collaboration awareness
  /// and activity tracking throughout shopping sessions.
  /// 
  /// **Note**: In full implementation, activity updates would be broadcast to all collaborative users.
  void _updateActivity(String activity, DateTime time) {
    _lastActivity = activity;
    _lastActivityTime = time;
    // Note: I real implementation, detta skulle skickas till andra användare
  }

  /// Formats time duration into Swedish human-readable format with comprehensive time representation.
  /// 
  /// [time] DateTime for relative time calculation and formatting
  /// 
  /// Returns Swedish localized relative time string enabling intuitive time display
  /// and collaboration timing awareness throughout activity tracking.
  /// 
  /// **Time Format Mapping:**
  /// - <1 minute: 'just nu' (just now)
  /// - <1 hour: '[minutes]m sedan' (minutes ago)
  /// - <1 day: '[hours]h sedan' (hours ago)
  /// - ≥1 day: '[days]d sedan' (days ago)
  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'just nu';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m sedan';
    if (difference.inHours < 24) return '${difference.inHours}h sedan';
    return '${difference.inDays}d sedan';
  }

  // ===== MIXIN INTEGRATION =====
  
  /// Mixin methods integration for async operations and state management.
  /// 
  /// **Available Mixin Methods:**
  /// - executeAsync: Provided by AsyncOperationMixin for loading state management
  /// - setError: Provided by StateNotifierMixin for error state coordination
  /// - notifyListeners: Provided by ChangeNotifier for UI notification
  /// 
  /// **Note**: Methods are automatically available through mixin integration.

  // ===== LIFECYCLE MANAGEMENT =====

  /// Disposes collaborative shopping ViewModel with comprehensive cleanup and resource management.
  /// 
  /// Performs complete resource cleanup including state disposal, service cleanup,
  /// and memory management ensuring proper collaborative shopping ViewModel lifecycle management.
  /// 
  /// **Disposal Process:**
  /// - Resource cleanup and memory management
  /// - Service connection cleanup (when implemented)
  /// - State disposal and UI notification cleanup
  /// - Parent disposal coordination through super.dispose()
  @override
  void dispose() {
    AppLogger.info('🗑️ CollaborativeShoppingViewModel disposed');
    super.dispose();
  }
}
