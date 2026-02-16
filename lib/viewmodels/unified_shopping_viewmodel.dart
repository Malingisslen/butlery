/// Unified shopping ViewModel for comprehensive shopping list management.
/// Coordinates personal and collaborative shopping lists, item management,
/// analytics, and export functionality. Delegates specialized operations
/// to focused manager classes while maintaining clean MVVM architecture.
/// **Architecture:**
/// - Main ViewModel: Service coordination, list management, error handling
/// - ShoppingAnalyticsManager: Insights, statistics, export functionality
/// - ShoppingItemOperationsManager: Search, grouping, bulk operations
/// **Usage:**
/// ```dart
/// final viewModel = UnifiedShoppingViewModel();
/// await viewModel.initialize();
/// ```
/// See tests for comprehensive examples.

// lib/viewmodels/unified_shopping_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/shopping/shopping_analytics_manager.dart';
import 'package:butlery/viewmodels/shopping/shopping_item_operations_manager.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Unified shopping ViewModel coordinating shopping operations through service delegation.
class UnifiedShoppingViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService =
      ServiceLocator.get<UnifiedShoppingService>();
  late final ShoppingAnalyticsManager _analyticsManager;
  late final ShoppingItemOperationsManager _itemOpsManager;

  /// All shopping lists (personal + collaborative)
  List<UnifiedShoppingList> get lists => _shoppingService.lists;

  /// Personal shopping lists only
  List<UnifiedShoppingList> get personalLists => _shoppingService.personalLists;

  /// Collaborative shopping lists only
  List<UnifiedShoppingList> get collaborativeLists =>
      _shoppingService.collaborativeLists;

  /// Currently active shopping list
  UnifiedShoppingList? get activeList => _shoppingService.activeList;

  /// Items in active shopping list
  List<UnifiedShoppingItem> get items => activeList?.items ?? [];

  /// Loading operation state
  @override
  bool get isLoading => _shoppingService.isLoading;

  /// Synchronization state
  bool get isSyncing => _shoppingService.isSyncing;

  /// Initialization state
  bool get isInitialized => _shoppingService.isInitialized;

  /// Current error message
  @override
  String? get error => _shoppingService.error;

  /// Error state indicator
  @override
  bool get hasError => _shoppingService.hasError;

  /// Online connectivity status
  bool get isOnline => !hasError && isInitialized;

  /// Shopping list availability indicator
  bool get hasLists => _shoppingService.hasLists;

  /// Shopping items availability
  bool get hasItems => items.isNotEmpty;

  /// Total item count in active list
  int get totalItems => (activeList?.totalItems).orZero();

  /// Purchased item count
  int get boughtItems => (activeList?.boughtItems).orZero();

  /// Remaining item count
  int get unboughtItems => (activeList?.unboughtItems).orZero();

  /// Shopping completion percentage
  double get completionPercentage =>
      (activeList?.completionPercentage).orZero();

  /// Active list summary
  String get listSummary =>
      activeList?.summary ?? AppLocale.current.errorNotFound;

  /// Complete shopping indicator
  bool get allItemsBought => (activeList?.allItemsBought).orFalse();

  /// Current user identifier
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Current user display name
  String? get currentUserDisplayName => _shoppingService.currentUserDisplayName;

  /// Initializes unified shopping ViewModel with service integration and manager setup
  UnifiedShoppingViewModel() {
    _analyticsManager = ShoppingAnalyticsManager(_shoppingService);
    _itemOpsManager = ShoppingItemOperationsManager();
    _shoppingService.addListener(_onServiceUpdate);
  }

  /// Handles state updates from shopping service
  void _onServiceUpdate() {
    notifyListeners();
  }

  /// Initializes unified shopping system
  Future<void> initialize() async {
    await executeAsync(() async {
      await _shoppingService.initialize();
    });
  }

  /// Creates personal shopping list with validation
  Future<bool> createPersonalList(String name) async {
    if (ValidationUtils.isNullOrWhitespace(name)) return false;

    final listId = await _shoppingService.createPersonalList(name.trim());
    return listId != null;
  }

  /// Creates collaborative shopping list with member management
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
    if (ValidationUtils.isNullOrWhitespace(name)) return false;

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

  /// Renames active shopping list
  Future<bool> renameActiveList(String newName) async {
    if (activeList == null || ValidationUtils.isNullOrWhitespace(newName)) {
      return false;
    }
    return await _shoppingService.renameList(activeList!.id, newName.trim());
  }

  /// Deletes active shopping list
  Future<bool> deleteActiveList() async {
    if (activeList == null) return false;
    return await _shoppingService.deleteList(activeList!.id);
  }

  /// Sets active shopping list
  Future<bool> setActiveList(String listId) async {
    return await _shoppingService.setActiveList(listId);
  }

  /// Loads all shopping lists
  Future<void> loadLists() async {
    await _shoppingService.loadLists();
  }

  /// Creates shopping list (delegates to createPersonalList)
  Future<bool> createList(String name) async {
    return await createPersonalList(name);
  }

  /// Create a new shopping list from a template
  Future<void> createListFromTemplate(String templateId) async {
    await _shoppingService.createListFromTemplate(templateId: templateId);
    notifyListeners();
  }

  /// Renames specific shopping list
  Future<bool> renameList(String listId, String newName) async {
    return await _shoppingService.renameList(listId, newName);
  }

  /// Deletes specific shopping list
  Future<bool> deleteList(String listId) async {
    return await _shoppingService.deleteList(listId);
  }

  /// Exports shopping list (delegates to exportListAsText)
  String exportList() {
    return exportListAsText();
  }

  /// Adds bulk items to specific shopping list using batch operations
  Future<bool> addItemsToList(
      String listId, List<UnifiedShoppingItem> items) async {
    await setActiveList(listId);
    return await _shoppingService.addItemsBatch(items);
  }

  /// Add item (original API)
  Future<bool> addItem({
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    if (ValidationUtils.isNullOrWhitespace(name)) {
      return false;
    }

    // ULTRATHINK PHASE 13A: Enhanced permission checking
    AppLogger.info(
        'Starting addItem for "${name.trim()}" to list: ${activeList?.name}');

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

  /// Add item (ShoppingListSelector API)
  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
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

  /// Remove item (alias for compatibility)
  Future<bool> removeItemFromActiveList(String itemId) async {
    return await removeItem(itemId);
  }

  Future<bool> clearBoughtItems() async {
    return await _shoppingService.clearBoughtItems();
  }

  Future<bool> uncheckAllItems() async {
    return await _shoppingService.uncheckAllItems();
  }

  /// Bulk add items from recipe ingredients
  Future<bool> addItemsFromRecipe(
      List<Map<String, dynamic>> ingredientData) async {
    return await executeAsync(() async {
      return _itemOpsManager.addItemsFromRecipe(
        ingredientData,
        ({required name, required amount, required unit, required category}) =>
            addItem(name: name, amount: amount, unit: unit, category: category),
      );
    });
  }

  /// Group items by category for UI rendering
  Map<String, List<UnifiedShoppingItem>> get itemsByCategory =>
      _itemOpsManager.groupItemsByCategory(items);

  /// Get list of all used categories
  List<String> get usedCategories => _itemOpsManager.getUsedCategories(items);

  /// Search items by name or category
  List<UnifiedShoppingItem> searchItems(String query) =>
      _itemOpsManager.searchItems(items, query);

  /// Check if the user can edit the active list
  bool get canEditActiveList {
    if (activeList == null || currentUserId == null) {
      AppLogger.warning(
          'canEditActiveList - activeList: ${activeList?.name}, currentUserId: $currentUserId');
      return false;
    }

    // ULTRATHINK PHASE 13A FIX: Use correct DI system
    final permissionService = ServiceLocator.get<PermissionService>();
    final canEdit = permissionService.canEditShoppingList(activeList!.id);

    AppLogger.info(
        'Permission check - List: ${activeList!.name} (${activeList!.type}), User: $currentUserId, CanEdit: $canEdit');

    return canEdit;
  }

  /// Check if the user can manage the active list
  bool get canManageActiveList {
    if (activeList == null || currentUserId == null) return false;

    // ULTRATHINK PHASE 13A FIX: Use correct DI system
    return ServiceLocator.get<PermissionService>()
        .canManageShoppingList(activeList!.id);
  }

  /// Get members of the active list
  List<String> get activeListMembers {
    if (activeList == null || !activeList!.isCollaborative) return [];
    return activeList!.memberPermissions.keys.toList();
  }

  @override
  void clearError() {
    _shoppingService.clearError();
  }

  /// Get shopping insights for UI
  Map<String, dynamic> get shoppingInsights =>
      _analyticsManager.getShoppingInsights(activeList, items, usedCategories);

  /// Export list as text for sharing
  String exportListAsText() => _analyticsManager.exportListAsText();

  /// Export list as text with categories for UI
  String exportListAsTextWithCategories() => _analyticsManager
      .exportListAsTextWithCategories(activeList, itemsByCategory);
  @override
  void dispose() {
    _shoppingService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  /// Debug info for development
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
    // Debug info printing disabled - use debugInfo getter directly if needed
  }
}
