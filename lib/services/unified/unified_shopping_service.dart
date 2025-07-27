// lib/services/unified/unified_shopping_service.dart - FACADE PATTERN

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/firebase_sync_mixin.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/unified/operations/personal_shopping_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/services/unified/modules/shopping_service_initialization.dart';
import 'package:butlery/services/unified/modules/shopping_list_management.dart';
import 'package:butlery/services/unified/modules/shopping_item_management.dart';
import 'package:butlery/services/unified/modules/shopping_firebase_sync.dart';
import 'package:butlery/services/unified/modules/shopping_cache_management.dart';

class UnifiedShoppingService extends ChangeNotifier with FirebaseSyncMixin<UnifiedShoppingList> {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;
  
  // Feature interfaces
  late final PersonalShoppingOperations _personalOps;
  late final CollaborativeShoppingOperations _collaborativeOps;
  late final ShoppingShareOperations _shareOps;
  
  // Feature modules
  late final ShoppingServiceInitialization _initialization;
  late final ShoppingListManagement _listManagement;
  late final ShoppingItemManagement _itemManagement;
  late final ShoppingFirebaseSync _firebaseSync;
  late final ShoppingCacheManagement _cacheManagement;
  
  /// JSON cache helper for shopping list data
  late final JsonCacheHelper _cacheHelper;

  UnifiedShoppingService({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
  }) : _firestoreRepository = firestoreRepository,
       _authRepository = authRepository {
    _initializeModules();
  }

  void _initializeModules() {
    // Initialize cache helper
    _cacheHelper = JsonCacheFactory.shoppingCache();
    
    // Initialize feature interfaces
    _personalOps = PersonalShoppingOperations(this);
    _collaborativeOps = CollaborativeShoppingOperations(this);
    _shareOps = ShoppingShareOperations(this);
    
    // Initialize feature modules
    _initialization = ShoppingServiceInitialization(
      firestoreRepository: _firestoreRepository,
      authRepository: _authRepository,
      cacheHelper: _cacheHelper,
      lists: _lists,
      setActiveListId: _setActiveListId,
      notifyListeners: notifyListeners,
      setError: _setError,
      clearAll: _clearAll,
      startFirebaseSync: startFirebaseSync,
      getCurrentUserId: () => currentUserId,
    );
    
    _cacheManagement = ShoppingCacheManagement(
      cacheHelper: _cacheHelper,
    );
    
    _listManagement = ShoppingListManagement(
      lists: _lists,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setActiveListId: _setActiveListId,
      notifyListeners: notifyListeners,
      setError: _setError,
      updateListInternal: _updateList,
      saveToCache: _cacheManagement.saveToCache,
      scheduleSyncForItem: scheduleSyncForItem,
      scheduleDeleteForList: _scheduleDeleteForList,
    );
    
    _itemManagement = ShoppingItemManagement(
      lists: _lists,
      getActiveListId: () => _activeListId,
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      setError: _setError,
      updateListInternal: _updateList,
      personalOps: _personalOps,
    );
    
    _firebaseSync = ShoppingFirebaseSync(
      firestore: _firestore,
      getCurrentUserId: () => currentUserId,
      updateLocalList: _updateLocalList,
      removeLocalList: _removeLocalList,
      setError: _setError,
    );
  }

  // State
  final List<UnifiedShoppingList> _lists = [];
  String? _activeListId;
  bool _isLoading = false;
  String? _error;

  // Feature interface getters
  PersonalShoppingOperations get personal => _personalOps;
  CollaborativeShoppingOperations get collaborative => _collaborativeOps;
  ShoppingShareOperations get share => _shareOps;
  
  /// Compatibility getter for legacy code
  ShoppingShareOperations get sharing => _shareOps;

  // ===== GETTERS =====

  List<UnifiedShoppingList> get lists => List.unmodifiable(_lists);
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
  String? get currentUserId => sl<PermissionService>().currentUserId;
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

  // ===== INTERNAL METHODS =====

  void _setActiveListId(String? listId) {
    _activeListId = listId;
    _cacheManagement.saveActiveListId(listId);
  }

  Future<bool> _updateList(UnifiedShoppingList updatedList) async {
    try {
      final index = _lists.indexWhere((list) => list.id == updatedList.id);
      if (index == -1) {
        _setError('Lista hittades inte');
        return false;
      }

      // Uppdatera lokalt (optimistic update)
      _lists[index] = updatedList;
      notifyListeners();

      // Spara till cache
      await _cacheManagement.saveToCache(updatedList);

      // Schemalägg synk using mixin (debounced)
      scheduleSyncForItem(updatedList.id);

      return true;
    } catch (e) {
      AppLogger.error('❌ Kunde inte uppdatera lista: $e');
      _setError('Kunde inte uppdatera lista: $e');
      return false;
    }
  }

  void _scheduleDeleteForList(String listId, bool isCollaborative) {
    // För borttagning, gör direkt utan debounce
    _firebaseSync.deleteListFromFirebase(listId, isCollaborative);
  }

  void _updateLocalList(UnifiedShoppingList updatedList) {
    final index = _lists.indexWhere((l) => l.id == updatedList.id);
    if (index != -1) {
      _lists[index] = updatedList;
    } else {
      _lists.add(updatedList);
    }
    _cacheManagement.saveToCache(updatedList);
  }

  void _removeLocalList(String listId) {
    _lists.removeWhere((l) => l.id == listId);
    _cacheManagement.removeFromCache(listId);
  }

  // ===== ERROR HANDLING =====

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearAll() {
    _lists.clear();
    _activeListId = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopFirebaseSync();
    super.dispose();
  }
}