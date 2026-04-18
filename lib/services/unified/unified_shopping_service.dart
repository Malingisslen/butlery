/// Unified shopping service for personal and collaborative shopping list management.
/// Implements facade pattern coordinating personal operations, collaborative sharing,
/// and real-time synchronization with Firebase.

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:butlery/services/unified/types/service_states.dart';
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
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_member_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_item_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_activity_operations.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/offline_service.dart';

// Module imports
import 'package:butlery/services/unified/modules/shopping_initialization_module.dart';
import 'package:butlery/services/unified/modules/shopping_list_management_module.dart';
import 'package:butlery/services/unified/modules/shopping_item_management_module.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';

/// Stub firebase sync implementation
class ShoppingFirebaseSync {
  ShoppingFirebaseSync();
  List<SyncCollection> get syncCollections => [];
  Future<void> syncItemToFirebase(String itemId, dynamic data) async {}
}

/// Unified shopping service implementing facade pattern for shopping list management.
///
/// ## Usage
/// ```dart
/// final service = ServiceLocator.get<UnifiedShoppingService>();
///
/// // Create a shopping list
/// final list = await service.createList(title: 'Weekly Groceries');
///
/// // Add items
/// await service.addItemsFromRecipe(list.id, recipe);
///
/// // Collaborate
/// await service.shareList(listId: list.id, userIds: ['friend1']);
/// ```
class UnifiedShoppingService
    with FirebaseSyncMixin<UnifiedShoppingList>, ErrorHandlingMixin {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  final ShoppingRepository _shoppingRepository;
  JsonCacheHelper? _cacheHelper;
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  /// Lazy getter for cache helper - initializes from OfflineService when first accessed
  JsonCacheHelper get cacheHelper {
    if (_cacheHelper == null) {
      final offlineService = ServiceLocator.get<OfflineService>();
      _cacheHelper = JsonCacheHelper(
        'unified_shopping_lists_cache',
        offlineService.database.cacheDao,
      );
    }
    return _cacheHelper!;
  }

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
  late final ShoppingCategoryPreferencesModule _categoryPreferences;
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
    // Note: _cacheHelper is lazily initialized via cacheHelper getter
    // This avoids circular dependency with OfflineService during DI setup

    // Initialize feature interfaces
    _personalOps = PersonalShoppingOperations(
      getPersonalLists: () => personalLists,
      getActiveList: () => activeList,
      getActiveListId: () => _activeListId,
      createPersonalList: createPersonalList,
      renameList: renameList,
      deleteList: deleteList,
      setActiveList: setActiveList,
      addItemToActiveList: addItemToActiveList,
      updateList: updateList,
      toggleItemBought: toggleItemBought,
      removeItemFromActiveList: removeItemFromActiveList,
      clearBoughtItems: clearBoughtItems,
      uncheckAllItems: uncheckAllItems,
    );

    final lifecycleOps = ListLifecycleOperations(
      getCollaborativeLists: () => collaborativeLists,
      getPersonalLists: () => personalLists,
      createCollaborativeList: createCollaborativeList,
      deleteList: deleteList,
      createPersonalList: createPersonalList,
    );

    final memberOps = ListMemberOperations(
      getCurrentUserId: () => currentUserId,
      updateList: updateList,
      lifecycleOps: lifecycleOps,
    );

    final itemOps = ListItemOperations(
      getCurrentUserId: () => currentUserId,
      getCurrentUserDisplayName: () => currentUserDisplayName,
      updateList: updateList,
      lifecycleOps: lifecycleOps,
    );

    final activityOps = ListActivityOperations(lifecycleOps);

    _collaborativeOps = CollaborativeShoppingOperations(
      lifecycleOps: lifecycleOps,
      memberOps: memberOps,
      itemOps: itemOps,
      activityOps: activityOps,
    );
    // Lazy initialize shareOps to avoid circular dependency during DI setup
    // PermissionService will be retrieved when first needed

    // Initialize feature modules with dependency injection
    _initialization = ShoppingInitializationModule(
      authRepository: _authRepository,
      shoppingRepository: _shoppingRepository,
      getCacheHelper: () => cacheHelper,
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
      getCategoryPreferences: () => _categoryPreferences,
    );

    _categoryPreferences = ShoppingCategoryPreferencesModule(
      repository: ServiceLocator.get<CategoryPreferencesRepository>(),
    );

    _firebaseSync = ShoppingFirebaseSync();
  }

  // State
  final List<UnifiedShoppingList> _lists = [];
  String? _activeListId;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<UnifiedShoppingList>>? _collaborativeStreamSub;

  final _stateSubject = BehaviorSubject<ShoppingServiceState>.seeded(
      const ShoppingStateLoading());

  Stream<ShoppingServiceState> get stateStream => _stateSubject.stream;
  ShoppingServiceState get currentState => _stateSubject.value;

  @override
  void onSyncStateChanged() => notifyListeners();

  void notifyListeners() {
    _emitState();
  }

  void _emitState() {
    if (_stateSubject.isClosed) return;
    if (_error != null && _lists.isEmpty) {
      _stateSubject.add(ShoppingStateError(message: _error!));
      return;
    }
    _stateSubject.add(ShoppingStateData(
      lists: _lists,
      activeListId: _activeListId,
      error: _error,
    ));
  }

  // Feature interface getters
  PersonalShoppingOperations get personal => _personalOps;
  CollaborativeShoppingOperations get collaborative => _collaborativeOps;
  ShoppingShareOperations get share => _shareOps;
  ShoppingCategoryPreferencesModule get categoryPreferences =>
      _categoryPreferences;

  /// Compatibility getter for legacy code
  ShoppingShareOperations get sharing => _shareOps;
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
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;
  String? get currentUserDisplayName =>
      _authRepository.getCurrentUser()?.displayName ?? 'Du';
  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  List<SyncCollection> get syncCollections => _firebaseSync.syncCollections;

  @override
  Future<void> syncItemToFirebase(String itemId) async {
    await _firebaseSync.syncItemToFirebase(itemId, _lists);
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _initialization.initialize(),
        _categoryPreferences.load(),
      ]);
      _startCollaborativeStream();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startCollaborativeStream() {
    _collaborativeStreamSub?.cancel();
    _collaborativeStreamSub =
        _shoppingRepository.collaborativeListsStream().listen(
      (collabLists) {
        _lists.removeWhere((l) => l.isCollaborative);
        _lists.addAll(collabLists);
        notifyListeners();
      },
      onError: (Object e, StackTrace _) =>
          AppLogger.error('Collaborative list stream error', e),
    );
  }

  /// Load lists - alias for initialize for compatibility
  Future<void> loadLists() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _initialization.loadLists();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

  /// Update a single item on a collaborative list (BUT-238 claim/unclaim).
  /// Goes through the repository's updateItem which enforces permission rules
  /// and refreshes local cache via the collaborative stream. Returns true
  /// when Firestore confirms the write; false on any failure.
  Future<bool> updateCollaborativeItem(
    String listId,
    UnifiedShoppingItem item,
  ) async {
    try {
      await _shoppingRepository.updateItem(listId, item);
      // Optimistically reflect in local state — the collaborative stream
      // will reconcile with the authoritative server copy shortly.
      final listIndex = _lists.indexWhere((l) => l.id == listId);
      if (listIndex >= 0) {
        final items = List<UnifiedShoppingItem>.from(_lists[listIndex].items);
        final itemIndex = items.indexWhere((i) => i.id == item.id);
        if (itemIndex >= 0) {
          items[itemIndex] = item;
          _lists[listIndex] = _lists[listIndex].copyWith(items: items);
          notifyListeners();
        }
      }
      return true;
    } catch (e, st) {
      AppLogger.error('updateCollaborativeItem failed', e, null, st);
      return false;
    }
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

  /// Add multiple items to active list using high-performance batch operations
  Future<bool> addItemsBatch(List<UnifiedShoppingItem> items) async {
    return await _itemManagement.addItemsBatchToActiveList(items);
  }

  // Template operations (delegating to repository)

  Future<List<Map<String, dynamic>>> getUserTemplates() async {
    return await _shoppingRepository.getUserTemplates();
  }

  Future<void> deleteTemplate(String templateId) async {
    await _shoppingRepository.deleteTemplate(templateId);
  }

  Future<String> createListFromTemplate({
    required String templateId,
    String? listName,
  }) async {
    return await _shoppingRepository.createListFromTemplate(
      templateId: templateId,
      listName: listName ?? 'Inköpslista',
    );
  }

  /// Save active list ID to cache for persistence across app restarts
  Future<void> _saveActiveListId() async {
    await safeExecute(
      () async {
        const activeListKey = 'active_list_id';
        await cacheHelper.saveActiveId(activeListKey, _activeListId);
        AppLogger.debug(
            '💾 Saved active list ID: $_activeListId', 'ShoppingService');
      },
      operationName: 'Save active list ID',
      // Don't rethrow - this is not critical for app functionality
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetForLogout() {
    _collaborativeStreamSub?.cancel();
    _collaborativeStreamSub = null;
    stopFirebaseSync();
    _lists.clear();
    _activeListId = null;
    _error = null;
    _categoryPreferences.reset();
    _stateSubject.add(const ShoppingStateLoading());
  }

  void dispose() {
    _collaborativeStreamSub?.cancel();
    stopFirebaseSync();
    _stateSubject.close();
  }
}
