// lib/viewmodels/unified_shopping_viewmodel.dart

/// 🧠 UNIFIED SHOPPING VIEWMODEL
/// Ersätter shopping_list_viewmodel.dart med alla features
/// Kopplar samman UI med UnifiedShoppingService

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../services/unified/unified_shopping_service.dart';
import '../services/permission_service.dart';
import '../models/unified/unified_shopping_item.dart';
import '../models/unified/unified_shopping_list.dart';

class UnifiedShoppingViewModel extends ChangeNotifier {
  final UnifiedShoppingService _shoppingService =
      GetIt.instance<UnifiedShoppingService>();

  // ===== GETTERS - samma API som din befintliga shopping_list_viewmodel =====

  // Lists och state
  List<UnifiedShoppingList> get lists => _shoppingService.lists;
  List<UnifiedShoppingList> get personalLists => _shoppingService.personalLists;
  List<UnifiedShoppingList> get collaborativeLists =>
      _shoppingService.collaborativeLists;
  UnifiedShoppingList? get activeList => _shoppingService.activeList;
  List<UnifiedShoppingItem> get items => activeList?.items ?? [];

  // Loading states
  bool get isLoading => _shoppingService.isLoading;
  bool get isSyncing => _shoppingService.isSyncing;
  bool get isInitialized => _shoppingService.isInitialized;

  // Error handling
  String? get error => _shoppingService.error;
  bool get hasError => _shoppingService.hasError;

  // Connection status
  bool get isOnline => !hasError && isInitialized;

  // Lista existence checks
  bool get hasLists => _shoppingService.hasLists;
  bool get hasItems => items.isNotEmpty;

  // Shopping statistics - samma som du har idag
  int get totalItems => activeList?.totalItems ?? 0;
  int get boughtItems => activeList?.boughtItems ?? 0;
  int get unboughtItems => activeList?.unboughtItems ?? 0;
  double get completionPercentage => activeList?.completionPercentage ?? 0.0;
  String get listSummary => activeList?.summary ?? 'Ingen aktiv lista';
  bool get allItemsBought => activeList?.allItemsBought ?? false;

  // User info
  String? get currentUserId => GetIt.instance<PermissionService>().currentUserId;
  String? get currentUserDisplayName => _shoppingService.currentUserDisplayName;

  UnifiedShoppingViewModel() {
    // Lyssna på service changes - samma pattern som innan
    _shoppingService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    try {
      await _shoppingService.initialize();

      // Om inga listor finns, skapa en default lista
      if (!hasLists && GetIt.instance<PermissionService>().currentUserId != null) {
        await createPersonalList('Min Inköpslista');
      }
    } catch (e) {
      debugPrint('Fel vid ViewModel initialisering: $e');
    }
  }

  // ===== LIST MANAGEMENT - samma metoder som din befintliga ViewModel =====

  Future<bool> createPersonalList(String name) async {
    if (name.trim().isEmpty) return false;

    final listId = await _shoppingService.createPersonalList(name.trim());
    return listId != null;
  }

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

  Future<bool> renameActiveList(String newName) async {
    if (activeList == null || newName.trim().isEmpty) return false;
    return await _shoppingService.renameList(activeList!.id, newName.trim());
  }

  Future<bool> deleteActiveList() async {
    if (activeList == null) return false;
    return await _shoppingService.deleteList(activeList!.id);
  }

  Future<bool> setActiveList(String listId) async {
    return await _shoppingService.setActiveList(listId);
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
    if (name.trim().isEmpty) return false;

    return await _shoppingService.addItemToActiveList(
      name: name.trim(),
      amount: amount,
      unit: unit,
      category: category,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
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
    return await _shoppingService.toggleItemBought(itemId);
  }

  Future<bool> removeItem(String itemId) async {
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
    try {
      for (final ingredient in ingredientData) {
        await addItem(
          name: ingredient['name'] as String,
          amount: (ingredient['amount'] as num).toDouble(),
          unit: ingredient['unit'] as String? ?? '',
          category: ingredient['category'] as String? ?? 'Övrigt',
        );
      }
      return true;
    } catch (e) {
      debugPrint('Fel vid bulk add: $e');
      return false;
    }
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
    if (activeList == null || currentUserId == null) return false;
    return GetIt.instance<PermissionService>().canEditShoppingList(activeList!.id);
  }

  /// Kontrollera om användaren kan hantera aktiv lista
  bool get canManageActiveList {
    if (activeList == null || currentUserId == null) return false;
    return GetIt.instance<PermissionService>().canManageShoppingList(activeList!.id);
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
