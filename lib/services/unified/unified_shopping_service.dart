/// Unified shopping service for personal and collaborative shopping list management.
/// Implements facade pattern coordinating personal operations, collaborative sharing,
/// and real-time synchronization with Firebase.

import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rxdart/rxdart.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/mixins/firebase_sync_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';
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
import 'package:butlery/services/unified/shopping_failure_message.dart';
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
  }) : _firestoreRepository = firestoreRepository,
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
      mutateSharedList: mutateSharedList,
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
      // BUT-1696: the checkbox on a shared list reaches Firestore through this
      // module, not through mutateSharedList, so it needs the same seam to
      // report WHY an optimistic tick was rolled back.
      reportFailure: _failMutation,
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

  /// Why the LAST mutation failed, kept strictly apart from [_error].
  ///
  /// BUT-1696 originally wrote mutation failures into [_error], which is
  /// load-scoped: [hasError] and [_emitState] read it, so a transient "you may
  /// not edit this list" replaced the whole shopping tab with a full-screen
  /// error + retry button, and it stayed there until the next
  /// `initialize()`/`loadLists()` because this service is a lazy singleton.
  /// This field is read ONLY through [consumeMutationError], which self-clears,
  /// so no caller has to remember to clean up and no ordering hazard (an early
  /// `if (!mounted) return;`) can leave a sticky error behind.
  String? _lastMutationError;
  StreamSubscription<List<UnifiedShoppingList>>? _collaborativeStreamSub;

  final _stateSubject = BehaviorSubject<ShoppingServiceState>.seeded(
    const ShoppingStateLoading(),
  );

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
    _stateSubject.add(
      ShoppingStateData(
        lists: _lists,
        activeListId: _activeListId,
        error: _error,
      ),
    );
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

  /// BUT-1697: the PROFILE name, not the Auth handle, and never a placeholder.
  ///
  /// This getter feeds persisted attribution — `ownerDisplayName` and
  /// `lastActivityByDisplayName` on a document other household members read —
  /// so the literal `'Du'` it used to fall back to was written into their copy
  /// of the list and shown to them as the editor's name. An unresolved name
  /// stamps empty (every display site already guards `isNotEmpty`), which is
  /// honest; the "Du" wording belongs at display time, to the person it is
  /// actually about. Same source as `FirebaseShoppingRepository`'s
  /// `resolveDisplayName`, so the two writers cannot disagree.
  String? get currentUserDisplayName =>
      ServiceLocator.tryGet<UserService>()?.currentDisplayName;
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
    _error = null;
    notifyListeners();
    try {
      await Future.wait([
        _initialization.initialize(),
        _categoryPreferences.load(),
      ]);
      _startCollaborativeStream();
    } catch (e) {
      // Record the error so _emitState can surface a ShoppingStateError when
      // there are no cached lists to fall back on. Without this the failure
      // path silently emits an empty ShoppingStateData (lists:[], error:null)
      // and the UI shows an empty list instead of an error state.
      AppLogger.error('Failed to initialize shopping service', e);
      _error = AppLocale.current.shoppingCouldNotLoadLists;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startCollaborativeStream() {
    _collaborativeStreamSub?.cancel();
    _collaborativeStreamSub = _shoppingRepository.collaborativeListsStream().listen(
      (collabLists) {
        _lists.removeWhere((l) => l.isCollaborative);
        _lists.addAll(collabLists);
        notifyListeners();
      },
      onError: (Object e, StackTrace _) {
        AppLogger.error('Collaborative list stream error', e);
        // Surface to the UI when there is nothing cached to show. If personal
        // lists are already loaded, data wins over the stale error (see
        // _emitState), so this only flips to an error state on a cold failure.
        _error = AppLocale.current.shoppingCouldNotLoadLists;
        notifyListeners();
      },
    );
  }

  /// Load lists - alias for initialize for compatibility
  Future<void> loadLists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _initialization.loadLists();
    } catch (e) {
      AppLogger.error('Failed to load shopping lists', e);
      _error = AppLocale.current.shoppingCouldNotLoadLists;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createPersonalList(
    String name, {
    List<UnifiedShoppingItem>? items,
  }) async {
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

  /// BUT-1665: single-item mutation of a SHARED list, applied server-side.
  ///
  /// [updateList] writes the whole list from the client's cached copy, which
  /// loses a household member's concurrent tick. This routes the same model
  /// mutator through a Firestore transaction so the merge happens against the
  /// live document. The local copy is refreshed optimistically; the
  /// collaborative snapshot stream is still the authority and lands right
  /// after.
  /// BUT-1696: the three ways this can fail are three different things to tell
  /// the user, and collapsing them into a bare `false` made a denied edit look
  /// like a checkbox that ticks and un-ticks itself. The wording comes from
  /// [shoppingFailureMessage] — the ONE mapping, shared with the item module,
  /// so a new failure class can never be worded here and not there. It is read
  /// back via [consumeMutationError], NOT via [error], which would turn a
  /// failed tick into a full-screen error state; the bool still says only "did
  /// it land". The typed arms survive only for their distinct log lines.
  Future<bool> mutateSharedList(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  ) async {
    _beginMutation();
    try {
      final merged = await _shoppingRepository.mutateCollaborativeList(
        listId,
        mutate,
      );
      final index = _lists.indexWhere((l) => l.id == merged.id);
      if (index >= 0) {
        _lists[index] = merged;
        notifyListeners();
      }
      return true;
    } on PermissionDeniedException catch (e) {
      AppLogger.warning(
        'Edit denied on shared list $listId: ${e.message}',
        'ShoppingService',
      );
      _failMutation(shoppingFailureMessage(e, shared: true));
      return false;
    } on ResourceNotFoundException catch (e) {
      AppLogger.warning(
        'Shared list $listId is gone: ${e.message}',
        'ShoppingService',
      );
      _failMutation(shoppingFailureMessage(e, shared: true));
      return false;
    } on FirebaseException catch (e) {
      // A denial raised by the RULES rather than by a client-side guard arrives
      // as a raw FirebaseException; [shoppingFailureMessage] has the arm for it,
      // so the server's verdict cannot reach the shopper as "check your
      // connection" — that is the BUT-1696 defect wearing a different mask.
      AppLogger.warning(
        'Shared list $listId mutation failed with ${e.code}: ${e.message}',
        'ShoppingService',
      );
      _failMutation(shoppingFailureMessage(e, shared: true));
      return false;
    } catch (e) {
      AppLogger.error('Failed to mutate shared list $listId', e);
      _failMutation(shoppingFailureMessage(e, shared: true));
      return false;
    }
  }

  /// Records why a mutation failed so the view can show it. Deliberately does
  /// NOT touch [_error]: the lists are still loaded and valid, so a failed tick
  /// must never turn into a full-screen error state.
  void _failMutation(String message) {
    _lastMutationError = message;
  }

  /// Drops any reason left behind by an earlier mutation.
  ///
  /// Read-to-clear is not enough on its own: a caller that shows its own static
  /// message and never consumes — the collaborative screen does exactly that on
  /// "rensa klara" — parks a sentence in the slot, and the next action to
  /// return `false` WITHOUT reporting (a row another member deleted, which is
  /// deliberately silent) would surface that stale sentence as its cause. Every
  /// mutation entry point clears on the way in, so a reason can only ever
  /// describe the action the user just took.
  void _beginMutation() {
    _lastMutationError = null;
  }

  /// Records a mutation failure decided ABOVE this service — a ViewModel that
  /// refuses a tap on a list the member may not edit never reaches
  /// [mutateSharedList], so without this the view would fall back to the
  /// cause-free generic message on the one case BUT-1696 is named for.
  void reportMutationFailure(String message) => _failMutation(message);

  /// Reads and clears the reason the last mutation failed. Returns null when
  /// the last mutation did not report one.
  ///
  /// Self-clearing on read is the point: a caller that shows the message cannot
  /// forget to clean up, and a caller that bails early (`if (!mounted) return;`)
  /// cannot strand it for the next reader.
  String? consumeMutationError() {
    final message = _lastMutationError;
    _lastMutationError = null;
    return message;
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
    _beginMutation();
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
    _beginMutation();
    return await clearCompletedItems();
  }

  Future<bool> uncheckAllItems() async {
    _beginMutation();
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

  /// Add multiple items to active list using high-performance batch operations.
  ///
  /// BUT-1681: this — not `UnifiedShoppingViewModel.addItemsFromRecipe` — is
  /// the path "lägg till receptets ingredienser" actually takes, so the
  /// analytics tag lives here. ONE event carrying [source] and the row count,
  /// not one per row: a recipe adds 8–20 lines and the funnel question is
  /// "where did this list come from", which a count answers as well as N
  /// events would, at 1/Nth the cost.
  Future<bool> addItemsBatch(
    List<UnifiedShoppingItem> items, {
    String source = 'manual',
  }) async {
    final listId = _activeListId;
    final added = await _itemManagement.addItemsBatchToActiveList(items);
    if (added && items.isNotEmpty && listId != null) {
      ServiceLocator.tryGet<AnalyticsService>()?.shopping
          .logShoppingListItemAdded(
            listId: listId,
            source: source,
            itemCount: items.length,
          );
    }
    return added;
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
          '💾 Saved active list ID: $_activeListId',
          'ShoppingService',
        );
      },
      operationName: 'Save active list ID',
      // Don't rethrow - this is not critical for app functionality
    );
  }

  void clearError() {
    _error = null;
    _lastMutationError = null;
    notifyListeners();
  }

  /// Test seam — injects an error string without going through any real
  /// error-producing code path. Allows unit tests to exercise the
  /// `_emitState` branch where `_error != null` but `_lists` is non-empty
  /// (data wins over stale error).
  @visibleForTesting
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void resetForLogout() {
    _collaborativeStreamSub?.cancel();
    _collaborativeStreamSub = null;
    stopFirebaseSync();
    _lists.clear();
    _activeListId = null;
    _error = null;
    _lastMutationError = null;
    _categoryPreferences.reset();
    _stateSubject.add(const ShoppingStateLoading());
  }

  void dispose() {
    _collaborativeStreamSub?.cancel();
    stopFirebaseSync();
    _stateSubject.close();
  }
}
