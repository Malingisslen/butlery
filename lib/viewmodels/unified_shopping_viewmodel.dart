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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/shopping_checkoff_pantry_service.dart';
import 'package:butlery/services/user_service.dart';
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
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Unified shopping ViewModel coordinating shopping operations through service delegation.
class UnifiedShoppingViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService =
      ServiceLocator.get<UnifiedShoppingService>();
  StreamSubscription? _shoppingServiceSubscription;
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
  late final AnalyticsService? _analytics =
      ServiceLocator.tryGet<AnalyticsService>();

  /// BUT-1306: policy seam from checkoff → pantry. Resolved lazily so the
  /// low-level `toggleItemBought` module stays free of service/userId deps —
  /// the VM (which already knows the userId and pre-toggle state) owns the wiring.
  late final ShoppingCheckoffPantryService? _checkoffPantryService =
      ServiceLocator.tryGet<ShoppingCheckoffPantryService>();

  late final UserService? _userService = ServiceLocator.tryGet<UserService>();

  UnifiedShoppingViewModel() {
    _analyticsManager = ShoppingAnalyticsManager(_shoppingService);
    _itemOpsManager = ShoppingItemOperationsManager();
    _shoppingServiceSubscription =
        _shoppingService.stateStream.listen((_) => _onServiceUpdate());
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
    if (listId != null) {
      _analytics?.shopping.logShoppingListCreated(
        listId: listId,
        listType: 'personal',
        initialItemCount: 0,
      );
    }
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

    if (listId != null) {
      _analytics?.shopping.logShoppingListCreated(
        listId: listId,
        listType: 'collaborative',
        initialItemCount: items?.length ?? 0,
      );
    }
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

    // Permission check before modifying list
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
        if (activeList != null) {
          _analytics?.shopping.logShoppingListItemAdded(
            listId: activeList!.id,
            source: 'manual',
          );
        }
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
    if (!canEditActiveList) {
      AppLogger.warning('PERMISSION DENIED: User cannot edit active list');
      return false;
    }

    // Capture the pre-toggle bought-state HERE (the layer that has it) so the
    // pantry policy seam can be fed a faithful wasBought without the low-level
    // module having to grow service/userId dependencies (BUT-1306).
    final wasBought = items.where((i) => i.id == itemId).firstOrNull?.bought;

    final result = await _shoppingService.toggleItemBought(itemId);
    if (result && activeList != null) {
      final checkedCount = activeList!.items.where((i) => i.bought).length;
      _analytics?.shopping.logShoppingListItemChecked(
        listId: activeList!.id,
        itemCount: checkedCount,
      );

      if (allItemsBought && activeList!.items.isNotEmpty) {
        _analytics?.shopping.logShoppingListCompleted(
          listId: activeList!.id,
          itemCount: activeList!.items.length,
        );
      }

      // BUT-1306: live wiring of the checkoff → pantry policy seam. The service
      // itself gates on a genuine false→true checkoff AND the user's opt-in
      // preference, so an unconditional call here is correct (and a no-op when
      // un-checking or when the preference is off).
      if (wasBought != null) {
        final toggled =
            activeList!.items.where((i) => i.id == itemId).firstOrNull;
        final userId = currentUserId;
        if (toggled != null && userId != null) {
          unawaited(
            _checkoffPantryService?.onItemCheckedOff(
                  userId,
                  toggled,
                  wasBought: wasBought,
                ) ??
                Future<void>.value(),
          );
        }
      }
    }
    return result;
  }

  // ── BUT-1306: auto-add-bought-to-pantry preference (Settings toggle + the
  //    one-time first-checkoff prompt). Reads/writes the complete user profile
  //    via UserService, not PermissionService (data-source rule). ──

  /// Current value of the "auto-add bought items to pantry" opt-in (default off).
  bool get autoAddBoughtToPantry =>
      _userService?.currentUserProfile?.autoAddBoughtToPantry ?? false;

  /// Whether the one-time first-checkoff prompt has already been shown.
  bool get pantryAutoAddPrompted =>
      _userService?.currentUserProfile?.pantryAutoAddPrompted ?? true;

  /// True only when the first-checkoff prompt should fire: it hasn't been shown
  /// yet AND the user hasn't already opted in. Drives the one-time dialog.
  bool get shouldShowFirstCheckoffPrompt =>
      !pantryAutoAddPrompted && !autoAddBoughtToPantry;

  /// Persist the Settings toggle. Notifies so a watching settings tile rebuilds.
  Future<void> setAutoAddToPantry(bool enabled) async {
    await _userService?.setAutoAddToPantry(enabled);
    notifyListeners();
  }

  /// Record that the first-checkoff prompt has been shown so it never re-nags.
  Future<void> markPantryAutoAddPrompted() async {
    await _userService?.markPantryAutoAddPrompted();
    notifyListeners();
  }

  Future<bool> removeItem(String itemId) async {
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

  // ── Category management ──

  /// Effective category order for the active list
  List<String> get categoryOrder {
    return _shoppingService.categoryPreferences
        .getEffectiveCategoryOrder(activeList?.id);
  }

  /// Move an item to a different category (updates item + saves user override)
  Future<bool> moveItemToCategory(String itemId, String newCategory) async {
    if (!canEditActiveList) return false;

    final result = await _shoppingService.updateItemInActiveList(
      itemId: itemId,
      category: newCategory,
    );
    if (result) {
      final item = items.where((i) => i.id == itemId).firstOrNull;
      if (item != null) {
        _shoppingService.categoryPreferences
            .setItemCategory(item.name, newCategory);
      }
    }
    return result;
  }

  /// Save category order for the active list
  Future<void> saveCategoryOrder(List<String> order) async {
    if (activeList == null) return;
    await _shoppingService.categoryPreferences
        .saveListCategoryOrder(activeList!.id, order);
    notifyListeners();
  }

  /// Save user's default category order
  Future<void> saveDefaultCategoryOrder(List<String> order) async {
    await _shoppingService.categoryPreferences.saveDefaultCategoryOrder(order);
    notifyListeners();
  }

  /// Reset active list's category order to user default
  Future<void> resetListCategoryOrder() async {
    if (activeList == null) return;
    await _shoppingService.categoryPreferences
        .resetListCategoryOrder(activeList!.id);
    notifyListeners();
  }

  /// Load list-specific category order (call when switching lists)
  Future<void> loadCategoryOrderForActiveList() async {
    if (activeList == null) return;
    await _shoppingService.categoryPreferences
        .loadListCategoryOrder(activeList!.id);
    notifyListeners();
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

    final permissionService = ServiceLocator.get<PermissionService>();
    final canEdit = permissionService.canEditShoppingList(activeList!.id);

    AppLogger.info(
        'Permission check - List: ${activeList!.name} (${activeList!.type}), User: $currentUserId, CanEdit: $canEdit');

    return canEdit;
  }

  /// Check if the user can manage the active list
  bool get canManageActiveList {
    if (activeList == null || currentUserId == null) return false;

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
    _shoppingServiceSubscription?.cancel();
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
