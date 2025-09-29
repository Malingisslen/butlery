/// Comprehensive unified shopping ViewModel providing advanced shopping list management for Flutter applications.
///
/// This module implements sophisticated shopping list management following Single Responsibility Principle,
/// serving as the main coordinator for all shopping list operations including personal and collaborative lists,
/// item management, bulk operations, and comprehensive analytics. It provides complete shopping functionality
/// while maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles shopping list presentation layer concerns:
/// - **Unified Shopping Coordination**: Comprehensive shopping list management with personal and collaborative list support
/// - **Item Management Excellence**: Advanced item operations including bulk operations, categorization, and search functionality
/// - **Collaborative Shopping**: Real-time collaborative list sharing, member management, and permission coordination
/// - **Analytics and Insights**: Comprehensive shopping analytics, completion tracking, and usage statistics
/// - **Cross-Platform Compatibility**: Unified API maintaining backward compatibility with existing shopping components
///
/// **What This Module Does NOT Handle:**
/// - Direct shopping data persistence (handled by UnifiedShoppingService and specialized data repositories)
/// - UI rendering and widget creation (handled by shopping views and presentation components)
/// - Complex business logic implementation (handled by UnifiedShoppingService and underlying service layer)
/// - Permission system implementation (handled by PermissionService for focused access control)
///
/// **Unified Shopping ViewModel Features:**
/// - **Personal Shopping Lists**: Individual user shopping list creation, management, and organization
/// - **Collaborative Shopping**: Multi-user collaborative lists with member management and real-time synchronization
/// - **Advanced Item Management**: Comprehensive item operations with categorization, priority, and bulk operations
/// - **Shopping Analytics**: Detailed completion tracking, usage statistics, and shopping insights
/// - **Import/Export Functionality**: Recipe ingredient import and list sharing capabilities
///
/// **Usage Examples:**
/// ```dart
/// // Initialize unified shopping ViewModel
/// final shoppingViewModel = UnifiedShoppingViewModel();
/// await shoppingViewModel.initialize();
/// 
/// // Personal shopping list management
/// final personalCreated = await shoppingViewModel.createPersonalList('Veckans Inköp');
/// await shoppingViewModel.setActiveList('list_123');
/// 
/// // Collaborative shopping list creation
/// final collaborativeCreated = await shoppingViewModel.createCollaborativeList(
///   name: 'Familjen Inköpslista',
///   memberIds: ['user1', 'user2', 'user3'],
///   memberDisplayNames: {'user1': 'Anna', 'user2': 'Erik', 'user3': 'Lisa'},
///   allowGuestEditing: true,
///   autoRemoveCompleted: false,
/// );
/// 
/// // Advanced item management
/// final itemAdded = await shoppingViewModel.addItem(
///   name: 'Mjölk',
///   amount: 1.0,
///   unit: 'liter',
///   category: 'Mejeri',
///   note: 'Laktosfri',
///   priority: 4,
/// );
/// 
/// // Bulk operations from recipe ingredients
/// await shoppingViewModel.addItemsFromRecipe([
///   {'name': 'Mjöl', 'amount': 500.0, 'unit': 'g', 'category': 'Bakning'},
///   {'name': 'Ägg', 'amount': 3.0, 'unit': 'st', 'category': 'Mejeri'},
/// ]);
/// 
/// // Item state management
/// await shoppingViewModel.toggleItemBought('item_456');
/// await shoppingViewModel.updateItem(
///   itemId: 'item_789',
///   name: 'Uppdaterat namn',
///   quantity: 2.0,
///   category: 'Ny kategori',
/// );
/// 
/// // Shopping analytics and insights
/// final insights = shoppingViewModel.shoppingInsights;
/// final completion = shoppingViewModel.completionPercentage;
/// final categorizedItems = shoppingViewModel.itemsByCategory;
/// 
/// // Search and filtering
/// final searchResults = shoppingViewModel.searchItems('mjölk');
/// final categories = shoppingViewModel.usedCategories;
/// 
/// // Export functionality
/// final exportedText = shoppingViewModel.exportListAsTextWithCategories();
/// ```

// lib/viewmodels/unified_shopping_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive unified shopping ViewModel providing advanced shopping list management through service coordination.
///
/// Serves as the main presentation layer coordinator for all shopping operations, providing unified API
/// for personal and collaborative shopping lists, item management, analytics, and export functionality
/// while maintaining clean MVVM architecture separation between shopping business logic and UI presentation concerns.
class UnifiedShoppingViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedShoppingService _shoppingService = ServiceLocator.get<UnifiedShoppingService>();

  // ===== SHOPPING LIST STATE ACCESSORS =====

  /// Complete shopping list collection for comprehensive access and management.
  /// 
  /// Provides access to all shopping lists across personal and collaborative categories
  /// for unified shopping management and complete application functionality.
  List<UnifiedShoppingList> get lists => _shoppingService.lists;
  
  /// Personal shopping lists collection for individual user list management.
  /// 
  /// Provides access to user-owned shopping lists for personal shopping operations
  /// and individual meal planning functionality.
  List<UnifiedShoppingList> get personalLists => _shoppingService.personalLists;
  
  /// Collaborative shopping lists collection for social shopping management and sharing.
  /// 
  /// Provides access to shared and collaborative shopping lists for family and group
  /// shopping coordination and collaborative meal planning functionality.
  List<UnifiedShoppingList> get collaborativeLists => _shoppingService.collaborativeLists;
  
  /// Currently active shopping list for focused shopping operations and item management.
  /// 
  /// Provides access to the selected shopping list for item operations, analytics,
  /// and focused shopping functionality throughout the application.
  UnifiedShoppingList? get activeList => _shoppingService.activeList;
  
  /// Items in active shopping list for display and management operations.
  /// 
  /// Provides direct access to shopping items in the currently active list
  /// for item display, management, and shopping completion tracking.
  List<UnifiedShoppingItem> get items => activeList?.items ?? [];

  // ===== LOADING AND SYNCHRONIZATION STATE =====

  /// Loading operation state for UI progress indication and interaction control.
  /// 
  /// Indicates active loading operations for UI loading indicators and user interaction
  /// management during shopping data retrieval and synchronization processes.
  bool get isLoading => _shoppingService.isLoading;
  
  /// Synchronization state for data consistency indication and offline coordination.
  /// 
  /// Indicates active synchronization between local and remote data sources
  /// for data consistency management and offline shopping functionality.
  bool get isSyncing => _shoppingService.isSyncing;
  
  /// Initialization state for application readiness and feature availability.
  /// 
  /// Indicates whether shopping service is fully initialized and ready for operations,
  /// enabling UI feature activation and shopping functionality availability.
  bool get isInitialized => _shoppingService.isInitialized;

  // ===== ERROR HANDLING AND CONNECTIVITY =====

  /// Current error message for user feedback and error state management.
  /// 
  /// Delegates to UnifiedShoppingService for centralized error handling with localized
  /// Swedish error messages for comprehensive user feedback and error recovery.
  String? get error => _shoppingService.error;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Provides boolean error state check for UI error display decisions
  /// and error state management throughout shopping operations.
  bool get hasError => _shoppingService.hasError;

  /// Online connectivity status for feature availability and user guidance.
  /// 
  /// Combines initialization and error states to indicate application connectivity
  /// and feature availability for user interface adaptation and functionality guidance.
  bool get isOnline => !hasError && isInitialized;

  // ===== SHOPPING LIST AVAILABILITY AND STATISTICS =====

  /// Shopping list availability indicator for UI conditional display and feature enabling.
  /// 
  /// Indicates whether any shopping lists are available for display and operations,
  /// enabling UI conditional rendering and shopping-dependent feature activation.
  bool get hasLists => _shoppingService.hasLists;
  
  /// Shopping items availability for active list feature enabling and UI coordination.
  /// 
  /// Indicates whether active list contains items for item-dependent feature
  /// activation and shopping completion functionality.
  bool get hasItems => items.isNotEmpty;

  // ===== SHOPPING ANALYTICS AND COMPLETION TRACKING =====

  /// Total item count in active list for statistics display and completion tracking.
  /// 
  /// Provides total number of items in active shopping list for analytics display
  /// and shopping progress calculations.
  int get totalItems => activeList?.totalItems ?? 0;
  
  /// Purchased item count for completion tracking and progress indication.
  /// 
  /// Provides number of purchased items for shopping completion progress
  /// and shopping analytics functionality.
  int get boughtItems => activeList?.boughtItems ?? 0;
  
  /// Remaining item count for shopping progress and completion tracking.
  /// 
  /// Provides number of unpurchased items for shopping progress indication
  /// and remaining shopping task management.
  int get unboughtItems => activeList?.unboughtItems ?? 0;
  
  /// Shopping completion percentage for progress indication and analytics.
  /// 
  /// Calculates completion percentage for shopping progress bars and
  /// completion analytics display throughout the application.
  double get completionPercentage => activeList?.completionPercentage ?? 0.0;
  
  /// Active list summary for display and status indication.
  /// 
  /// Provides formatted summary of active shopping list status for UI display
  /// and shopping overview functionality.
  String get listSummary => activeList?.summary ?? 'Ingen aktiv lista';
  
  /// Complete shopping indicator for completion celebration and status management.
  /// 
  /// Indicates whether all items in active list are purchased for completion
  /// celebration and shopping task completion functionality.
  bool get allItemsBought => activeList?.allItemsBought ?? false;

  // ===== USER CONTEXT AND IDENTIFICATION =====

  /// Current user identifier for permission management and operation coordination.
  /// 
  /// Provides current user ID for permission validation, operation attribution,
  /// and user-specific functionality throughout shopping management operations.
  String? get currentUserId => ServiceLocator.get<PermissionService>().currentUserId;
  
  /// Current user display name for UI personalization and collaborative interaction.
  /// 
  /// Provides user display name for UI personalization, collaborative features,
  /// and social interaction display throughout the shopping application.
  String? get currentUserDisplayName => _shoppingService.currentUserDisplayName;

  /// Initializes unified shopping ViewModel with comprehensive service integration and reactive coordination.
  /// 
  /// Establishes shopping service integration with reactive state coordination, enabling
  /// comprehensive shopping list management with automatic state synchronization and UI updates
  /// for optimal user experience and responsive shopping functionality.
  /// 
  /// **Initialization Process:**
  /// - Shopping service listener setup for reactive state management
  /// - State synchronization coordination for unified shopping operations
  /// - UI notification system preparation for responsive updates
  UnifiedShoppingViewModel() {
    // Establish reactive service state synchronization
    _shoppingService.addListener(_onServiceUpdate);
  }

  /// Handles unified state updates from shopping service with comprehensive coordination.
  /// 
  /// Provides centralized state synchronization for all shopping operations ensuring
  /// UI components receive immediate updates when shopping service changes state,
  /// maintaining reactive consistency across the entire shopping management system.
  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== COMPREHENSIVE INITIALIZATION =====

  /// Initializes unified shopping system with comprehensive service coordination and default list creation.
  /// 
  /// Performs complete system initialization including service initialization, data loading,
  /// and default list creation for new users. Includes comprehensive error handling
  /// and automatic default list setup for improved user experience.
  /// 
  /// **Initialization Process:**
  /// - UnifiedShoppingService initialization with data loading
  /// - User authentication and permission validation
  /// - Default shopping list creation for new users
  /// - Error handling and recovery coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final viewModel = UnifiedShoppingViewModel();
  /// await viewModel.initialize();
  /// // System ready for all shopping operations
  /// ```
  Future<void> initialize() async {
    await safeExecute(
      () async {
        await _shoppingService.initialize();
      },
      operationName: 'Initialize unified shopping system',
    );
  }

  // ===== PERSONAL SHOPPING LIST MANAGEMENT =====

  /// Creates personal shopping list with comprehensive validation and Swedish localization.
  /// 
  /// [name] Shopping list name for identification and display
  /// 
  /// Returns true if list creation succeeds, false if validation fails or creation errors occur.
  /// Performs personal shopping list creation through service coordination with validation,
  /// data processing, and state synchronization for complete shopping list management.
  /// 
  /// **Creation Process:**
  /// - Name validation with trimming and empty check
  /// - Personal shopping list creation through service
  /// - State synchronization and UI notification
  /// - Error handling with user feedback
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final created = await shoppingViewModel.createPersonalList('Veckans Inköp');
  /// if (created) {
  ///   // List created successfully, update UI
  /// }
  /// ```
  Future<bool> createPersonalList(String name) async {
    if (name.trim().isEmpty) return false;

    final listId = await _shoppingService.createPersonalList(name.trim());
    return listId != null;
  }

  /// Creates collaborative shopping list with comprehensive member management and permission coordination.
  /// 
  /// [name] Shopping list name for identification and collaborative display
  /// [description] Optional detailed description for collaborative context
  /// [memberIds] List of user IDs for collaborative access and member management
  /// [memberDisplayNames] User ID to display name mapping for collaborative UI
  /// [items] Optional initial items for list pre-population
  /// [categoryIds] Category assignments for collaborative organization
  /// [allowGuestEditing] Whether non-members can edit collaborative list
  /// [autoRemoveCompleted] Whether completed items are automatically removed
  /// 
  /// Returns true if collaborative list creation succeeds, false if validation or creation fails.
  /// Performs collaborative shopping list creation through service coordination with member validation,
  /// permission setup, and comprehensive collaborative feature configuration.
  /// 
  /// **Collaborative Creation Process:**
  /// - Name and member validation with comprehensive checks
  /// - Collaborative shopping list creation with member coordination
  /// - Permission system initialization for collaborative access
  /// - Collaborative feature configuration and settings
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final collaborativeCreated = await shoppingViewModel.createCollaborativeList(
  ///   name: 'Familjen Inköpslista',
  ///   description: 'Veckohandling för hela familjen',
  ///   memberIds: ['user1', 'user2', 'user3'],
  ///   memberDisplayNames: {
  ///     'user1': 'Anna Andersson',
  ///     'user2': 'Erik Svensson', 
  ///     'user3': 'Lisa Johansson'
  ///   },
  ///   allowGuestEditing: true,
  ///   autoRemoveCompleted: false,
  /// );
  /// ```
  Future<bool> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    if (name.trim().isEmpty) return false;

    final listId = await _shoppingService.createCollaborativeList(
      name: name.trim(),
      description: description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );

    return listId != null;
  }

  /// Renames active shopping list with comprehensive validation and state coordination.
  /// 
  /// [newName] New shopping list name for identification and display
  /// 
  /// Returns true if rename operation succeeds, false if validation fails or no active list.
  /// Performs active list renaming through service coordination with validation,
  /// state synchronization, and UI notification for complete list management.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final renamed = await shoppingViewModel.renameActiveList('Nytt Listnamn');
  /// ```
  Future<bool> renameActiveList(String newName) async {
    if (activeList == null || newName.trim().isEmpty) return false;
    return await _shoppingService.renameList(activeList!.id, newName.trim());
  }

  /// Deletes active shopping list with comprehensive validation and cleanup coordination.
  /// 
  /// Returns true if deletion succeeds, false if no active list or operation fails.
  /// Performs active list deletion through service coordination with state cleanup,
  /// UI notification, and active list reset for complete shopping list management.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await shoppingViewModel.deleteActiveList();
  /// if (deleted) {
  ///   // Active list deleted, update UI to show list selection
  /// }
  /// ```
  Future<bool> deleteActiveList() async {
    if (activeList == null) return false;
    return await _shoppingService.deleteList(activeList!.id);
  }

  /// Sets active shopping list with comprehensive validation and state coordination.
  /// 
  /// [listId] Shopping list identifier for activation
  /// 
  /// Returns true if activation succeeds, false if list not found or operation fails.
  /// Performs shopping list activation through service coordination with state updates,
  /// UI synchronization, and feature activation for focused shopping operations.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final activated = await shoppingViewModel.setActiveList('list_123');
  /// if (activated) {
  ///   // List activated, items now available for management
  /// }
  /// ```
  Future<bool> setActiveList(String listId) async {
    return await _shoppingService.setActiveList(listId);
  }

  // ===== BACKWARD COMPATIBILITY API METHODS =====

  /// Loads all shopping lists for shopping list selector API compatibility.
  /// 
  /// Performs comprehensive list loading through service coordination for
  /// shopping list selector functionality and UI population.
  Future<void> loadLists() async {
    await _shoppingService.loadLists();
  }

  /// Creates shopping list for shopping list selector API compatibility.
  /// 
  /// [name] Shopping list name for creation
  /// 
  /// Returns true if creation succeeds. Delegates to createPersonalList
  /// for backward compatibility with existing shopping list selector components.
  Future<bool> createList(String name) async {
    return await createPersonalList(name);
  }

  /// Renames specific shopping list for shopping list actions API compatibility.
  /// 
  /// [listId] Shopping list identifier for renaming
  /// [newName] New name for shopping list identification
  /// 
  /// Returns true if rename succeeds. Provides direct list renaming capability
  /// for shopping list actions and management components.
  Future<bool> renameList(String listId, String newName) async {
    return await _shoppingService.renameList(listId, newName);
  }

  /// Deletes specific shopping list for shopping list actions API compatibility.
  /// 
  /// [listId] Shopping list identifier for deletion
  /// 
  /// Returns true if deletion succeeds. Provides direct list deletion capability
  /// for shopping list actions and management components.
  Future<bool> deleteList(String listId) async {
    return await _shoppingService.deleteList(listId);
  }

  /// Exports shopping list for shopping list actions API compatibility.
  /// 
  /// Returns formatted text representation of active shopping list.
  /// Delegates to exportListAsText for backward compatibility with
  /// existing export functionality and sharing components.
  String exportList() {
    return exportListAsText();
  }

  /// Adds bulk items to specific shopping list using optimized batch operations.
  /// 
  /// [listId] Target shopping list identifier for item addition
  /// [items] List of shopping items for bulk addition
  /// 
  /// Returns true if bulk addition succeeds, false if operation fails.
  /// Uses Firebase batch operations for better performance and atomic operations.
  /// 
  /// **Optimized Bulk Addition Process:**
  /// - Target list activation for focused operations
  /// - Single batch Firebase operation for all items
  /// - Atomic transaction ensuring data consistency
  /// - Single UI notification after completion
  Future<bool> addItemsToList(String listId, List<UnifiedShoppingItem> items) async {
    // Activate target list for focused operations
    await setActiveList(listId);
    
    // Use optimized batch operation instead of individual item additions
    return await _shoppingService.addItemsBatch(items);
  }

  // ===== ITEM MANAGEMENT - BÅDA API:ER för kompatibilitet =====

  /// Lägg till artikel (original API)
  Future<bool> addItem({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    if (name.trim().isEmpty) {
      return false;
    }
    
    // ULTRATHINK PHASE 13A: Enhanced permission checking
    AppLogger.info('Starting addItem for "${name.trim()}" to list: ${activeList?.name}');
    
    if (!canEditActiveList) {
      AppLogger.error('PERMISSION DENIED - User cannot edit active list');
      return false;
    }

    try {
      final result = await _shoppingService.addItemToActiveList(
        name: name.trim(),
        amount: amount,
        unit: unit,
        category: category,
        note: note,
        estimatedPrice: estimatedPrice,
        priority: priority,
      );
      
      if (result) {
        AppLogger.success('Successfully added item "${name.trim()}" to list');
      } else {
        AppLogger.error('Failed to add item "${name.trim()}" to list');
      }
      
      return result;
    } catch (e) {
      AppLogger.error('Exception while adding item: $e');
      return false;
    }
  }

  /// ✅ NY: Lägg till artikel (ShoppingListSelector API)
  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    return await addItem(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  Future<bool> toggleItemBought(String itemId) async {
    // ULTRATHINK FIX: Check permissions before allowing edit operations
    if (!canEditActiveList) {
      AppLogger.warning('PERMISSION DENIED: User cannot edit active list');
      return false;
    }
    
    return await _shoppingService.toggleItemBought(itemId);
  }

  Future<bool> removeItem(String itemId) async {
    // ULTRATHINK FIX: Check permissions before allowing edit operations
    if (!canEditActiveList) {
      AppLogger.warning('PERMISSION DENIED: User cannot edit active list');
      return false;
    }
    
    return await _shoppingService.removeItemFromActiveList(itemId);
  }

  /// Restore a deleted item to the active list
  Future<bool> restoreItem(UnifiedShoppingItem item) async {
    return await _shoppingService.addItemToActiveList(
      name: item.name,
      amount: item.amount,
      unit: item.unit,
      category: item.category,
      note: item.note,
      priority: item.priority,
    );
  }

  /// Update an existing item in the active list
  Future<bool> updateItem({
    required String itemId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? notes,
    double? estimatedPrice,
    int? priority,
  }) async {
    // ULTRATHINK FIX: Check permissions before allowing edit operations
    if (!canEditActiveList) {
      AppLogger.warning('PERMISSION DENIED: User cannot edit active list');
      return false;
    }
    
    return await _shoppingService.updateItemInActiveList(
      itemId: itemId,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      notes: notes,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  /// ✅ NY: Ta bort artikel (alias för kompatibilitet)
  Future<bool> removeItemFromActiveList(String itemId) async {
    return await removeItem(itemId);
  }

  Future<bool> clearBoughtItems() async {
    return await _shoppingService.clearBoughtItems();
  }

  Future<bool> uncheckAllItems() async {
    return await _shoppingService.uncheckAllItems();
  }

  // ===== ADVANCED ITEM OPERATIONS =====

  /// Bulk add items (för recept-import)
  Future<bool> addItemsFromRecipe(
      List<Map<String, dynamic>> ingredientData) async {
    return await safeExecute(
      () async {
        for (final ingredient in ingredientData) {
          await addItem(
            name: ingredient['name'] as String,
            amount: (ingredient['amount'] as num).toDouble(),
            unit: ingredient['unit'] as String? ?? '',
            category: ingredient['category'] as String? ?? 'Övrigt',
          );
        }
        return true;
      },
      operationName: 'Add items from recipe',
    ) ?? false;
  }

  /// Gruppera items efter kategori - för UI rendering
  Map<String, List<UnifiedShoppingItem>> get itemsByCategory {
    final Map<String, List<UnifiedShoppingItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Sortera kategorier och items
    final sortedGrouped = <String, List<UnifiedShoppingItem>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedItems = grouped[key]!;
      sortedItems.sort((a, b) {
        // Oköpta först, sedan alfabetiskt
        if (a.bought != b.bought) {
          return a.bought ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
      sortedGrouped[key] = sortedItems;
    }

    return sortedGrouped;
  }

  /// Få lista över alla använda kategorier
  List<String> get usedCategories {
    final categories = items.map((item) => item.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Sök i items
  List<UnifiedShoppingItem> searchItems(String query) {
    if (query.trim().isEmpty) return items;

    final lowercaseQuery = query.toLowerCase();
    return items
        .where((item) =>
            item.name.toLowerCase().contains(lowercaseQuery) ||
            item.category.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  // ===== COLLABORATIVE FEATURES =====

  /// Kontrollera om användaren kan redigera aktiv lista
  bool get canEditActiveList {
    if (activeList == null || currentUserId == null) {
      AppLogger.warning('canEditActiveList - activeList: ${activeList?.name}, currentUserId: $currentUserId');
      return false;
    }
    
    // ULTRATHINK PHASE 13A FIX: Use correct DI system
    final permissionService = ServiceLocator.get<PermissionService>();
    final canEdit = permissionService.canEditShoppingList(activeList!.id);
    
    AppLogger.info('Permission check - List: ${activeList!.name} (${activeList!.type}), User: $currentUserId, CanEdit: $canEdit');
    
    return canEdit;
  }

  /// Kontrollera om användaren kan hantera aktiv lista
  bool get canManageActiveList {
    if (activeList == null || currentUserId == null) return false;
    
    // ULTRATHINK PHASE 13A FIX: Use correct DI system
    return ServiceLocator.get<PermissionService>().canManageShoppingList(activeList!.id);
  }

  /// Få medlemmar i aktiv lista
  List<String> get activeListMembers {
    if (activeList == null || !activeList!.isCollaborative) return [];
    return activeList!.memberPermissions.keys.toList();
  }

  // ===== ERROR HANDLING =====

  void clearError() {
    _shoppingService.clearError();
  }

  // ===== ANALYTICS & INSIGHTS =====

  /// Få shopping insights för UI
  Map<String, dynamic> get shoppingInsights {
    if (activeList == null) return {};

    return {
      'totalItems': totalItems,
      'boughtItems': boughtItems,
      'completionPercentage': completionPercentage,
      'isCollaborative': activeList!.isCollaborative,
      'memberCount': activeList!.memberCount,
      'lastActivity': activeList!.activitySummary,
      'hasRecentActivity': activeList!.hasRecentActivity,
      'categories': usedCategories.length,
      'priorityItems': items.where((item) => item.priority > 3).length,
    };
  }

  /// ✅ NY: Export lista som text - för delning (ShoppingListSelector API)
  String exportListAsText() {
    return _shoppingService.exportListAsText();
  }

  /// Export lista som text med kategorier - för UI
  String exportListAsTextWithCategories() {
    if (activeList == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('📝 ${activeList!.name}');
    buffer.writeln('');

    final grouped = itemsByCategory;
    for (final category in grouped.keys) {
      buffer.writeln('🏷️ $category:');
      for (final item in grouped[category]!) {
        final check = item.bought ? '✅' : '⬜';
        buffer.writeln('  $check ${item.displayText}');
      }
      buffer.writeln('');
    }

    buffer.writeln('📊 ${activeList!.summary}');
    return buffer.toString();
  }

  // ===== STATE MANAGEMENT =====

  @override
  void dispose() {
    _shoppingService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  // ===== DEBUGGING & DEVELOPMENT =====

  /// Debug info för utveckling
  Map<String, dynamic> get debugInfo {
    return {
      'listsCount': lists.length,
      'personalListsCount': personalLists.length,
      'collaborativeListsCount': collaborativeLists.length,
      'activeListId': activeList?.id,
      'isInitialized': isInitialized,
      'isLoading': isLoading,
      'hasError': hasError,
      'error': error,
      'currentUserId': currentUserId,
      'serviceState': {
        'isOnline': isOnline,
        'isSyncing': isSyncing,
      },
    };
  }

  void printDebugInfo() {
    debugPrint('=== UNIFIED SHOPPING DEBUG INFO ===');
    debugInfo.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=====================================');
  }
}
