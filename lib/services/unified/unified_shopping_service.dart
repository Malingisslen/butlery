/// Unified shopping service for personal and collaborative shopping list management.
///
/// Implements facade pattern coordinating personal operations, collaborative sharing,
/// and real-time synchronization with Firebase.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/mixins/firebase_sync_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/operations/personal_shopping_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';

// Module imports
import 'package:butlery/services/unified/modules/shopping_initialization_module.dart';
import 'package:butlery/services/unified/modules/shopping_list_management_module.dart';
import 'package:butlery/services/unified/modules/shopping_item_management_module.dart';

/// Stub firebase sync implementation
class ShoppingFirebaseSync {
  ShoppingFirebaseSync();
  List<SyncCollection> get syncCollections => [];
  Future<void> syncItemToFirebase(String itemId, dynamic data) async {}
}

/// Unified shopping service implementing facade pattern for shopping list management.
class UnifiedShoppingService extends ChangeNotifier
    with FirebaseSyncMixin<UnifiedShoppingList>, ErrorHandlingMixin {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  final ShoppingRepository _shoppingRepository;
  late final JsonCacheHelper _cacheHelper;
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  // Feature interfaces
  late final PersonalShoppingOperations _personalOps;
  late final CollaborativeShoppingOperations _collaborativeOps;

  // Lazy getter to avoid circular dependency during DI initialization
  ShoppingShareOperations get _shareOps =>
      __shareOps ??= ShoppingShareOperations(
        firestoreRepository: _firestoreRepository,
        permissionService: ServiceLocator.get<PermissionService>(),
      );
  ShoppingShareOperations? __shareOps;

  // Feature modules
  late final ShoppingInitializationModule _initialization;
  late final ShoppingListManagementModule _listManagement;
  late final ShoppingItemManagementModule _itemManagement;
  late final ShoppingFirebaseSync _firebaseSync;

  UnifiedShoppingService({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    required ShoppingRepository shoppingRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository,
        _shoppingRepository = shoppingRepository {
    _initializeModules();
  }

  void _initializeModules() {
    // Initialize cache helper for active list persistence
    _cacheHelper = JsonCacheHelper('unified_shopping_lists_cache');

    // Initialize feature interfaces
    _personalOps = PersonalShoppingOperations(this);
    _collaborativeOps = CollaborativeShoppingOperations(this);
    // Lazy initialize shareOps to avoid circular dependency during DI setup
    // PermissionService will be retrieved when first needed

    // Initialize feature modules with dependency injection
    _initialization = ShoppingInitializationModule(
      authRepository: _authRepository,
      shoppingRepository: _shoppingRepository,
      cacheHelper: _cacheHelper,
      lists: _lists,
      getActiveListId: () => _activeListId,
      setActiveListId: (id) => _activeListId = id,
      notifyListeners: notifyListeners,
      saveActiveListId: _saveActiveListId,
    );

    _listManagement = ShoppingListManagementModule(
      repository: _shoppingRepository,
      lists: _lists,
      getActiveListId: () => _activeListId,
      setActiveListId: (id) => _activeListId = id,
      notifyListeners: notifyListeners,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      saveActiveListId: _saveActiveListId,
    );

    _itemManagement = ShoppingItemManagementModule(
      repository: _shoppingRepository,
      lists: _lists,
      getActiveListId: () => _activeListId,
      notifyListeners: notifyListeners,
    );

    _firebaseSync = ShoppingFirebaseSync();
  }

  // State
  final List<UnifiedShoppingList> _lists = [];
  String? _activeListId;
  final bool _isLoading = false;
  String? _error;

  // Feature interface getters
  PersonalShoppingOperations get personal => _personalOps;
  CollaborativeShoppingOperations get collaborative => _collaborativeOps;
  ShoppingShareOperations get share => _shareOps;

  /// Compatibility getter for legacy code
  ShoppingShareOperations get sharing => _shareOps;

  // ===== GETTERS =====

  List<UnifiedShoppingList> get lists {
    // Deduplication safety: Remove duplicates by ID only
    final seen = <String>{};
    final deduplicated = _lists.where((list) {
      // Skip if we've already seen this ID
      if (seen.contains(list.id)) {
        AppLogger.warning(
            'DUPLICATE SAFETY: Removing duplicate list with ID: ${list.id} (${list.name})');
        return false;
      }

      seen.add(list.id);
      return true;
    }).toList();

    return List.unmodifiable(deduplicated);
  }

  List<UnifiedShoppingList> get personalLists =>
      lists.where((l) => l.isPersonal).toList();
  List<UnifiedShoppingList> get collaborativeLists =>
      lists.where((l) => l.isCollaborative).toList();

  UnifiedShoppingList? get activeList => _itemManagement.activeList;
  String? get activeListId => _activeListId;
  bool get hasLists => _lists.isNotEmpty;
  bool get isInitialized => _initialization.isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  @override
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;
  String? get currentUserDisplayName =>
      _authRepository.getCurrentUser()?.displayName ?? 'Du';

  // ===== FIREBASE SYNC MIXIN IMPLEMENTATION =====

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  List<SyncCollection> get syncCollections => _firebaseSync.syncCollections;

  @override
  Future<void> syncItemToFirebase(String itemId) async {
    await _firebaseSync.syncItemToFirebase(itemId, _lists);
  }

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    await _initialization.initialize();
  }

  /// Load lists - alias for initialize for compatibility
  Future<void> loadLists() async {
    await _initialization.loadLists();
  }

  // ===== LIST MANAGEMENT =====

  Future<String?> createPersonalList(String name,
      {List<UnifiedShoppingItem>? items}) async {
    return await _listManagement.createPersonalList(name, items: items);
  }

  Future<String?> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    return await _listManagement.createCollaborativeList(
      name: name,
      description: description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );
  }

  Future<String?> createCollaborativeListFromInvitation({
    required String name,
    String? description,
    required String ownerId,
    required String ownerDisplayName,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    return await _listManagement.createCollaborativeListFromInvitation(
      name: name,
      description: description,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );
  }

  Future<bool> updateList(UnifiedShoppingList list) async {
    return await _listManagement.updateList(list);
  }

  Future<bool> renameList(String listId, String newName) async {
    return await _listManagement.renameList(listId, newName);
  }

  Future<bool> deleteList(String listId) async {
    return await _listManagement.deleteList(listId);
  }

  Future<bool> setActiveList(String listId) async {
    return await _listManagement.setActiveList(listId);
  }

  String exportListAsText([String? listId]) {
    final targetListId = listId ?? activeListId;
    if (targetListId == null) return '';
    return _listManagement.exportListAsText(targetListId);
  }

  // ===== ITEM MANAGEMENT =====

  Future<bool> addItemToActiveList({
    required String name,
    double? amount,
    String? unit,
    String? category,
    String? note,
    double? estimatedPrice,
    int? priority,
    String? recipeId,
    String? recipeName,
  }) async {
    return await _itemManagement.addItemToActiveList(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
      recipeId: recipeId,
      recipeName: recipeName,
    );
  }

  Future<bool> toggleItemBought(String itemId) async {
    return await _itemManagement.toggleItemBought(itemId);
  }

  Future<bool> removeItemFromActiveList(String itemId) async {
    return await _itemManagement.removeItemFromActiveList(itemId);
  }

  Future<bool> updateItemInActiveList({
    required String itemId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? notes,
    double? estimatedPrice,
    int? priority,
  }) async {
    return await _itemManagement.updateItemInActiveList(
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

  Future<bool> clearCompletedItems() async {
    return await _itemManagement.clearCompletedItems();
  }

  /// Alias for clearCompletedItems for backward compatibility
  Future<bool> clearBoughtItems() async {
    return await clearCompletedItems();
  }

  Future<bool> uncheckAllItems() async {
    return await _itemManagement.uncheckAllItems();
  }

  Future<bool> addItemsFromRecipe({
    required String recipeId,
    required String recipeName,
    required List<UnifiedShoppingItem> items,
  }) async {
    return await _itemManagement.addItemsFromRecipe(
      recipeId: recipeId,
      recipeName: recipeName,
      items: items,
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Add multiple items to active list using high-performance batch operations
  Future<bool> addItemsBatch(List<UnifiedShoppingItem> items) async {
    return await _itemManagement.addItemsBatchToActiveList(items);
  }

  // ===== INTERNAL METHODS =====

  /// Save active list ID to cache for persistence across app restarts
  Future<void> _saveActiveListId() async {
    await safeExecute(
      () async {
        const activeListKey = 'active_list_id';
        await _cacheHelper.saveActiveId(activeListKey, _activeListId);
        AppLogger.debug(
            '💾 Saved active list ID: $_activeListId', 'ShoppingService');
      },
      operationName: 'Save active list ID',
      // Don't rethrow - this is not critical for app functionality
    );
  }

  // ===== ERROR HANDLING =====

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}
